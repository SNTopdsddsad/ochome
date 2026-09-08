# iCloud Backup and Restore

## 1. Scope / Trigger

Read before changing backup transport/catalog/protocol, local media storage,
SQLite snapshotting, dataset activation, provider lifecycle or cloud cleanup.
The v3 production path replaces the old single-slot writer. The old
`ICloudBackupService` / `ICloudContainer` sources remain for compatibility tests;
no production route may invoke their writes or implicit cloud-directory migration.

## 2. Signatures and ownership

```dart
Future<DataStorage> initializeDataStorage({Future<Directory> Function()? supportDirectory});
Future<Directory> getActiveDataDirectory();
DataStorage.open(Directory supportDirectory, {StorageAtomicReplace? atomicReplace, bool allowRecovery = false});
AppDatabase.forStorage(DataStorage storage, {QueryExecutor? executor});

BackupCoordinator({required DataStorage storage, BackupTransport? transport,
  required Future<void> Function() closeDatabase,
  required Future<void> Function() reopenDatabase});
Stream<BackupJobState> watchJob();
Future<String> startBackup();
Future<String> prepareRestore(BackupSource source);
Future<void> confirmRestore(String operationId);
Future<void> cancel(String operationId);
Future<void> retry(String operationId);
Future<void> restorePrevious();
Future<void> discardPrevious();
Future<void> retryCleanup();
```

`lib/features/backup/backup_protocol.dart` owns strict JSON decoding and stable
wire fields. `backup_models.dart` owns job/availability/review state.
`backup_transport.dart` is the only Dart/native bridge. The coordinator owns the
whole task independently of navigation. Pages must never replace live files or
close/reopen the database themselves.

## 3. Data and protocol contracts

- Business schema stays **8**. A protocol upgrade is not a reason to increment it.
- Documents root is `Documents/ochome-backup-v3` in
  `iCloud.com.xuwudi.ochome`. Immutable files live at
  `writers/<writerId>/objects/<objectId>` and
  `writers/<writerId>/snapshots/<snapshotId>/{database.sqlite,contents.json,manifest.json,commit.json}`.
- Manifest/commit format is **3**, contents format **1**. Unknown versions,
  invalid UUIDs/digests, negative/fractional counts, unsafe paths, duplicate
  references and inconsistent counts fail closed. JSON reads are bounded;
  original media never uses whole-file `readAsBytes`.
- Every required DB/media/index object is bound by exact length and SHA-256.
  Database snapshots use SQLite's Online Backup API, including committed WAL.
  Restore checks SQLite structure, foreign keys and domain field decoding;
  supported old schema migration occurs in the isolated candidate dataset.
- A contents index is derived from its snapshot. Historical names/counts never
  join against current roles. No-manifest legacy indexes can have unknown sizes:
  `SnapshotContentFile.knownBytes` and `SnapshotSummary.knownLogicalDataBytes`
  return null. Do not display those as zero or claim a historical digest exists.
- Legacy root discovery is read-only and fixes the selected slot. Only definite
  `legacy_manifest_missing` / known missing-manifest signals permit no-manifest
  compatibility. Network, pending discovery and malformed existing manifests do
  not. Schema 3–8 fixtures must preserve original fields and migrations.

## 4. Local storage and concurrency

- Bootstrap storage before business providers. DataStorage owns process.lock,
  a reentrant queued mutation gate, current dataset epoch and mutation revision.
  Production repositories capture their epoch and reject stale writes. Explicit
  injected database executors remain isolated for tests.
- Active data is selected by `storage-control/active.json` with
  `{format:1,current,previous,epoch,garbage}`. Initial valid legacy data stays in
  Application Support; restored data lives in `datasets/<id>/`.
- Native downloads first go to operation-owned
  `storage-control/backup-jobs/<operationId>/restore-data`, so damaged active
  controls do not prevent a rescue download. Fully validated contents move by
  same-volume rename into a fresh dataset before review; no second GB media copy.
- Activation writes a prepared intent and atomic pointer, closes the old DB,
  switches the root, reopens/checks the new DB, and records healthy before normal
  writes resume. Cleanup failures after healthy never roll back new user data.
  A higher-epoch pointer wins over stale intent. Uncertain connection/control
  errors enter recovery-only and notify listeners even if epoch did not change.
- Production Apple pointer replacement uses `storageAtomicReplace`: file fsync,
  same-directory rename, immediate-parent fsync. Tests use an injectable fallback.
  Process-kill correctness is not a blanket hardware power-loss guarantee.
- On Apple, canonicalize a missing file by resolving its nearest existing
  ancestor and appending missing components. Resolving a nonexistent leaf alone
  may retain `/private/var` while the existing support root resolves to `/var`.
  Both sides of first-launch atomic replacement must share the same physical
  parent. Keep inner-symlink rejection; never fix aliases by disabling containment.
- Preserve one previous known dataset. Unknown directories/control evidence from
  corrupted-state recovery are retained rather than guessed/deleted. Normal
  writes and data-root lookup are forbidden in recovery-only, while validated
  cloud restore remains possible; never silently replace corruption with an empty DB.
- The coordinator validates local previous restore using detached DB business inventory and actual
  referenced media (existence/exact known length and historical hash when recorded)
  before activation. SQLite readability alone is insufficient.
- `pinFiles` uses canonical physical paths and reference counts. Deletion waits
  for pins; retired dataset GC also respects pins. Galleries, native previews,
  renderer reads and backup snapshots release pins in finally/dispose.
- Cancellation drains native writers before staging cleanup. Confirmation cannot
  overtake cancellation; neither may accept stale operation/epoch/review revision.
  Restarted ready tasks require review again and never auto-activate.

## 5. Fingerprints and imports

`file-fingerprints.sqlite` is a rebuildable local-only cache under
`storage-control`. Its table stores canonical absolute path, digest, bytes,
mtime and ctime. It is separate from business DB and backup task/catalog metadata.

```dart
FileFingerprintStore(Directory controlRoot);
Future<FileFingerprint> fingerprint(File file, {bool force = false});
Future<FileFingerprint?> cachedFingerprint(File file, {bool requireCurrentStat = true});
Future<void> remember(File file, FileFingerprint fingerprint);
ManagedFileImporter.copy(XFile source, File target, {FileFingerprintStore? fingerprints});
```

- Import source once, stream bounded chunks with backpressure to a worker that
  writes/hashes identical bytes, then close/length-check/rename before caching.
  Current copying holds the mutation lease while hashing runs off the UI isolate;
  other writes wait. Measure frame timing on real devices rather than promising
  responsiveness or concurrent unrelated saves during a GB import.
- Rename changes display metadata only and reuses digest. Different dataset/path,
  changed size/version or missing cache requires recomputation. A cache hit is
  not a fresh integrity scan.
- First/re-upload and restore verify the bytes actually copied against expected
  digests. Do not merely compare two cached hash fields or overwrite a historical
  expectation with newly corrupted bytes. Read-only cachedFingerprint can retain
  a historical expected digest without mutating the cache during validation.

## 6. Account catalog and native boundary

Channel `com.xuwudi.ochome/backup_v3`, events `.../backup_v3/events`.
Shared Swift Support/Catalog/Transport/ChannelHandler sources compile for iOS
and macOS. Local `storageAtomicReplace` and `availableCapacity` do not require
CloudKit/iCloud availability.

CloudKit private custom zone **OchomeBackupV3** uses these types:

| Type | Fields |
|---|---|
| OchomeBackupCatalog | payload: Bytes |
| OchomeBackupClock | nonce: String |
| OchomeBackupReceipt | payload: Bytes |
| OchomeBackupTombstone | path: String |
| OchomeBackupAbort | payload: Bytes |

No whole-table query/index is required. Same-zone modifications are atomic and
use `ifServerRecordUnchanged`; conflict means fetch/recompute/retry, not overwrite.
Server sequence/time determine publication ordering and lease expiry. Account-wide
active history is **3 total**, never three per writer/device.

- reserve fixes active base refs and protects ongoing upload/restore dependencies.
- stage writes immutable unique targets; original bytes are verified before publish.
- awaitUploaded accepts only real ubiquitous-item uploaded confirmation, never
  local copy completion. Unknown/timeout is pending, not completed.
- publish rechecks content and records receipt plus latest3/retirement atomically.
  Response-loss retry checks receipt first and cannot resurrect a retired entry.
- claimCleanup/deleteAuthorized use bounded exact-path claims and persistent
  tombstones, excluding active/reserved references. Claims can resume on another
  device; unknown metadata stops cleanup.
- `abandonUpload {operationId:<new cleanup id>,accountId,abandonedOperationId}`
  first reconciles publication receipt, then uses an irrevocable account abort
  fence and durable native create-ownership journal. Only provably newly created,
  unreferenced files are reclaimed. Existing identical targets are not owned by
  the new operation. Late reserve/publish cannot revive abandoned/deleted IDs.
  Unknown ownership/old ledgers remain cleanupPending; OS space release may lag.
- availability returns actual short+build appVersion and stable writerId from a
  local excluded-backup marker bound to ThisDeviceOnly Keychain material. Missing
  binding rotates identity. Existing account changes fail the operation.

Native signing/CloudKit schema readiness and double-device behavior require real
Apple validation; pure fake-store tests cannot establish them. Runtime errors
must remain visible and no completion result may fake that readiness.

## 7. Validation matrix

| Case | Required outcome |
|---|---|
| interrupted upload/new catalog conflict | old completed refs unchanged; pending/retry |
| truncated/same-length corrupt media | reject before activation |
| zero-byte document | valid when expected length is zero |
| malformed current business DB | valid incoming restore can be reviewed with currentUnreadable, not invented zero counts |
| malformed incoming DB/JSON/unknown version | reject, preserve local data |
| cancelled ready restore + late confirm | no activation |
| failed close/reopen/rollback | recovery-only; no writable stale session |
| completed activation + failed cleanup | completed with cleanupPending |
| two writers / clock skew | same account-wide latest3 by server sequence |
| lost publish response then abort/retry | retain acknowledged publication; no duplicate slot or byte deletion |
| cached duplicate but missing/retired cloud object | no unsafe reuse |
| cancelled owned upload | drain + receipt check + exact fenced reclamation |

## 8. Good / Base / Bad and tests

Good: import/hash once → cached immutable identity → snapshot refs → confirmed
account publication → isolated verified restore → explicit review → atomic dataset
activation. Base: empty original-file list with valid DB still makes a complete
backup. Bad: trust equal lengths, use a mutable latest file, copy active SQLite
without its snapshot API, migrate after overwriting live data, or prune from an
incomplete directory list.

Required suites: `test/features/backup/backup_core_test.dart`,
`test/data/data_storage_test.dart`, `storage_repository_isolation_test.dart`,
`file_fingerprint_store_test.dart`, `managed_file_importer_test.dart`,
`sqlite_snapshotter_test.dart`, `test/pages/backup_restore_page_test.dart`, and
`test/native/backup_v3_test.swift`.
`test/data/backup_provider_integration_test.dart` exercises the real ProviderContainer,
production DataStorage bootstrap, close/invalidate/reopen callbacks and stale repository rejection. Assert behavioral fault boundaries, not
implementation-shaped mock call counts alone.

## Startup error classification

Only explicit malformed controls, missing/structurally corrupt data, unsupported
versions and SQLite CORRUPT/FORMAT/NOTADB may enter recovery-only at startup.
PlatformException, filesystem permissions/capacity and SQLite I/O/CANTOPEN/READONLY
errors propagate to bootstrap, release process ownership and support retry.
Do not classify every initialization exception as damaged user data. Schema < 3
remains protected: the historical Drift branch drops/recreates role, so its
presence does not prove lossless migration support.

`test/pages/storage_bootstrap_test.dart` connects real storage initialization with
AppStorageBootstrap, MyApp and GoRouter. It verifies fresh/healthy startup opens
archive without cloud availability, native replace failure shows a retryable
local error, and corrupt SQLite remains behind the recovery route.
