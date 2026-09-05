# Role Custom Attributes — Implementation Plan

## Entry Gate

- [x] Capture the confirmed scope in `prd.md` and complete its convergence pass.
- [x] Inspect domain, repository, editor, migration, backup and relevant tests.
- [x] Record design, compatibility risks and context manifests.
- [x] Complete the final implementation review; the user approved implementation with “开始” on 2026-09-05.

The repository's Codex dispatch setting defaults to sub-agent mode. At implementation/check time follow the workflow's bounded `trellis-implement` / `trellis-check` dispatch instructions and curated manifests. No implementation agent has been dispatched during planning.

## Ordered Work

1. **Domain, storage and migration**
   - [x] Add the ordered attribute value model, role field and equality/hash behavior.
   - [x] Extend the create interface, Drift mapping/codec and all relevant role copy paths.
   - [x] Add the defaulted JSON column, schema-7 migration and generated Drift output.
   - [x] Preserve attributes when restoring description history; update the fake repository.
   - [x] Verify persistence, role isolation, empty content, Unicode/multiline content, order, attribute-only edits and revision restore.
2. **Editor**
   - [x] Add draft entry state, stable keys, controller lifecycle and inline form validation.
   - [x] Implement add-only empty state and the custom card between the existing cards.
   - [x] Implement rename/content editing, deletion and reordering with accessible controls.
   - [x] Include the draft snapshot in role save and guard mutations while saving.
   - [x] Verify save/reopen, save failure, unsaved navigation, delete-all, sorting after edits, history return and light/dark phone layout.
3. **Compatibility and integration**
   - [x] Add a schema-6 migration fixture; verify no fixed data or revision loss.
   - [x] Exercise existing supported older migrations and backup restores.
   - [x] Extend backup/restore coverage with nonempty attributes and ordering.
   - [x] Run the full relevant suite and review every PRD acceptance criterion.
4. **Finish**
   - [x] Run the workflow's full-scope check and review both frontend/backend guidelines.
   - [x] Record any new durable conventions in specs, especially full-role reconstruction and migration pitfalls.
   - [x] Present the task's commit grouping as required by workflow; exclude unrelated pre-existing `.vscode/` and `CLAUDE.md` changes. The user approved `commit-plan.md`; application and tests are committed as `29269d4` and `53e10f2`, with task/spec records in the third group.

## Validation Commands

Use the project's installed Flutter/Dart SDK; inspect local SDK configuration if the commands are not on PATH.

```sh
dart run build_runner build --delete-conflicting-outputs
dart format <changed Dart source and test files>
flutter analyze
flutter test test/data/drift_role_repository_test.dart
flutter test test/data/role_custom_attributes_migration_test.dart
flutter test test/pages/role_create_page_custom_attributes_test.dart
flutter test test/data/icloud_backup_service_test.dart test/data/cover_path_migration_test.dart
flutter test
```

The two custom-attribute test files are planned additions. Focus tests on observable persistence, migration and interaction failures; do not add tests that merely duplicate implementation details. Run the full suite once after integration; repeat only for later changes or failures.

## Review and Rollback Points

- Before generated output: inspect table definition and migration guards, including older rebuild paths.
- Before UI integration: verify repository/restore operations retain nonempty attributes.
- Before completion: review controller identities through reorder/delete and audit all `Role(...)` construction sites.
- Roll back code using only this task's changes if needed. Preserve user databases and any unrelated working-tree edits; do not downgrade an upgraded database in place.

## Planning Verification

Planning artifacts and context references are validated separately with `python3 .trellis/scripts/task.py validate 09-05-role-custom-attributes`. Implementation is complete: static analysis, all 110 tests, changed-file formatting and context validation pass. See `verification.md`.
