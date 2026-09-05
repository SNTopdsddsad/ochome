# Work Commit Plan

All groups contain only changes made for this task. The user approved these three groups with “按计划提交” on 2026-09-05. Application commit: `29269d4`; test commit: `53e10f2`. The third group records the task and specs.

## 1. 应用: 增加角色自定义属性

- `lib/data/database/app_database.dart`
- `lib/data/database/app_database.g.dart`
- `lib/data/database/tables/role.dart`
- `lib/data/models/role.dart`
- `lib/data/models/role_custom_attribute.dart`
- `lib/data/repositories/drift_role_repository.dart`
- `lib/data/repositories/role_repository.dart`
- `lib/pages/role_create_page.dart`

## 2. 测试: 验证自定义属性保存与兼容恢复

- `test/data/drift_role_repository_test.dart`
- `test/data/icloud_backup_service_test.dart`
- `test/data/role_custom_attributes_migration_test.dart`
- `test/data/sqlite_snapshotter_test.dart`
- `test/fakes/fake_role_repository.dart`
- `test/pages/role_create_page_cover_test.dart`
- `test/pages/role_create_page_custom_attributes_test.dart`
- `test/pages/role_custom_attributes_keyboard_test.dart`

## 3. Trellis: 记录自定义属性需求与开发规范

- `.trellis/spec/backend/index.md`
- `.trellis/spec/backend/role-custom-attributes.md`
- `.trellis/spec/frontend/component-guidelines.md`
- `.trellis/spec/frontend/index.md`
- `.trellis/tasks/09-05-role-custom-attributes/check.jsonl`
- `.trellis/tasks/09-05-role-custom-attributes/commit-plan.md`
- `.trellis/tasks/09-05-role-custom-attributes/design.md`
- `.trellis/tasks/09-05-role-custom-attributes/implement.jsonl`
- `.trellis/tasks/09-05-role-custom-attributes/implement.md`
- `.trellis/tasks/09-05-role-custom-attributes/prd.md`
- `.trellis/tasks/09-05-role-custom-attributes/research/repository-context.md`
- `.trellis/tasks/09-05-role-custom-attributes/task.json`
- `.trellis/tasks/09-05-role-custom-attributes/verification.md`

## Pre-existing Files Excluded

- `.vscode/`
- `CLAUDE.md`
