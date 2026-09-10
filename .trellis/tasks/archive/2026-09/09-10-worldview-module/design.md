# 世界观模块 · 技术设计

## 1. 架构与边界

沿用现有四层结构，新增一条与 Role 平行的实体链路，并给 Role 加一个可空外键：

```
WorldViewPage(列表) / WorldCreatePage(编辑)         RoleCreatePage(+世界观选择器)
        ↓ ref.watch                                      ↓
worldsProvider / worldRepositoryProvider      rolesProvider / rolesInWorldProvider(worldId)
        ↓                                                ↓
WorldRepository (抽象)                          RoleRepository (+worldId, +watchByWorld)
        ↓                                                ↓
DriftWorldRepository ──────── AppDatabase (schema 9) ──── DriftRoleRepository
```

边界规则不变：仓库接口只暴露领域模型；`import ... as db` 隔离 Drift 行类型；页面只依赖 provider。

## 2. 数据模型

### 2.1 新表 `world`（Drift 类 `Worlds`）

| 列 | 类型 | 说明 |
|---|---|---|
| `id` | INTEGER PK autoincrement | |
| `name` | TEXT NOT NULL | 名称，必填 |
| `summary` | TEXT NOT NULL | 简介，可空字符串 |
| `coverimg` | TEXT NOT NULL | 封面相对路径 `covers/<file>`，复用 `CoverPath` 契约；空字符串表示无封面 |
| `entries` | TEXT NOT NULL DEFAULT '[]' | 有序词条 JSON，见 2.3 |

不加时间戳列——与 `role` 保持一致，列表按 id 顺序。

### 2.2 `role.world_id`

`INTEGER NULL REFERENCES world(id) ON DELETE SET NULL`。Drift：`integer().nullable().references(Worlds, #id, onDelete: KeyAction.setNull)()`。已有 `PRAGMA foreign_keys = ON`（`app_database.dart:92`），删除世界观时数据库自动解除归属，仓库层不用手写 UPDATE。

### 2.3 词条 JSON

镜像 `role.custom_attributes`（`.trellis/spec/backend/role-custom-attributes.md`）：

```json
[{"title":"地理","content":"..."},{"title":"势力","content":"..."}]
```

- 数组顺序 = 展示顺序；`title` 非空白（写入前 trim，拒绝空标题），`content` 允许空、保留内部换行。
- `DriftWorldRepository` 独占编解码；坏数据抛 `FormatException`，不静默吞成空数组。
- 不给词条单独建表：D3 决定本期无修订历史/附件，JSON 列写入原子、复用已验证的模式。后续若需要按词条挂历史，再迁到子表（迁移时把 JSON 展开即可，不封死）。

### 2.4 领域模型

```dart
class World {
  const World({required id, required name, required summary,
               required coverImg, this.entries = const []});
  final int id; final String name; final String summary; final String coverImg;
  final List<WorldEntry> entries;   // 不可变快照，参与值相等
}
class WorldEntry { const WorldEntry({required title, required content}); }
```

`Role` 新增 `final int? worldId;`，构造参数 `this.worldId`（可选、默认 null），保持现有 const 调用点不改；纳入 `==`/`hashCode`。**所有重建 `Role` 的地方必须显式带上 `worldId`**（`restoreDescRevision`、编辑页 `_submit`、fake、测试）——与 customAttributes 的规则相同。

命名冲突：Drift 会生成行类型 `World`/`WorldEntry`？——只有表行类型 `World`（来自 `Worlds`）会与领域 `World` 同名，沿用 `as db` 前缀；`WorldEntry` 仅是领域类，无冲突。

## 3. 仓库接口

```dart
abstract interface class WorldRepository {
  Future<List<World>> list();
  Future<World?> getById(int id);
  Future<World> create({required String name, required String summary,
                        required String coverImg, List<WorldEntry> entries = const []});
  Future<World> update(World world);          // 全量更新，找不到抛 StateError
  Future<void> delete(int id);                // 不存在不报错；角色由 FK SET NULL 解除归属
  Stream<List<World>> watchAll();
}
```

`RoleRepository` 增量：

```dart
Future<Role> create({..., int? worldId});     // 新增可选参数
Stream<List<Role>> watchByWorld(int worldId); // 世界观「角色」页签数据源
```

写入都走 `_db.mutate(() => _db.transaction(...))`，与现有 epoch 门禁一致。

## 4. Provider

- `worldRepositoryProvider`（`@Riverpod(keepAlive: true)`）→ `DriftWorldRepository(ref.watch(appDatabaseProvider))`
- `worldsProvider`（`@riverpod Stream<List<World>>`）：`databaseSwitchProvider` 为真时返回空流，否则 `watchAll()`——与 `rolesProvider` 同构。
- `rolesInWorldProvider(int worldId)`（family stream）：同样受 `databaseSwitchProvider` 门控。

需要 `build_runner` 生成 `.g.dart`。

## 5. 路由（遵守 `.trellis/spec/frontend/navigation.md`）

| Location | Page | 说明 |
|---|---|---|
| `/worlds/new` | `WorldCreatePage()` | root 路由，`parentNavigatorKey: rootKey` |
| `/worlds/:id` | `WorldCreatePage(world: extra as World)` | extra 非 `World` → redirect `/archive` |

世界观「角色」页签点击角色 → `context.push('/roles/${role.id}', extra: role)`（已有路由）。

## 6. 页面

### 6.1 `WorldViewPage`（列表，替换占位）

与 `RoleListPage` 同构：`ConsumerStatefulWidget` + `AutomaticKeepAliveClientMixin`；`Scaffold` + `ListView.separated`；tile = 56px 圆角封面缩略图（`CoverFileView`，占位图标用 `Icons.public_outlined`）+ 名称 + 简介首行；FAB「添加世界观」→ `/worlds/new`；空态文案「还没有世界观」（原「暂无世界观」，与「还没有角色」对齐；同步改 `home_shell_test.dart:99,107`）。

### 6.2 `WorldCreatePage`（新建 / 编辑）

照 `RoleCreatePage` 的结构：

- **新建**：单个 `CustomScrollView`：沉浸封面 → 「新建世界观」标题 → 基本信息卡（名称，必填）→ 简介卡（多行）→ 词条 sliver（`SliverReorderableList`，每条 = 标题 + 多行内容，支持增/删（确认弹窗）/拖拽排序，与自定义属性交互一致）。
- **编辑**：`NestedScrollView` + 置顶封面 `SliverAppBar`，bottom 为「详情 / 角色」`TabBar`；详情 = 同上表单；角色 = `rolesInWorldProvider(world.id)` 的只读列表（复用 `RoleListPage` 的 tile 视觉，点击跳角色编辑页；空态「还没有角色归属这个世界观」）。遵守 `.trellis/spec/frontend/role-assets.md` 的滚动契约（overlap absorber/injector、PageStorageKey、keep-alive、仅 depth==0 的横向拖动才 unfocus）。
- **顶部玻璃工具栏**：返回 / 折叠后显示的封面+名称 / 保存；编辑态额外一个「更多」玻璃按钮 → 菜单「删除世界观」→ `showZaidangConfirmDialog`（正文明确写「归属的角色不会被删除，只会解除归属」）→ `WorldRepository.delete` → pop 回列表。删除按钮不用火漆红（theming 规则：accent 不给破坏性操作）。
- 保存：名称 trim 非空；词条标题全部非空（离屏行也校验，与 `_submit` 同法）；成功 pop；失败 `showZaidangSnackBar(error)` 并保留草稿。
- `PopScope(canPop: !_saving)`；保存中 `AbsorbPointer`。

### 6.3 共享编辑器组件抽取（前置重构）

`RoleCreatePage` 里的展示型私有组件需被两个页面共用。抽到 `lib/widgets/archive_editor/`：

| 现私有类 | 新公开类 | 变化 |
|---|---|---|
| `_ImmersiveCover` | `ImmersiveCover` | `name/race/occupation` → `title` + `subtitle`（角色页传 `race · occupation`，世界观页传空或「世界观」） |
| `_CallingCard` / `_PortraitPlaceholder` / `_HeroBackdrop` | 随 `ImmersiveCover` 一起迁移 | 占位图标可配置（角色 `person_outline`，世界观 `public_outlined`） |
| `_PinnedRoleIdentity` | `PinnedIdentity` | 仅改名 |
| `_GlassIconButton` / `_GlassSaveButton` | `GlassIconButton` / `GlassSaveButton` | 仅改名 |
| `_ArchiveCard` / `_archiveCardDecoration` / `_SectionLabel` / `_FieldRow` | `ArchiveCard` / `archiveCardDecoration` / `SectionLabel` / `FieldRow` | 仅改名 |
| `_KeepAliveDetails` | `KeepAliveDetails` | 仅改名 |

这些全是 `StatelessWidget`/纯函数，抽取是机械搬移；`role_create_page_cover_test.dart`、`role_assets_tab_test.dart` 是回归网。**抽取作为独立步骤先做、先跑测试、单独提交**，再开世界观页面。

### 6.4 `RoleCreatePage` 世界观选择器

基本信息卡末尾（`role_create_page.dart:663` 之后）加一行「世界观」只读字段（与 `_field` 同视觉，右侧下拉箭头），显示所选世界观名或「未归属」。点击 → `showModalBottomSheet` 列出 `worldsProvider` 的世界观 + 顶部「不归属」项。状态 `int? _worldId`，初值 `widget.role?.worldId`。提交时若 `_worldId` 不在当前世界观列表中（编辑期间被删除），置 null 后再保存，避免 FK 报错。`RoleCardSnapshot`（导出）不含世界观，不改。

## 7. 迁移（schema 8 → 9）

```dart
if (from < 3) {
  await migrator.deleteTable('role');
  await migrator.createTable(worlds);   // 先建被引用表
  await migrator.createTable(roles);    // 最新定义已含 world_id
}
...
if (from >= 3 && from < 9) {
  await migrator.createTable(worlds);
  await migrator.addColumn(roles, roles.worldId);  // 可空 + REFERENCES，SQLite ADD COLUMN 允许
}
```

`currentSchemaVersion = 8 → 9`。`from < 3` 重建分支已用最新表定义，不能再 addColumn（同 customAttributes 的教训，`app_database.dart:82-85`）。

## 8. 备份 / 恢复兼容

- sqlite 整库快照 → `world` 表和 `role.world_id` 自动进备份，manifest 格式不变、不加新文件。
- 世界观封面通过 `CoverImagePicker` 落到同一个 `covers/` 目录，备份按目录枚举（`icloud_backup_service.dart:112`）自动包含。
- `RestoreVersionGate` / `data_storage.dart:744` 均相对 `currentSchemaVersion`：升到 9 后，旧 ≤8 快照恢复时经 `onUpgrade` 迁移得到空 `world` 表和全 NULL `world_id`；9 的快照不能被旧版 app 恢复（既有行为）。
- 测试里若有把「未来版本」硬编码为 9 的用例会在升级后变成合法版本，需按 spec 改成 `currentSchemaVersion + 1`（实施时 grep 确认）。

## 9. 取舍记录

| 取舍 | 选择 | 原因 |
|---|---|---|
| 词条 JSON 列 vs 子表 | JSON 列 | 本期无按词条历史/附件；原子写入；复用已验证模式；后续可展开迁移 |
| 角色归属删除策略 | FK `SET NULL` | 用户确认「删世界观保留角色」；交给 SQLite 比仓库手写更不易漏 |
| 世界观角色查询放哪 | `RoleRepository.watchByWorld` | 返回的是 `Role`，归属角色仓库更自然，也避免 WorldRepository 依赖 Role 映射 |
| 共享组件抽取 vs 复制 | 抽取到 `lib/widgets/archive_editor/` | 避免 ~600 行重复；抽取对象全是无状态展示件，回归网已有 |
| 列表是否显示角色数 | 不显示 | 需要 join/额外查询，本期价值低 |

## 10. 回滚

- 抽取重构独立提交，可单独 revert。
- schema 9 迁移只加表/加列，不改旧数据；回滚代码到 8 后旧 app 打开 9 的库会因 Drift 版本检查失败——这是所有升级共有的既定行为，靠备份恢复兜底。
