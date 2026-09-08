import Foundation
import CloudKit
import Security
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Shared iOS/macOS transport. Invoked on a serial worker; only metadata-query
/// start/stop and UI event delivery enter the main queue.
final class BackupV3Transport {
  private let fm = FileManager.default
  private var sequences: [String: Int64] = [:]
  private var legacySlots: [String: URL] = [:]
  var emit: (([String: Any]) -> Void)?
  private var accountToken: Data? { fm.ubiquityIdentityToken.flatMap { try? NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: false) } }
  private func accountID() throws -> String {
    guard let token = accountToken else { throw BackupV3Error("account_unavailable", "请登录 iCloud 并启用 iCloud 云盘") }
    return BackupV3Support.digest(token)
  }
  private func checkAccount(_ account: String) throws {
    guard try accountID() == account else { throw BackupV3Error("account_changed", "iCloud 账户已更换，请重新打开备份页面") }
  }
  private func container() throws -> URL {
    guard let url = fm.url(forUbiquityContainerIdentifier: BackupV3Support.containerID) else {
      throw BackupV3Error("documents_unavailable", "iCloud 云盘不可用；请检查系统设置、网络以及 App 的 iCloud 容器配置")
    }; return url.resolvingSymlinksInPath()
  }
  private func cloudURL(_ relative: String) throws -> URL {
    let root = try container().appendingPathComponent("Documents/" + BackupV3Support.folder)
    let path = root.appendingPathComponent(try BackupV3Support.relative(relative))
    return try BackupV3Support.contained(path.path, root: root)
  }
  private func event(_ operation: String, phase: String, path: String? = nil,
                     bytes: Int64? = nil, total: Int64? = nil, files: Int? = nil, totalFiles: Int? = nil) {
    let sequence = (sequences[operation] ?? 0) + 1; sequences[operation] = sequence
    var value: [String: Any] = ["operationId": operation, "sequence": sequence, "phase": phase]
    if let path = path { value["relativePath"] = path }; if let bytes = bytes { value["completedBytes"] = bytes }
    if let total = total { value["totalBytes"] = total }; if let files = files { value["completedFiles"] = files }
    if let totalFiles = totalFiles { value["totalFiles"] = totalFiles }
    emit?(value)
  }
  func accountChanged(operations: [String]) {
    for operation in operations { event(operation, phase: "accountChanged") }
    legacySlots.removeAll()
  }
  private func cloudStatus(_ cloud: CKContainer) throws {
    let semaphore = DispatchSemaphore(value: 0)
    var account: CKAccountStatus = .couldNotDetermine; var problem: Error?
    cloud.accountStatus { value, error in account = value; problem = error; semaphore.signal() }
    guard semaphore.wait(timeout: .now() + 30) == .success else { throw BackupV3Error("cloud_pending", "等待 iCloud 账户状态超时，请检查网络") }
    if let problem = problem { throw problem }
    switch account {
    case .available: break
    case .noAccount: throw BackupV3Error("account_unavailable", "请在系统设置登录 iCloud")
    case .restricted: throw BackupV3Error("account_restricted", "系统限制了此账户使用 iCloud")
    case .temporarilyUnavailable: throw BackupV3Error("cloud_pending", "iCloud 账户暂时不可用，请稍后重试")
    default: throw BackupV3Error("cloud_pending", "尚无法确认 iCloud 账户状态")
    }
  }
  static func error(_ error: Error) -> BackupV3Error {
    if let value = error as? BackupV3Error { return value }
    if let value = error as? CKError {
      switch value.code {
      case .notAuthenticated: return BackupV3Error("account_unavailable", "iCloud 登录已失效，请在系统设置检查账户")
      case .quotaExceeded: return BackupV3Error("cloud_quota", "iCloud 空间不足，请释放空间后重试")
      case .permissionFailure, .missingEntitlement, .badContainer, .badDatabase, .serverRejectedRequest:
        return BackupV3Error("cloud_configuration", "iCloud 备份配置尚未就绪：请检查 CloudKit 容器权限、签名能力和已部署的数据库 schema（\(value.code.rawValue)）")
      case .serverRecordChanged: return BackupV3Error("catalog_changed", "另一台设备更新了备份目录，请重试")
      case .operationCancelled: return BackupV3Error("cancelled", "操作已取消")
      case .networkFailure, .networkUnavailable, .serviceUnavailable, .requestRateLimited, .zoneBusy:
        return BackupV3Error("cloud_pending", "iCloud 暂时无法完成请求，请联网后重试")
      case .partialFailure:
        if let nested = value.partialErrorsByItemID?.values.first { return Self.error(nested) }
      default: break
      }
    }
    let value = error as NSError
    if value.domain == NSCocoaErrorDomain && value.code == NSFileWriteOutOfSpaceError {
      return BackupV3Error("local_space", "本机存储空间不足")
    }
    return BackupV3Error("backup_io", error.localizedDescription)
  }
  func perform(_ method: String, arguments args: [String: Any], token: BackupV3Cancellation) throws -> Any? {
    if method == "storageAtomicReplace" {
      let temporary = try BackupV3Support.owned(BackupV3Support.string(args, "temporaryPath"), write: true, controlOnly: true)
      let destination = try BackupV3Support.owned(BackupV3Support.string(args, "destinationPath"), write: true, controlOnly: true)
      try BackupV3Support.atomicReplace(temporary: temporary, destination: destination); return nil
    }
    if method == "availableCapacity" { return try capacity() }
    if method == "availability" {
      var result: [String: Any] = ["supported": true, "available": false, "deviceName": deviceName,
        "appVersion": BackupV3Support.appVersion(
          shortVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
          buildVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String)]
      do {
        let account = try accountID(); _ = try container()
        try cloudStatus(CKContainer(identifier: BackupV3Support.containerID)); try checkAccount(account)
        result["writerId"] = try writerID()
        result["available"] = true; result["accountId"] = account
        result.merge(try capacity()) { _, new in new }
      } catch { let problem = Self.error(error); result["errorCode"] = problem.code; result["message"] = problem.message }
      return result
    }
    let account = try BackupV3Support.string(args, "accountId"); try checkAccount(account)
    let operation = args["operationId"] as? String ?? "metadata"
    try token.check()
    let cloud = CKContainer(identifier: BackupV3Support.containerID)
    let catalog = BackupV3Catalog(container: cloud, token: token,
      checkAccount: { try token.check(); try self.checkAccount(account) },
      references: { try self.references($0, account: account, operation: operation, token: token) },
      discoverEmpty: { try self.discoverV3Empty(token: token) })
    switch method {
    case "catalog": try catalog.ensureZone(); return try catalog.list()
    case "reserve":
      return try catalog.reserve(operationID: operation, kind: BackupV3Support.string(args, "kind"), bases: args["baseSnapshotIds"] as? [String] ?? [])
    case "release":
      try catalog.release(operationID: operation, reservationID: BackupV3Support.string(args, "reservationId")); return nil
    case "publish":
      guard let snapshot = args["snapshot"] as? [String: Any] else { throw BackupV3Error("invalid_arguments", "缺少备份描述") }
      if let receipt = try catalog.publicationReceipt(operationID: operation, snapshot: snapshot) { return receipt }
      let refs = try references(snapshot, account: account, operation: operation, token: token)
      try awaitUploaded(paths: Array(refs), account: account, operation: operation, token: token)
      let published = try catalog.publish(operationID: operation, reservationID: BackupV3Support.string(args, "reservationId"), snapshot: snapshot, newPaths: try stagedPaths(operation: operation, account: account))
      return published
    case "stage":
      let path = try BackupV3Support.relative(BackupV3Support.string(args, "relativePath"))
      let source = try BackupV3Support.owned(BackupV3Support.string(args, "localPath"), write: false)
      let bytes = try BackupV3Support.integer(args, "bytes")
      let checksum = try BackupV3Support.hash(BackupV3Support.string(args, "sha256"))
      try catalog.assertOperationAllowed(operation)
      try catalog.assertNotDeleted([path]); try checkAccount(account)
      try rememberStaged(path, operation: operation, account: account, journal: "attempts")
      let target = try cloudURL(path)
      var copyReceipt: (Int64, String, Bool)?
      var outcome: Error?; var coordinationError: NSError?
      try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
      NSFileCoordinator().coordinate(writingItemAt: target, options: [], error: &coordinationError) { location in
        do { copyReceipt = try BackupV3Support.verifiedCopy(from: source, to: location, bytes: bytes, sha256: checksum, token: token) { done in
          self.event(operation, phase: "staging", path: path, bytes: done, total: bytes)
        } } catch { outcome = error }
      }
      if let error = coordinationError ?? outcome as NSError? { throw error }
      // Ownership differs from upload eligibility: an identical pre-existing
      // target is valid for stage retry, but must never become ours to delete.
      if copyReceipt?.2 == true {
        try rememberStaged(path, operation: operation, account: account, journal: "owned")
      }
      try checkAccount(account); try token.check()
      try rememberStaged(path, operation: operation, account: account); return nil
    case "awaitUploaded":
      guard let paths = args["relativePaths"] as? [String], paths.count <= 100_004 else { throw BackupV3Error("invalid_arguments", "无效上传清单") }
      try awaitUploaded(paths: paths, account: account, operation: operation, token: token); return nil
    case "download":
      let legacy = args["legacy"] as? Bool ?? false
      let path = try BackupV3Support.relative(BackupV3Support.string(args, "relativePath"), legacy: legacy)
      let local = try BackupV3Support.restoreTarget(BackupV3Support.string(args, "localPath"))
      let bytes = args["bytes"] == nil ? nil : try BackupV3Support.integer(args, "bytes")
      let checksum = args["sha256"] == nil ? nil : try BackupV3Support.hash(BackupV3Support.string(args, "sha256"))
      let metadataLimit: Int64? = path.hasSuffix("commit.json") ? 64 * 1024 :
        (path.hasSuffix("manifest.json") || path.hasSuffix("contents.json") ? 16 * 1024 * 1024 : nil)
      if let maximum = metadataLimit, let expected = bytes, expected > maximum {
        throw BackupV3Error("invalid_format", "备份元数据超出大小限制")
      }
      let source = legacy ? try legacyURL(path, operation: operation, account: account, token: token) : try cloudURL(path)
      try materialize(source, account: account, operation: operation, relative: path, token: token)
      var result: (Int64, String, Bool)?; var outcome: Error?; var coordinationError: NSError?
      NSFileCoordinator().coordinate(readingItemAt: source, options: .withoutChanges, error: &coordinationError) { location in
        do { result = try BackupV3Support.verifiedCopy(from: location, to: local, bytes: bytes, sha256: checksum, token: token, maximumBytes: metadataLimit) { done in
          self.event(operation, phase: "downloading", path: path, bytes: done, total: bytes)
        } } catch { outcome = error }
      }
      if let error = coordinationError ?? outcome as NSError? { throw error }
      try checkAccount(account); try token.check()
      guard let verified = result else { throw BackupV3Error("download_pending", "文件下载尚未完成") }
      return ["bytes": verified.0, "sha256": verified.1]
    case "legacyInfo":
      let urls = try discover(token: token)
      let roots = try legacyRoots()
      let exists = urls.contains { url in roots.contains { url.path == $0.appendingPathComponent("ochome.sqlite").path } }
      return ["exists": exists, "discoveryComplete": true]
    case "claimCleanup":
      return try catalog.claim(operationID: operation, revision: BackupV3Support.string(args, "revision"), paths: args["relativePaths"] as? [String] ?? [])
    case "deleteAuthorized":
      try catalog.deleteAuthorized(claimID: BackupV3Support.string(args, "claimId")) { path in
        try self.deleteCloudPath(path, account: account, token: token)
      }; return nil
    case "abandonUpload":
      let abandoned = try BackupV3Support.string(args, "abandonedOperationId")
      guard abandoned != operation else { throw BackupV3Error("invalid_arguments", "清理必须使用独立任务标识") }
      // Publication receipt is authoritative even when a local journal became
      // unavailable or the published snapshot was retired after this job.
      if let published = try catalog.receiptForOperation(abandoned) {
        return ["aborted": false, "published": published, "cleanupPending": false]
      }
      let owned = try stagedPaths(operation: abandoned, account: account, journal: "owned")
      let attempts = try stagedPaths(operation: abandoned, account: account, journal: "attempts")
      let staged = try stagedPaths(operation: abandoned, account: account)
      let unsettled = !attempts.subtracting(staged.union(owned)).isEmpty || (!staged.isEmpty && attempts.isEmpty)
      let result = try catalog.abandon(operationID: abandoned, cleanupOperationID: operation,
        ownedPaths: owned, unsettledAttempts: unsettled) { path in
          try self.deleteCloudPath(path, account: account, token: token)
        }
      // A successful result does not remove ownership evidence: later retries
      // still need it to distinguish a proved empty job from an old unknown one.
      return result
    default: throw BackupV3Error("unsupported_method", "不支持的备份操作")
    }
  }
  private func deleteCloudPath(_ path: String, account: String, token: BackupV3Cancellation) throws {
    let url = try cloudURL(path); try checkAccount(account); try token.check()
    var failure: Error?; var coordinationError: NSError?
    NSFileCoordinator().coordinate(writingItemAt: url, options: .forDeleting, error: &coordinationError) { location in
      do { try self.fm.removeItem(at: location) } catch { failure = error }
    }
    if let error = coordinationError ?? failure as NSError? {
      let missing = (error.domain == NSCocoaErrorDomain &&
        [NSFileNoSuchFileError, NSFileReadNoSuchFileError].contains(error.code)) ||
        (error.domain == NSPOSIXErrorDomain && error.code == Int(ENOENT))
      guard missing else { throw error }
      // A missing local materialization is not proof of cloud absence. Only a
      // completed metadata discovery can settle an idempotent absent target.
      let present = try discover(token: token).contains { $0.path == url.path }
      if present { throw BackupV3Error("cleanup_pending", "云端文件尚未完成删除，请联网后重试") }
    }
  }
  private var deviceName: String {
    #if os(iOS)
    return UIDevice.current.name
    #else
    return Host.current().localizedName ?? "Mac"
    #endif
  }
  private func capacity() throws -> [String: Any] {
    let root = try BackupV3Support.supportRoots()[0]
    try fm.createDirectory(at: root, withIntermediateDirectories: true)
    let values = try root.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
    if let bytes = values.volumeAvailableCapacityForImportantUsage { return ["availableBytes": bytes] }
    return [:]
  }
  private func awaitUploaded(paths: [String], account: String, operation: String, token: BackupV3Cancellation) throws {
    let urls = try paths.map { (try BackupV3Support.relative($0), try cloudURL($0)) }
    let deadline = ProcessInfo.processInfo.systemUptime + 120
    while true {
      try token.check(); try checkAccount(account); var completed = 0
      for (_, url) in urls {
        var refreshed = url; refreshed.removeAllCachedResourceValues()
        let values = try refreshed.resourceValues(forKeys: [.isUbiquitousItemKey, .ubiquitousItemIsUploadedKey,
          .ubiquitousItemUploadingErrorKey, .ubiquitousItemHasUnresolvedConflictsKey])
        if let error = values.ubiquitousItemUploadingError { throw error }
        if values.ubiquitousItemHasUnresolvedConflicts == true { throw BackupV3Error("cloud_conflict", "iCloud 文件存在冲突，未将备份标记为完成") }
        if values.isUbiquitousItem == true && values.ubiquitousItemIsUploaded == true { completed += 1 }
      }
      event(operation, phase: completed == urls.count ? "uploading" : "waiting", files: completed, totalFiles: urls.count)
      if completed == urls.count { return }
      guard ProcessInfo.processInfo.systemUptime < deadline else { throw BackupV3Error("upload_pending", "文件已保存到 iCloud 本机目录，正在等待云端上传确认；请保持联网后重试") }
      Thread.sleep(forTimeInterval: 0.3)
    }
  }
  private func materialize(_ url: URL, account: String, operation: String, relative: String, token: BackupV3Cancellation) throws {
    try checkAccount(account); try token.check()
    try fm.startDownloadingUbiquitousItem(at: url)
    let deadline = ProcessInfo.processInfo.systemUptime + 120
    while true {
      try checkAccount(account); try token.check()
      var refreshed = url; refreshed.removeAllCachedResourceValues()
      let values = try refreshed.resourceValues(forKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey,
        .ubiquitousItemDownloadingErrorKey, .ubiquitousItemHasUnresolvedConflictsKey, .isRegularFileKey])
      if let error = values.ubiquitousItemDownloadingError { throw error }
      if values.ubiquitousItemHasUnresolvedConflicts == true { throw BackupV3Error("cloud_conflict", "备份文件存在 iCloud 冲突") }
      if values.isRegularFile == true && (values.ubiquitousItemDownloadingStatus == .current || values.ubiquitousItemDownloadingStatus == .downloaded) { return }
      event(operation, phase: "waiting", path: relative)
      guard ProcessInfo.processInfo.systemUptime < deadline else { throw BackupV3Error("download_pending", "仍在等待 iCloud 下载，请保持联网后重试") }
      Thread.sleep(forTimeInterval: 0.3)
    }
  }
  /// NSMetadataQuery provides initial discovery completion, unlike a local
  /// directory enumeration. An incomplete query is never an empty account.
  private func discover(token: BackupV3Cancellation) throws -> [URL] {
    let query = NSMetadataQuery(); let semaphore = DispatchSemaphore(value: 0)
    var observer: NSObjectProtocol?; var urls: [URL] = []; var started = false
    DispatchQueue.main.sync {
      query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope, NSMetadataQueryUbiquitousDataScope]
      query.predicate = NSPredicate(value: true)
      observer = NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidFinishGathering, object: query, queue: .main) { _ in
        query.disableUpdates(); urls = query.results.compactMap { ($0 as? NSMetadataItem)?.value(forAttribute: NSMetadataItemURLKey) as? URL }
        query.stop(); semaphore.signal()
      }
      started = query.start()
    }
    defer { DispatchQueue.main.sync { query.stop(); if let observer = observer { NotificationCenter.default.removeObserver(observer) } } }
    guard started else { throw BackupV3Error("discovery_pending", "iCloud 尚未开始发现文件") }
    for _ in 0..<150 {
      try token.check()
      if semaphore.wait(timeout: .now() + 0.1) == .success { return urls.map { $0.resolvingSymlinksInPath() } }
    }
    throw BackupV3Error("discovery_pending", "iCloud 文件发现尚未完成，请稍后重试")
  }
  private func discoverV3Empty(token: BackupV3Cancellation) throws -> Bool {
    let prefix = try container().appendingPathComponent("Documents/" + BackupV3Support.folder).path + "/"
    return try !discover(token: token).contains { $0.path.hasPrefix(prefix) }
  }
  private func legacyRoots() throws -> [URL] {
    let base = try container()
    return [base.appendingPathComponent("Documents/ochome-backup"), base.appendingPathComponent("ochome-backup"), base.appendingPathComponent("Documents")]
  }
  private func legacyURL(_ path: String, operation: String, account: String, token: BackupV3Cancellation) throws -> URL {
    let key = account + ":" + operation
    if let root = legacySlots[key], path != "manifest.json" {
      return try BackupV3Support.contained(root.appendingPathComponent(path).path, root: root)
    }
    // discover either returns a completed metadata-query result or throws a
    // pending error. Only this branch can classify a missing legacy manifest.
    let urls = try discover(token: token)
    let roots = try legacyRoots()
    let selection = try BackupV3Support.legacySource("ochome.sqlite", roots: roots,
      discoveredURLs: urls, selectedRoot: legacySlots[key])
    legacySlots[key] = selection.root
    return try BackupV3Support.legacySource(path, roots: roots,
      discoveredURLs: urls, selectedRoot: selection.root).file
  }
  private func ledgerURL(operation: String, account: String, journal: String = "paths") throws -> URL {
    var root = try BackupV3Support.supportRoots()[0].appendingPathComponent("storage-control/native-v3")
    try fm.createDirectory(at: root, withIntermediateDirectories: true)
    var attributes = URLResourceValues(); attributes.isExcludedFromBackup = true
    try root.setResourceValues(attributes)
    // The attempt journal must survive before any cloud final path is created.
    // Persist its newly created directory entries as well as its file contents.
    try BackupV3Support.syncDirectory(root)
    try BackupV3Support.syncDirectory(root.deletingLastPathComponent())
    try BackupV3Support.syncDirectory(root.deletingLastPathComponent().deletingLastPathComponent())
    return root.appendingPathComponent(BackupV3Support.digest(Data((account + ":" + operation).utf8)) + "." + journal)
  }
  private func stagedPaths(operation: String, account: String, journal: String = "paths") throws -> Set<String> {
    let url = try ledgerURL(operation: operation, account: account, journal: journal)
    if !fm.fileExists(atPath: url.path) { return [] }
    let data = try boundedData(url, maximum: 32 * 1024 * 1024, token: BackupV3Cancellation())
    guard let text = String(data: data, encoding: .utf8), let end = text.lastIndex(of: "\n") else {
      throw BackupV3Error("ledger_invalid", "本机上传记录无效，请重新创建备份")
    }
    let paths = text[..<end].split(separator: "\n").map(String.init)
    guard paths.count <= 200_008 else { throw BackupV3Error("ledger_invalid", "本机上传重试记录过多，请重新创建备份") }
    return Set(try paths.map { try BackupV3Support.relative($0) })
  }
  private func rememberStaged(_ path: String, operation: String, account: String, journal: String = "paths") throws {
    let url = try ledgerURL(operation: operation, account: account, journal: journal)
    if !fm.fileExists(atPath: url.path) {
      guard fm.createFile(atPath: url.path, contents: nil) else { throw BackupV3Error("storage_unavailable", "无法记录上传进度") }
    }
    let file = try FileHandle(forUpdating: url); defer { try? file.close() }
    let end = try file.seekToEnd()
    if end > 0 {
      let tailStart = end > 1024 ? end - 1024 : 0
      try file.seek(toOffset: tailStart); let tail = try file.readToEnd() ?? Data()
      if tail.last != 10 {
        // A crash can leave only the last appended receipt incomplete. Discard
        // that receipt, so retry must verify/stage its original file again.
        guard let newline = tail.lastIndex(of: 10) else {
          if tailStart != 0 { throw BackupV3Error("ledger_invalid", "上传进度记录损坏") }
          try file.truncate(atOffset: 0)
          try file.write(contentsOf: Data((path + "\n").utf8)); try file.synchronize()
          try BackupV3Support.syncDirectory(url.deletingLastPathComponent()); return
        }
        try file.truncate(atOffset: tailStart + UInt64(newline) + 1)
      }
    }
    _ = try file.seekToEnd(); try file.write(contentsOf: Data((path + "\n").utf8)); try file.synchronize()
    try BackupV3Support.syncDirectory(url.deletingLastPathComponent())
  }
  private func writerID() throws -> String {
    var directory = try BackupV3Support.supportRoots()[0].appendingPathComponent("storage-control/native-v3")
    try fm.createDirectory(at: directory, withIntermediateDirectories: true)
    var flags = URLResourceValues(); flags.isExcludedFromBackup = true; try directory.setResourceValues(flags)
    let marker = directory.appendingPathComponent("installation.json")
    var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: BackupV3Support.containerID + ".backup-writer-v3",
      kSecAttrAccount as String: "installation", kSecUseDataProtectionKeychain as String: true]
    var readQuery = query; readQuery[kSecReturnData as String] = true; readQuery[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: CFTypeRef?; let status = SecItemCopyMatching(readQuery as CFDictionary, &result)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw BackupV3Error("installation_identity", "无法读取本机备份身份，请解锁设备后重试（\(status)）")
    }
    if let secure = result as? Data, let local = try? Data(contentsOf: marker), secure == local,
      let map = try? BackupV3Support.json(secure, maxBytes: 1024),
      let writer = map["writerId"] as? String, (try? BackupV3Support.uuid(writer)) != nil { return writer }
    let writer = UUID().uuidString.lowercased()
    let data = try BackupV3Support.encode(["writerId": writer, "installationNonce": UUID().uuidString])
    let writeStatus: OSStatus
    if status == errSecItemNotFound {
      query[kSecValueData as String] = data
      query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
      writeStatus = SecItemAdd(query as CFDictionary, nil)
    } else {
      writeStatus = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data,
        kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly] as CFDictionary)
    }
    guard writeStatus == errSecSuccess else { throw BackupV3Error("installation_identity", "无法保存本机备份身份（\(writeStatus)）") }
    let temporary = marker.appendingPathExtension("pending"); try data.write(to: temporary)
    try BackupV3Support.atomicReplace(temporary: temporary, destination: marker)
    return writer
  }
  private func boundedData(_ url: URL, maximum: Int, token: BackupV3Cancellation) throws -> Data {
    let input = try FileHandle(forReadingFrom: url); defer { try? input.close() }
    var data = Data()
    while true {
      try token.check(); let chunk = try input.read(upToCount: min(BackupV3Support.chunkBytes, maximum + 1 - data.count)) ?? Data()
      if chunk.isEmpty { return data }; data.append(chunk)
      guard data.count <= maximum else { throw BackupV3Error("invalid_format", "备份清单超出大小限制") }
    }
  }
  private func references(_ descriptor: [String: Any], account: String, operation: String, token: BackupV3Cancellation) throws -> Set<String> {
    let writer = try BackupV3Support.uuid(BackupV3Support.string(descriptor, "writerId"))
    let snapshot = try BackupV3Support.uuid(BackupV3Support.string(descriptor, "snapshotId"))
    let base = "writers/\(writer)/snapshots/\(snapshot)"
    guard try BackupV3Support.string(descriptor, "basePath") == base else { throw BackupV3Error("invalid_format", "快照路径与标识不一致") }
    let manifestURL = try cloudURL(base + "/manifest.json")
    try materialize(manifestURL, account: account, operation: operation, relative: base + "/manifest.json", token: token)
    let data = try boundedData(manifestURL, maximum: 16 * 1024 * 1024, token: token)
    guard BackupV3Support.digest(data) == (try BackupV3Support.hash(BackupV3Support.string(descriptor, "manifestSha256"))) else { throw BackupV3Error("integrity", "快照清单摘要不一致，已停止操作") }
    let commitURL = try cloudURL(base + "/commit.json")
    try materialize(commitURL, account: account, operation: operation, relative: base + "/commit.json", token: token)
    let commitData = try boundedData(commitURL, maximum: 64 * 1024, token: token)
    guard BackupV3Support.digest(commitData) == (try BackupV3Support.hash(BackupV3Support.string(descriptor, "commitSha256"))) else {
      throw BackupV3Error("integrity", "快照完成标记摘要不一致")
    }
    let commit = try BackupV3Support.json(commitData)
    guard try BackupV3Support.integer(commit, "format") == 3,
      commit["writerId"] as? String == writer, commit["snapshotId"] as? String == snapshot,
      commit["manifestSha256"] as? String == descriptor["manifestSha256"] as? String,
      try BackupV3Support.integer(commit, "manifestBytes") == Int64(data.count) else {
      throw BackupV3Error("invalid_format", "快照完成标记与清单不一致")
    }
    let manifest = try BackupV3Support.json(data)
    guard try BackupV3Support.integer(manifest, "format") == 3,
      manifest["writerId"] as? String == writer, manifest["snapshotId"] as? String == snapshot,
      let files = manifest["files"] as? [[String: Any]], files.count <= 100_000,
      let required = manifest["requiredFeatures"] as? [String], required.isEmpty else {
      throw BackupV3Error("invalid_format", "快照格式未知，已停止操作")
    }
    var paths = Set(["database.sqlite", "manifest.json", "contents.json", "commit.json"].map { base + "/" + $0 })
    for file in files {
      let object = try BackupV3Support.uuid(BackupV3Support.string(file, "objectId"))
      _ = try BackupV3Support.integer(file, "bytes"); _ = try BackupV3Support.hash(BackupV3Support.string(file, "sha256"))
      paths.insert("writers/\(writer)/objects/\(object)")
    }
    return paths
  }
}
