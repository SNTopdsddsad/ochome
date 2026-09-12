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
  Future<void> Function()? onPrepareRestore, BackupCoordinator? coordinator,
  Future<void> Function(BackupJobState)? onReviewRestore,
  Future<void> Function(BackupJobState)? onCancelJob});
```

`backupCoordinatorProvider` is a non-auto-disposed FutureProvider. The page may
leave/reopen without cancelling the coordinator. The app's bootstrap initializes
storage before the database. MyApp listens to every storage change (including
same-epoch recovery-only transitions) and returns to /backup after a switch.
Recovery-only starts at /backup and prohibits navigation to business editors.

## Contracts

- No backup file export/import or old 保存到文件 action. The standard archive
  cloud action remains the entry point; no change to the bottom-tab destinations.
- The app has not launched: expose only the current snapshot backups, with no
  legacy backup entry or discovery notice. History loading must not query legacy
  slots, and empty-state copy must not distinguish old/new formats.
- Show current saved data separately from historical contents. History uses its
  immutable snapshot index and account-wide latest3; device is a source label.
  Local inventory can load even while cloud metadata is waiting.
- Home shows one primary “立即备份” action and a compact historical list: time,
  source device and total bytes. No local inventory card, task report or per-type
  counters are expanded by default. One tap starts backup; no scope-confirmation
  dialog precedes this non-destructive action. Do not show introductory copy,
  retention-policy labels or a generic backup-content explanation. Cloud read
  failure is distinct from an empty history. Refresh
  failures retain already loaded history with a stale-data hint; explicit sign-out
  or a known account change clears it so another account never inherits the list.
- An app-owned job replaces the primary action while running or awaiting review.
  Failed/interrupted jobs retain their reason and retry affordance. Detailed
  filenames and stop stages live behind a disclosure. Completed/cancelled
  journals never create permanent result reports on entry or reentry.
- App-scoped backupCompletionFeedbackProvider retains a session-only completion
  event across the storage-driven router reset. The mounted page consumes it
  after a frame; it expires after 30 seconds and is never persisted.
  A newly observed active-to-completed transition produces one shared brief
  snackbar and refreshes history. Repeated terminal events and persisted terminal
  state do not replay the feedback. Short completion notices follow the shared
  auto-dismiss timeout even with accessible navigation; only scrollable long
  notices persist, and the native close control remains available.
- All stage, progress and diagnostic data comes from BackupJobState. A stage may
  reach 100% while overall backup waits for cloud/account confirmation.
- Native per-file byte events are labeled current-file progress, not whole-phase bytes.
  Waiting for cloud upload stays in the upload step; only publishing follows confirmed upload.
- Use indeterminate progress if no truthful denominator exists. Do not estimate
  transfer bytes from file count or make up an ETA/speed. Live-region announcements
  cover stage changes, not every byte update.
- Historical detail starts with the snapshot time, device and compact scope/size.
  Its role list and file-category summary are collapsed by default and always use frozen
  metadata. “恢复这份备份” starts preparation; omit routine process explanations.
  Only the final confirmation explains replacement and its consequences. Detail observes the matching coordinator job
  rather than immediately popping when the start intent returns.
- Download/validation ends in readyForReview. Newly observed readiness may open
  review only on the current detail route. Reentry shows “继续恢复”; neither
  navigation nor restarting the app authorizes activation. Confirmation rechecks
  the current operation ID/readiness, names the incoming snapshot and scope,
  explains full replacement and no undo, and preserves limited-integrity or
  unreadable-current warnings. Core space and epoch/revision checks stay
  authoritative; no file operations move into widgets.
- The final action uses the shared Zaidang confirmation, default cancel focus,
  ink-colored “确认恢复”, and explicit “暂不恢复”. Cancelling writes nothing.
- Activating disables back/cancel on both home and detail. Safe cancellation
  continues to use the existing confirmation and coordinator.canCancel boundary.
- Do not expose local previous-copy restore/cleanup actions. Successful restore
  automatically retires the old dataset; failed activation still rolls back.
- Preserve cleanupPending independently of hidden success reports. A direct
  “重试空间清理” action calls the coordinator and never
  deletes paths in a widget.
- Role lists paginate. File contents, both account-wide and inside a role, show
  only nonempty category totals in the fixed order 立绘 / 图片 / 视频 / 音频 / 文档.
  Count frozen SnapshotContents.files entries, not current local assets or summed
  per-role references: a shared file contributes once globally. Inside a role,
  first filter by roleIds and then group. Do not render filenames, per-file
  details, pagination or category drill-down; layout size is bounded by kinds.
  Empty files show “暂无文件”.
- Legacy `.knownBytes` / `.knownLogicalDataBytes` null means 大小待检查 /
  总量待检查, never zero. Missing completion timestamp means 未提供.
- Theme uses ZaidangTokens + stock Material widgets; backupSecondaryColor
  derives stronger page-local secondary ink without changing the global palette.
  24px gutters, 8px primary-button corners and separators match the approved
  design/backup-restore prototype. 320px and large text must
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
| successful restore | old dataset retired automatically; no local undo entry |
| failed activation | original dataset preserved for rollback |
| 320px light/dark with large text | no overflow; scrollable review |

Good: observe app-owned job and send an intent. Base: view an empty contents
index without downloading media. Bad: page-local _busy as the only lock, using
current role names in old backups, or calling ICloudBackupService.commitRestore
from a widget.

Tests: backup_restore_page_test covers data visibility, no manual file export,
phase truth, frozen role names and file counts, explicit review, reentry, retired-data cleanup
and narrow large-text layouts. home_shell_test must override the backup provider
because it tests routing, not real file/CloudKit initialization.

Local startup failures and cloud availability are separate. Bootstrap shows retry
for ordinary storage/environment errors, with expandable actual local error
details. Recovery-only shows the preserved-data notice plus local error details;
cloud configuration errors must never alone redirect normal startup to backup.

Long waits remain observable: the compact panel tracks changes to phase, friendly
file name, byte count and file count. After 60 seconds without observed progress,
it changes to a longer-wait heading and offers the actual step. This is a UI
observation threshold, not a timeout or an ETA; it never cancels activation.

Copy restraint: normal states show only the operation name and meaningful data.
Omit instructional paragraphs, duplicate status explanations, routine validation
success, metadata time-log tabs and empty-state tutorials. Failed states retain
an actionable cause; active replacement retains “请保持 App 打开”; the final
restore dialog must still clearly state the replacement scope and inability to
undo. Do not remove these consent or recovery boundaries for visual minimalism.
