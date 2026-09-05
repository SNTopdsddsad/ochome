# Repository Evidence — Role Custom Attributes

Inspected on 2026-09-05 during planning. These are repository facts and implementation implications, not additional product requests.

| Area | Evidence | Implication |
| --- | --- | --- |
| Domain | `lib/data/models/role.dart`: immutable fixed scalar fields, a const constructor, value equality/hash | Add empty-default attributes and ordered value comparison; audit constructor calls. |
| Storage | `lib/data/database/tables/role.dart`: one `role` row holds all fixed data | An ordered text JSON column can remain within current whole-role writes. |
| Migration | `lib/data/database/app_database.dart`: schema 6; `from < 3` recreates `role`; earlier upgrades add fields, revisions and cover conversion | Add schema 7 without double-adding the column on the rebuild path; retain existing supported migrations. |
| Repository | `lib/data/repositories/drift_role_repository.dart`: transactional create/update, watched role rows, `_toDomain`, full `Role` reconstruction in `restoreDescRevision` | Save attributes in existing transactions and explicitly preserve them during history restore. |
| Interface | `lib/data/repositories/role_repository.dart`: named create fields and full-role update | Add an empty-default create argument and carry the list in `Role`; no separate attribute repository needed. |
| Editor | `lib/pages/role_create_page.dart`: local controllers, `_formKey`, `_saving`, whole-form submit, `_ArchiveCard`, `_openDescHistory` changes only description controller | Put drafts in page state, render between cards, include one save snapshot and preserve history-return behavior. |
| Backup | `lib/data/services/icloud_backup_service.dart` and `sqlite_snapshotter.dart`: checkpoint and copy the complete SQLite file; manifest uses actual `user_version` | Attributes participate through the DB snapshot; verify service-level round trips. |
| Restore gate | `lib/data/services/restore_version_gate.dart`: accepts schema ≥3 up to app version; refuses newer or too-old snapshots | Continue restoring supported old backups; keep forward-version refusal. |
| Tests | `test/data/drift_role_repository_test.dart`, `test/data/cover_path_migration_test.dart`, `test/data/icloud_backup_service_test.dart`, `test/fakes/fake_role_repository.dart`, role editor widget tests | Extend existing test seams; add a real schema-6 fixture and focused custom-attribute editor tests. |

## Applicable Specs

- `.trellis/spec/frontend/index.md` and `.trellis/spec/backend/index.md`: layer entry points; many scaffold guidelines remain unfilled, so current source/tests are the concrete evidence.
- `.trellis/spec/frontend/component-guidelines.md`: meaningful button semantics and guarding navigation during pending saves.
- `.trellis/spec/frontend/theming.md`: paper/ink tokens, light/dark variants and ink-colored destructive controls with confirmation.

## Technical Decisions from This Evidence

Use an ordered JSON array on the role row and typed domain values. Keep local draft identity independent of names so renaming/reordering does not recreate or mix input state. Keep the feature inside existing save, backup and history boundaries. No external library research or dependency change is required for this design.
