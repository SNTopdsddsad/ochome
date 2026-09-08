import Foundation
import CloudKit

/// Boundary for deterministic native fault tests. Production always uses
/// CloudKit below; test stores never initialize a user's CKContainer.
protocol BackupV3RecordStore {
  func fetch(_ ids: [CKRecord.ID]) throws -> [CKRecord.ID: CKRecord]
  func save(_ records: [CKRecord]) throws -> [CKRecord]
  func revision(_ record: CKRecord) -> String?
  func serverDate(_ record: CKRecord, created: Bool) -> Date?
}

/// All account decisions use one custom-zone record and change-tag CAS. Large
/// media stays in Documents. CloudKit never implies those bytes were uploaded.
final class BackupV3Catalog {
  static let zoneID = CKRecordZone.ID(zoneName: "OchomeBackupV3", ownerName: CKCurrentUserDefaultName)
  private let database: CKDatabase?
  private let recordStore: BackupV3RecordStore?
  private let token: BackupV3Cancellation
  private let checkAccount: () throws -> Void
  private let references: ([String: Any]) throws -> Set<String>
  private let discoverEmpty: () throws -> Bool
  private let catalogID = CKRecord.ID(recordName: "catalog", zoneID: zoneID)
  private let limit = 700_000
  init(container: CKContainer, token: BackupV3Cancellation,
       checkAccount: @escaping () throws -> Void,
       references: @escaping ([String: Any]) throws -> Set<String>,
       discoverEmpty: @escaping () throws -> Bool) {
    database = container.privateCloudDatabase; recordStore = nil; self.token = token
    self.checkAccount = checkAccount; self.references = references; self.discoverEmpty = discoverEmpty
  }
  init(recordStore: BackupV3RecordStore, token: BackupV3Cancellation,
       checkAccount: @escaping () throws -> Void = {},
       references: @escaping ([String: Any]) throws -> Set<String>,
       discoverEmpty: @escaping () throws -> Bool = { true }) {
    database = nil; self.recordStore = recordStore; self.token = token
    self.checkAccount = checkAccount; self.references = references; self.discoverEmpty = discoverEmpty
  }
  private func revision(_ record: CKRecord) -> String? {
    recordStore?.revision(record) ?? record.recordChangeTag
  }
  private func serverDate(_ record: CKRecord, created: Bool = false) -> Date? {
    recordStore?.serverDate(record, created: created) ?? (created ? record.creationDate : record.modificationDate)
  }
  private func id(_ name: String) -> CKRecord.ID { CKRecord.ID(recordName: name, zoneID: Self.zoneID) }
  private func perform<T>(_ operation: CKDatabaseOperation, install: (@escaping (Result<T, Error>) -> Void) -> Void) throws -> T {
    try token.check(); try checkAccount()
    let semaphore = DispatchSemaphore(value: 0)
    var outcome: Result<T, Error>?
    install { result in outcome = result; semaphore.signal() }
    operation.configuration.timeoutIntervalForRequest = 60
    operation.configuration.timeoutIntervalForResource = 120
    let cancellation = token.register { operation.cancel() }
    defer { token.unregister(cancellation) }
    guard let database = database else { throw BackupV3Error("catalog_internal", "未初始化云端目录") }
    database.add(operation)
    // Drain the operation's completion even after cancellation. Do not return a
    // timeout while a publication callback can still change account state.
    semaphore.wait()
    try checkAccount()
    guard let result = outcome else { throw BackupV3Error("cloud_pending", "等待 iCloud 账户目录确认") }
    return try result.get()
  }
  func ensureZone() throws {
    if recordStore != nil { return }
    let operation = CKModifyRecordZonesOperation(recordZonesToSave: [CKRecordZone(zoneID: Self.zoneID)], recordZoneIDsToDelete: nil)
    let _: Void = try perform(operation) { finish in operation.modifyRecordZonesResultBlock = finish }
  }
  private func fetch(_ recordID: CKRecord.ID) throws -> CKRecord? { try fetchMany([recordID])[recordID] }
  private func fetchMany(_ recordIDs: [CKRecord.ID]) throws -> [CKRecord.ID: CKRecord] {
    try token.check(); try checkAccount()
    if let store = recordStore { return try store.fetch(recordIDs) }
    var all: [CKRecord.ID: CKRecord] = [:]
    for offset in stride(from: 0, to: recordIDs.count, by: 200) {
      let ids = Array(recordIDs[offset..<min(offset + 200, recordIDs.count)])
      let operation = CKFetchRecordsOperation(recordIDs: ids)
      let lock = NSLock(); var records: [CKRecord.ID: CKRecord] = [:]; var failure: Error?; var responses = 0
      let values: [CKRecord.ID: CKRecord] = try perform(operation) { finish in
        operation.perRecordResultBlock = { id, result in
          lock.lock(); defer { lock.unlock() }; responses += 1
          switch result {
          case .success(let record): records[id] = record
          case .failure(let error): if (error as? CKError)?.code != .unknownItem { failure = error }
          }
        }
        operation.fetchRecordsResultBlock = { result in
          lock.lock(); let values = records; let problem = failure; let count = responses; lock.unlock()
          if let problem = problem { finish(.failure(problem)); return }
          if case .failure(let error) = result {
            guard (error as? CKError)?.code == .partialFailure, count == ids.count else { finish(.failure(error)); return }
          }
          guard count == ids.count else { finish(.failure(BackupV3Error("catalog_incomplete", "云端目录读取尚未完成"))); return }
          finish(.success(values))
        }
      }
      all.merge(values) { _, new in new }
    }
    return all
  }
  static func contains(_ error: Error, code: CKError.Code) -> Bool {
    guard let cloud = error as? CKError else { return false }
    if cloud.code == code { return true }
    if cloud.code == .partialFailure, let errors = cloud.partialErrorsByItemID {
      return errors.values.contains { contains($0, code: code) }
    }
    return false
  }
  private func save(_ records: [CKRecord]) throws -> [CKRecord] {
    try token.check(); try checkAccount()
    if let store = recordStore { return try store.save(records) }
    let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
    operation.isAtomic = true; operation.savePolicy = .ifServerRecordUnchanged
    let lock = NSLock(); var saved: [CKRecord] = []; var failure: Error?
    return try perform(operation) { finish in
      operation.perRecordSaveBlock = { _, result in
        lock.lock(); defer { lock.unlock() }
        switch result { case .success(let record): saved.append(record); case .failure(let error): failure = error }
      }
      operation.modifyRecordsResultBlock = { result in
        lock.lock(); let values = saved; let problem = failure; lock.unlock()
        if case .failure(let error) = result { finish(.failure(error)); return }
        if let problem = problem { finish(.failure(problem)); return }
        guard values.count == records.count else { finish(.failure(BackupV3Error("publication_pending", "等待完整的云端修改回执"))); return }
        finish(.success(values))
      }
    }
  }
  private func payload(_ record: CKRecord) throws -> [String: Any] {
    guard let data = record["payload"] as? Data else { throw BackupV3Error("catalog_invalid", "账户备份目录缺少内容，已停止清理") }
    let value = try BackupV3Support.json(data, maxBytes: limit)
    guard try BackupV3Support.integer(value, "format") == 3 else { throw BackupV3Error("catalog_version", "账户备份目录需要更新版本的 App") }
    return value
  }
  private func write(_ payload: [String: Any], to record: CKRecord) throws {
    let data = try BackupV3Support.encode(payload)
    guard data.count <= limit else { throw BackupV3Error("catalog_capacity", "待清理备份记录过多，请联网完成清理后重试") }
    record["payload"] = data as CKRecordValue
  }
  private func catalog() throws -> CKRecord {
    if let current = try fetch(catalogID) { _ = try payload(current); return current }
    guard try discoverEmpty() else { throw BackupV3Error("catalog_missing", "云端已有备份文件但账户目录尚未同步；请稍后重试，现有文件不会被删除") }
    let record = CKRecord(recordType: "OchomeBackupCatalog", recordID: catalogID)
    try write(["format": 3, "nextSequence": 1, "snapshots": [], "reservations": [], "retired": [], "claims": []], to: record)
    do { return try save([record])[0] }
    catch { if Self.contains(error, code: .serverRecordChanged), let existing = try fetch(catalogID) { return existing }; throw error }
  }
  /// Every operation obtains a fresh server modification date. Device wall clocks
  /// never authorize expiry, GC, or the global publication ordering.
  private func serverTime() throws -> Date {
    for _ in 0..<8 {
      let record = try fetch(id("clock")) ?? CKRecord(recordType: "OchomeBackupClock", recordID: id("clock"))
      record["nonce"] = UUID().uuidString as CKRecordValue
      do {
        guard let saved = try save([record]).first, let timestamp = serverDate(saved) else { throw BackupV3Error("server_time_unknown", "无法确认云端时间，操作暂缓") }
        return timestamp
      } catch { if Self.contains(error, code: .serverRecordChanged) { continue }; throw error }
    }
    throw BackupV3Error("catalog_busy", "其他设备正在更新备份目录，请稍后重试")
  }
  private func rows(_ map: [String: Any], _ key: String) throws -> [[String: Any]] {
    guard let result = map[key] as? [[String: Any]] else { throw BackupV3Error("catalog_invalid", "账户目录字段无效：\(key)") }
    return result
  }
  private func liveReservations(_ map: [String: Any], at now: Date) throws -> [[String: Any]] {
    try rows(map, "reservations").filter { row in
      try BackupV3Support.date(BackupV3Support.string(row, "expiresAtUtc")) > now
    }
  }
  func list() throws -> [String: Any] {
    let record = try catalog(); var value = try payload(record)
    var snapshots = try rows(value, "snapshots")
    for index in snapshots.indices { snapshots[index] = try withReceiptTime(snapshots[index]) }
    value["snapshots"] = snapshots; value["revision"] = revision(record) ?? ""
    return value
  }
  private func abortID(_ operationID: String) -> CKRecord.ID {
    id("aborted-" + BackupV3Support.digest(Data(operationID.utf8)))
  }
  func assertOperationAllowed(_ operationID: String) throws {
    if try fetch(abortID(operationID)) != nil {
      throw BackupV3Error("operation_abandoned", "此上传任务已取消并封存，请创建新的备份")
    }
  }
  func reserve(operationID: String, kind: String, bases: [String]) throws -> [String: Any] {
    guard ["backup", "restore"].contains(kind), bases.count <= 3 else { throw BackupV3Error("invalid_arguments", "无效任务保护范围") }
    let now = try serverTime()
    for _ in 0..<8 {
      let record = try catalog(); var value = try payload(record)
      try assertOperationAllowed(operationID)
      let active = try rows(value, "snapshots"); var leases = try liveReservations(value, at: now)
      let prior = leases.first { $0["operationId"] as? String == operationID }
      let priorBases = prior?["baseSnapshotIds"] as? [String] ?? []
      let allowed = Set(active.compactMap { $0["snapshotId"] as? String } + priorBases)
      guard Set(bases).isSubset(of: allowed) else { throw BackupV3Error("snapshot_retired", "备份已不在可恢复列表，请刷新后重新选择") }
      leases.removeAll { $0["operationId"] as? String == operationID }
      guard leases.count < 64 else { throw BackupV3Error("catalog_busy", "账户中有过多未完成操作，请稍后重试") }
      let reservation: [String: Any] = ["reservationId": prior?["reservationId"] as? String ?? UUID().uuidString,
        "operationId": operationID, "kind": kind, "baseSnapshotIds": bases,
        "expiresAtUtc": BackupV3Support.iso(now.addingTimeInterval(24 * 3600))]
      leases.append(reservation); value["reservations"] = leases
      try write(value, to: record)
      do { _ = try save([record]); return reservation }
      catch { if Self.contains(error, code: .serverRecordChanged) { continue }; throw error }
    }
    throw BackupV3Error("catalog_busy", "账户目录正在更新，请重试")
  }
  func release(operationID: String, reservationID: String) throws {
    for _ in 0..<8 {
      let record = try catalog(); var value = try payload(record)
      var leases = try rows(value, "reservations")
      leases.removeAll { $0["reservationId"] as? String == reservationID && $0["operationId"] as? String == operationID }
      value["reservations"] = leases; try write(value, to: record)
      do { _ = try save([record]); return }
      catch { if Self.contains(error, code: .serverRecordChanged) { continue }; throw error }
    }
    throw BackupV3Error("catalog_busy", "任务保护释放待确认")
  }
  private func receiptID(_ operationID: String) -> CKRecord.ID {
    id("receipt-" + BackupV3Support.digest(Data(operationID.utf8)))
  }
  private func withReceiptTime(_ snapshot: [String: Any]) throws -> [String: Any] {
    guard let receiptName = snapshot["receiptName"] as? String,
      let receipt = try fetch(id(receiptName)), let date = serverDate(receipt, created: true) else {
      throw BackupV3Error("publication_pending", "等待云端备份完成回执")
    }
    var result = snapshot; result["completedAtUtc"] = BackupV3Support.iso(date); return result
  }
  func receiptForOperation(_ operationID: String) throws -> [String: Any]? {
    guard let receipt = try fetch(receiptID(operationID)) else { return nil }
    guard let snapshot = try payload(receipt)["snapshot"] as? [String: Any] else {
      throw BackupV3Error("publication_pending", "无法确认上传任务是否已经发布，已保留文件")
    }
    return try withReceiptTime(snapshot)
  }
  func publicationReceipt(operationID: String, snapshot: [String: Any]) throws -> [String: Any]? {
    guard let receipt = try fetch(receiptID(operationID)) else { return nil }
    let result = try payload(receipt)
    guard let prior = result["snapshot"] as? [String: Any],
      prior["snapshotId"] as? String == snapshot["snapshotId"] as? String,
      prior["manifestSha256"] as? String == snapshot["manifestSha256"] as? String,
      prior["commitSha256"] as? String == snapshot["commitSha256"] as? String else {
      throw BackupV3Error("operation_conflict", "同一操作已发布不同的备份")
    }
    return try withReceiptTime(prior)
  }
  func publish(operationID: String, reservationID: String, snapshot: [String: Any],
               newPaths: Set<String>) throws -> [String: Any] {
    let receiptID = receiptID(operationID)
    if let prior = try publicationReceipt(operationID: operationID, snapshot: snapshot) { return prior }
    try assertOperationAllowed(operationID)
    let incoming = try references(snapshot)
    for _ in 0..<8 {
      let now = try serverTime()
      let record = try catalog(); var value = try payload(record)
      try assertOperationAllowed(operationID)
      let leases = try liveReservations(value, at: now)
      guard let lease = leases.first(where: { $0["reservationId"] as? String == reservationID && $0["operationId"] as? String == operationID && $0["kind"] as? String == "backup" }) else {
        throw BackupV3Error("reservation_expired", "备份保护已过期，请重新检查文件后重试")
      }
      var active = try rows(value, "snapshots"); var retired = try rows(value, "retired")
      let bases = Set(lease["baseSnapshotIds"] as? [String] ?? [])
      var allowed = newPaths
      for base in active + retired where bases.contains(base["snapshotId"] as? String ?? "") { allowed.formUnion(try references(base)) }
      guard incoming.isSubset(of: allowed) else { throw BackupV3Error("unprotected_reference", "部分备份文件没有上传或有效复用保护") }
      try assertNotDeleted(incoming)
      guard !active.contains(where: { $0["snapshotId"] as? String == snapshot["snapshotId"] as? String }),
        !retired.contains(where: { $0["snapshotId"] as? String == snapshot["snapshotId"] as? String }) else {
        throw BackupV3Error("snapshot_conflict", "备份标识已存在")
      }
      let sequence = try BackupV3Support.integer(value, "nextSequence")
      guard sequence < Int64.max - 1, retired.count < 512 else { throw BackupV3Error("catalog_capacity", "请先完成旧备份清理") }
      var published = snapshot; published["accountSequence"] = sequence; published["receiptName"] = receiptID.recordName
      active.append(published)
      active.sort { ($0["accountSequence"] as? NSNumber)?.int64Value ?? 0 > ($1["accountSequence"] as? NSNumber)?.int64Value ?? 0 }
      if active.count > 3 { retired.append(contentsOf: active.dropFirst(3)); active = Array(active.prefix(3)) }
      value["snapshots"] = active; value["retired"] = retired; value["nextSequence"] = sequence + 1
      value["reservations"] = leases.filter { $0["reservationId"] as? String != reservationID }
      try write(value, to: record)
      let receipt = CKRecord(recordType: "OchomeBackupReceipt", recordID: receiptID)
      try write(["format": 3, "snapshot": published], to: receipt)
      do {
        _ = try save([record, receipt]); return try withReceiptTime(published)
      } catch {
        // An uncertain response can follow a successful atomic save. Receipt is
        // authoritative even if a later backup has already retired this one.
        if let saved = try? fetch(receiptID), let payload = try? payload(saved), let prior = payload["snapshot"] as? [String: Any] {
          return try withReceiptTime(prior)
        }
        if Self.contains(error, code: .serverRecordChanged) { continue }; throw error
      }
    }
    throw BackupV3Error("publication_pending", "等待账户目录确认，请重试")
  }
  /// Irrevocably fences an unpublished operation before any exact-path cleanup.
  /// Ownership is supplied only from native atomic-create receipts, never from
  /// a directory listing or a successful copy into an already-existing path.
  func abandon(operationID: String, cleanupOperationID: String, ownedPaths: Set<String>,
               unsettledAttempts: Bool, delete: (String) throws -> Void) throws -> [String: Any] {
    var fenced = false
    for _ in 0..<8 {
      if let published = try receiptForOperation(operationID) {
        return ["aborted": false, "published": published, "cleanupPending": false]
      }
      let record = try catalog(); var value = try payload(record)
      if let abort = try fetch(abortID(operationID)) {
        let existing = try payload(abort)
        guard existing["operationId"] as? String == operationID else {
          throw BackupV3Error("catalog_invalid", "取消标记不一致，文件已保留")
        }
        fenced = true; break
      }
      value["reservations"] = try rows(value, "reservations").filter { $0["operationId"] as? String != operationID }
      try write(value, to: record)
      let abort = CKRecord(recordType: "OchomeBackupAbort", recordID: abortID(operationID))
      try write(["format": 3, "operationId": operationID], to: abort)
      do { _ = try save([record, abort]); fenced = true; break }
      catch {
        // Publication and abort both conditionally change the same catalog. A
        // lost publish response must not authorize deletion of a valid backup.
        if let published = try receiptForOperation(operationID) {
          return ["aborted": false, "published": published, "cleanupPending": false]
        }
        if Self.contains(error, code: .serverRecordChanged) { continue }; throw error
      }
    }
    guard fenced else { throw BackupV3Error("abandon_pending", "等待云端确认取消任务，文件已保留") }
    do {
      var record = try catalog(); var value = try payload(record)
      let existingClaims = try rows(value, "claims")
      if let claim = existingClaims.first {
        guard claim["abandonedOperationId"] as? String == operationID else {
          return ["aborted": true, "cleanupPending": true]
        }
        try deleteAuthorized(claimID: BackupV3Support.string(claim, "claimId"), delete: delete)
        record = try catalog(); value = try payload(record)
      }
      // Keep every catalog-referenced file, including retired files. This also
      // protects active reservations, whose bases must belong to these rows.
      let allSnapshots = try rows(value, "snapshots") + rows(value, "retired")
      let knownIDs = Set(allSnapshots.compactMap { $0["snapshotId"] as? String })
      for reservation in try rows(value, "reservations") {
        guard let bases = reservation["baseSnapshotIds"] as? [String], Set(bases).isSubset(of: knownIDs) else {
          return ["aborted": true, "cleanupPending": true]
        }
      }
      var referenced = Set<String>()
      for snapshot in allSnapshots { referenced.formUnion(try references(snapshot)) }
      let owned = Set(try ownedPaths.map { try BackupV3Support.relative($0) })
      let candidates = owned.subtracting(referenced)
      let tombstones = try fetchMany(candidates.map(tombstoneID))
      let remaining = candidates.filter { tombstones[tombstoneID($0)] == nil }.sorted()
      if remaining.isEmpty { return ["aborted": true, "cleanupPending": unsettledAttempts] }
      let paths = Array(remaining.prefix(256))
      let claimID = UUID().uuidString
      value["claims"] = [["claimId": claimID, "operationId": cleanupOperationID,
        "abandonedOperationId": operationID, "relativePaths": paths, "retiredSnapshotIds": []]]
      try write(value, to: record)
      var records = [record]
      for path in paths {
        let tombstone = CKRecord(recordType: "OchomeBackupTombstone", recordID: tombstoneID(path))
        tombstone["path"] = path as CKRecordValue; records.append(tombstone)
      }
      // Any reserve/publish since reachability was read changes the catalog tag
      // and aborts this entire authorization, including every tombstone.
      _ = try save(records)
      try deleteAuthorized(claimID: claimID, delete: delete)
      return ["aborted": true, "cleanupPending": unsettledAttempts || remaining.count > paths.count]
    } catch {
      // The abort fence is already durable; uncertain reachability/deletion is
      // a pending maintenance result, never permission to broaden the scope.
      return ["aborted": true, "cleanupPending": true]
    }
  }
  private func tombstoneID(_ path: String) -> CKRecord.ID { id("deleted-" + BackupV3Support.digest(Data(path.utf8))) }
  func assertNotDeleted(_ paths: Set<String>) throws {
    guard try fetchMany(paths.map(tombstoneID)).isEmpty else {
      throw BackupV3Error("object_retired", "文件路径已退休，请使用新的备份对象")
    }
  }
  func claim(operationID: String, revision: String, paths: [String]) throws -> [String: Any] {
    guard !paths.isEmpty, paths.count <= 256, Set(paths).count == paths.count else { throw BackupV3Error("cleanup_scope", "每次清理需为 1–256 个确切文件") }
    let now = try serverTime(); let record = try catalog(); var value = try payload(record)
    var claims = try rows(value, "claims")
    if let pending = claims.first { return ["claimId": try BackupV3Support.string(pending, "claimId")] }
    guard self.revision(record) == revision else { throw BackupV3Error("catalog_changed", "备份列表已更新，请重新计算清理范围") }
    let active = try rows(value, "snapshots"); let retired = try rows(value, "retired")
    let leases = try liveReservations(value, at: now)
    let protected = Set(leases.flatMap { $0["baseSnapshotIds"] as? [String] ?? [] })
    var reachable = Set<String>(); var retiredPaths = Set<String>()
    for item in active { reachable.formUnion(try references(item)) }
    for item in retired {
      let refs = try references(item)
      if protected.contains(item["snapshotId"] as? String ?? "") { reachable.formUnion(refs) }
      else { retiredPaths.formUnion(refs) }
    }
    let requested = Set(try paths.map { try BackupV3Support.relative($0) })
    guard requested.isSubset(of: retiredPaths.subtracting(reachable)) else { throw BackupV3Error("cleanup_protected", "清理范围包含使用中的文件，已停止删除") }
    // Snapshot metadata is deleted together, after its unshared objects; never
    // lose a manifest needed to authorize a later batch.
    var finishedIDs: [String] = []
    for item in retired where !protected.contains(item["snapshotId"] as? String ?? "") {
      let base = try BackupV3Support.string(item, "basePath")
      let metadata = Set(["database.sqlite", "manifest.json", "contents.json", "commit.json"].map { base + "/" + $0 })
      if !requested.isDisjoint(with: metadata) {
        let remaining = try references(item).subtracting(reachable)
        let removed = try fetchMany(remaining.map(tombstoneID))
        let outstanding = Set(remaining.filter { removed[tombstoneID($0)] == nil })
        guard outstanding.isSubset(of: requested), metadata.isSubset(of: requested) else { throw BackupV3Error("cleanup_order", "请先分批清理媒体，最后一起清理快照元数据") }
        finishedIDs.append(try BackupV3Support.string(item, "snapshotId"))
      }
    }
    let claimID = UUID().uuidString
    claims.append(["claimId": claimID, "operationId": operationID, "relativePaths": paths, "retiredSnapshotIds": finishedIDs])
    value["claims"] = claims; value["reservations"] = leases; try write(value, to: record)
    var records = [record]
    let existingTombstones = try fetchMany(paths.map(tombstoneID))
    for path in paths {
      let recordID = tombstoneID(path)
      let tombstone = existingTombstones[recordID] ?? CKRecord(recordType: "OchomeBackupTombstone", recordID: recordID)
      tombstone["path"] = path as CKRecordValue; records.append(tombstone)
    }
    _ = try save(records)
    return ["claimId": claimID]
  }
  func deleteAuthorized(claimID: String, delete: (String) throws -> Void) throws {
    let record = try catalog(); let value = try payload(record)
    guard let claim = try rows(value, "claims").first(where: { $0["claimId"] as? String == claimID }) else { return }
    guard let paths = claim["relativePaths"] as? [String], paths.count <= 256 else { throw BackupV3Error("catalog_invalid", "无效清理许可") }
    for path in paths.sorted(by: { ($0.contains("/objects/") ? 0 : 1) < ($1.contains("/objects/") ? 0 : 1) }) {
      try token.check(); try checkAccount(); try delete(BackupV3Support.relative(path))
    }
    for _ in 0..<8 {
      let fresh = try catalog(); var next = try payload(fresh)
      let ids = Set(claim["retiredSnapshotIds"] as? [String] ?? [])
      next["retired"] = try rows(next, "retired").filter { !ids.contains($0["snapshotId"] as? String ?? "") }
      next["claims"] = try rows(next, "claims").filter { $0["claimId"] as? String != claimID }
      try write(next, to: fresh)
      do { _ = try save([fresh]); return }
      catch { if Self.contains(error, code: .serverRecordChanged) { continue }; throw error }
    }
    throw BackupV3Error("cleanup_pending", "文件清理已执行，等待云端确认")
  }
}
