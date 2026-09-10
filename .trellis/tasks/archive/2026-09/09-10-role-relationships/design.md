# 设计：OC 关系

## 数据

新表 `role_relationship`（schema **9**）：

| 列 | 类型 | 说明 |
|---|---|---|
| id | INTEGER PK AI | |
| from_role_id | INTEGER FK role(id) ON DELETE CASCADE | 创建关系时所在的 OC |
| to_role_id | INTEGER FK role(id) ON DELETE CASCADE | 对方 OC |
| from_label | TEXT NOT NULL | from 是 to 的 ___ |
| to_label | TEXT NOT NULL | to 是 from 的 ___ |
| created_at | INTEGER NOT NULL | |

索引：`role_relationship_from_role_id`、`role_relationship_to_role_id`。
不加 `(from,to)` 唯一约束——允许多条；`from != to` 由仓储层校验。

一条关系只存一行，两端页面共享同一行，按视角翻转文案。

迁移：`if (from < 9) createTable + createIndex ×2`，不改写已有表。

## 领域与仓储

- `RoleRelationship`：与表一一对应的不可变模型，附带 `otherRoleId(selfId)`、
  `selfLabel(selfId)`、`otherLabel(selfId)` 视角辅助方法。
- `RoleRelationshipRepository`：
  - `Stream<List<RoleRelationship>> watchForRole(int roleId)`（from 或 to 等于 roleId，按创建时间倒序）
  - `Future<List<RoleRelationship>> listForRole(int roleId)`
  - `Future<RoleRelationship> create({fromRoleId, toRoleId, fromLabel, toLabel})`
  - `Future<RoleRelationship> update(RoleRelationship)`
  - `Future<void> delete({roleId, relationshipId})`（roleId 必须是任一端，防止越权）
- 校验统一在仓储：两端 id 不同且都存在；两段 label trim 后非空。违规抛 `FormatException`
  （文案）/`StateError`（对象缺失），与资产模块一致。
- `DriftRoleRelationshipRepository` 全部写操作走 `_db.mutate`，接口不暴露 Drift 类型。
- Provider：`roleRelationshipRepositoryProvider`、`roleRelationshipsProvider.family(roleId)`，
  受 `databaseSwitchProvider` 控制；备份关库前 invalidate，重开后 invalidate 仓储。

## 备份

- `AppDatabase.currentSchemaVersion` 8 → 9。
- `snapshot_store.inspectBackupDatabase`：`userVersion >= 9` 时校验 `role_relationship` 行：
  两端角色存在、不相同、label 非空。
- 版本门与健康检查用 `currentSchemaVersion` 常量，自动跟随。
- 遗留恢复测试期望的迁移后版本改为 `AppDatabase.currentSchemaVersion`。

## UI

- `RoleCreatePage` 编辑模式 TabController 长度 2 → 3，新 Tab「关系」→ `RoleRelationshipsTab`。
- Tab 结构照抄 `RoleAssetsTab`：`CustomScrollView` + `SliverOverlapInjector`，头部计数 +「添加关系」，
  列表项显示对方名字/封面缩略、两段文案；`more_horiz` 弹菜单编辑/删除。
- 编辑器 `RoleRelationshipEditorSheet`（第一版 AlertDialog + 下拉框被用户否决，按 hallmark 重做为「关系便条」底部面板）：
  - 对方 OC：横向立绘小卡（排除自己），选中态火漆红描边，编辑态可切换。
  - 两句填空「{我} 是 {对方} 的 ____」「{对方} 是 {我} 的 ____」，名字随所选对方实时变化；
    填空只有一条下划线，附「交换」按钮。
  - 首次提交后才校验（touched 模式），统一提示行；保存失败留在面板内提示。
- 对方角色信息来自 `rolesProvider` 全量列表（个人应用规模小，避免 join）。
  对方已不存在的关系理论上不会出现（级联），兜底显示「已删除的 OC」。
- 忙碌状态通过 `onBusyChanged` 上抛，复用现有 `_assetBusy` 门控。

## 权衡

- 不做类型表：与「不预置类型」「每条关系两段自由文案」一致，避免多一套管理 UI。
- 单行双向存储而非双行镜像：保证两端一致，删改一次生效。
