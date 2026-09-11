# Directory Structure (Data Layer)

> Where data-layer code lives in 崽档 and what each folder is allowed to know about.

---

## Overview

崽档 is a single Flutter package with no server. "Backend" here means everything
under `lib/data/` plus the non-widget parts of `lib/features/backup/`: the Drift
SQLite database, domain models, repository interfaces and their Drift
implementations, Riverpod providers, and file/iCloud/platform-channel services.

The layer is organised by responsibility, not by feature. A feature such as
role relationships touches one file in each folder:

| Concern | File |
|---------|------|
| Table | `lib/data/database/tables/role_relationship.dart` |
| Domain model + validation helpers | `lib/data/models/role_relationship.dart` |
| Repository interface | `lib/data/repositories/role_relationship_repository.dart` |
| Drift implementation | `lib/data/repositories/drift_role_relationship_repository.dart` |
| Providers | `lib/data/providers/role_relationships_provider.dart` |
| Tests | `test/data/role_relationships_test.dart`, `test/fakes/fake_role_relationship_repository.dart` |

Role assets follow the identical spread (`role_asset.dart`,
`role_asset_repository.dart`, `drift_role_asset_repository.dart`,
`role_assets_provider.dart`).

---

## Directory Layout

```
lib/
  main.dart                  runApp(ProviderScope(child: AppStorageBootstrap()))
  bootstrap.dart             initializeDataStorage() before MyApp; startup error UI
  data/
    database/
      app_database.dart      @DriftDatabase, currentSchemaVersion, migrations
      app_database.g.dart    generated, committed
      tables/*.dart          one Drift Table class per SQLite table
    models/*.dart            immutable domain models and value objects
    repositories/
      <name>_repository.dart        abstract interface (domain types only)
      drift_<name>_repository.dart  Drift implementation
    providers/*.dart         Riverpod providers (+ committed .g.dart for codegen ones)
    services/*.dart          DataStorage, file stores, importers, MethodChannel wrappers,
                             legacy iCloud backup, restore gate
  features/
    backup/                  Backup v3: coordinator, models, protocol, transport, snapshot store
    role_card/               role-card export pipeline (content, renderer, fonts, delivery)
test/
  data/                      repository, migration, storage and service tests
  fakes/                     in-memory fakes and backup fixtures shared by widget tests
  features/backup/           BackupCoordinator + FakeBackupTransport tests
  native/*.swift             standalone swiftc tests for iOS handlers
```

---

## Module Organization

**`database/`** knows only Drift. Table classes are plural (`Roles`,
`RoleAssets`, `RoleRelationships`) with `tableName` overridden to the singular
snake_case SQLite name. `AppDatabase` owns the schema version, migrations and
the `mutate()` epoch gate; it never imports models or repositories.

**`models/`** knows nothing about Drift. Domain classes are `const`,
all-`final`, and live next to the validation helpers that produce their
user-facing `FormatException` messages (`normalizeRelationshipLabel` in
`role_relationship.dart`, `RoleAssetName.validateBaseName` in
`role_asset_name.dart`).

**`repositories/`** is the only place where Drift rows meet domain models.
Interfaces expose domain types exclusively — `role_repository.dart` documents
"只暴露领域 Role，不出现 Drift 的 AppDatabase / RolesCompanion". Drift
implementations import the database with an alias
(`import '../database/app_database.dart' as db;`) and map rows in private
`_toDomain` / `_map` functions.

**`providers/`** wires repositories to the database and exposes streams to the
UI. Every watch provider checks `databaseSwitchProvider` first and returns
`Stream.empty()` during a dataset switch. See
`frontend/hook-guidelines.md` for the provider conventions.

**`services/`** holds infrastructure without business rules: `DataStorage`
(dataset pointer, epochs, recovery-only mode), `LocalFileStore` /
`CoverStore` / `RoleAssetStore` (files under the dataset directory),
`ManagedFileImporter` (streamed copy + SHA-256), `FileFingerprintStore`,
`SqliteSnapshotter`, the MethodChannel wrappers (`icloud_container.dart`,
`role_asset_opener.dart`, `video_thumbnail_service.dart`) and the legacy
iCloud backup service. Channel names all start with `com.xuwudi.ochome/`.

**`features/backup/`** is the current backup product (v3). It is a feature
folder because it spans data (coordinator, protocol, snapshot store) and UI
(`widgets/`). Its data half depends on `services/data_storage.dart` and
`sqlite_snapshotter.dart`, never the reverse. `backup_exceptions.dart` in
`services/` belongs to the older iCloud path; new backup code uses
`BackupFailure` from `features/backup/backup_models.dart`.

---

## Naming Conventions

- Files: `snake_case.dart`; Drift implementations prefixed `drift_`; fakes
  prefixed `fake_` in `test/fakes/`.
- Table classes: plural PascalCase, `tableName` singular snake_case
  (`RoleDescRevisions` → `'role_desc_revision'`).
- Generated files keep the `.g.dart` suffix and are committed; do not edit them.
- Providers are named `<subject>Provider` whether generated
  (`appDatabaseProvider`, `rolesProvider`) or hand-written
  (`roleAssetsProvider`, `backupCoordinatorProvider`).
- Repository method names are verbs on the domain: `create`, `update`,
  `delete`, `getById`, `list`, `watchAll`, `watchForRole`.
- Static file-layout constants live where the layout is decided:
  `AppDatabase.sqliteFileName = 'ochome.sqlite'`, `CoverPath` helpers,
  `RoleAssetStore` directory name.

---

## Examples

Adding a new persisted entity (mirror `role_relationship`):

1. `lib/data/database/tables/<entity>.dart` — table class with FK cascades
   and `@TableIndex` for every FK column.
2. Register it in `@DriftDatabase(tables: [...])`, bump
   `currentSchemaVersion`, add an `if (from < N)` block (see
   `database-guidelines.md`).
3. `lib/data/models/<entity>.dart` — const model with `==`/`hashCode`, plus
   any validation helper that throws `FormatException` with Chinese copy.
4. `lib/data/repositories/<entity>_repository.dart` and
   `drift_<entity>_repository.dart`.
5. `lib/data/providers/<entity>_provider.dart` — `Provider` for the
   repository, `StreamProvider.autoDispose.family` for watches, gated on
   `databaseSwitchProvider`; add the new watch provider to the `invalidate`
   list in `backup_coordinator_provider.dart`.
6. Extend the backup inventory/validation in
   `lib/features/backup/snapshot_store.dart` if the table must survive
   backup/restore, and update `backend/backup-restore.md`.
7. `test/data/<entity>_test.dart` with an in-memory `AppDatabase` and an
   upgrade fixture from the previous schema; `test/fakes/fake_<entity>_repository.dart`
   for widget tests.

Anti-patterns seen and rejected in review:

- Importing `AppDatabase` or a `*Companion` into `lib/pages/` or
  `lib/widgets/`. UI only sees repository interfaces and models.
- Putting file I/O into a repository interface signature (assets take
  `XFile`/`File` from the picker, but return only `RoleAsset`).
- Creating a second database instance outside `appDatabaseProvider` /
  `AppDatabase.forStorage`; the epoch gate depends on one live instance.
