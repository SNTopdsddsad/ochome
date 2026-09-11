# Journal - 丹青 (Part 1)

> AI development session journal
> Started: 2026-08-31

---



## Session 1: OC 关系功能：数据层、备份校验、关系 Tab 与关系便条编辑器

**Date**: 2026-09-10
**Task**: OC 关系功能：数据层、备份校验、关系 Tab 与关系便条编辑器
**Branch**: `main`

### Summary

Session summary was not supplied.

### Main Changes

| 层 | 内容 |
|---|---|
| 数据 | `role_relationship` 表（schema v9，两端 FK 级联、双索引），单行有向模型 `from_label`/`to_label` + 视角 helper；`RoleRelationshipRepository` 校验自关联、角色缺失（区分当前/对方）、文案非空与 30 字上限；`delete` 返回 bool |
| 备份 | `inspectBackupDatabase` 在 userVersion ≥ 9 校验关系记录；`closeDatabase`/`reopenDatabase` 失效关系 provider；legacy 恢复覆盖 3–9 |
| UI | `RoleCreatePage` 编辑态第三个 Tab「关系」；编辑器按 hallmark 组件流程重做为「关系便条」底部面板：立绘小卡选对方、两句填空、共享提示行（touched 模式 + 字数触顶提示）、满色保存按钮；点空白可关，保存中不可关，未开下拉关闭 |
| 测试 | 仓储/迁移 5 例，备份 legacy 3–9 + 业务校验，Tab widget 7 例；全量 355 通过 |

**决策**：第一版 AlertDialog + 下拉框被用户否决；对方头像保持 3:4 名片形不改圆；超长角色名单行省略不处理。

**Spec**：`spec/backend/role-relationships.md`、`spec/frontend/role-relationships.md` 新增；`backup-restore.md`、`role-assets.md`、两个 index 更新。


### Git Commits

| Hash | Message |
|------|---------|
| `d05c996` | (see git log) |
| `90ed5d1` | (see git log) |
| `e2e0b61` | (see git log) |
| `883faaf` | (see git log) |

### Status

[OK] **Completed**


## Session 2: 统一字号、间距与圆角设计 Token

**Date**: 2026-09-11
**Task**: 统一字号、间距与圆角设计 Token
**Branch**: `main`

### Summary

新增 ZaidangType / ZaidangSpacing / ZaidangRadius 三套刻度并接入 ThemeData，14 个页面与全部共享组件的字号、间距、圆角字面量清零，新增字面量守卫测试；spec 同步。

### Main Changes

| 层 | 内容 |
|---|---|
| Token | `lib/theme/zaidang_type.dart`（`ThemeExtension`，11 个角色 / 7 个字号 26·22·20·17·15·13·12，颜色烘进样式，`toTextTheme()` 填满 15 个槽位）、`zaidang_spacing.dart`（2/4/8/12/16/20/24/32 + `page`/`card` 别名）、`zaidang_radius.dart`（sm 8 / md 16 / lg 26 / pill） |
| 主题 | `zaidang_theme.dart` 注入 `extensions: [tokens, type]` 与 `textTheme`；AppBar / Dialog / SnackBar / NavigationBar / ListTile / TabBar / 三种 Button / InputDecoration 的文字样式、圆角、内边距全部走 Token |
| 组件 | `SectionLabel` 提升到 `lib/widgets/section_label.dart`，删除关系 Sheet 私有 `_SectionLabel`；archive_editor 五件、确认便笺、SnackBar、备份组件、字段选择器、bootstrap 全部迁移 |
| 页面 | `lib/pages/` 12 个有字面量的页面迁移完毕；ListTile `contentPadding` 与 AppBar 标题样式交给主题；非间距尺寸抽成带注释的 `static const`（`_fieldScrollInset` 80 / `_fieldScrollTopInset` 128 / `_compactPreviewMinHeight` 240 / `_compactPreviewMaxHeight` 520） |
| 测试 | `test/theme/zaidang_type_test.dart` 7 例（角色表、7 字号、明暗色、槽位映射、主题接线、lerp、`of`）；`design_token_guard_test.dart` 扫描 `lib/**`（排除 `lib/theme/` 与导出渲染器）拦截 `fontSize` / `fontWeight` / 数字 `EdgeInsets` / 单向无 child 的 `SizedBox` / `Radius.circular` / `Wrap` 间距字面量；全量 393 通过 |
| Spec | `theming.md` 新增 Type / Spacing / Radius 三张刻度表、签名、校验矩阵、测试项、Don't；`quality-guidelines.md` 删除「字号可写字面量」豁免并加禁止项 / 必需模式 / 评审项；`component-guidelines.md`、`role-relationships.md`、`worlds.md`、`index.md` 同步 |

**决策**：
- `copyWith` 只允许改 `color`（token 色）和 `height`，禁止改字号 / 字重；唯一被认可的行高覆盖是确认便笺正文 `body.copyWith(height: 1.8)`。
- 间距取整：最近档、卡中间向上（6/7→8、10→12、14→16、18→20、22→24、28→32、48→32）；`0` 保留。
- 守卫对 `SizedBox` 的判定收窄为「只有 height / width 之一、且没有 child」，实参按顶层逗号拆分后只看该参数本身，避免嵌套子树误报。
- `ThemeData` 会把默认 Typography 合并进 `textTheme`，测试逐字段断言而不是比较整个 `TextStyle`。

**未纳入**：`ios/Podfile.lock`、`devtools_options.yaml` 为工作区既有改动；`dart format` 对 `lib/data/**`、`test/data/**` 等 7 个无关文件的格式漂移已还原，建议另起一条「应用: 统一格式化」提交。


### Git Commits

| Hash | Message |
|------|---------|
| `19f720d` | (see git log) |
| `d168eb2` | (see git log) |
| `eb3c675` | (see git log) |
| `b9677bc` | (see git log) |

### Status

[OK] **Completed**
