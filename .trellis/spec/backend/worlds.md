# Worlds (世界观)

## 1. Scope / Trigger

Read this contract when touching the `world` table, `World` / `WorldEntry` models, `WorldRepository`, `Role.worldId`, schema migrations at or above version 9, or any backup/restore path that opens an older snapshot. A world is a user-owned setting document (名称 + 封面 + 简介 + ordered 词条). Roles may belong to at most one world; a world never owns roles.

## 2. Signatures

```dart
const World({required int id, required String name, required String summary,
             required String coverImg, List<WorldEntry> entries = const []});
const WorldEntry({required String title, required String content});

abstract interface class WorldRepository {
  Future<List<World>> list();
  Future<World?> getById(int id);
  Future<World> create({required String name, required String summary,
                        required String coverImg, List<WorldEntry> entries = const []});
  Future<World> update(World world);          // StateError when the id is unknown
  Future<void> delete(int id);                // silent for unknown ids
  Stream<List<World>> watchAll();
}

// RoleRepository additions
Future<Role> create({..., int? worldId});
Stream<List<Role>> watchByWorld(int worldId);
// Role gains `final int? worldId;` (optional ctor arg, part of == / hashCode)
```

Schema 9 (`AppDatabase.currentSchemaVersion = 9`):

```sql
CREATE TABLE world (
  id       INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
  name     TEXT NOT NULL,
  summary  TEXT NOT NULL,
  coverimg TEXT NOT NULL,                 -- relative `covers/<file>` or ''
  entries  TEXT NOT NULL DEFAULT '[]'     -- ordered JSON, see below
);
ALTER TABLE role ADD COLUMN world_id INTEGER NULL
  REFERENCES world (id) ON DELETE SET NULL;
```

`entries` JSON: `[{"title":"地理","content":"北方雪原\n南方海"}]`. Array order is display order; titles are labels, not keys, and duplicates are allowed.

Drift table class is `Worlds` (`tableName 'world'`) so the generated row type `World` does not clash with the domain class; repositories import the database `as db` and map with a private `_toDomain`.

## 3. Contracts

- `DriftWorldRepository` owns JSON encode/validate/decode. Pages consume `World` / `WorldEntry`, never maps or raw JSON.
- Writes trim `name`, `summary`, entry `title` and entry `content`; reject blank `name` and blank entry `title` with `ArgumentError`; allow empty content and empty entry lists. Encode entries before the transaction yields so caller-side list mutation cannot leak into an in-flight write.
- Reads return unmodifiable entry lists. Malformed stored JSON (not a list, wrong keys/types, blank title) throws `FormatException`; never substitute `[]`.
- `role.world_id` is the only link. Deleting a world lets SQLite null out `role.world_id` (`PRAGMA foreign_keys = ON` is set in `beforeOpen`); the repository does not touch roles. Roles are never deleted by world operations.
- Inserting/updating a role with a `worldId` that does not exist fails at the foreign key. The role editor resolves the id with `WorldRepository.getById` right before saving and writes `null` when the world has gone; do not swallow the FK error instead.
- Every production reconstruction of an existing `Role` must pass `worldId` explicitly (repository `update`, `restoreDescRevision`, the editor's submit, test fakes). Omitting it silently detaches the role.
- `watchByWorld` filters in SQL (`WHERE world_id = ?`); the fake filters in memory and re-emits on every role change.
- Migration: `from >= 3 && from < 9` runs `createTable(worlds)` then `addColumn(roles, roles.worldId)`. The `from < 3` rebuild branch creates `worlds` **before** `roles` (the latest role definition references it) and must skip the `addColumn`. Follow the same two-branch shape for any future world column.
- Backup/restore is unchanged: the whole SQLite snapshot carries `world` and `role.world_id`; world covers live in the same `covers/` directory and are enumerated with role covers; the version gate is relative to `currentSchemaVersion`. Older snapshots (≤ 8) migrate on open. No manifest change.

## 4. Validation & Error Matrix

| Input / action | Required outcome |
| --- | --- |
| World with no entries | Persist `[]`; list/edit work normally |
| Entry with title and empty content | Accept, keep order |
| Blank name / blank entry title | Reject write (`ArgumentError`); editor shows field error |
| Multiline / Unicode content | Preserved through save, load and backup |
| Malformed stored `entries` | `FormatException` on read; never an empty list |
| Role created with unknown `worldId` | FK failure; nothing inserted |
| Delete world with members | World row gone; members remain with `worldId == null` |
| Delete unknown world id | No error, no change |
| Restore ≤ v8 snapshot | Opens, migrates to v9, `world` empty, `role.world_id` null |
| Restore description revision | `worldId` unchanged |

## 5. Good / Base / Bad Cases

- **Good:** Editor builds one immutable `List<WorldEntry>`, repository encodes it inside the write transaction, deletion relies on the FK to detach roles.
- **Base:** Existing role callers omit `worldId`; roles stay unassigned and every previous test fixture remains valid.
- **Bad:** A `world_role` join table, a nullable-but-unenforced integer without the FK, cascading role deletion, decoding entries in a widget, or hardcoding `9` in a version-gate test (use `AppDatabase.currentSchemaVersion` / `+ 1`).

## 6. Tests Required

- `test/data/drift_world_repository_test.dart`: create/get/update/delete/watch round trips, trimming and rejection rules, immutable reads, malformed JSON, role membership (`watchByWorld`, move/detach, FK rejection, delete → SET NULL, revision restore keeps `worldId`) and a real v8 fixture upgrading to `currentSchemaVersion` with `world_id` present and existing role/asset/revision rows intact.
- `test/data/role_custom_attributes_migration_test.dart` keeps exercising the v2 rebuild and v3–v6 upgrades against the latest schema.
- `test/features/backup/backup_core_test.dart` legacy cases assert `userVersion == AppDatabase.currentSchemaVersion` and that `role.world_id` / `world` exist after restore.
- Test fakes (`FakeRoleRepository`, `FakeWorldRepository`) mirror the trim/reject rules and expose `detachWorld` / `onDelete` so page tests can simulate `SET NULL`.

## 7. Wrong vs Correct

```dart
// Wrong: dropping the membership when rebuilding a role
Role(id: role.id, ..., customAttributes: role.customAttributes)

// Correct: carry it explicitly
Role(id: role.id, ..., customAttributes: role.customAttributes, worldId: role.worldId)
```

```dart
// Wrong: migration order in the rebuild branch
await migrator.createTable(roles);   // role references world → fails
await migrator.createTable(worlds);

// Correct
await migrator.createTable(worlds);
await migrator.createTable(roles);
```
