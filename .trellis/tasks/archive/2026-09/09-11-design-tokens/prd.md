# 统一字号、间距与圆角设计 Token

## Goal

崽档 App 目前只有颜色有 Token（`ZaidangTokens`），字号、字重、间距、圆角全部是页面里手写的字面量：
`fontSize:` 69 处 / 11 个字号，间距约 160 处 / 20 多个值，`BorderRadius.circular` 32 处 / 9 个值，
`ThemeData` 没有设置 `textTheme`。同一语义（分区标签、空态文案、页面大标题）在不同页面尺寸和字重不一致。

本任务在 `lib/theme/` 补齐字号、间距、圆角三套 Token，接入 `ThemeData`，并把 14 个页面与全部共享组件
一次性迁移到 Token，最后用守卫测试和 spec 固化规则。

## Requirements

- 新增 `ZaidangType`（`ThemeExtension`，11 个语义角色、7 个字号：26/22/20/17/15/13/12，颜色已烘进样式），
  提供 `toTextTheme()` 填满全部 15 个 Material 槽位。
- 新增 `ZaidangSpacing`（2/4/8/12/16/20/24/32 + `page`/`card` 别名）与 `ZaidangRadius`（8/16/26 + pill）。
- `zaidangTheme()` 接入以上 Token：`textTheme`、AppBar/Dialog/SnackBar/NavigationBar/ListTile/Input/Tab/Button 组件主题。
- 迁移范围：`lib/pages/` 全部、`lib/widgets/**`、`lib/features/backup/widgets/*`、
  `lib/features/role_card/role_card_field_picker.dart`、`lib/bootstrap.dart`。
- 迁移范围内不得再出现 `fontSize:` / `fontWeight:` / 数字圆角 / 非 0 数字间距字面量；
  `TextStyle.copyWith` 只允许改 `color`（Token 色）和 `height`。
- `SectionLabel` 提升为 `lib/widgets/section_label.dart`，删除关系编辑 Sheet 的私有 `_SectionLabel`。
- 导出卡渲染器（`role_card_renderer.dart`、`role_card_fonts.dart`）不在范围内，保持原样。
- 字体族选型、图标尺寸、触控尺寸（44/48）、maxWidth 等布局常量不在本任务范围。

## Constraints

- 不引入第三方设计系统包；沿用 `ZaidangTokens` 的 `ThemeExtension` 模式。
- 颜色契约（`theming.md`）不变；不得反向影响导出卡模板。
- 间距取整规则：四舍五入到最近档，正好中间时向上（6→8、10→12、14→16、18→20、22→24、26→24、28→32）。
- 圆角取整：6/12→8、14/15/18→16、20→26、22→pill。
- 关系编辑 Sheet 的 17px 句子体系保留（pageTitle / subheading / bodyLarge 三个字重）。

## Acceptance Criteria

- [ ] `flutter analyze` 无告警，`flutter test` 全绿。
- [ ] `test/theme/zaidang_type_test.dart` 验证 11 个角色的 size/weight/height/颜色与 `toTextTheme()` 15 个槽位。
- [ ] `test/theme/design_token_guard_test.dart` 扫描迁移范围源码，字号/字重/圆角/间距字面量为 0。
- [ ] 迁移范围内 `fontSize:` 出现次数为 0（渲染器与 `lib/theme/` 除外）。
- [ ] `.trellis/spec/frontend/theming.md`、`quality-guidelines.md`、`component-guidelines.md`、
      `role-relationships.md`、`index.md` 更新完毕，与代码一致。
- [ ] 提交按 `git-commit.md` 拆分为 应用 / 测试 / Trellis 三个模块。
