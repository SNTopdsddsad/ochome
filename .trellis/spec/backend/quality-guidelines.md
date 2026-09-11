# Quality Guidelines (Data Layer)

> What must be true before data-layer code is committed.

---

## Overview

Quality is enforced by three commands and by tests that run against real
SQLite, not mocks:

```bash
flutter analyze                                   # flutter_lints 6 + riverpod_lint plugin, zero issues
flutter test                                      # whole suite, currently ~355 tests
dart run build_runner build --delete-conflicting-outputs   # after table/@riverpod changes
```

There is no CI and no git hook; the developer runs these locally before
committing. Commits follow `.trellis/spec/frontend/git-commit.md` (Chinese
`模块: 功能声明`, one module per commit — data changes are typically
`数据:` and their tests `测试:`).

`analysis_options.yaml` uses the stock `flutter_lints` set with no extra rules
and no suppressions in hand-written code; the only `ignore_for_file` lines are
in generated `.g.dart` files.

---

## Forbidden Patterns

- **Drift types outside `lib/data/`.** No `AppDatabase`, `*Companion` or
  generated row class in pages, widgets or features other than backup
  internals. Repository interfaces expose domain models only.
- **Writes outside `_db.mutate(() => _db.transaction(...))`.** Bypassing the
  epoch gate lets a write land on a dataset the user just replaced.
- **Editing a shipped migration block or forgetting the
  `currentSchemaVersion` bump.**
- **Hand-editing `.g.dart` files.** Regenerate them.
- **`print`, `Logger`, or new logging in repositories/services.** See
  `logging-guidelines.md`.
- **Generic `Exception('...')`.** Use `FormatException`, `StateError`,
  `ArgumentError` or `BackupFailure` per `error-handling.md`.
- **Static mutable singletons beyond the existing ones.** `DataStorage.current`
  and the `ManagedFileWork` queue exist for bootstrap and file serialisation;
  new services take their dependencies through constructors so tests can
  inject them (`CoverImagePicker(picker:, supportDirectory:)`,
  `RoleAssetOpener(channel:)`, `BackupCoordinator(storage, transport, ...)`).
- **Tests that mock Drift.** Data tests open `AppDatabase(NativeDatabase.memory())`
  or a temp file; fakes exist only at the repository interface for widget tests.

---

## Required Patterns

- Interface + `Drift*` implementation pair for every repository; the interface
  file carries the doc comment describing semantics (what `delete` returns for
  a missing row, ordering guarantees).
- Import the database as `db` in repositories; map rows in a private
  `_toDomain`/`_map`.
- Validation helpers next to the model
  (`normalizeRelationshipLabel`, `RoleAssetName.validateBaseName`) with
  Chinese `FormatException` messages, exported constants for limits
  (`relationshipLabelMaxLength`).
- New stream providers gate on `databaseSwitchProvider` and are added to the
  `invalidate` list in `lib/data/providers/backup_coordinator_provider.dart`.
- New tables get FK cascades, a `@TableIndex` per FK, a migration block, and
  are covered by the backup inventory in
  `lib/features/backup/snapshot_store.dart` when they hold user data.
- Every `MethodChannel` wrapper converts `PlatformException` into a domain
  exception at the wrapper.
- Spec updates land with the code: a new or changed data contract updates the
  matching file in `.trellis/spec/backend/` (see `role-relationships.md`,
  `role-assets.md`, `backup-restore.md` for the expected depth: signatures,
  validation matrix, test points).

---

## Testing Requirements

Location and style follow the existing suite:

- `test/data/<feature>_test.dart` uses `test()` with English descriptions
  (Chinese product nouns inside are fine, e.g. `'... creates 设定修订表'`).
  `group()` is rare; one file per feature is the norm.
- Open the database in `setUp` and close it in `tearDown` / `addTearDown`:

```dart
late AppDatabase database;
setUp(() => database = AppDatabase(NativeDatabase.memory()));
tearDown(() async => database.close());
```

- Every migration has an upgrade test that seeds the previous schema with the
  raw `sqlite3` package (`PRAGMA user_version = N-1`) and asserts data after
  `AppDatabase` opens the file.
- Repository tests cover: happy path, each `FormatException` /
  `StateError` message (`throwsA(isA<StateError>().having(...))` or
  `predicate`), cascade deletes, and ordering.
- Dataset isolation and epoch behaviour are tested with
  `AppDatabase.forStorage(storage, executor: NativeDatabase(file))`
  (`test/data/storage_repository_isolation_test.dart`,
  `test/data/data_storage_test.dart`).
- Widget-facing fakes in `test/fakes/fake_<name>_repository.dart` are
  in-memory, expose broadcast `StreamController`s for `watch*`, and offer
  knobs such as `pendingSave` (a `Completer` to hold a write), `failSave`,
  and call counters (`createCalls`, `renameCalls`). Update the fake in the
  same change as the interface.
- Temp directories come from `Directory.systemTemp.createTemp(...)` and are
  deleted in teardown.
- Backup v3 changes run `test/features/backup/backup_core_test.dart` against
  `FakeBackupTransport` and the schema-8 fixture from
  `test/fakes/backup_test_support.dart`; native Swift handlers have standalone
  `swiftc` tests in `test/native/`.

---

## Code Review Checklist

- [ ] `flutter analyze` is clean and `flutter test` passes locally.
- [ ] Schema change: `currentSchemaVersion` bumped, new `if (from < N)` block,
      `.g.dart` regenerated and committed, upgrade test added.
- [ ] Writes are inside `_db.mutate(() => _db.transaction(...))`.
- [ ] Repository interface exposes only domain types; doc comment states
      delete/ordering semantics; fake repository updated.
- [ ] User-facing failures throw `FormatException`/`StateError` with Chinese
      copy that the UI test asserts; unexpected failures are not swallowed
      silently.
- [ ] New stream provider is gated on `databaseSwitchProvider` and
      invalidated in `backup_coordinator_provider.dart`.
- [ ] New user-data table is included in backup inventory/validation and
      `backend/backup-restore.md` is updated.
- [ ] No Drift import leaks into `lib/pages/`, `lib/widgets/`.
- [ ] Matching spec file in `.trellis/spec/backend/` updated or created.
- [ ] Commit split by module (`数据:` / `备份:` / `测试:` / `Trellis:`).
