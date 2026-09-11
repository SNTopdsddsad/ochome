# Theming and Design Tokens

> Visual contract for **崽档** App UI. Source note (v1, 2026-08-31, 已拍板): SiYuan `/需求讨论/OC 档案馆 · 立项调研与产品简报/主题色与设计 Token`.
>
> Export-card templates have their own palette and are **not** bound by this file.
> The implemented character-sheet template is specified in [Role-card Export](./role-card-export.md).

---

## 1. Scope / Trigger

**Trigger**: Any `ThemeData` / `ColorScheme` change, new hardcoded color, **any `fontSize` / `fontWeight` / `EdgeInsets` / gap `SizedBox` / `Radius.circular` literal**, AppBar / list / form / empty / paywall chrome, destructive-action styling, watermark, or App icon.

**Applies to**: in-app UI only (list, create/edit, settings, buyout badge).

**Does not apply to**: 设定卡导出模板。模板审美基准见调研笔记第四节（10 张圈内设卡），在 Figma/纸上定版式后再自绘渲染。`lib/features/role_card/role_card_renderer.dart` and `role_card_fonts.dart` keep their own pixel values and are excluded from the literal guard.

**Current implementation**: `lib/theme/` holds four token files. `zaidang_tokens.dart` is the hand-written light/dark palette; `zaidang_type.dart` (`ZaidangType`, a `ThemeExtension`), `zaidang_spacing.dart` (`ZaidangSpacing`) and `zaidang_radius.dart` (`ZaidangRadius`) are the type / spacing / radius scales. `zaidang_theme.dart` maps all of them into `ThemeData` (extensions, `textTheme`, component themes). Do not reintroduce a seed palette.

---

## 2. Signatures

Keep the note's semantic names. One Dart token class, light + dark factories. Do not generate a Material 3 seed palette (red becomes pink-purple).

```dart
class ZaidangTokens {
  const ZaidangTokens({
    required this.bg,
    required this.surface,
    required this.ink,
    required this.inkSecondary,
    required this.border,
    required this.accent,
    required this.onAccent,
    required this.accentGold,
  });

  final Color bg;            // 页面背景（纸白 / 暖黑）
  final Color surface;       // 卡片 / 弹窗
  final Color ink;           // 正文、标题（永远墨色，不用红）
  final Color inkSecondary;  // 次要文字
  final Color border;        // 分隔线 / 描边
  final Color accent;        // 主按钮、选中态、火漆印、水印
  final Color onAccent;      // 主色上的文字
  final Color accentGold;    // 买断 / 会员标识

  static const light = ZaidangTokens(
    bg: Color(0xFFFAF6F0),
    surface: Color(0xFFFFFFFF),
    ink: Color(0xFF2B2622),
    inkSecondary: Color(0xFF8C8177),
    border: Color(0xFFEAE3D9),
    accent: Color(0xFFC2402A),
    onAccent: Color(0xFFFFFFFF),
    accentGold: Color(0xFFB97D2A),
  );

  static const dark = ZaidangTokens(
    bg: Color(0xFF171412),
    surface: Color(0xFF201C19),
    ink: Color(0xFFEDE7DF),
    inkSecondary: Color(0xFFA79C90),
    border: Color(0xFF35302B),
    accent: Color(0xFFD96C5A),
    onAccent: Color(0xFF2B1310),
    accentGold: Color(0xFFD9A254),
  );
}
```

Dark `accent` is desaturated and lifted (`#D96C5A`), not an invert of `#C2402A`.

### Type, spacing and radius scales

```dart
// lib/theme/zaidang_type.dart — 11 roles, 7 sizes, colour baked from tokens.
class ZaidangType extends ThemeExtension<ZaidangType> {
  final TextStyle hero, title, heading, pageTitle, subheading,
      bodyLarge, body, label, sectionLabel, caption, micro;

  factory ZaidangType.from(ZaidangTokens tokens);
  static final light = ZaidangType.from(ZaidangTokens.light);
  static final dark = ZaidangType.from(ZaidangTokens.dark);
  static ZaidangType of(BuildContext context); // falls back to light
  TextTheme toTextTheme();                     // mirrors the roles into 15 slots
}

// lib/theme/zaidang_spacing.dart
abstract final class ZaidangSpacing {
  static const double xxs = 2, xs = 4, sm = 8, md = 12, lg = 16,
      xl = 20, xxl = 24, xxxl = 32;
  static const double page = xl;  // horizontal page inset
  static const double card = lg;  // card inner padding
}

// lib/theme/zaidang_radius.dart
abstract final class ZaidangRadius {
  static const double sm = 8, md = 16, lg = 26;
  static const BorderRadius smAll, mdAll, lgAll, lgTop;
  static const ShapeBorder pill = StadiumBorder();
}
```

`copyWith` on a `ZaidangType` style may change **only** `color` (a token colour) and `height`. Never override `fontSize` or `fontWeight` at a call site; pick another role instead.

---

## 3. Contracts

### Three color rules (from the note)

1. **UI is the frame, not the painting.** User 立绘 is the subject. Paper + ink cover ≥ 90% of the screen. Accent is only for primary actions, selected state, and brand moments (5–10% area).
2. **Warm paper, not cold gray.** Circle mental model is 机密档案 / 手帐 / 无料 (调研笔记第四节). Use 暖白 `#FAF6F0`, never `#FFFFFF` as the page canvas and never cool gray.
3. **Accent doubles as watermark.** Export-card watermark is the acquisition surface; the red must stay recognizable on any art style.

### Decided palette (2026-08-31)

| Option | Hex | Role |
|--------|-----|------|
| **A 火漆红** | `#C2402A` | **Selected.** Seal / ownership / anti-theft. Rare among 二次元 tools; fits 小红书. |
| B 琥珀蜜蜡 | `#B97D2A` | Demoted to `accentGold` (buyout / member). |
| C 档案墨蓝 | `#2E4E6B` | Rejected. Crowded tool-app color; too cold for 养崽. |

Brand extras that ship with A (do not invent a second accent):

- Export success: 火漆印落章 animation
- Watermark: small seal, not a wordmark strip
- App icon: 「崽档」二字 + 红印 (placeholder OK until asset exists)

### Flutter `ColorScheme` mapping

| Flutter field | Token | Why |
|---------------|--------|-----|
| `surface` | `bg` | Scaffold / list canvas is paper, not card white |
| `surfaceContainerLow` / card | `surface` | Cards and sheets sit on paper |
| `onSurface` | `ink` | Titles and body |
| `onSurfaceVariant` | `inkSecondary` | Hints, subtitles, labels |
| `outline` | `border` | Dividers |
| `primary` | `accent` | Buttons, selected, FAB, 保存 |
| `onPrimary` | `onAccent` | Text on accent |
| `secondary` | `accentGold` | Buyout / member only |
| `onSecondary` | `ink` (light) / `bg` (dark) | Gold is a badge, not a large fill |
| `error` | **do not use accent red** | See destructive contract |
| `surfaceTint` | `Colors.transparent` | No M3 tinted elevation |

`ColorScheme.error` must not be `#C2402A` / `#D96C5A`. Destructive actions use ink buttons + confirm dialog + explicit copy.

### Component contract

| Surface | Tokens |
|---------|--------|
| Scaffold | `bg` |
| Card / dialog / input fill | `surface` + `border` |
| AppBar | List/settings: `bg` or `surface`, title `ink`, **no** `inversePrimary`. Create/edit: **no AppBar** — blurred full-bleed cover, glass back/save, bottom-left 3:4 calling-card portrait, paper cap into the form. |
| AppBar 保存 | `accent` text; disabled = `inkSecondary` |
| List title / subtitle | `ink` / `inkSecondary` |
| Empty state | `inkSecondary` |
| FAB / filled primary | `accent` + `onAccent` |
| Selected chip / tab | `accent` at 5–10% area, not a red page |
| Bottom `NavigationBar` | 56px content height, 24px icons, `micro` labels (12 / 1.2 line height) with `ZaidangSpacing.xxs` top spacing. Paper `bg`, 1px top `border` hairline, transparent indicator, selected icon+label `accent`, unselected `inkSecondary`. The stock bar adds the device bottom safe area once, outside the 56px content height. No red bar fill, no cool gray. |
| Buyout / member badge | `accentGold` |
| Body / heading text | `ink` only — never accent paragraphs |
| Delete / dangerous | ink button + second confirm; no red fill |
| SnackBar feedback | floating `surface` + `border`, `body` ink text, `ZaidangRadius.mdAll` corners; small accent check only for success |

Secondary confirmations use the approved **创作便笺** layout in
`ZaidangConfirmDialog`; see [Component Guidelines](./component-guidelines.md#reusable-confirmation-dialogs).
The global `DialogThemeData` shares surface, transparent tint, `ZaidangRadius.lgAll`
border, `heading` title / `body` content styles and soft shadow with the separate
history-content viewer. It does not change that viewer into a confirmation flow.

Use `showZaidangSnackBar` for operation feedback. Its shared content and global
SnackBar theme replace the default inverse gray strip; see the floating-feedback
contract in [Component Guidelines](./component-guidelines.md#floating-feedback).

### Type scale

Every visible `Text` takes its style from `ZaidangType.of(context).<role>` (or
inherits it from a component theme — AppBar title, dialog title/content, list
tile title/subtitle, tab label, button label, input hint/error are already
wired). `Theme.of(context).textTheme` mirrors the same roles for third-party
widgets; app code prefers the semantic names.

| Role | Size / weight / height | Colour | Use for |
|------|------------------------|--------|---------|
| `hero` | 26 / w600 / 1.2 | `ink` | Page-level headline, backup byte total |
| `title` | 22 / w600 / 1.25 | `ink` | 新建 / 编辑 角色 · 世界观 title on the cover |
| `heading` | 20 / w500 / 1.3 | `ink` | Dialog titles, stat numbers, bootstrap error title |
| `pageTitle` | 17 / w600 / 1.3 | `ink` | `AppBar.titleTextStyle`, sheet titles |
| `subheading` | 17 / w500 / 1.4 | `ink` | `ListTile` title, card title, pinned name, sentence names |
| `bodyLarge` | 17 / w400 / 1.5 | `ink` | Input text + hint, field values, sentence particles |
| `body` | 15 / w400 / 1.5 | `ink` | Body copy, dialog content, SnackBar, empty-state main line |
| `label` | 15 / w500 / 1.3 | `ink` | Filled / outlined / text button and tab labels |
| `sectionLabel` | 13 / w600 / 1.4 | `inkSecondary` | `SectionLabel` widget (分区标签) |
| `caption` | 13 / w400 / 1.4 | `inkSecondary` | Subtitles, hints, counts, empty-state helper line |
| `micro` | 12 / w400 / 1.3 | `inkSecondary` | Ordinals (`属性 3`), stat captions, nav labels, input errors |

Only seven sizes exist: 26 / 22 / 20 / 17 / 15 / 13 / 12. If a design needs an
eighth, change the scale in `zaidang_type.dart` and this table, never the page.

### Spacing scale

Use `ZaidangSpacing` for every `EdgeInsets`, gap `SizedBox`, `Wrap.spacing` /
`runSpacing`, `titleSpacing`, `middleSpacing` and `Positioned` inset.

| Token | Value | Typical use |
|-------|-------|-------------|
| `xxs` | 2 | Nav label top spacing, hairline offsets |
| `xs` | 4 | Tight gaps inside a row, indicator / tab padding |
| `sm` | 8 | Gap between a label and its control, thumb padding |
| `md` | 12 | Gap between related rows, form gutter |
| `lg` | 16 | Standard gap between blocks, list-tile horizontal padding |
| `xl` | 20 | Page horizontal inset (`page`) |
| `xxl` | 24 | Dialog / sheet padding, section gaps |
| `xxxl` | 32 | Large section dividers, top breathing room |

Rounding rule when migrating a literal: nearest step, ties round up
(6 / 7 → `sm`, 10 → `md`, 14 → `lg`, 18 → `xl`, 22 → `xxl`, 28 → `xxxl`). `0`
stays `0`. A `SizedBox` with a single dimension and no `child` is a gap and must
use a token; a `SizedBox` with a `child`, or with both `width` and `height`, is a
size and may keep a **named** constant (`_compactPreviewMaxHeight`,
`glassButtonSize`, `_fieldScrollInset`). Bare magic numbers are not allowed even
for sizes.

### Radius scale

| Token | Value | Use for |
|-------|-------|---------|
| `ZaidangRadius.sm` / `smAll` | 8 | Cards, inputs, thumbnails, buttons, tab indicator |
| `ZaidangRadius.md` / `mdAll` | 16 | SnackBar, dialog action buttons, candidate strip cells |
| `ZaidangRadius.lg` / `lgAll` / `lgTop` | 26 | Dialogs, bottom sheets, hero paper cap |
| `ZaidangRadius.pill` | `StadiumBorder` | Glass save button |

### Type (prep checklist, UI-related)

Ship only fonts that are free for commercial use: 思源宋体 / 思源黑体 / 霞鹜文楷. Pick with the visual draft. Do not embed licensed display fonts. Swapping the family happens once in `ZaidangType.from`, not per page.

### How much polish

Product brief: **only the export card is allowed to be pixel-obsessed.** Other screens use these tokens + stock widgets. Do not start a second design system review; extend the scales instead of bypassing them.

---

## 4. Validation & Error Matrix

| Check | Pass | Fail |
|-------|------|------|
| Seed | Hand-written `ZaidangTokens` | `ColorScheme.fromSeed` |
| Canvas | Light `bg == #FAF6F0` | `#FFFFFF` or `#F6F6F6` page, or Material purple |
| Accent area | Red on buttons / selected / seal only | Red AppBar fill, red body text, red delete |
| Dark accent | `#D96C5A` | Copy light `#C2402A` into dark |
| Contrast | `ink`/`bg` ≥ 4.5:1; large type / icons ≥ 3:1; **verify each mode** | Infer dark from light |
| Gold | Buyout / member only | Gold as second primary |
| Export vs App | App uses this table; card template may differ | Reuse export-card colors as ThemeData |
| Destructive | Ink + confirm | `colorScheme.error = accent` |
| Type | `ZaidangType.of(context).body` / `.caption` … | `TextStyle(fontSize: 15)` or `fontWeight:` at a call site |
| Type override | `copyWith(color: tokens.ink)` / `copyWith(height: 1.8)` | `copyWith(fontSize:)` / `copyWith(fontWeight:)` |
| Spacing | `EdgeInsets.all(ZaidangSpacing.card)`, `SizedBox(height: ZaidangSpacing.md)` | `EdgeInsets.all(16)`, `SizedBox(height: 12)` |
| Radius | `ZaidangRadius.smAll`, `ZaidangRadius.pill` | `BorderRadius.circular(8)` |
| Sizes | Named `static const` (`_compactPreviewMaxHeight = 520`) | Bare `520` in a `SizedBox(child:)` |

---

## 5. Good / Base / Bad Cases

**Good**: `theme` / `darkTheme` both from `ZaidangTokens`; pages read `Theme.of(context)`, `ZaidangTokens.of(context)` and `ZaidangType.of(context)`; spacing and radii come from `ZaidangSpacing` / `ZaidangRadius`; 立绘 is the largest color block.

**Base**: Pages consume the existing semantic theme; app canvas is paper and primary actions use the hand-written accent. No new illustration dependency is needed for routine chrome.

**Bad**: Reintroducing a Material purple seed, treating SiYuan Note's `daylight`/`midnight` CSS as 崽档 tokens (wrong source), or sprinkling `fontSize: 14` / `EdgeInsets.all(10)` into a page because "it looked right".

---

## 6. Tests Required

| Test | Assertion |
|------|-----------|
| Light tokens | `bg == 0xFFFAF6F0`, `accent == 0xFFC2402A`, `ink == 0xFF2B2622` |
| Dark tokens | `bg == 0xFF171412`, `accent == 0xFFD96C5A`, `onAccent == 0xFF2B1310` |
| No seed | Theme module has no `fromSeed` / `Colors.deepPurple` |
| AppBar | Background is `bg` or `surface`; action 保存 uses `accent` |
| Destructive | Delete control is not `accent` / `error` red |
| Contrast smoke | Light and dark `ink` on `bg` checked separately |
| Type scale (`test/theme/zaidang_type_test.dart`) | Role table sizes / weights / heights; exactly seven sizes; `ink` vs `inkSecondary` per role in both modes; `toTextTheme` slot mapping; theme wiring (AppBar, dialog, SnackBar, ListTile, TabBar, input, nav label); `lerp` and `ZaidangType.of` |
| Literal guard (`test/theme/design_token_guard_test.dart`) | No `fontSize:` / `fontWeight:` / `Radius.circular(<n>)` / numeric `EdgeInsets` / numeric gap `SizedBox` / numeric `spacing`, `runSpacing`, `titleSpacing` in `lib/**` outside `lib/theme/` and the export-card renderer |

---

## 7. Wrong vs Correct

#### Wrong

```dart
theme: ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
),
// or: seedColor: Color(0xFFC2402A)  // still generates pink-purple
appBar: AppBar(
  backgroundColor: Theme.of(context).colorScheme.inversePrimary,
),
```

#### Correct

```dart
theme: zaidangTheme(ZaidangTokens.light),
darkTheme: zaidangTheme(ZaidangTokens.dark),
// AppBar inherits ink title; 保存 uses colorScheme.primary (== accent)
```

---

## Design Decision: 火漆红 + 琥珀辅色

**Context**: Need a brand color that reads as 封存 / 确权, works as a watermark on any 立绘, and is not another tool-app blue.

**Options**: A 火漆红 / B 琥珀 / C 墨蓝 (full comparison in the source note).

**Decision**: A as `accent`, B as `accentGold` only. C dropped.

**Extensibility**: If the note versions past v1, update this spec from the SiYuan doc first, then the Dart class. Do not restyle widgets ad hoc.

---

## Don't

- Don't use `ColorScheme.fromSeed` (explicitly forbidden in the note).
- Don't paint titles or body with `accent`.
- Don't use accent red for delete / irreversible actions.
- Don't fill the AppBar or scaffold with accent (breaks the 5–10% rule).
- Don't use SiYuan Note's own `daylight` / `midnight` CSS as ochome tokens.
- Don't apply this table to 设定卡 templates.
- Don't introduce a third brand hue beyond 火漆红 and 琥珀金.
- Don't sit a Material AppBar (opaque or transparent-with-title) on the create/edit 立绘. Use glass overlay controls and a paper bottom cap.
- Don't write `fontSize:` / `fontWeight:` outside `lib/theme/zaidang_type.dart`; pick a `ZaidangType` role.
- Don't write numeric `EdgeInsets`, gap `SizedBox`, `Wrap.spacing` or `Radius.circular` in pages and widgets; use `ZaidangSpacing` / `ZaidangRadius`.
- Don't reach for `Theme.of(context).textTheme.bodyMedium` in app code; `ZaidangType.of(context).body` is the same style with a name that says what it is for.
- Don't add an eighth font size or a ninth spacing step at a call site. Change the scale file and this spec together.

---

## Common Mistake: mapping `ink` to Flutter `onSurfaceVariant`

**Symptom**: Titles look dusty on paper.

**Cause**: Treating `inkSecondary` as the only text color because Material examples use `onSurfaceVariant` everywhere.

**Fix**: Body and titles = `ink`. Hints and list subtitles = `inkSecondary`.

---

## Source notes

| Note | What was taken |
|------|----------------|
| `/需求讨论/OC 档案馆 · 立项调研与产品简报/主题色与设计 Token` | Principles, A/B/C decision, light/dark tables, implementation constraints |
| `…/立项调研数据` 第四节 | 纸质 / 手帐 / 无料 mental model; 10-card aesthetic is for **export templates only** |
| `…/开发前准备清单` | Free-to-use fonts; icon = 崽档 + 火漆红印 |
| `…/OC 档案馆 · 立项调研与产品简报` 第七节 | Only the export card gets pixel-level visual polish |
