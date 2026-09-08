# Backup and Restore UI

## Scope

Use when editing backup pages, contents browsing, provider/bootstrap wiring,
progress semantics or dataset-dependent image reads. Persistence/native contracts
are in [Backend Backup and Restore](../backend/backup-restore.md).

## Signatures

```dart
BackupRestorePage({bool? icloudSupported});
BackupContentsPage({required Future<SnapshotContents> Function() loadContents,
  BackupDescriptor? descriptor, String title = '备份内容',
  Future<void> Function()? onPrepareRestore});
```

`backupCoordinatorProvider` is a non-auto-disposed FutureProvider. The page may
leave/reopen without cancelling the coordinator. The app's bootstrap initializes
storage before the database. MyApp listens to every storage change (including
same-epoch recovery-only transitions) and returns to /backup after a switch.
Recovery-only starts at /backup and prohibits navigation to business editors.

## Contracts

- No backup file export/import or old 保存到文件 action. The standard archive
  cloud action remains the entry point; no change to the bottom-tab destinations.
- Show current saved data separately from historical contents. History uses its
  immutable snapshot index and account-wide latest3; device is a source label.
  Local inventory can load even while cloud metadata is waiting.
- Scope preview before start shows saved role/history/attribute/media totals.
  Upload/reuse amounts stay unknown until measured by the core; never invent
  numbers to match the design preview.
- Job phase, current friendly filename, known bytes/file counts, stop phase,
  timestamps, retries and cleanup state come from BackupJobState. A stage may
  reach 100% while overall backup waits for cloud/account confirmation.
- Native per-file byte events are labeled current-file progress, not whole-phase bytes.
  Waiting for cloud upload stays in the upload step; only publishing follows confirmed upload.
- Use indeterminate progress if no truthful denominator exists. Do not estimate
  transfer bytes from file count or make up an ETA/speed. Live-region announcements
  cover stage changes, not every byte update.
- Download/validation ends in readyForReview. Show incoming scope, current scope
  (or explicit unreadable state), source time, space estimate and one previous
  copy before explicit activation confirmation. Clicking “先不恢复” writes nothing.
  Domain epoch/revision check is authoritative if data changes during review.
- Activating disables back/cancel. Cancelling, deleting a previous copy and
  returning to a previous dataset need explicit confirmation; use ink-colored
  destructive actions and existing confirmation design.
- Do not hide a physically retained previous copy merely because it is not
  restorable; `previousExists` keeps cleanup accessible. Local rollback performs
  its own integrity validation before changing datasets.
- Show result reports and cleanupPending; explicit “重试空间清理” calls the
  coordinator, never deletes paths in a widget.
- Contents lists paginate; per-role file lists also paginate. Long names show
  full information in detail, and no internal object IDs appear as display names.
- Legacy `.knownBytes` / `.knownLogicalDataBytes` null means 大小待检查 /
  总量待检查, never zero. Missing completion timestamp means 未提供.
- Theme uses ZaidangTokens + stock Material widgets. 320px and large text must
  fit, and no second independent visual system is introduced.

## Data root and lifecycle

`CoverFileView`, gallery resolution and role-card renderer use
`getActiveDataDirectory()` by default; do not cache the old root across epochs.
Explicit test directory injection stays supported. Gallery, native asset preview
and renderer reads pin managed physical files, releasing in dispose/finally so
retired directory GC does not remove still-used originals.

The provider closes the old connection before switching and invalidates/reopens
DB-backed providers for health checks on the new root. Recovery-only must not
materialize an empty old DB. Unknown bootstrap failure retains files and displays
retry; it never deletes storage as a repair shortcut.

## Validation matrix / examples

| Scenario | Outcome |
|---|---|
| unsupported platform | explanation, no backup call |
| route leave/reopen | same job identity/status |
| bytes 100%, cloud pending | still waiting, not completed |
| ready restore, dialog cancelled | no activation |
| current content unreadable | explicit unknown scope; valid incoming still reviewable |
| history after live rename | original backed-up name remains |
| cleanup click/cancel | no deletion until confirm |
| 320px light/dark with large text | no overflow; scrollable review |

Good: observe app-owned job and send an intent. Base: view an empty contents
index without downloading media. Bad: page-local _busy as the only lock, using
current role names in old backups, or calling ICloudBackupService.commitRestore
from a widget.

Tests: backup_restore_page_test covers data visibility, no manual file export,
phase truth, immutable filenames, explicit review, reentry, cleanup confirmation
and narrow large-text layouts. home_shell_test must override the backup provider
because it tests routing, not real file/CloudKit initialization.

Local startup failures and cloud availability are separate. Bootstrap shows retry
for ordinary storage/environment errors, with expandable actual local error
details. Recovery-only shows the preserved-data notice plus local error details;
cloud configuration errors must never alone redirect normal startup to backup.
