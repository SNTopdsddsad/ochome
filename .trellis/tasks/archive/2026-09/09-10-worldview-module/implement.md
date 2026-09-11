# 世界观模块 · 实施计划

每一步结束都要 `flutter analyze` 通过；标 ★ 的步骤结束后跑对应测试并**单独提交**（提交规范见 `.trellis/spec/frontend/git-commit.md`，`模块: 功能声明`）。

## Step 0 · 前置

- [x] 读 `.trellis/spec/frontend/theming.md`、`navigation.md`、`role-assets.md`、`component-guidelines.md`，`.trellis/spec/backend/role-custom-attributes.md`、`role-assets.md`、`backup-restore.md`（trellis-before-dev）。
- [x] `flutter test` 基线全绿。

## Step 1 ★ 抽取共享编辑器组件（纯重构，不改行为）

- [x] 新建 `lib/widgets/archive_editor/`：`immersive_cover.dart`（`ImmersiveCover` + 名片/占位/背景）、`pinned_identity.dart`、`glass_buttons.dart`、`archive_card.dart`（`ArchiveCard`/`archiveCardDecoration`/`SectionLabel`/`FieldRow`）、`keep_alive_details.dart`。
- [x] `ImmersiveCover` 接口改为 `title` / `subtitle` / `placeholderIcon`；`RoleCreatePage` 调用处组装 `race · occupation`。
- [x] `RoleCreatePage` 删除对应私有类，改 import。
- [x] 验证：`flutter test test/pages/role_create_page_cover_test.dart test/pages/role_assets_tab_test.dart test/pages/role_card_export_page_test.dart test/pages/home_shell_test.dart`。
- [x] 提交：`应用: 抽取角色编辑页共享组件`

## Step 2 ★ 数据层：schema 9 + World 实体 + Role.worldId

- [x] `lib/data/database/tables/world.dart`：`Worlds` 表（`tableName = 'world'`）。
- [x] `tables/role.dart`：`worldId` 可空外键 `onDelete: KeyAction.setNull`。
- [x] `app_database.dart`：`@DriftDatabase(tables: [..., Worlds])`、`currentSchemaVersion = 9`、迁移（含 `from < 3` 分支先建 `worlds`）。
- [x] `lib/data/models/world.dart`、`world_entry.dart`；`role.dart` 加 `worldId`（`==`/`hashCode`）。
- [x] `lib/data/repositories/world_repository.dart` + `drift_world_repository.dart`（JSON 编解码、校验同 customAttributes）。
- [x] `role_repository.dart` / `drift_role_repository.dart`：`create(worldId)`、`update` 写 `worldId`、`_toDomain` 映射、`restoreDescRevision` 保留 `worldId`、`watchByWorld`。
- [x] `dart run build_runner build --delete-conflicting-outputs`。
- [x] 测试：
  - 新增 `test/data/drift_world_repository_test.dart`：CRUD、词条有序/多行/空内容往返、空标题拒绝、坏 JSON 抛错、`watchAll`、**删除世界观后角色 `worldId` 变 null 且角色仍在**。
  - `test/data/drift_role_repository_test.dart` 补：`worldId` 往返、`restoreDescRevision` 保留 `worldId`、`watchByWorld` 只返回归属角色。
  - 迁移：参照 `test/data/role_custom_attributes_migration_test.dart` 加 v8→v9 用例（旧角色保留、`world_id` 为 NULL、`world` 表可写）；确认 `from<3` 重建路径不重复加列。
  - `test/fakes/fake_role_repository.dart` 补 `worldId`/`watchByWorld`；新增 `test/fakes/fake_world_repository.dart`。
  - grep 测试目录中硬编码的未来版本 `9`，改为 `AppDatabase.currentSchemaVersion + 1`；跑 `test/data/icloud_backup_service_test.dart`、`sqlite_snapshotter_test.dart`、`data_storage_test.dart`、`backup_provider_integration_test.dart` 确认旧快照恢复仍通过。
- [x] 提交：`应用: 新增世界观数据表与角色归属字段`（测试若量大可拆 `测试: ...`）

## Step 3 ★ Provider + 路由 + 世界观列表页

- [x] `lib/data/providers/world_repository_provider.dart`、`worlds_provider.dart`、`roles_in_world_provider.dart`；build_runner。
- [x] `app_router.dart`：`/worlds/new`、`/worlds/:id`（root，extra 校验 redirect）。
- [x] `lib/pages/world_view_page.dart` 改为列表页（空态「还没有世界观」、tile、FAB）。
- [x] 更新 `.trellis/spec/frontend/navigation.md` 路由表与校验矩阵。
- [x] 测试：新增 `test/pages/world_view_page_test.dart`（空态/列表/FAB 跳转/点击带 extra）；修 `home_shell_test.dart`（`_pumpApp` 覆盖 `worldRepositoryProvider`；世界观页签断言改为「还没有世界观」+ 有 FAB）。
- [x] 提交：`应用: 世界观列表与路由`

## Step 4 ★ 世界观编辑页

- [x] `lib/pages/world_create_page.dart`：新建单滚动 / 编辑 NestedScrollView + 详情/角色页签；词条 sliver 增删排序；保存校验；删除（更多菜单 → 确认 → 删除 → pop）。
- [x] 角色页签：`rolesInWorldProvider(id)`，点击 `context.push('/roles/${role.id}', extra: role)`。
- [x] 测试：`test/pages/world_create_page_test.dart` —— 新建保存字段/词条配对；名称空报错；词条空标题阻止保存并提示；编辑态两页签、草稿在切页签后保留；角色页签只显示归属角色、点击跳转；删除确认文案含「不会被删除」、确认后调用 `delete` 并 pop、取消不删；保存失败保留草稿；亮/暗两主题不出现 accent 填充 AppBar。
- [x] 提交：`应用: 世界观新建与编辑页`

## Step 5 ★ 角色表单世界观选择器

- [x] `RoleCreatePage`：`_worldId` 状态、基本信息卡「世界观」行、底部弹层选择（含「不归属」）、提交时校验归属仍存在，`Role(...)` 重建带 `worldId`。
- [x] 测试：新增 `test/pages/role_create_page_world_test.dart` —— 选择后保存写入 `worldId`；「不归属」写 null；编辑态预选；被删除的世界观提交时置 null；不影响导出快照。
- [x] 提交：`应用: 角色可归属世界观`

## Step 6 · 收尾

- [x] `flutter analyze` + `flutter test` 全绿。
- [ ] 真机/模拟器手动过一遍（待用户在真机验证）：新建世界观带封面 → 备份 → 恢复 → 封面与词条完好；删除世界观后角色仍在且归属为空。
- [x] 写 spec：新增 `.trellis/spec/backend/worlds.md`（schema 9、JSON 契约、SET NULL、备份）与 `.trellis/spec/frontend/worlds.md`（列表/编辑/选择器交互）；更新两个 `index.md`；`navigation.md` 已在 Step 3 更新。
- [x] `python3 ./.trellis/scripts/task.py finish` → archive。

## 验证命令

```bash
flutter analyze
dart run build_runner build --delete-conflicting-outputs
flutter test
flutter test test/data/drift_world_repository_test.dart
flutter test test/pages/world_create_page_test.dart
```

## 风险文件 / 回滚点

| 文件 | 风险 | 回滚 |
|---|---|---|
| `lib/pages/role_create_page.dart` | Step 1 抽取 + Step 5 加选择器，两次触碰 1600 行页面 | 两步各自独立提交，可单独 revert |
| `lib/data/database/app_database.dart` | 迁移分支顺序（`from<3` 先建 world） | 迁移测试覆盖；提交前不发版 |
| `test/pages/home_shell_test.dart` | 世界观页签断言变化 | 与 Step 3 同提交 |
| 备份相关测试 | 硬编码版本号 | 改为相对 `currentSchemaVersion` |

## 实施记录（2026-09-10）

实际提交（Step 3/4 合并为一个功能提交；`lib/` 与 `test/` 按规范拆开）：

| 提交 | 内容 |
|---|---|
| `应用: 抽取角色编辑页共享组件供世界观页复用` | `lib/widgets/archive_editor/` 5 个组件；`RoleCreatePage` 1617 → 975 行 |
| `应用: 新增世界观数据表与角色归属字段` | schema 9、`World`/`WorldEntry`、`Role.worldId`、`WorldRepository`、`watchByWorld` |
| `测试: 覆盖世界观仓库、角色归属与 v8 升级` | `drift_world_repository_test.dart`（含 v8→v9 fixture）、fakes |
| `应用: 增加世界观列表、新建编辑页与删除` | provider、路由、`WorldViewPage`、`WorldCreatePage`、`RoleListTile` |
| `测试: 覆盖世界观列表、编辑页与删除流程` | `world_view_page_test`、`world_create_page_test`、`home_shell_test` 调整 |
| `应用: 角色可归属世界观` | 基本信息卡「世界观」行 + 底部选择弹层 + 提交前校验 |
| `测试: 覆盖角色世界观选择与恢复升级到当前版本` | `role_create_page_world_test`、`backup_core_test` 去硬编码 8 |

与计划的偏差：
- Step 3 与 Step 4 合并提交：路由需要引用 `WorldCreatePage`，拆开会留下无法编译或占位的中间提交。
- `RoleListTile` / `RoleCoverThumb` 从 `RoleListPage` 抽到 `lib/widgets/role_list_tile.dart`，供世界观「角色」页签与列表复用（原计划未列）。
- `GlassIconButton.onTap` 改为可空并加禁用态着色，服务于保存/删除进行中的「更多」按钮。
- 备份测试 `backup_core_test.dart` 里硬编码的当前版本 `8`（不是未来版本 `9`）改为 `AppDatabase.currentSchemaVersion`，并增加 `world_id`/`world` 存在断言。

验证：`flutter analyze` 无问题；`flutter test` 370 全绿。
