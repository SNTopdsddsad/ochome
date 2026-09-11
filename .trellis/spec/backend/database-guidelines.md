# Database Guidelines

> Drift + SQLite conventions for 崽档's local dataset.

---

## Overview

- ORM: `drift` 2.34 with `drift_flutter`; codegen via `drift_dev` and
  `build_runner`. Generated `app_database.g.dart` is committed.
- One database class, `AppDatabase` in `lib/data/database/app_database.dart`,
  registers every table: `Roles`, `RoleDescRevisions`, `RoleAssets`,
  `Worlds`, `RoleRelationships`.
- The live file is `ochome.sqlite` inside the active dataset directory chosen
  by `DataStorage` (`lib/data/services/data_storage.dart`). Opening is refused
  with `StateError('本地资料不可用，请先完成恢复')` when storage is
  recovery-only.
- `PRAGMA foreign_keys = ON` runs in `beforeOpen`; all child tables declare
  `onDelete: KeyAction.cascade`, so deleting a role removes its revisions,
  assets and relationships at the SQL level.
- `currentSchemaVersion` is `10`. The doc comment on it is the rule:
  "增删列后必须递增并补 migration".

Regenerate after any table or `@riverpod` change:

```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## Query Patterns

**Reads** go through Drift's query builder and are mapped to domain models in
the repository:

- Streams for the UI: `select(...).watch().map(rows => rows.map(_toDomain))`
  — `watchAll` in `drift_role_repository.dart`, `watchForRole` in
  `drift_role_asset_repository.dart` and `drift_role_relationship_repository.dart`.
- One-shot: `.get()`, `getSingleOrNull()` for `getById`.
- Ordering is explicit for time-ordered tables: `orderBy` on `createdAt`
  descending then `id` descending (revisions, assets, relationships). The
  `role` table is read without an `orderBy`.
- Existence checks use `selectOnly(table)..addColumns([table.id])` rather than
  loading full rows (`_ensureEndpoints` in the relationship repository).

**Writes** always go through the epoch gate and a transaction:

```dart
return _db.mutate(
  () => _db.transaction(() async {
    // inserts / updates / deletes
  }),
);
```

`AppDatabase.mutate` forwards to `DataStorage.mutate(action, expectedEpoch:)`,
which throws `StateError('资料已经切换，请重新打开页面后操作')` if the dataset
was swapped by a restore since this `AppDatabase` was created, and
`StateError('本地资料不可用，请先完成恢复')` in recovery-only mode. With a bare
`AppDatabase(NativeDatabase.memory())` (tests) `mutate` is a pass-through.

Use `insertReturning` / `writeReturning` when the caller needs the persisted
row (role create/update, relationship create/update) so the domain object
reflects defaults and the generated id. Plain `.insert` / `.write` / `.go()`
are fine when nothing is returned.

**Raw SQL** is limited to places Drift cannot express or that run outside a
Drift connection:

- `customStatement` in migrations (ALTER with DEFAULT, INSERT…SELECT backfill,
  `PRAGMA foreign_keys`).
- `customSelect('SELECT 1')` / `SELECT id FROM role LIMIT 1` in
  `backup_coordinator_provider.dart` to force the connection to open or reopen.
- The `sqlite3` package directly in `sqlite_snapshotter.dart`,
  `file_fingerprint_store.dart` and `DataStorage._checkHealth`
  (`PRAGMA quick_check`, online backup API) because these operate on files
  that are not the live Drift database.

Do not add raw SQL to repositories for ordinary CRUD.

---

## Migrations

`MigrationStrategy` overrides `onUpgrade` and `beforeOpen` only; table
creation on a fresh install is Drift's default `onCreate`. Each upgrade step
is a guarded block that runs exactly once per install:

```dart
if (from < 8) {
  await m.createTable(roleAssets);
  await m.createIndex(roleAssetRoleId);
}
if (from < 10) {
  await m.createTable(roleRelationships);
  if (!await _hasIndex('role_relationship_from_role_id')) {
    await m.createIndex(roleRelationshipFromRoleId);
  }
  ...
}
```

Rules that the existing blocks (v3…v10) follow:

- Never rewrite an earlier block; append a new `if (from < N)` and bump
  `currentSchemaVersion` to `N`.
- Never let two branches claim the same version number. v9 was assigned to
  both the worlds and the relationships branches; the v10 block therefore
  probes `PRAGMA table_info` / `sqlite_master` before `addColumn` /
  `createIndex` (Drift's `createTable` is already `IF NOT EXISTS`, the other
  two are not). Coordinate the next version before starting a schema branch.
- Adding a NOT NULL column to an existing table needs a DEFAULT; v4 does this
  with `customStatement('ALTER TABLE role ADD COLUMN age TEXT NOT NULL DEFAULT \'\'')`.
- Data backfills happen in the same block as the schema change (v5 seeds the
  first `role_desc_revision` from `role.desc`; v6 rewrites absolute cover paths
  to relative via `_rewriteCoverImgToRelative`).
- `DateTimeColumn` values stored by hand in SQL must be unix **seconds**
  (`strftime('%s', 'now')`), matching Drift's default DateTime storage.
- Backup restore compares versions with `RestoreVersionGate`
  (`minSupportedSchema = 3`) and the v3 `SnapshotStore` migrates imported
  datasets by opening them with `AppDatabase.forStorage`, so every migration
  must be safe to run on a restored file as well as an in-place upgrade.

Every migration ships with a test that builds the previous schema with the raw
`sqlite3` package, sets `PRAGMA user_version`, opens `AppDatabase` on that file
and asserts the upgraded rows:
`test/data/role_custom_attributes_migration_test.dart`,
`test/data/cover_path_migration_test.dart`, the upgrade cases in
`test/data/role_assets_test.dart` and `test/data/role_relationships_test.dart`,
and the schema-8 fixture in `test/fakes/backup_test_support.dart`.

---

## Naming Conventions

| Thing | Convention | Example |
|-------|------------|---------|
| Table class | plural PascalCase | `RoleRelationships` |
| `tableName` | singular snake_case | `'role_relationship'` |
| Columns | camelCase getter → Drift snake_case | `roleId` → `role_id` |
| Legacy column names | keep via `.named()` | `coverImg` → `.named('coverimg')` |
| Primary key | `integer().autoIncrement()()` | every table |
| Foreign key | `references(Roles, #id, onDelete: KeyAction.cascade)` | assets, revisions, relationships |
| Index | `@TableIndex(name: '<table>_<column>', columns: {#column})` | `role_asset_role_id` |
| Two FKs to one table | `@ReferenceName` on each | `outgoingRelationships` / `incomingRelationships` |
| Timestamps | `DateTimeColumn get createdAt => dateTime()()` | revisions, assets, relationships |
| JSON blob | `TextColumn` with `withDefault(const Constant('[]'))`, encoded by the repository | `Roles.customAttributes` |

There are no Drift `TypeConverter`s; JSON encode/decode for
`custom_attributes` lives in `DriftRoleRepository._encodeAttributes` /
`_decodeAttributes` so that a malformed blob surfaces as a `FormatException`
with Chinese copy instead of a converter crash.

---

## Common Mistakes

- Forgetting to bump `currentSchemaVersion` after adding a table: the app
  opens fine on a fresh install and crashes on every upgraded device. The
  migration test with a previous-version fixture catches this.
- Editing a shipped `if (from < N)` block. Devices already at N never run it
  again; add a new block instead.
- Writing outside `_db.mutate(...)`. The write succeeds against a dataset the
  user just replaced by a restore, and the UI shows stale data. Widget tests
  cannot catch this; `test/data/storage_repository_isolation_test.dart` does.
- Closing the database while a `watch()` stream is still subscribed hangs
  `close()`. `backup_coordinator_provider.dart` invalidates every stream
  provider before calling `close()` — add new stream providers to that list.
- Seeding `DateTime` columns in SQL with milliseconds. Drift reads them as
  seconds; the fixture in `role_custom_attributes_migration_test.dart` shows
  the seconds-based expectation.
- Importing generated row classes (`Role`, `RoleAsset`) into UI code. Alias the
  database import as `db` in repositories and `hide Role` when tests import
  `app_database.dart` alongside the model.
