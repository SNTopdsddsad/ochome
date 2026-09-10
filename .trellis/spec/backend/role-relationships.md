# Role Relationships

## Scope and ownership

Read before touching `role_relationship`, `RoleRelationshipRepository`, the
relationship editor, or any code that enumerates business tables (backup
inventory, health checks, migration fixtures).

- Schema version **9** adds `role_relationship`: `id`, `from_role_id`,
  `to_role_id`, `from_label`, `to_label`, `created_at`. Both role columns
  reference `role(id)` with `ON DELETE CASCADE` and have their own index
  (`role_relationship_from_role_id`, `role_relationship_to_role_id`).
- No uniqueness constraint on the role pair: one pair may hold several
  relationships (师徒 and 恋人 at once). `from != to` is enforced by the
  repository, not the schema.
- Relationship rows belong to `RoleRelationshipRepository`
  (`lib/data/repositories/role_relationship_repository.dart`), separate from
  whole-role `update`, description history and assets. Only saved roles can
  participate; the create form has no relationship UI.
- Upgrade creates the table and two indexes only; it never rewrites `role`,
  revisions or assets.

## Directed single-row model

One row stores both directions and is shared by both endpoints:

```
from_label : from 是 to 的 ___   (e.g. 师父)
to_label   : to 是 from 的 ___   (e.g. 徒弟)
```

`RoleRelationship` (`lib/data/models/role_relationship.dart`) exposes
perspective helpers; UI must go through them instead of comparing ids inline:

```dart
relationship.otherRoleId(selfId);  // counterpart id
relationship.selfLabel(selfId);    // 我是对方的 ___
relationship.otherLabel(selfId);   // 对方是我的 ___
```

They throw `ArgumentError` when `selfId` is not an endpoint. Do not store a
mirrored second row; do not cache the counterpart's name or cover in the row.
Names and covers are joined at display time from `rolesProvider`.

## Repository contract

```dart
Stream<List<RoleRelationship>> watchForRole(int roleId); // from OR to, newest first
Future<List<RoleRelationship>> listForRole(int roleId);
Future<RoleRelationship> create({fromRoleId, toRoleId, fromLabel, toLabel});
Future<RoleRelationship> update(RoleRelationship relationship); // by id, all fields
Future<bool> delete({required int roleId, required int relationshipId}); // true if a row went
```

| Input or state | Contract |
|---|---|
| Labels with surrounding spaces | Trim before persistence (`normalizeRelationshipLabel`) |
| Empty/whitespace label, label containing a newline, more than `relationshipLabelMaxLength` (30) grapheme clusters | `FormatException` with user-facing message |
| `fromRoleId == toRoleId` | `FormatException('不能和自己建立关系')` |
| `fromRoleId` missing (`from` is the editing role by convention) | `StateError('当前角色已不存在，请先保存角色')` |
| `toRoleId` missing (counterpart deleted meanwhile) | `StateError('对方 OC 已不存在，请重新选择')` |
| `update` on a missing id | `StateError('关系不存在')` |
| `delete` with a `roleId` that is not an endpoint, or an unknown id | No rows affected, returns `false`, no error |
| Deleting a role | Both incoming and outgoing rows disappear via FK cascade |

`create`/`update` are `async` so label validation surfaces as a Future error;
callers must not rely on synchronous throws. All writes run through
`AppDatabase.mutate` and reject stale storage epochs like other repositories.
`normalizeRelationshipLabel` / `validateRelationshipLabel` are the single
validation policy shared by the editor and the repository; the length cap
counts grapheme clusters via `package:characters` so it matches the
`TextField.maxLength` enforcement in the editor.

## Providers and lifecycle

`roleRelationshipRepositoryProvider` and
`roleRelationshipsProvider.family(roleId)` live in
`lib/data/providers/role_relationships_provider.dart`. The stream family
returns `Stream.empty()` while `databaseSwitchProvider` is true. Backup's
`closeDatabase` must invalidate `roleRelationshipsProvider`; `reopenDatabase`
must invalidate `roleRelationshipRepositoryProvider`. Forgetting either leaves a
watched query attached to the closing database.

## Backup and restore

- Business schema is now **9**. `inspectBackupDatabase` validates
  `role_relationship` when `userVersion >= 9`: both endpoints exist, differ,
  labels are non-empty, `created_at` is an integer. A violation fails the
  backup/restore before review, matching custom attribute validation.
- Legacy snapshots at schema 3–8 restore with an empty relationship set; the
  isolated candidate database migrates to 9 before activation.
- The full-SQLite snapshot carries relationships; no manifest/protocol change.

## Good / Base / Bad

Good: create `(A→B, 师父, 徒弟)` once; A's tab shows `我是 TA 的师父 · TA 是我的徒弟`,
B's tab shows the reverse from the same row.
Base: a role with no relationships shows the empty state and a working add button.
Bad: inserting a second mirrored row for B, or overloading `customAttributes`
with a "关系" entry that has no role id.

## Validation

`test/data/role_relationships_test.dart`: both perspectives from one row,
multiple rows per pair, self-link/missing-role/empty-label rejection, update
semantics, scoped delete, cascade on role delete, v8→9 migration preserving
roles/history/assets and creating both indexes.
`test/features/backup/backup_core_test.dart`: legacy schema 3–9 fixtures
migrate to `AppDatabase.currentSchemaVersion`; self-linked rows fail business
validation.
`test/pages/role_relationships_tab_test.dart`: tab visibility, add/edit/delete
flows, perspective wording, busy gating and in-dialog failure.
