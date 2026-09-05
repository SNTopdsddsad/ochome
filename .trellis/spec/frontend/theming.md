# Theming and Design Tokens

> Visual contract for **崽档** App UI. Source note (v1, 2026-08-31, 已拍板): SiYuan `/需求讨论/OC 档案馆 · 立项调研与产品简报/主题色与设计 Token`.
>
> Export-card templates have their own palette and are **not** bound by this file.
> The implemented character-sheet template is specified in [Role-card Export](./role-card-export.md).

---

## 1. Scope / Trigger

**Trigger**: Any `ThemeData` / `ColorScheme` change, new hardcoded color, AppBar / list / form / empty / paywall chrome, destructive-action styling, watermark, or App icon.

**Applies to**: in-app UI only (list, create/edit, settings, buyout badge).

**Does not apply to**: 设定卡导出模板。模板审美基准见调研笔记第四节（10 张圈内设卡），在 Figma/纸上定版式后再自绘渲染。

**Current implementation**: `lib/theme/zaidang_tokens.dart` defines the hand-written light/dark palette, and `lib/theme/zaidang_theme.dart` maps it into `ThemeData`. Do not reintroduce a seed palette.

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
| Buyout / member badge | `accentGold` |
| Body / heading text | `ink` only — never accent paragraphs |
| Delete / dangerous | ink button + second confirm; no red fill |
| SnackBar feedback | floating `surface` + `border`, `ink` text, 16-radius corners; small accent check only for success |

Secondary confirmations use the approved **创作便笺** layout in
`ZaidangConfirmDialog`; see [Component Guidelines](./component-guidelines.md#reusable-confirmation-dialogs).
The global `DialogThemeData` shares surface, transparent tint, 26-radius border
and soft shadow with the separate history-content viewer. It does not change
that viewer into a confirmation flow.

Use `showZaidangSnackBar` for operation feedback. Its shared content and global
SnackBar theme replace the default inverse gray strip; see the floating-feedback
contract in [Component Guidelines](./component-guidelines.md#floating-feedback).

### Type (prep checklist, UI-related)

Ship only fonts that are free for commercial use: 思源宋体 / 思源黑体 / 霞鹜文楷. Pick with the visual draft. Do not embed licensed display fonts.

### How much polish

Product brief: **only the export card is allowed to be pixel-obsessed.** Other screens use these tokens + stock widgets. Do not start a second design system review.

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

---

## 5. Good / Base / Bad Cases

**Good**: `theme` / `darkTheme` both from `ZaidangTokens`; pages read `Theme.of(context)` or `ZaidangTokens.of(context)`; 立绘 is the largest color block.

**Base**: Pages consume the existing semantic theme; app canvas is paper and primary actions use the hand-written accent. No new illustration dependency is needed for routine chrome.

**Bad**: Reintroducing a Material purple seed, or treating SiYuan Note's `daylight`/`midnight` CSS as 崽档 tokens (wrong source).

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
