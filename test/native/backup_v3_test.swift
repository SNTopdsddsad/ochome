// Run without opening CloudKit or Keychain:
// swiftc ios/Runner/BackupV3Support.swift ios/Runner/BackupV3Catalog.swift \
//   test/native/backup_v3_test.swift -o /tmp/ochome-backup-v3-test && /tmp/ochome-backup-v3-test
import Foundation
import CloudKit

private final class MemoryRecords: BackupV3RecordStore {
  struct Stored { let record: CKRecord; let version: Int; let created: Date; let modified: Date }
  var entries: [CKRecord.ID: Stored] = [:]
  var observed: [ObjectIdentifier: Int] = [:]
  var retained: [ObjectIdentifier: CKRecord] = [:]
  var observedDates: [ObjectIdentifier: (Date, Date)] = [:]
  var now = Date(timeIntervalSince1970: 1_800_000_000)
  var beforeSave: (([CKRecord]) throws -> Void)?
  var loseReceiptReply = false
  var loseAbortReply = false
  var nextFetchError: Error?
  func copy(_ record: CKRecord) -> CKRecord {
    let copy = CKRecord(recordType: record.recordType, recordID: record.recordID)
    for key in record.allKeys() { copy[key] = record[key] }; return copy
  }
  func fetch(_ ids: [CKRecord.ID]) throws -> [CKRecord.ID: CKRecord] {
    if let error = nextFetchError { nextFetchError = nil; throw error }
    var result: [CKRecord.ID: CKRecord] = [:]
    for id in ids {
      if let entry = entries[id] {
        let record = copy(entry.record); observed[ObjectIdentifier(record)] = entry.version
        retained[ObjectIdentifier(record)] = record
        observedDates[ObjectIdentifier(record)] = (entry.created, entry.modified); result[id] = record
      }
    }
    return result
  }
  func save(_ records: [CKRecord]) throws -> [CKRecord] {
    if let action = beforeSave { beforeSave = nil; try action(records) }
    for record in records {
      let expected = observed[ObjectIdentifier(record)]
      if entries[record.recordID]?.version != expected { throw CKError(.serverRecordChanged) }
    }
    // All-or-nothing validation precedes every mutation, matching custom-zone CAS.
    for record in records {
      let prior = entries[record.recordID]
      entries[record.recordID] = Stored(record: copy(record), version: (prior?.version ?? 0) + 1,
        created: prior?.created ?? now, modified: now)
    }
    if loseAbortReply && records.contains(where: { $0.recordType == "OchomeBackupAbort" }) {
      loseAbortReply = false; throw CKError(.networkFailure)
    }
    if loseReceiptReply && records.contains(where: { $0.recordType == "OchomeBackupReceipt" }) {
      loseReceiptReply = false; throw CKError(.networkFailure)
    }
    return try records.map { try fetch([$0.recordID])[$0.recordID]! }
  }
  func revision(_ record: CKRecord) -> String? { observed[ObjectIdentifier(record)].map(String.init) }
  func serverDate(_ record: CKRecord, created: Bool) -> Date? {
    let dates = observedDates[ObjectIdentifier(record)]; return created ? dates?.0 : dates?.1
  }
}

@main
struct BackupV3Tests {
  static var checks = 0
  static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message); checks += 1
  }
  static func rejects(_ code: String? = nil, _ action: () throws -> Void) {
    do { try action(); fatalError("Expected rejection: \(code ?? "error")") }
    catch { if let code = code { expect((error as? BackupV3Error)?.code == code, "Expected \(code), got \(error)") } else { checks += 1 } }
  }
  static func main() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("backup-v3-test-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try fileTests(root)
    try legacyAndVersionTests(root)
    try catalogTests()
    try abandonedUploadTests()
    print("Backup v3 native checks passed: \(checks). No user iCloud, Keychain or dataset accessed.")
  }
  static func fileTests(_ root: URL) throws {
    do {
    let control = root.appendingPathComponent("storage-control", isDirectory: true)
    try FileManager.default.createDirectory(at: control, withIntermediateDirectories: true)
    let canonicalRoot = BackupV3Support.canonicalFileURL(root)
    // The target does not exist on first launch. Dart can supply /private/var
    // while Foundation returns /var for the existing Application Support root.
    let aliasPath = canonicalRoot.path.hasPrefix("/private/var/")
      ? String(canonicalRoot.path.dropFirst("/private".count))
      : (canonicalRoot.path.hasPrefix("/var/") ? "/private" + canonicalRoot.path : canonicalRoot.path)
    let pending = try BackupV3Support.contained(aliasPath + "/storage-control/active.json.pending", root: canonicalRoot)
    try Data("preserved pointer".utf8).write(to: pending)
    let active = try BackupV3Support.contained(aliasPath + "/storage-control/active.json", root: canonicalRoot)
    expect(active.deletingLastPathComponent() == pending.deletingLastPathComponent(), "Missing target lost its canonical parent")
    try BackupV3Support.atomicReplace(temporary: pending, destination: active)
    let pointer = try String(contentsOf: active, encoding: .utf8)
    expect(pointer == "preserved pointer", "First-launch pointer rename failed")
    let nested = try BackupV3Support.contained(aliasPath + "/storage-control/not-created/child.json", root: canonicalRoot)
    expect(nested.path == canonicalRoot.appendingPathComponent("storage-control/not-created/child.json").path, "Missing ancestor was not canonicalized")
    let outside = root.appendingPathComponent("outside", isDirectory: true)
    try FileManager.default.createSymbolicLink(at: control.appendingPathComponent("escape"), withDestinationURL: outside)
    rejects("unsafe_path") { _ = try BackupV3Support.contained(aliasPath + "/storage-control/escape/missing.json", root: canonicalRoot) }
    }
    let token = BackupV3Cancellation()
    let empty = root.appendingPathComponent("empty"); try Data().write(to: empty)
    let emptyDigest = BackupV3Support.digest(Data())
    let copied = try BackupV3Support.verifiedCopy(from: empty, to: root.appendingPathComponent("empty-copy"), bytes: 0,
      sha256: emptyDigest, token: token) { _ in }
    expect(copied.0 == 0 && copied.1 == emptyDigest, "Valid empty document failed")
    expect(copied.2, "Atomic create did not supply ownership receipt")
    let existingCopy = try BackupV3Support.verifiedCopy(from: empty, to: root.appendingPathComponent("empty-copy"), bytes: 0,
      sha256: emptyDigest, token: token) { _ in }
    expect(!existingCopy.2, "Identical pre-existing file was misclassified as owned")
    let source = root.appendingPathComponent("original"); let target = root.appendingPathComponent("target")
    let bytes = Data(repeating: 0x5a, count: 5 * 1024 * 1024 + 7); try bytes.write(to: source)
    let digest = BackupV3Support.digest(bytes)
    _ = try BackupV3Support.verifiedCopy(from: source, to: target, bytes: Int64(bytes.count), sha256: digest, token: token) { _ in }
    let content = try Data(contentsOf: target); expect(content == bytes, "Chunk boundary corrupted")
    _ = try BackupV3Support.verifiedCopy(from: source, to: target, bytes: Int64(bytes.count), sha256: digest, token: token) { _ in }
    rejects("integrity") { _ = try BackupV3Support.verifiedCopy(from: source, to: root.appendingPathComponent("truncated"), bytes: Int64(bytes.count + 1), sha256: digest, token: token) { _ in } }
    rejects("integrity") { _ = try BackupV3Support.verifiedCopy(from: source, to: root.appendingPathComponent("wrong-hash"), bytes: Int64(bytes.count), sha256: emptyDigest, token: token) { _ in } }
    rejects("invalid_format") { _ = try BackupV3Support.verifiedCopy(from: source, to: root.appendingPathComponent("huge-manifest"), bytes: nil, sha256: nil, token: token, maximumBytes: 1024) { _ in } }
    let other = root.appendingPathComponent("other"); try Data([1, 2, 3]).write(to: other)
    rejects("immutable_conflict") { _ = try BackupV3Support.verifiedCopy(from: other, to: target, bytes: nil, sha256: nil, token: token) { _ in } }
    let preserved = try Data(contentsOf: target); expect(preserved == bytes, "Conflict overwrote prior target")
    let cancelled = BackupV3Cancellation(); let cancelledTarget = root.appendingPathComponent("cancelled")
    rejects("cancelled") { _ = try BackupV3Support.verifiedCopy(from: source, to: cancelledTarget, bytes: nil, sha256: nil, token: cancelled) { _ in cancelled.cancel() } }
    expect(!FileManager.default.fileExists(atPath: cancelledTarget.path), "Cancelled copy became visible")
    let leftovers = try FileManager.default.contentsOfDirectory(atPath: root.path)
    expect(!leftovers.contains(where: { $0.hasSuffix(".part") }), "Failed copies left partial files")
    let pointer = root.appendingPathComponent("active.json"); let pending = root.appendingPathComponent("active.json.pending")
    try Data("old".utf8).write(to: pointer); try Data("new".utf8).write(to: pending)
    try BackupV3Support.atomicReplace(temporary: pending, destination: pointer)
    let pointerValue = try String(contentsOf: pointer, encoding: .utf8); expect(pointerValue == "new", "Pointer did not atomically replace")
    rejects { try BackupV3Support.atomicReplace(temporary: pending, destination: pointer) }
    let afterFailedReplace = try String(contentsOf: pointer, encoding: .utf8); expect(afterFailedReplace == "new", "Missing temporary removed old pointer")
    let writer = UUID().uuidString; let object = UUID().uuidString
    _ = try BackupV3Support.relative("writers/\(writer)/objects/\(object)")
    for invalid in ["../database.sqlite", "/tmp/database.sqlite", "writers/\(writer)/objects/../bad", "writers/\(writer)/objects/.hidden", "writers/x/objects/\(object)"] {
      rejects("unsafe_path") { _ = try BackupV3Support.relative(invalid) }
    }
    rejects("invalid_arguments") { _ = try BackupV3Support.integer(["size": true], "size") }
    rejects("invalid_arguments") { _ = try BackupV3Support.integer(["size": 1.5], "size") }
    let link = root.appendingPathComponent("link"); try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
    rejects("unsafe_path") { _ = try BackupV3Support.contained(link.path, root: root) }
    let parentLink = root.appendingPathComponent("linked-dir"); try FileManager.default.createSymbolicLink(at: parentLink, withDestinationURL: root)
    rejects("unsafe_path") { _ = try BackupV3Support.contained(parentLink.appendingPathComponent("original").path, root: root) }
  }
  static func legacyAndVersionTests(_ root: URL) throws {
    expect(BackupV3Support.appVersion(shortVersion: "1.2.3", buildVersion: "407") == "1.2.3+407", "Native app version omitted build")
    expect(BackupV3Support.appVersion(shortVersion: "1.2.3", buildVersion: nil) == "1.2.3", "Missing build fabricated a value")
    expect(BackupV3Support.appVersion(shortVersion: nil, buildVersion: "407") == "unknown+407", "Known running build was lost")
    let preferred = root.appendingPathComponent("Documents/ochome-backup")
    let old = root.appendingPathComponent("ochome-backup")
    let roots = [preferred, old]
    let db = preferred.appendingPathComponent("ochome.sqlite")
    let manifest = preferred.appendingPathComponent("manifest.json")
    let selected = try BackupV3Support.legacySource("manifest.json", roots: roots, discoveredURLs: [db, manifest])
    expect(selected.root == preferred && selected.file == manifest, "Legacy slot was not selected by database")
    rejects("discovery_pending") { _ = try BackupV3Support.legacySource("manifest.json", roots: roots, discoveredURLs: nil) }
    rejects("legacy_manifest_missing") { _ = try BackupV3Support.legacySource("manifest.json", roots: roots, discoveredURLs: [db]) }
    rejects("legacy_missing") { _ = try BackupV3Support.legacySource("manifest.json", roots: roots, discoveredURLs: []) }
    rejects("legacy_manifest_missing") {
      _ = try BackupV3Support.legacySource("manifest.json", roots: roots,
        discoveredURLs: [db, old.appendingPathComponent("ochome.sqlite"), old.appendingPathComponent("manifest.json")])
    }
    let lowerPriority = try BackupV3Support.legacySource("ochome.sqlite", roots: roots,
      discoveredURLs: [old.appendingPathComponent("ochome.sqlite")])
    expect(lowerPriority.root == old, "Read-only legacy fallback failed")
    let pinned = try BackupV3Support.legacySource("ochome.sqlite", roots: roots,
      discoveredURLs: [db, manifest, old.appendingPathComponent("ochome.sqlite")], selectedRoot: old)
    expect(pinned.root == old, "Subsequent discovery silently switched legacy slots")
  }
  static func catalogTests() throws {
    let store = MemoryRecords(); var refs: [String: Set<String>] = [:]
    let makeCatalog = { BackupV3Catalog(recordStore: store, token: BackupV3Cancellation(), references: { item in
      guard let id = item["snapshotId"] as? String, let paths = refs[id] else { throw BackupV3Error("integrity", "Missing manifest") }
      return paths
    }) }
    let first = makeCatalog(); let second = makeCatalog(); let writer = UUID().uuidString
    let shared = "writers/\(writer)/objects/\(UUID().uuidString)"
    func descriptor(_ number: Int) -> [String: Any] {
      let id = UUID().uuidString; let base = "writers/\(writer)/snapshots/\(id)"
      refs[id] = Set(["database.sqlite", "manifest.json", "contents.json", "commit.json"].map { base + "/" + $0 } + [shared])
      return ["snapshotId": id, "writerId": writer, "basePath": base, "manifestSha256": String(repeating: "a", count: 64),
        "commitSha256": String(repeating: "b", count: 64), "createdAtUtc": number.isMultiple(of: 2) ? "2000-01-01T00:00:00Z" : "2099-01-01T00:00:00Z"]
    }
    func publish(_ catalog: BackupV3Catalog, _ item: [String: Any], _ operation: String) throws -> [String: Any] {
      let reservation = try catalog.reserve(operationID: operation, kind: "backup", bases: [])
      return try catalog.publish(operationID: operation, reservationID: reservation["reservationId"] as! String,
        snapshot: item, newPaths: refs[item["snapshotId"] as! String]!)
    }
    let a = descriptor(1); let b = descriptor(2); let c = descriptor(3); let d = descriptor(4)
    _ = try publish(first, a, "a"); _ = try publish(second, b, "b"); _ = try publish(first, c, "c")
    let restoreLease = try first.reserve(operationID: "restore-a", kind: "restore", bases: [a["snapshotId"] as! String])
    _ = try publish(second, d, "d")
    let list = try first.list(); let active = list["snapshots"] as! [[String: Any]]
    expect(active.count == 3, "Retention was per-device instead of account-wide")
    expect(active.map { $0["snapshotId"] as! String } == [d, c, b].map { $0["snapshotId"] as! String }, "Client clocks influenced retention")
    let metadataA = refs[a["snapshotId"] as! String]!.subtracting([shared]).sorted()
    rejects("cleanup_protected") { _ = try second.claim(operationID: "gc", revision: list["revision"] as! String, paths: metadataA) }
    try first.release(operationID: "restore-a", reservationID: restoreLease["reservationId"] as! String)
    let revision = try first.list()["revision"] as! String
    rejects("cleanup_protected") { _ = try second.claim(operationID: "gc", revision: revision, paths: [shared]) }
    let claim = try second.claim(operationID: "gc", revision: revision, paths: metadataA)
    var interruptedDeletes = 0
    rejects { try second.deleteAuthorized(claimID: claim["claimId"] as! String) { _ in
      interruptedDeletes += 1
      if interruptedDeletes == 2 { throw BackupV3Error("offline", "Fixture lost connection") }
    } }
    let resumed = try first.claim(operationID: "other-device", revision: "stale", paths: metadataA)
    expect(resumed["claimId"] as? String == claim["claimId"] as? String, "Other device could not resume durable claim")
    var removed: [String] = []
    try first.deleteAuthorized(claimID: claim["claimId"] as! String) { removed.append($0) }
    rejects("object_retired") { try second.assertNotDeleted(Set(metadataA)) }
    expect(Set(removed) == Set(metadataA), "GC did not follow exact persisted authorization")
    let retired = try first.list()["retired"] as! [[String: Any]]
    expect(retired.isEmpty, "Finished retirement remained in catalog")
    let receipt = try first.publicationReceipt(operationID: "a", snapshot: a)
    expect(receipt?["accountSequence"] as? Int == 1, "Retry resurrected retired backup")
    refs.removeValue(forKey: a["snapshotId"] as! String)
    let idempotent = try first.publish(operationID: "a", reservationID: "expired", snapshot: a, newPaths: [])
    expect(idempotent["accountSequence"] as? Int == 1, "Receipt lookup required already-deleted manifest")
    let expired = try first.reserve(operationID: "expired", kind: "backup", bases: [])
    store.now += 24 * 3600 + 1
    let e = descriptor(5)
    rejects("reservation_expired") { _ = try first.publish(operationID: "expired", reservationID: expired["reservationId"] as! String, snapshot: e, newPaths: refs[e["snapshotId"] as! String]!) }
    store.loseReceiptReply = true
    let saved = try publish(first, e, "e")
    expect(saved["accountSequence"] as? Int == 5, "Lost reply allocated another sequence")
    let f = descriptor(6); let g = descriptor(7)
    let leaseF = try first.reserve(operationID: "f", kind: "backup", bases: [])
    let leaseG = try second.reserve(operationID: "g", kind: "backup", bases: [])
    // Interleave the competing publication immediately before the first one's
    // conditional save. Its stale change tag must trigger a refetch and merge.
    func interleave(_ records: [CKRecord]) throws {
      if records.contains(where: { $0.recordType == "OchomeBackupReceipt" }) {
        _ = try second.publish(operationID: "g", reservationID: leaseG["reservationId"] as! String, snapshot: g, newPaths: refs[g["snapshotId"] as! String]!)
      } else { store.beforeSave = interleave }
    }
    store.beforeSave = interleave
    _ = try first.publish(operationID: "f", reservationID: leaseF["reservationId"] as! String, snapshot: f, newPaths: refs[f["snapshotId"] as! String]!)
    let afterRace = try first.list()["snapshots"] as! [[String: Any]]
    expect(afterRace.map { $0["snapshotId"] as! String } == [f, g, e].map { $0["snapshotId"] as! String }, "Concurrent CAS lost another device's publication")
    let brokenID = (try first.list()["retired"] as! [[String: Any]]).first!["snapshotId"] as! String
    let missingRefs = refs.removeValue(forKey: brokenID)!
    let corruptRevision = try first.list()["revision"] as! String
    rejects("integrity") { _ = try first.claim(operationID: "corrupt", revision: corruptRevision, paths: Array(missingRefs.prefix(1))) }
    refs[brokenID] = missingRefs
    let unavailable = BackupV3Catalog(recordStore: MemoryRecords(), token: BackupV3Cancellation(), references: { _ in [] }, discoverEmpty: { false })
    rejects("catalog_missing") { _ = try unavailable.list() }
  }
  static func abandonedUploadTests() throws {
    let store = MemoryRecords(); var refs: [String: Set<String>] = [:]
    let catalog = BackupV3Catalog(recordStore: store, token: BackupV3Cancellation(), references: { row in
      guard let id = row["snapshotId"] as? String, let paths = refs[id] else { throw BackupV3Error("integrity", "Fixture manifest missing") }
      return paths
    })
    let writer = UUID().uuidString
    func object() -> String { "writers/\(writer)/objects/\(UUID().uuidString)" }
    func snapshot(_ files: Set<String>) -> [String: Any] {
      let id = UUID().uuidString; refs[id] = files
      return ["snapshotId": id, "writerId": writer, "basePath": "writers/\(writer)/snapshots/\(id)",
        "manifestSha256": String(repeating: "a", count: 64), "commitSha256": String(repeating: "b", count: 64)]
    }
    let shared = object(); let published = snapshot([shared])
    let successful = try catalog.reserve(operationID: "published", kind: "backup", bases: [])
    _ = try catalog.publish(operationID: "published", reservationID: successful["reservationId"] as! String,
      snapshot: published, newPaths: [shared])
    _ = try catalog.reserve(operationID: "reader", kind: "restore", bases: [published["snapshotId"] as! String])
    let orphan = object()
    let abandoned = try catalog.reserve(operationID: "abandoned", kind: "backup", bases: [published["snapshotId"] as! String])
    var deleted: [String] = []
    let result = try catalog.abandon(operationID: "abandoned", cleanupOperationID: "cleanup-1",
      ownedPaths: [orphan, shared], unsettledAttempts: false) { deleted.append($0) }
    expect(result["aborted"] as? Bool == true && result["cleanupPending"] as? Bool == false, "Proved cancelled upload did not finish")
    expect(deleted == [orphan], "Cancel cleanup deleted a retained/shared file")
    let leases = try catalog.list()["reservations"] as! [[String: Any]]
    expect(!leases.contains { $0["operationId"] as? String == "abandoned" }, "Aborted upload reservation survived")
    expect(leases.contains { $0["operationId"] as? String == "reader" }, "Abort removed another operation's protection")
    rejects("operation_abandoned") { _ = try catalog.reserve(operationID: "abandoned", kind: "backup", bases: []) }
    let late = snapshot([orphan])
    rejects("operation_abandoned") {
      _ = try catalog.publish(operationID: "abandoned", reservationID: abandoned["reservationId"] as! String,
        snapshot: late, newPaths: [orphan])
    }
    rejects("object_retired") { try catalog.assertNotDeleted([orphan]) }
    let count = deleted.count
    let retry = try catalog.abandon(operationID: "abandoned", cleanupOperationID: "cleanup-2",
      ownedPaths: [orphan], unsettledAttempts: false) { deleted.append($0) }
    expect(retry["cleanupPending"] as? Bool == false && deleted.count == count, "Repeated abandon deleted paths twice")
    let receiptResult = try catalog.abandon(operationID: "published", cleanupOperationID: "cleanup-published",
      ownedPaths: [shared], unsettledAttempts: false) { _ in fatalError("Deleted a published snapshot") }
    expect(receiptResult["aborted"] as? Bool == false && receiptResult["published"] is [String: Any], "Publication receipt was not checked first")
    let raced = object(); let racingSnapshot = snapshot([raced])
    let racingLease = try catalog.reserve(operationID: "racing", kind: "backup", bases: [])
    func publishBeforeAbort(_ records: [CKRecord]) throws {
      if records.contains(where: { $0.recordType == "OchomeBackupAbort" }) {
        store.loseReceiptReply = true
        _ = try catalog.publish(operationID: "racing", reservationID: racingLease["reservationId"] as! String,
          snapshot: racingSnapshot, newPaths: [raced])
      } else { store.beforeSave = publishBeforeAbort }
    }
    store.beforeSave = publishBeforeAbort
    let racedResult = try catalog.abandon(operationID: "racing", cleanupOperationID: "cleanup-race",
      ownedPaths: [raced], unsettledAttempts: false) { _ in fatalError("Deleted concurrently published file") }
    expect(racedResult["published"] is [String: Any] && racedResult["aborted"] as? Bool == false,
      "Abort fence ignored a successful publication with lost response")
    let interruptedFiles: Set<String> = [object(), object()]
    _ = try catalog.reserve(operationID: "interrupted", kind: "backup", bases: [])
    var calls = 0
    let interrupted = try catalog.abandon(operationID: "interrupted", cleanupOperationID: "cleanup-interrupted",
      ownedPaths: interruptedFiles, unsettledAttempts: false) { _ in
        calls += 1; if calls == 2 { throw CKError(.networkUnavailable) }
      }
    expect(interrupted["cleanupPending"] as? Bool == true, "Interrupted deletion pretended to complete")
    let claimRows = try catalog.list()["claims"] as! [[String: Any]]
    expect(claimRows.first?["abandonedOperationId"] as? String == "interrupted", "Interrupted abort claim was not persisted")
    let recovered = try catalog.abandon(operationID: "interrupted", cleanupOperationID: "cleanup-resumed",
      ownedPaths: interruptedFiles, unsettledAttempts: false) { _ in calls += 1 }
    expect(recovered["cleanupPending"] as? Bool == false, "Interrupted abort cleanup could not resume")
    let many = Set((0..<257).map { _ in object() })
    _ = try catalog.reserve(operationID: "bounded", kind: "backup", bases: [])
    var batchDeleted = 0
    let batch = try catalog.abandon(operationID: "bounded", cleanupOperationID: "cleanup-batch",
      ownedPaths: many, unsettledAttempts: false) { _ in batchDeleted += 1 }
    expect(batchDeleted == 256 && batch["cleanupPending"] as? Bool == true, "Abort cleanup did not enforce batch bound")
    let last = try catalog.abandon(operationID: "bounded", cleanupOperationID: "cleanup-last",
      ownedPaths: many, unsettledAttempts: false) { _ in batchDeleted += 1 }
    expect(batchDeleted == 257 && last["cleanupPending"] as? Bool == false, "Remaining abandoned files were lost")
    let lostAbortFile = object()
    _ = try catalog.reserve(operationID: "lost-abort", kind: "backup", bases: [])
    store.loseAbortReply = true
    rejects { _ = try catalog.abandon(operationID: "lost-abort", cleanupOperationID: "cleanup-lost-abort",
      ownedPaths: [lostAbortFile], unsettledAttempts: false) { _ in fatalError("Deleted before uncertain abort resolved") } }
    let resolvedAbort = try catalog.abandon(operationID: "lost-abort", cleanupOperationID: "cleanup-lost-abort-retry",
      ownedPaths: [lostAbortFile], unsettledAttempts: false) { _ in }
    expect(resolvedAbort["cleanupPending"] as? Bool == false, "Lost abort response could not recover its durable fence")
    let sharedAfterClaimRead = object(); let laterPublication = snapshot([sharedAfterClaimRead])
    _ = try catalog.reserve(operationID: "cancel-cas", kind: "backup", bases: [])
    let otherLease = try catalog.reserve(operationID: "other-publisher", kind: "backup", bases: [])
    func publishBeforeClaim(_ records: [CKRecord]) throws {
      if records.contains(where: { $0.recordType == "OchomeBackupTombstone" }) {
        _ = try catalog.publish(operationID: "other-publisher", reservationID: otherLease["reservationId"] as! String,
          snapshot: laterPublication, newPaths: [sharedAfterClaimRead])
      } else { store.beforeSave = publishBeforeClaim }
    }
    store.beforeSave = publishBeforeClaim
    let racedClaim = try catalog.abandon(operationID: "cancel-cas", cleanupOperationID: "cleanup-cas",
      ownedPaths: [sharedAfterClaimRead], unsettledAttempts: false) { _ in fatalError("Deleted after reachability changed") }
    expect(racedClaim["cleanupPending"] as? Bool == true, "Changed reachability did not cancel deletion claim")
    let refreshedClaim = try catalog.abandon(operationID: "cancel-cas", cleanupOperationID: "cleanup-cas-retry",
      ownedPaths: [sharedAfterClaimRead], unsettledAttempts: false) { _ in fatalError("Deleted newly retained shared object") }
    expect(refreshedClaim["cleanupPending"] as? Bool == false, "Refreshed retained reference was not protected")
    let unknown = try catalog.abandon(operationID: "uncertain-write", cleanupOperationID: "cleanup-unknown",
      ownedPaths: [], unsettledAttempts: true) { _ in fatalError("Deleted unknown ownership") }
    expect(unknown["cleanupPending"] as? Bool == true, "Unsettled write evidence was discarded")
    store.nextFetchError = CKError(.networkFailure)
    rejects { _ = try catalog.abandon(operationID: "receipt-offline", cleanupOperationID: "cleanup-offline",
      ownedPaths: [object()], unsettledAttempts: false) { _ in fatalError("Deleted without reading publication receipt") } }
    expect(!store.entries.values.contains { item in
      guard item.record.recordType == "OchomeBackupAbort", let data = item.record["payload"] as? Data,
        let payload = try? BackupV3Support.json(data) else { return false }
      return payload["operationId"] as? String == "receipt-offline"
    }, "Unknown receipt status wrote an abort marker")
  }

}
