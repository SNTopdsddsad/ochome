# Design: 字号 / 间距 / 圆角 Token

## 边界

```
ZaidangTokens (colors)  ──►  ZaidangType.from(tokens)  ──►  zaidangTheme(): ThemeData
ZaidangSpacing (static) ──►      │                                  │
ZaidangRadius  (static) ──►      │                                  ▼
                                 ▼                     stock widgets (AppBar / ListTile /
                        pages & shared widgets          Dialog / Input / Tab / Button)
```

- `lib/theme/zaidang_type.dart`：`ZaidangType extends ThemeExtension<ZaidangType>`，字段为 11 个 `TextStyle`，
  `ZaidangType.from(ZaidangTokens)` 烘入 `ink` / `inkSecondary`，`of(context)`、`copyWith`、`lerp`（`TextStyle.lerp`）、
  `toTextTheme()`。
- `lib/theme/zaidang_spacing.dart`：`abstract final class ZaidangSpacing`，静态 `double` 常量。
- `lib/theme/zaidang_radius.dart`：`abstract final class ZaidangRadius`，静态 `double` 与 `BorderRadius` 常量、`pill` 形状。

## 字号角色（size / weight / height / color）

| role | spec | color | Material 槽位 | 用途 |
|---|---|---|---|---|
| hero | 26 / w600 / 1.2 | ink | displayLarge/Medium/Small | 备份页大标题、容量大数字 |
| title | 22 / w600 / 1.25 | ink | headlineLarge/Medium/Small | 编辑页「新建/编辑角色 · 世界观」 |
| heading | 20 / w500 / 1.3 | ink | titleLarge | 弹窗标题、统计数字、启动错误标题 |
| pageTitle | 17 / w600 / 1.3 | ink | titleMedium | AppBar / Sheet 标题 |
| subheading | 17 / w500 / 1.4 | ink | titleSmall | ListTile 标题、卡片小标题、任务标题、pinned 名字、句中人名 |
| bodyLarge | 17 / w400 / 1.5 | ink | bodyLarge | 输入框内容 / hint / label、字段值、句中助词 |
| body | 15 / w400 / 1.5 | ink | bodyMedium | 正文、弹窗正文、SnackBar、空态主文案 |
| label | 15 / w500 / 1.3 | ink | labelLarge | 按钮、Tab 文字 |
| sectionLabel | 13 / w600 / 1.4 | inkSecondary | labelMedium | 分区标签 |
| caption | 13 / w400 / 1.4 | inkSecondary | bodySmall | 副标题、提示、计数、空态辅助 |
| micro | 12 / w400 / 1.3 | inkSecondary | labelSmall | 序号、统计说明、导航栏文字、输入框错误 |

`copyWith` 契约：调用方只允许覆盖 `color`（必须是 `ZaidangTokens` 色）和 `height`。

## 间距

`xxs 2` `xs 4` `sm 8` `md 12` `lg 16` `xl 20` `xxl 24` `xxxl 32`；别名 `page = xl`（页面横向内边距）、`card = lg`（卡片内边距）。
单维 `SizedBox(height|width: n)` 视为间隔 → Token；双维 `SizedBox(width, height)` 视为尺寸 → 不动。

## 圆角

`sm 8`（卡片 / 输入框 / 缩略图 / 小按钮）、`md 16`（SnackBar / 便笺按钮 / 候选卡 / 纸卡）、`lg 26`（弹窗 / Sheet 顶部 / hero 纸边）、
`pill`（`StadiumBorder`，玻璃保存按钮）。`smAll / mdAll / lgAll / lgTop` 作为 `BorderRadius` 常量。

## 主题接线

`zaidangTheme(tokens)` 内构造 `type = ZaidangType.from(tokens)`：
- `extensions: [tokens, type]`，`textTheme: type.toTextTheme()`
- `appBarTheme.titleTextStyle = pageTitle`
- `dialogTheme`：`titleTextStyle = heading`、`contentTextStyle = body`、圆角 lg
- `snackBarTheme`：`contentTextStyle = body`、圆角 md、`insetPadding` 走 spacing
- `navigationBarTheme.labelTextStyle = micro.copyWith(color: state)`
- `listTileTheme`：标题 subheading、副标题 caption、`contentPadding = (h: lg, v: sm)`
- `inputDecorationTheme`：label/hint = bodyLarge inkSecondary，floating = caption ink，error = micro ink，`contentPadding = (lg, lg)`，圆角 sm
- 新增 `tabBarTheme`（label）、`filledButtonTheme` / `textButtonTheme` / `outlinedButtonTheme`（`textStyle = label`，圆角 sm）

## 兼容与回滚

- 页面测试只断言 Key 与文案，不断言尺寸；预计无需改测试逻辑。
- 回滚点：Token 文件 + 主题接线是独立 commit，可单独回退。
- 导出卡渲染器不受影响（不读 `ThemeData`）。
