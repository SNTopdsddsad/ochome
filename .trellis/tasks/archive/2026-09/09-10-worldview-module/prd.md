# 世界观模块

## Goal

让用户在「档案 → 世界观」页签里创建、查看、编辑、删除自己的世界观（设定集），并把 OC 归属到某个世界观，使世界观成为与 OC 并列的第二类核心内容。目前该页签只是「暂无世界观」占位（`lib/pages/world_view_page.dart`）。

## Background（代码事实）

- `ArchivePage` 用 `DefaultTabController` 并列 `RoleListPage` 与 `WorldViewPage`（`lib/pages/archive_page.dart:56`）。
- 分层：页面 → Riverpod provider → 抽象 repository → Drift `AppDatabase`；领域模型与 Drift 行类型通过 `import ... as db` 隔离。
- schema 版本 **8**（`AppDatabase.currentSchemaVersion`），表 `role` / `role_desc_revision` / `role_asset`。版本门禁（`data_storage.dart:744`、`RestoreVersionGate`）均相对 `currentSchemaVersion`，无硬编码上限。
- OC 已有可复用模式：有序自定义属性 JSON 列（`.trellis/spec/backend/role-custom-attributes.md`）、封面 `covers/<file>` 相对路径（`CoverPath` / `CoverImagePicker` / `CoverFileView`）、编辑页沉浸封面 + 详情/资产页签（`.trellis/spec/frontend/role-assets.md`）。
- 备份 v3 整库快照 sqlite；封面按本地 `covers/` 目录枚举（`icloud_backup_service.dart:112`），不按引用。
- 路由契约（`.trellis/spec/frontend/navigation.md`）：创建/编辑页为 root 路由；编辑通过 `extra` 传对象。
- OC 目前**没有**删除角色的 UI（`RoleRepository.delete` 无调用方）。
- `RoleCreatePage` 基本信息卡是纯字段列表（`role_create_page.dart:614-666`），可插入选择器行。

## Key Decisions（用户已确认）

| # | 决策 | 否决项 |
|---|---|---|
| D1 | 世界观 = 名称 + 封面 + 简介 + **有序词条列表**（词条 = 标题 + 长文本），复用自定义属性 / 长文本模式 | 单篇长文；可嵌套章节树 |
| D2 | **角色可选归属一个世界观**（一对多）：`role.world_id` 可空；角色表单加选择器；世界观编辑页列出归属角色。删除世界观时**角色保留、仅解除归属**（`ON DELETE SET NULL`） | 本期不关联；多对多 |
| D3 | 本期**不做**词条修订历史、附件、导出卡片；只保留封面图 | — |
| D4 | 页面形态**照 OC**：列表点击直接进编辑页；编辑页分「详情 / 角色」两页签，「角色」仅已保存的世界观显示 | 独立只读详情页；角色列表放详情底部 |
| D5 | **支持删除**世界观：编辑页更多菜单 + `showZaidangConfirmDialog` 二次确认，文案明确「角色不会被删除」 | 不支持删除；顺带给 OC 加删除 |

## Requirements

### R1 世界观数据

- R1.1 新表 `world`：`id`、`name`（必填）、`summary`、`coverimg`（`covers/<file>` 相对路径，空串表示无）、`entries`（JSON，默认 `[]`）。schema 升到 **9**。
- R1.2 词条 JSON `[{"title","content"}]`：顺序即展示顺序；标题 trim 后非空，内容可空、保留换行；坏数据抛错不吞。
- R1.3 `WorldRepository`：`list / getById / create / update / delete / watchAll`，只暴露领域 `World` / `WorldEntry`。
- R1.4 `role.world_id INTEGER NULL REFERENCES world(id) ON DELETE SET NULL`；`Role.worldId` 可空，参与值相等；所有重建 `Role` 的路径（含 `restoreDescRevision`）必须保留 `worldId`。
- R1.5 `RoleRepository.create` 接受可选 `worldId`；新增 `watchByWorld(worldId)`。
- R1.6 迁移：`from >= 3 && from < 9` 建 `world` + 加列；`from < 3` 重建分支先建 `world` 再建 `role`，不重复加列。

### R2 世界观列表页（`WorldViewPage`）

- R2.1 与 `RoleListPage` 同构：封面缩略图 + 名称 + 简介首行；按 id 顺序；保持 keep-alive。
- R2.2 空态「还没有世界观」；FAB「添加世界观」→ `/worlds/new`。
- R2.3 点击条目 → `/worlds/:id`，`extra` 为 `World`；extra 非法 redirect `/archive`。

### R3 世界观编辑页（`WorldCreatePage`）

- R3.1 新建：沉浸封面（可选图、可预览）+ 名称（必填）+ 简介 + 词条列表（增 / 删（确认）/ 拖拽排序）。
- R3.2 编辑：置顶封面 + 「详情 / 角色」页签；切页签保留未保存草稿与滚动位置；遵守 `role-assets.md` 滚动契约。
- R3.3 「角色」页签：只读列出 `worldId == 当前` 的角色（封面 + 名字 + 副标题），点击 → `/roles/:id` 带 `extra`；空态「还没有角色归属这个世界观」。
- R3.4 保存：名称空 → 字段错误；任一词条标题空 → 阻止保存并 SnackBar 提示；成功 pop；失败 SnackBar + 保留草稿；保存中禁止操作与返回。
- R3.5 删除（仅编辑态）：更多菜单 →「删除世界观」→ 确认弹窗（说明角色不会被删）→ 删除 → pop 回列表；取消无副作用；删除按钮不用火漆红。

### R4 角色表单世界观选择器（`RoleCreatePage`）

- R4.1 基本信息卡末尾「世界观」只读行，显示所选名称或「未归属」；点击弹底部列表（含「不归属」）。
- R4.2 编辑态预选 `role.worldId`；提交时若所选世界观已不存在则置 null 再保存。
- R4.3 不影响导出角色卡快照。

### R5 备份 / 恢复

- R5.1 世界观数据随 sqlite 快照进备份；封面落 `covers/` 自动纳入；manifest 格式不变。
- R5.2 ≤8 的旧快照恢复后经迁移得到空 `world` 表、`world_id` 全 NULL；既有备份测试保持通过（未来版本用 `currentSchemaVersion + 1` 表达）。

### R6 共享组件抽取（前置重构）

- R6.1 把 `RoleCreatePage` 的沉浸封面、玻璃按钮、卡片/分节/双列字段、折叠身份、keep-alive 等无状态展示件抽到 `lib/widgets/archive_editor/`，`ImmersiveCover` 改为 `title / subtitle / placeholderIcon`。
- R6.2 抽取不改变角色页任何行为，独立提交，现有 `role_create_page_cover_test` / `role_assets_tab_test` 通过。

## Acceptance Criteria

- [ ] AC1（R1.1–R1.3）仓库测试：创建/更新/删除/监听世界观；词条有序、多行、空内容往返一致；空标题写入被拒；坏 JSON 读取抛 `FormatException`。
- [ ] AC2（R1.4、D2）删除一个有归属角色的世界观后，角色仍存在且 `worldId == null`；`restoreDescRevision` 后 `worldId` 不变。
- [ ] AC3（R1.5）`watchByWorld` 只返回归属该世界观的角色，其他角色不出现。
- [ ] AC4（R1.6、R5.2）v8 数据库升级到 v9：原角色/属性/修订/资产完好、`world_id` 为 NULL、可写入 `world`；`from<3` 路径无重复列；旧快照恢复测试通过。
- [ ] AC5（R2）世界观页签：无数据显示「还没有世界观」与 FAB；有数据显示封面/名称/简介；点 FAB 进入新建页且底部 tab 栏不可见；点条目进入编辑页并带 `extra`。
- [ ] AC6（R3.1、R3.4）新建页填写名称、简介、两条词条并保存 → 仓库收到同名同序数据；名称空提示「请填写名称」；词条标题空阻止保存并提示。
- [ ] AC7（R3.2、R3.3）编辑页显示「详情 / 角色」；切换页签后详情草稿保留；角色页签只列归属角色，点击进入角色编辑页；无归属显示空态。
- [ ] AC8（R3.5）更多菜单 → 删除 → 弹窗文案包含「不会被删除」；确认后调用 `delete` 并返回列表；取消不调用。
- [ ] AC9（R4）角色新建选择世界观后保存 `worldId` 正确；选「不归属」保存 null；编辑态预选正确；所选世界观被删后提交写 null 不报错。
- [ ] AC10（R6）抽取后 `flutter test` 全绿，角色编辑页视觉与交互无变化。
- [ ] AC11（主题）新页面亮/暗主题下 AppBar/工具栏无 accent 填充，accent 只出现在 FAB、保存、选中态。
- [ ] AC12 `flutter analyze` 无告警；`build_runner` 产物已提交。

## Out of Scope

- 词条修订历史、世界观附件、世界观导出卡片（D3）。
- 多对多归属、角色列表按世界观筛选/分组、世界观内新建角色。
- OC 删除入口（D5 否决项）。
- 列表显示角色数量、世界观排序/搜索。
- 深链 / `getById` 加载编辑页（navigation spec 既有约束）。

## Technical Notes

详见 `design.md`（表结构、JSON 契约、仓库接口、路由、页面结构、迁移、备份兼容、取舍）与 `implement.md`（六步实施、验证命令、风险文件）。
