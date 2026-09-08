import Foundation
import CryptoKit
import Darwin

struct BackupV3Error: LocalizedError {
  let code: String
  let message: String
  var errorDescription: String? { message }
  init(_ code: String, _ message: String) { self.code = code; self.message = message }
}

/// Cancellation is observed by streams and waits. A cancel reply is queued behind
/// the worker, so no application-owned writer survives that reply.
final class BackupV3Cancellation {
  private let lock = NSLock()
  private var stopped = false
  private var callbacks: [UUID: () -> Void] = [:]
  func check() throws {
    lock.lock(); let value = stopped; lock.unlock()
    if value { throw BackupV3Error("cancelled", "操作已取消") }
  }
  func cancel() {
    lock.lock(); stopped = true; let actions = Array(callbacks.values); lock.unlock()
    for action in actions { action() }
  }
  func register(_ action: @escaping () -> Void) -> UUID {
    let id = UUID(); lock.lock(); callbacks[id] = action; let run = stopped; lock.unlock()
    if run { action() }; return id
  }
  func unregister(_ id: UUID) { lock.lock(); callbacks.removeValue(forKey: id); lock.unlock() }
}

enum BackupV3Support {
  static let containerID = "iCloud.com.xuwudi.ochome"
  static let folder = "ochome-backup-v3"
  static let chunkBytes = 1024 * 1024
  static func string(_ map: [String: Any], _ key: String) throws -> String {
    guard let value = map[key] as? String, !value.isEmpty else {
      throw BackupV3Error("invalid_arguments", "缺少有效参数：\(key)")
    }; return value
  }
  static func integer(_ map: [String: Any], _ key: String) throws -> Int64 {
    guard let value = map[key] as? NSNumber,
      CFGetTypeID(value) != CFBooleanGetTypeID(), value.doubleValue.isFinite,
      value.doubleValue >= 0, value.doubleValue <= 9_007_199_254_740_991,
      value.doubleValue.rounded(.towardZero) == value.doubleValue else {
      throw BackupV3Error("invalid_arguments", "无效数字：\(key)")
    }; return value.int64Value
  }
  static func hash(_ value: String) throws -> String {
    guard value.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil else {
      throw BackupV3Error("invalid_arguments", "无效 SHA-256")
    }; return value
  }
  static func digest(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }
  static func uuid(_ value: String) throws -> String {
    guard UUID(uuidString: value) != nil else { throw BackupV3Error("unsafe_path", "无效备份标识") }
    return value
  }
  static func relative(_ value: String, legacy: Bool = false) throws -> String {
    guard !value.hasPrefix("/"), !value.contains("\\"), !value.contains("\0") else {
      throw BackupV3Error("unsafe_path", "备份路径不安全")
    }
    let parts = value.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
    guard !parts.contains(where: { $0.isEmpty || $0.hasPrefix(".") }) else {
      throw BackupV3Error("unsafe_path", "备份路径不安全")
    }
    if legacy {
      guard (parts.count == 1 && ["ochome.sqlite", "manifest.json"].contains(parts[0])) ||
        (parts.count == 2 && ["covers", "role_assets"].contains(parts[0])) else {
        throw BackupV3Error("unsafe_path", "旧备份路径不受支持")
      }
    } else {
      guard parts.count >= 4, parts[0] == "writers" else {
        throw BackupV3Error("unsafe_path", "备份路径不受支持")
      }
      _ = try uuid(parts[1])
      if parts[2] == "objects" && parts.count == 4 { _ = try uuid(parts[3]) }
      else if parts[2] == "snapshots" && parts.count == 5 {
        _ = try uuid(parts[3])
        guard ["database.sqlite", "manifest.json", "contents.json", "commit.json"].contains(parts[4]) else {
          throw BackupV3Error("unsafe_path", "未知快照文件")
        }
      } else { throw BackupV3Error("unsafe_path", "备份路径不受支持") }
    }
    return value
  }
  /// Foundation may leave /private/var unresolved when the final file does not
  /// exist yet. Resolve the nearest existing ancestor, then append missing
  /// components so both sides of an atomic rename use the same physical root.
  static func canonicalFileURL(_ url: URL) -> URL {
    var ancestor = url.standardizedFileURL
    var missing: [String] = []
    while !FileManager.default.fileExists(atPath: ancestor.path) && ancestor.path != "/" {
      missing.append(ancestor.lastPathComponent)
      ancestor.deleteLastPathComponent()
    }
    var resolved = ancestor.resolvingSymlinksInPath()
    for component in missing.reversed() { resolved.appendPathComponent(component) }
    return resolved
  }
  static func contained(_ path: String, root: URL) throws -> URL {
    let url = URL(fileURLWithPath: path).standardizedFileURL
    let resolved = canonicalFileURL(url)
    let canonicalRoot = canonicalFileURL(root)
    let base = canonicalRoot.path + "/"
    guard resolved.path.hasPrefix(base) else {
      throw BackupV3Error("unsafe_path", "文件必须位于 App 管理的目录，且不能是符号链接")
    }
    // /var -> /private/var is a system alias on Apple platforms. Resolve it,
    // while refusing every symlink within the app-owned subtree itself.
    var supplied = url
    while canonicalFileURL(supplied).path.hasPrefix(base) || canonicalFileURL(supplied).path == canonicalRoot.path {
      if (try? FileManager.default.attributesOfItem(atPath: supplied.path)[.type]) as? FileAttributeType == .typeSymbolicLink {
        throw BackupV3Error("unsafe_path", "App 资料路径不能是符号链接")
      }
      supplied.deleteLastPathComponent()
    }
    var current = resolved
    while current.path.count > canonicalRoot.path.count {
      let attributes = try? FileManager.default.attributesOfItem(atPath: current.path)
      if attributes?[.type] as? FileAttributeType == .typeSymbolicLink {
        throw BackupV3Error("unsafe_path", "App 资料路径不能是符号链接")
      }
      current.deleteLastPathComponent()
    }
    // Reject a symlink at the supplied leaf even when it points back inside.
    if (try? FileManager.default.attributesOfItem(atPath: url.path)[.type]) as? FileAttributeType == .typeSymbolicLink {
      throw BackupV3Error("unsafe_path", "App 资料文件不能是符号链接")
    }
    return resolved
  }
  static func supportRoots() throws -> [URL] {
    let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                           appropriateFor: nil, create: true).resolvingSymlinksInPath()
    #if os(macOS)
    guard let bundle = Bundle.main.bundleIdentifier else {
      throw BackupV3Error("storage_unavailable", "无法取得 App 存储目录")
    }
    return [canonicalFileURL(root.appendingPathComponent(bundle, isDirectory: true))]
    #else
    return [canonicalFileURL(root)]
    #endif
  }
  static func owned(_ path: String, write: Bool, controlOnly: Bool = false) throws -> URL {
    for root in try supportRoots() {
      if let url = try? contained(path, root: root) {
        let tail = String(url.path.dropFirst(root.path.count + 1))
        if !write || tail.hasPrefix("storage-control/") || (!controlOnly && tail.hasPrefix("datasets/")) {
          return url
        }
      }
    }
    throw BackupV3Error("unsafe_path", "恢复文件必须写入 App 的准备区")
  }
  static func restoreTarget(_ path: String) throws -> URL {
    let url = try owned(path, write: true)
    let root = try supportRoots()[0]
    let tail = String(url.path.dropFirst(root.path.count + 1))
    if tail.hasPrefix("storage-control/backup-jobs/") || tail.hasPrefix("storage-control/jobs/") { return url }
    guard tail.hasPrefix("datasets/") else { throw BackupV3Error("unsafe_path", "下载目标必须是备份准备区") }
    let parts = tail.split(separator: "/").map(String.init)
    guard parts.count >= 3 else { throw BackupV3Error("unsafe_path", "下载目标必须是文件") }
    let pointerURL = root.appendingPathComponent("storage-control/active.json")
    let handle = try FileHandle(forReadingFrom: pointerURL); defer { try? handle.close() }
    let data = try handle.read(upToCount: 64 * 1024 + 1) ?? Data()
    let pointer = try json(data, maxBytes: 64 * 1024)
    guard try integer(pointer, "format") == 1, pointer["current"] is [String: Any] else {
      throw BackupV3Error("storage_unavailable", "无法确认当前资料，已停止写入")
    }
    for key in ["current", "previous"] {
      if let ref = pointer[key] as? [String: Any], ref["kind"] as? String == "dataset", ref["id"] as? String == parts[1] {
        throw BackupV3Error("unsafe_path", "不能下载到当前资料或恢复前副本")
      }
    }
    return url
  }
  static func appVersion(shortVersion: String?, buildVersion: String?) -> String {
    let short = shortVersion?.trimmingCharacters(in: .whitespacesAndNewlines)
    let build = buildVersion?.trimmingCharacters(in: .whitespacesAndNewlines)
    let version = (short?.isEmpty == false) ? short! : "unknown"
    return (build?.isEmpty == false) ? version + "+" + build! : version
  }
  /// A missing manifest is meaningful only after complete metadata discovery in
  /// the fixed slot. An absent/unfinished discovery never enables weaker legacy
  /// validation, and a manifest in another layout cannot fill this slot's gap.
  static func legacySource(_ relativePath: String, roots: [URL], discoveredURLs: [URL]?,
                           selectedRoot: URL? = nil) throws -> (root: URL, file: URL) {
    _ = try relative(relativePath, legacy: true)
    guard let discovered = discoveredURLs else {
      throw BackupV3Error("discovery_pending", "旧备份文件发现尚未完成，请稍后重试")
    }
    let known = Set(discovered.map { $0.resolvingSymlinksInPath().path })
    let fixed: URL
    if let selected = selectedRoot {
      guard roots.contains(selected) else { throw BackupV3Error("unsafe_path", "旧备份目录不受支持") }
      fixed = selected
    } else {
      guard let root = roots.first(where: { known.contains($0.appendingPathComponent("ochome.sqlite").resolvingSymlinksInPath().path) }) else {
        throw BackupV3Error("legacy_missing", "未发现完整旧版备份目录，请稍后重试")
      }
      fixed = root
    }
    let file = try contained(fixed.appendingPathComponent(relativePath).path, root: fixed)
    if relativePath == "manifest.json" && !known.contains(file.path) {
      throw BackupV3Error("legacy_manifest_missing", "这份旧版备份没有清单，将按旧版资料结构检查")
    }
    return (fixed, file)
  }
  static func iso(_ date: Date) -> String { ISO8601DateFormatter().string(from: date) }
  static func date(_ string: String) throws -> Date {
    let formatter = ISO8601DateFormatter()
    if let date = formatter.date(from: string) { return date }
    formatter.formatOptions.insert(.withFractionalSeconds)
    guard let date = formatter.date(from: string) else { throw BackupV3Error("invalid_format", "无效备份时间") }
    return date
  }
  static func json(_ data: Data, maxBytes: Int = 16 * 1024 * 1024) throws -> [String: Any] {
    guard data.count <= maxBytes, let result = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw BackupV3Error("invalid_format", "备份清单格式或大小不受支持")
    }; return result
  }
  static func encode(_ value: Any) throws -> Data {
    try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
  }
  /// Streams the original bytes once. Empty files are valid. The final name only
  /// appears after fsync and exact length + SHA-256 validation.
  static func verifiedCopy(from source: URL, to destination: URL, bytes: Int64?, sha256: String?,
                           token: BackupV3Cancellation, maximumBytes: Int64? = nil, progress: (Int64) -> Void) throws -> (Int64, String, Bool) {
    try token.check()
    let fm = FileManager.default
    try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
    let temporary = destination.deletingLastPathComponent().appendingPathComponent(".\(UUID().uuidString).part")
    guard fm.createFile(atPath: temporary.path, contents: nil) else { throw BackupV3Error("storage_unavailable", "无法创建准备文件") }
    defer { try? fm.removeItem(at: temporary) }
    let input = try FileHandle(forReadingFrom: source)
    let output = try FileHandle(forWritingTo: temporary)
    defer { try? input.close(); try? output.close() }
    var digest = SHA256(); var count: Int64 = 0; var lastProgress = -Double.infinity
    while true {
      try token.check()
      let data = try input.read(upToCount: chunkBytes) ?? Data()
      if data.isEmpty { break }
      count += Int64(data.count)
      if let maximum = maximumBytes, count > maximum { throw BackupV3Error("invalid_format", "备份元数据超出大小限制") }
      if let expected = bytes, count > expected { throw BackupV3Error("integrity", "文件长度超过备份清单：\(source.lastPathComponent)") }
      digest.update(data: data); try output.write(contentsOf: data)
      let now = ProcessInfo.processInfo.systemUptime
      if now - lastProgress >= 0.1 { progress(count); lastProgress = now }
    }
    let checksum = digest.finalize().map { String(format: "%02x", $0) }.joined()
    if let expected = bytes, count != expected { throw BackupV3Error("integrity", "文件长度不一致：\(source.lastPathComponent)") }
    if let expected = sha256, checksum != expected { throw BackupV3Error("integrity", "文件内容校验失败：\(source.lastPathComponent)") }
    try output.synchronize(); try token.check()
    var created = false
    // Existing immutable targets must already contain these exact bytes.
    if fm.fileExists(atPath: destination.path) {
      let existing = try fingerprint(destination, token: token)
      guard existing.0 == count, existing.1 == checksum else { throw BackupV3Error("immutable_conflict", "同一备份路径已存在不同内容") }
    } else {
      // link is atomic and refuses a concurrently created target; no overwrite.
      if Darwin.link(temporary.path, destination.path) != 0 {
        if errno == EEXIST {
          let existing = try fingerprint(destination, token: token)
          guard existing.0 == count, existing.1 == checksum else { throw BackupV3Error("immutable_conflict", "备份路径发生并发冲突") }
        } else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
      } else { created = true }
    }
    try syncDirectory(destination.deletingLastPathComponent())
    progress(count); return (count, checksum, created)
  }
  static func fingerprint(_ file: URL, token: BackupV3Cancellation) throws -> (Int64, String) {
    let input = try FileHandle(forReadingFrom: file); defer { try? input.close() }
    var digest = SHA256(); var count: Int64 = 0
    while true {
      try token.check(); let data = try input.read(upToCount: chunkBytes) ?? Data()
      if data.isEmpty { break }; digest.update(data: data); count += Int64(data.count)
    }
    return (count, digest.finalize().map { String(format: "%02x", $0) }.joined())
  }
  static func syncDirectory(_ directory: URL) throws {
    let fd = Darwin.open(directory.path, O_RDONLY); guard fd >= 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
    defer { Darwin.close(fd) }
    guard Darwin.fsync(fd) == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
  }
  static func atomicReplace(temporary: URL, destination: URL) throws {
    guard temporary.deletingLastPathComponent() == destination.deletingLastPathComponent(), temporary != destination else {
      throw BackupV3Error("unsafe_path", "存储指针必须在同一目录原子替换")
    }
    let file = try FileHandle(forWritingTo: temporary); try file.synchronize(); try file.close()
    guard Darwin.rename(temporary.path, destination.path) == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
    try syncDirectory(destination.deletingLastPathComponent())
  }
}
