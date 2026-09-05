# Role Custom Attributes

## 1. Scope / Trigger

Read this contract when changing role fields, whole-role writes, description restoration, migrations, backups or the custom-attribute editor. Attributes are ordered, character-owned text values; they are not shared definitions or a revisioned subdocument.

## 2. Signatures

```dart
const RoleCustomAttribute({required String name, required String content});
// Role constructor retains its existing required fields:
// List<RoleCustomAttribute> customAttributes = const []
// RoleRepository.create also accepts that optional argument.
Future<Role> update(Role role);
Future<Role> restoreDescRevision({required int roleId, required int revisionId});
```

Schema 7 stores `role.custom_attributes` as `TEXT NOT NULL DEFAULT '[]'`:

```json
[{"name":"魔法属性","content":"冰"},{"name":"能力代价","content":"失去记忆\n无法回忆名字"}]
```

The array order is the display order. Names are editable text, not primary keys. Duplicate names are permitted.

## 3. Contracts

- `Role.customAttributes` participates in ordered value equality and hashing. Repository reads and UI submissions supply immutable list snapshots. The const role constructor remains available; callers must not mutate lists supplied to a role.
- `DriftRoleRepository` owns JSON encoding/validation and decoding. Pages consume `RoleCustomAttribute`, not maps or raw JSON.
- Encode before an asynchronous transaction can yield, so changes to a caller-owned list do not alter an in-flight write. The encoded attributes and fixed fields are committed together.
- Trim outer whitespace on writes, preserve internal line breaks, reject blank names and allow empty content.
- Every production reconstruction of an existing `Role` must explicitly preserve attributes unless the operation intentionally replaces them. This includes `restoreDescRevision`.
- Description-only history restoration retains saved attributes. Returning from the history page updates only the description controller so other form drafts remain intact. Attribute-only changes do not create description revisions.
- On upgrade from schemas 3–6, add the defaulted column. The `from < 3` rebuild branch already creates the latest table and must skip the extra column addition.
- A nonempty schema-3 table also needs `age` and `race` backfilled with empty text. Use migration SQL with `NOT NULL DEFAULT ''`; adding those required columns without defaults fails on existing rows. This backfill does not change the current domain's fixed-field rules.
- Backup/restore uses the complete SQLite snapshot and existing version gate. Do not add a second attribute backup file or fake an older schema version.

## 4. Validation & Error Matrix

| Input / action | Required outcome |
| --- | --- |
| No custom attributes | Persist `[]`; old roles remain valid |
| Named entry with empty content | Accept and preserve entry/order |
| Blank or whitespace-only name | Field error in the editor; reject repository write |
| Multiline / Unicode content | Preserve internal text through save, load and backup |
| Malformed JSON, wrong shape/types or blank stored name | Propagate a load error; never silently substitute an empty list |
| Same name on separate entries | Preserve both entries and their distinct content |
| Reorder / rename | Keep draft identity independent of name/index; persist intended pairs |
| Restore description history | Change description/history only; retain attributes |
| Supported older backup | Migrate and supply empty attributes |

## 5. Good / Base / Bad Cases

- **Good:** One immutable ordered list passes from editor to repository and back; the repository encodes it in the role transaction.
- **Base:** Existing callers omit the new argument and create a role with no attributes.
- **Bad:** Use names as a map key, silently discard malformed entries, update attributes outside role save, or omit the list while reconstructing an existing role.

## 6. Tests Required

- Repository tests assert ordered round trips, multiline/empty values, independent roles, no extra description revision, preservation during history restore, immutable read results and rejection of invalid writes/stored data.
- Migration tests open actual old SQLite fixtures, verify fixed fields/revisions survive and ensure the rebuild branch does not add the new column twice.
- Backup service tests replace locally modified data from a real snapshot and compare the full ordered attribute values. Retain a supported older backup case.
- Version-gate tests must express future snapshots as `AppDatabase.currentSchemaVersion + 1`; a hardcoded future version becomes the current supported version after a migration.
- Editor tests edit then reorder/delete entries and assert persisted name/content pairing, validate offscreen drafts, retain failed-save drafts and verify history return does not replace attribute drafts.

## 7. Wrong vs Correct

When reconstructing a role for description restoration:

```dart
// Wrong: omitting customAttributes silently selects its empty default.
// Role(...existingFixedFields, desc: revision.content)

// Correct: preserve the independent list along with existing fixed fields.
// Role(...existingFixedFields, desc: revision.content,
//      customAttributes: role.customAttributes)
```

The snippets abbreviate unchanged constructor arguments. The executable reference is `DriftRoleRepository.restoreDescRevision` in `lib/data/repositories/drift_role_repository.dart`.
