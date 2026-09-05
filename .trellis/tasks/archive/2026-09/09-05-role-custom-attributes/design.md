# Role Custom Attributes — Design

## Boundaries

Keep the existing UI → repository interface → Drift boundary. Custom attributes are an ordered part of a role, saved in the same operation. No new service, global provider or package is needed.

Repository evidence and relevant source locations are recorded in [research/repository-context.md](research/repository-context.md).

## Domain and Persistence

- Introduce a small immutable `RoleCustomAttribute` value with `name` and `content`, value equality and hashing.
- Add `Role.customAttributes`, defaulting to an empty list for existing callers. Domain equality/hash include the ordered values; database reads and UI submissions produce immutable list snapshots.
- Add an optional empty-default argument to `RoleRepository.create`. `update(Role)` continues to save a complete role. Audit every production and fake-repository reconstruction of `Role` to preserve the list when changing unrelated fields.
- Store the ordered list in a non-null text column `custom_attributes` on `role`, with a SQL default of `'[]'`. Encode as a JSON array of objects such as `[{"name":"魔法属性","content":"冰"}]`; array order is display order.
- Keep encoding/decoding at the data boundary. Validate object shape and string values explicitly; malformed stored data must produce a visible load error rather than silently becoming an empty list and later overwriting data.
- Reject blank attribute names before writes. Apply the existing form's outer-whitespace trimming convention while preserving internal newlines. The feature does not introduce name-uniqueness constraints; entries are identified by position in storage and independent draft identity in the UI.

An ordered JSON column fits the approved whole-role save boundary and requires no joins or child-query invalidation. A separate table would be useful for future cross-role querying or shared definitions, which are outside this task.

## Database Migration and Backup

- Increment `AppDatabase.currentSchemaVersion` from 6 to 7 and regenerate Drift output from source definitions.
- For existing schemas 3–6, add the column with its empty-list default. Preserve fixed columns, covers and revision rows.
- Compatibility testing found that the existing schema-3 migration could not add required `age`/`race` columns to a nonempty table without defaults. Backfill those columns with empty text through migration-only SQL so the already-supported upgrade path succeeds.
- The existing `from < 3` branch recreates `role` from the latest definition; it already receives the new column. Do not add the column again after that branch. This task must not expand the existing destructive migration policy.
- New databases receive the column through the generated schema. Restores from supported versions 3–6 run the same migration when opened.
- Backup copies the complete SQLite snapshot and reads its `user_version`, so the data format and manifest format do not need a separate attribute extension. Verify actual round-trip preservation and existing version refusal behavior.
- This is a forward schema migration. Do not implement a destructive downgrade or reduce `user_version` to make new snapshots appear old. Older app versions already reject newer-version backups.

## Editor State and Interaction

- The role editor owns an ordered list of draft entries. Each entry owns name/content controllers plus a stable local key unrelated to the editable name or current index.
- Initialize drafts once from the role. Adding creates a blank entry in place and focuses its name; validation can then identify the required field. Dispose controllers when a removed entry is no longer mounted and on page disposal.
- When empty, render only the add action between the existing cards. Otherwise render the custom-attribute card, draft entries and add action at that position, reusing `_ArchiveCard` and current form decoration/tokens.
- Support drag reordering with a dedicated handle and an accessible move action. Sorting must preserve controller ownership, cursor/content pairing and draft identity. Fit into the existing page scroll; do not create a competing scrolling form.
- Follow the project's ink-colored delete control and confirmation convention. Removal is a draft edit; persistence still waits for role save.
- On save, validate all entries and take one immutable snapshot for `create`/`update`. Disable custom-attribute mutations while saving, including stale callbacks, so the visible form cannot diverge from the pending snapshot.
- Save failure leaves drafts intact. Existing back/navigation behavior remains; this task adds no independent autosave flow.

## Description History Preservation

`restoreDescRevision` currently reconstructs `Role` before calling `update`. Pass through saved custom attributes there; otherwise the new empty default can erase them. `_openDescHistory` currently assigns only the returned description text. Retain that behavior so unsaved attribute controllers are not replaced when the history route returns.

Attribute-only edits must not append a description revision. The current description comparison already provides that boundary; verify it in the repository tests.

## Validation and Risks

- **Data loss:** Constructor defaults can hide a missed copy path. Cover full-role update, fake repository behavior and revision restore with nonempty lists.
- **Migration:** Test a real schema-6 file and existing older fixtures, including the rebuild/add-column branch distinction.
- **Interaction:** After edits, sorting and deletion, verify persisted name/content pairs; index-based keys can appear correct until a reorder.
- **Backup:** Test through the existing backup service using its fake container and temporary files, not only JSON round trips.
- **Theming/accessibility:** Verify light/dark paper cards, phone-width text entry and clear control labels.

Implementation details can be refined without changing the approved behavior. Product-scope changes require a revised review.
