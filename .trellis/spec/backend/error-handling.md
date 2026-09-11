# Error Handling

> How the data layer signals failure and how the UI is expected to react.

---

## Overview

There is no `Result`/`Either` type in this codebase. The data layer throws
Dart exceptions and the UI catches them at the action boundary (a save button,
a delete menu item, a backup job). The exception type carries the meaning:

- **`FormatException`** — invalid user input or invalid stored data, with a
  Chinese message that can be shown verbatim.
- **`StateError`** — the operation no longer makes sense (entity gone, dataset
  switched, storage recovery-only, page stopped editing). Messages are Chinese
  when user-facing; a few internal ones are English.
- **`ArgumentError`** — programmer error (empty attribute name, self-referencing
  relationship side, absolute path handed to a relative API). Not shown to users.
- **`BackupFailure(code, message, retryable)`** — the single failure type of
  Backup v3 (`lib/features/backup/backup_models.dart`).
- Legacy iCloud path only: the sealed `BackupException` hierarchy in
  `lib/data/services/backup_exceptions.dart` with a `userMessage` field.

Messages destined for the screen are written in Chinese with `…` for
ellipsis, and are the same strings the widget tests assert against.

---

## Error Types

| Type | Thrown by | Example message |
|------|-----------|-----------------|
| `FormatException` | `normalizeRelationshipLabel` (`lib/data/models/role_relationship.dart`) | `关系不能为空`, `关系最多 30 个字` |
| `FormatException` | `RoleAssetName.renamed` / `validateBaseName` | rename rule violations |
| `FormatException` | `DriftRoleRepository._decodeAttributes` | `自定义属性必须是数组` |
| `FormatException` | `BackupJson` in `backup_protocol.dart`, `SnapshotStore`, `DataStorage` pointer parsing | `资料指针损坏，原文件已保留，请修复后重试` |
| `StateError` | `DataStorage.mutate` | `资料已经切换，请重新打开页面后操作` |
| `StateError` | `AppDatabase._openConnection`, `DataStorage.mutate` | `本地资料不可用，请先完成恢复` |
| `StateError` | `DriftRoleRelationshipRepository._ensureEndpoints` | `当前角色已不存在，请先保存角色`, `对方 OC 已不存在，请重新选择` |
| `StateError` | `DriftRoleAssetRepository` import without saved role | `请先保存角色` |
| `StateError` | `DriftRoleRepository.update` | `Role $id not found` (internal, English) |
| `ArgumentError` | `_encodeAttributes`, relationship perspective helpers, `DataStorage` path checks | programmer misuse |
| `BackupFailure` | `BackupCoordinator`, `MethodChannelBackupTransport` | platform `code` + Chinese `message` |
| `AssetOpenException` | `RoleAssetOpener` | mapped from `PlatformException.code` |
| `FileSystemException` | `ManagedFileImporter`, asset store | propagated from `dart:io` |

---

## Error Handling Patterns

**Validate in the model or value object, not the widget.** The sheet in
`lib/widgets/role_relationship_editor_sheet.dart` calls the repository and
catches `FormatException(:final message)` / `StateError` to display the
message; it does not re-implement the length rule. Widgets may pre-check for
instant hints, but the data layer is the source of truth.

**Repositories propagate; they rarely catch.** The exceptions above bubble
out of `create`/`update`/`delete`. The known deliberate swallow is
`DriftRoleAssetRepository.delete`, which ignores a `FileSystemException` after
the metadata row is gone so a missing file cannot block deleting the record.

**Delete of a missing row is not an error.** `RoleRepository.delete` and
`RoleAssetRepository.delete` return `void` and do nothing;
`RoleRelationshipRepository.delete` returns `Future<bool>` (`deleted > 0`) so
the tab can say `关系已删除` or `这条关系已经不存在了`.

**Translate platform errors at the channel wrapper.**

- `MethodChannelBackupTransport` catches `PlatformException` and throws
  `BackupFailure(e.code, e.message ?? 'iCloud 操作未完成，请稍后重试', retryable: ...)`,
  marking `unsupported` / `invalid_arguments` / `invalid_path` as
  non-retryable.
- `ICloudContainer` wraps `PlatformException` into
  `ICloudUnavailableException`; `isAvailable` returns `false` instead of
  throwing.
- `RoleAssetOpener` switches on `error.code` (`fileNotFound`, …) to build
  `AssetOpenException` with user copy.
- `VideoThumbnailService` catches everything and returns `null`; a missing
  thumbnail is not an error state.

**Map unknown failures into the domain failure once.**
`BackupCoordinator._failure` converts `FormatException`, `FileSystemException`
and anything else into `BackupFailure` so job consumers only handle one type.

**Recovery-only mode is a state, not an exception path.** `DataStorage.open`
turns a `FormatException` on the pointer into `isRecoveryOnly = true` when
`allowRecovery` is set; the router then forces `/backup` and the database
refuses to open. Other startup errors rethrow to `AppStorageBootstrap`, which
shows the retry screen with `StorageErrorDetails`.

---

## API Error Responses

There is no HTTP API. The equivalent contract is "what the UI does with the
exception":

| Situation | UI behaviour |
|-----------|--------------|
| `FormatException` / `StateError` from a save | show `message` inline (sheet hint, dialog hint) and keep the form open |
| Any other exception from a save | fixed copy such as `没能保存这段关系，请再试一次`; raw error stays in `debugPrint` |
| Failed delete | error-tone `showZaidangSnackBar` with fixed copy, `debugPrint` of error and stack |
| `BackupFailure` | `BackupJobPanel` shows `message`; retry button only when `retryable` |
| Stale epoch `StateError` | the message itself tells the user to reopen the page |
| Startup failure | `AppStorageBootstrap` error screen with retry + collapsible details |

Callers must check `mounted` (or `context.mounted`) after every `await`
before showing feedback; see `frontend/state-management.md`.

---

## Common Mistakes

- Throwing `Exception('...')` or a bare `String`. Nothing upstream can
  distinguish it from a crash; use one of the types above.
- Writing user copy in English inside `StateError`/`FormatException` that the
  UI displays verbatim. The one English `StateError` (`Role $id not found`) is
  only reached by programmer error.
- Catching `Object` in a repository and returning `null`. Callers lose the
  reason and the tests in `test/data/` assert on `throwsA(isA<StateError>())`
  with specific messages.
- Re-implementing a validation rule in a widget and letting it drift from the
  model helper. `relationshipLabelMaxLength` is exported from the model
  precisely so the sheet and the repository share one number.
- Showing the exception's `toString()` to the user for unexpected errors.
  Only `StorageErrorDetails` does this, deliberately, behind an expander for
  support cases.
