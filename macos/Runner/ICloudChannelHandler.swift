import AppKit
import FlutterMacOS
import Foundation

enum ICloudChannel {
  static let name = "com.xuwudi.ochome/icloud"
  static let containerId = "iCloud.com.xuwudi.ochome"
  static let backupFolder = "ochome-backup"
}

private enum ICloudHandlerError: LocalizedError {
  case unavailable
  case notFound(String)
  case timeout(String)
  case badArgs

  var errorDescription: String? {
    switch self {
    case .unavailable:
      return "未登录 iCloud，或 iCloud 云盘不可用"
    case .notFound(let path):
      return "iCloud 中找不到 \(path)"
    case .timeout(let path):
      return "等待 iCloud 下载超时：\(path)"
    case .badArgs:
      return "iCloud 参数无效"
    }
  }
}

final class ICloudChannelHandler: NSObject {
  static let shared = ICloudChannelHandler()
  private let fileQueue = DispatchQueue(label: "com.xuwudi.ochome.icloud")

  func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: ICloudChannel.name, binaryMessenger: messenger)
    channel.setMethodCallHandler(handle)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "exportToDrive" {
      do {
        let root = try backupRoot()
        NSWorkspace.shared.activateFileViewerSelecting([root])
        result(nil)
      } catch {
        result(FlutterError(code: "icloud", message: error.localizedDescription, details: nil))
      }
      return
    }
    fileQueue.async {
      do {
        let value = try self.perform(call)
        DispatchQueue.main.async { result(value) }
      } catch {
        DispatchQueue.main.async {
          result(
            FlutterError(code: "icloud", message: error.localizedDescription, details: nil)
          )
        }
      }
    }
  }

  private func perform(_ call: FlutterMethodCall) throws -> Any? {
    switch call.method {
    case "isAvailable":
      return containerURL() != nil
    case "backupRoot":
      return try backupRoot().path
    case "upload":
      let args = try mapArgs(call)
      try upload(localPath: try stringArg(args, "localPath"), relativePath: try stringArg(args, "relativePath"))
      return nil
    case "download":
      let args = try mapArgs(call)
      try download(relativePath: try stringArg(args, "relativePath"), localPath: try stringArg(args, "localPath"))
      return nil
    case "list":
      let args = try mapArgs(call)
      return try list(relativeDir: (args["relativeDir"] as? String) ?? "")
    case "delete":
      let args = try mapArgs(call)
      try delete(relativePath: try stringArg(args, "relativePath"))
      return nil
    default:
      throw ICloudHandlerError.badArgs
    }
  }

  private func containerURL() -> URL? {
    let fm = FileManager.default
    return fm.url(forUbiquityContainerIdentifier: ICloudChannel.containerId)
      ?? fm.url(forUbiquityContainerIdentifier: nil)
  }

  /// 备份槽在 `Documents/ochome-backup/`，Files 里显示为一个文件夹。
  private func backupRoot() throws -> URL {
    guard let container = containerURL() else {
      throw ICloudHandlerError.unavailable
    }
    let fm = FileManager.default
    let documents = container.appendingPathComponent("Documents", isDirectory: true)
    let root = documents.appendingPathComponent(ICloudChannel.backupFolder, isDirectory: true)
    try fm.createDirectory(at: root, withIntermediateDirectories: true)
    try migrateLegacyBackup(
      from: container.appendingPathComponent(ICloudChannel.backupFolder, isDirectory: true),
      to: root
    )
    try migrateLooseDocuments(from: documents, to: root)
    try? fm.startDownloadingUbiquitousItem(at: root)
    return root
  }

  private func migrateLooseDocuments(from documents: URL, to root: URL) throws {
    let fm = FileManager.default
    let names = ["ochome.sqlite", "manifest.json", "covers", "崽档备份.txt"]
    for name in names {
      let src = documents.appendingPathComponent(name)
      let dest = root.appendingPathComponent(name)
      if src.standardizedFileURL == dest.standardizedFileURL { continue }
      if fm.fileExists(atPath: src.path), !fm.fileExists(atPath: dest.path) {
        try fm.moveItem(at: src, to: dest)
      }
    }
  }

  private func migrateLegacyBackup(from legacy: URL, to root: URL) throws {
    let fm = FileManager.default
    var isDir: ObjCBool = false
    guard fm.fileExists(atPath: legacy.path, isDirectory: &isDir), isDir.boolValue else {
      return
    }
    let children = try fm.contentsOfDirectory(
      at: legacy,
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles]
    )
    for child in children {
      let dest = root.appendingPathComponent(child.lastPathComponent)
      if !fm.fileExists(atPath: dest.path) {
        try fm.moveItem(at: child, to: dest)
      }
    }
    try? fm.removeItem(at: legacy)
  }

  private func remoteURL(_ relativePath: String) throws -> URL {
    try backupRoot().appendingPathComponent(relativePath)
  }

  private func upload(localPath: String, relativePath: String) throws {
    let source = URL(fileURLWithPath: localPath)
    let dest = try remoteURL(relativePath)
    try FileManager.default.createDirectory(
      at: dest.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try coordinatedCopy(from: source, to: dest)
  }

  private func download(relativePath: String, localPath: String) throws {
    let source = try remoteURL(relativePath)
    try ensurePresent(at: source, relativePath: relativePath)
    try ensureDownloaded(at: source)
    let dest = URL(fileURLWithPath: localPath)
    try FileManager.default.createDirectory(
      at: dest.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try coordinatedCopy(from: source, to: dest)
    let size = (try dest.resourceValues(forKeys: [.fileSizeKey])).fileSize ?? 0
    if size == 0 {
      throw ICloudHandlerError.timeout(relativePath)
    }
  }

  private func list(relativeDir: String) throws -> [[String: Any]] {
    let root = try backupRoot()
    let dir = relativeDir.isEmpty ? root : root.appendingPathComponent(relativeDir, isDirectory: true)
    var isDir: ObjCBool = false
    guard FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else {
      return []
    }
    guard let enumerator = FileManager.default.enumerator(
      at: dir,
      includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
      options: []
    ) else {
      return []
    }
    let rootPath = root.standardizedFileURL.path
    var items: [[String: Any]] = []
    for case let url as URL in enumerator {
      let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
      let isFile = values.isRegularFile == true || url.lastPathComponent.hasSuffix(".icloud")
      guard isFile else { continue }
      guard let rel = logicalRelativePath(url: url, rootPath: rootPath) else { continue }
      items.append(["relativePath": rel, "bytes": values.fileSize ?? 0])
    }
    return items
  }

  private func logicalRelativePath(url: URL, rootPath: String) -> String? {
    var name = url.lastPathComponent
    if name == ".DS_Store" { return nil }
    if name.hasSuffix(".icloud") {
      name = String(name.dropLast(".icloud".count))
      if name.hasPrefix(".") {
        name.removeFirst()
      }
    }
    let parent = url.deletingLastPathComponent().standardizedFileURL.path
    var dirRel = ""
    if parent.hasPrefix(rootPath) {
      dirRel = String(parent.dropFirst(rootPath.count))
      if dirRel.hasPrefix("/") { dirRel.removeFirst() }
    }
    if dirRel.isEmpty {
      return name
    }
    return "\(dirRel)/\(name)"
  }

  private func delete(relativePath: String) throws {
    let url = try remoteURL(relativePath)
    guard FileManager.default.fileExists(atPath: url.path) else { return }
    var coordinatorError: NSError?
    var innerError: Error?
    NSFileCoordinator().coordinate(
      writingItemAt: url,
      options: .forDeleting,
      error: &coordinatorError
    ) { writeURL in
      do {
        try FileManager.default.removeItem(at: writeURL)
      } catch {
        innerError = error
      }
    }
    if let coordinatorError { throw coordinatorError }
    if let innerError { throw innerError }
  }

  private func ensurePresent(at url: URL, relativePath: String) throws {
    let fm = FileManager.default
    if fm.fileExists(atPath: url.path) || fm.isUbiquitousItem(at: url) {
      return
    }
    try? fm.startDownloadingUbiquitousItem(at: try backupRoot())
    let deadline = Date().addingTimeInterval(60)
    while Date() < deadline {
      if fm.fileExists(atPath: url.path) || fm.isUbiquitousItem(at: url) {
        return
      }
      Thread.sleep(forTimeInterval: 0.2)
    }
    throw ICloudHandlerError.notFound(relativePath)
  }

  private func ensureDownloaded(at url: URL) throws {
    if isMaterialized(url) {
      return
    }
    let fm = FileManager.default
    if fm.isUbiquitousItem(at: url) {
      try fm.startDownloadingUbiquitousItem(at: url)
    } else {
      try? fm.startDownloadingUbiquitousItem(at: try backupRoot())
    }
    let deadline = Date().addingTimeInterval(120)
    while Date() < deadline {
      if isMaterialized(url) {
        return
      }
      let values = try url.resourceValues(forKeys: [.ubiquitousItemDownloadingErrorKey])
      if let downloadingError = values.ubiquitousItemDownloadingError {
        throw downloadingError
      }
      Thread.sleep(forTimeInterval: 0.2)
    }
    throw ICloudHandlerError.timeout(url.lastPathComponent)
  }

  private func isMaterialized(_ url: URL) -> Bool {
    let fm = FileManager.default
    let values = try? url.resourceValues(forKeys: [
      .ubiquitousItemDownloadingStatusKey,
      .ubiquitousItemIsDownloadingKey,
      .fileSizeKey,
    ])
    if values?.ubiquitousItemIsDownloading == true {
      return false
    }
    let status = values?.ubiquitousItemDownloadingStatus
    if status == URLUbiquitousItemDownloadingStatus.notDownloaded {
      return false
    }
    let size = values?.fileSize ?? 0
    if status == nil, fm.isUbiquitousItem(at: url) {
      return size > 0
    }
    if size > 0, status == URLUbiquitousItemDownloadingStatus.current
      || status == URLUbiquitousItemDownloadingStatus.downloaded {
      return true
    }
    if size > 0, status == nil, !fm.isUbiquitousItem(at: url) {
      return fm.fileExists(atPath: url.path)
    }
    return false
  }

  private func coordinatedCopy(from source: URL, to dest: URL) throws {
    var coordinatorError: NSError?
    var innerError: Error?
    NSFileCoordinator().coordinate(
      readingItemAt: source,
      options: [],
      writingItemAt: dest,
      options: .forReplacing,
      error: &coordinatorError
    ) { readURL, writeURL in
      do {
        let fm = FileManager.default
        if fm.fileExists(atPath: writeURL.path) {
          try fm.removeItem(at: writeURL)
        }
        try fm.copyItem(at: readURL, to: writeURL)
      } catch {
        innerError = error
      }
    }
    if let coordinatorError { throw coordinatorError }
    if let innerError { throw innerError }
  }

  private func mapArgs(_ call: FlutterMethodCall) throws -> [String: Any] {
    guard let args = call.arguments as? [String: Any] else {
      throw ICloudHandlerError.badArgs
    }
    return args
  }

  private func stringArg(_ args: [String: Any], _ key: String) throws -> String {
    guard let value = args[key] as? String, !value.isEmpty else {
      throw ICloudHandlerError.badArgs
    }
    return value
  }
}
