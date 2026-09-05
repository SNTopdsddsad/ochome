# Confirmation dialog design proposal

Status: v2 approved by the user on 2026-09-05 (“这个可以”), after v1 was found too formal for an OC product. Source note: [主题色与设计 Token](siyuan://blocks/20260831132039-dnb277v), v1 (2026-08-31).

## Direction: 创作便笺

A short, gentle interruption in the creator's notebook. The OC creator is working on a character they care about; bureaucratic labels and document-like subdivisions overemphasized record administration in v1. Remove the “崽档 / 档案编辑” masthead, separate target-label section and internal rule. Use a small notebook doodle, softer corners, normal-weight body copy and a conversational question. Embed the actual target naturally in the sentence. Keep the stock Flutter dialog route and interaction primitives.

A small notebook mark on a warm-paper patch is the visual signature. A tiny brand-red sparkle can accompany ordinary editor/history prompts; omit the sparkle for whole-device overwrite. This is a proposed decorative motif, not a danger signal or a new official logo. Keep it restrained, avoid character distress or guilt-based copy, and reserve the note's wax-seal animation for export success. The preview offers a decoration toggle and modest corner-radius adjustment through the host design controls.

This is a new proposal for geometry and composition, not a rule already present in the note. The note remains the authority on color and semantics.

## Existing state

`ZaidangTokens` already matches the source note. `zaidangTheme` has no shared dialog theme, so AlertDialog geometry, spacing and action layout are defaults. Attribute deletion and history restoration let cancel inherit the brand-red TextButton theme while confirmation is explicitly ink; iCloud overrides both to ink. The frontend theming spec's statement that the app still uses a purple seed is stale; current code is the authority for this audit.

## Shared structure

1. A small 46-pixel notebook patch, slightly tilted, with an ink line icon; a small accent sparkle is optional for editor/history scenes. No category masthead.
2. Left-aligned conversational question, about 20 logical pixels, medium weight. Natural wrapping is allowed.
3. One compact paragraph names the target and what will change; a second short sentence explains timing or irreversibility. Use ink, 15 logical pixels and normal weight. Do not add a separate labeled data-summary box for these short scenarios.
4. Two roomy actions when they fit: warm-paper cancellation with ink text, and ink-filled confirmation with surface text. Same height, approximately equal width, 12 logical pixel gap. On narrow/text-scaled layouts allow button-label wrapping, then stack when needed; keyboard order follows visual order.

Keep actual attribute names and actual history timestamps. Do not invent role avatars, counts or backup dates unavailable to the caller. Long names must wrap rather than disappear behind ellipses.

Proposed Flutter dimensions: width `min(availableWidth - 48, 380)`, outer inset 24, inner padding about 24 (top 28), 26 corner radius, 1 logical pixel border, 12 heading/body gap, 8 consequence gap, 26 gap before actions, 48 minimum action height, 15 action radius. Use a very soft neutral shadow. At very narrow widths prioritize usable insets and wrapping over a fixed target width. Long content may scroll while actions remain available. Font selection stays with the existing app font; no new font dependency is required.

The v2 inline preview uses product-specific typography, surfaces and 48-pixel buttons. It remains a browser mockup, not a Flutter golden or a substitute for route/focus/text-scaling validation.

## Colors and variants

Use `surface` for the sheet, `bg` for the notebook patch and cancellation fill, `ink` for heading/body/icon, `border` for the thin outer edge. No internal rule. Disable Material surface tint. Preserve the eight existing color tokens and add no new palette.

All three current confirmations remove or replace content, so their action is ink-filled. In dark mode the same semantic pairing becomes light ink on a warm-dark sheet with dark surface text; validate that pair independently. A later non-destructive primary confirmation can use `accent` / `onAccent`, but it is not needed for these three call sites. Gold remains reserved for membership/buyout. The small optional sparkle is brand decoration, not a danger icon, title or action color. The whole-device restore omits it to keep the consequence easy to read.

Use `ink` on essential explanatory text: light `inkSecondary` on a white sheet does not reach 4.5:1. Do not silently change that global token for this task.

## Scenario copy

| Scenario | Heading | Body / consequence | Cancel / confirm |
|---|---|---|---|
| Remove custom attribute | 要删掉这条属性吗？ | 「{名称}」和里面的内容会一起移除。保存角色后生效。 | 先留着 / 删除属性 |
| Restore history | 换回这一版设定吗？ | 将立即换回 {时间} 的设定。还没保存的设定修改会丢失。已经存下的修改历史会保留。 | 先不换 / 恢复此版 |
| Restore iCloud | 用云端备份替换本机内容？ | 本机的角色资料、设定历史和立绘都会被 iCloud 备份替换。这次替换无法撤销。 | 先不恢复 / 覆盖恢复 |

For an unnamed attribute use “这条未命名属性和里面的内容会一起移除。” Cancellation accessible names include visible copy plus purpose: 先留着，保留这条属性 / 先不换，取消恢复设定 / 先不恢复，保留本机内容. Friendly wording must not weaken the action label or consequence.

The timestamp and attribute name in the preview are explicitly sample values. Existing custom-attribute order/content belongs to role data and therefore to full-database restore; do not imply only the description text is replaced.

## Interaction and accessibility

- Escape, system back, barrier dismissal and cancel produce a non-confirm result; only the explicit action returns true. Destructive action must not be automatically focused or triggered by Enter immediately after opening. Avoid extra typed phrases, countdowns and extra confirmation steps for these existing flows.
- Keep focus inside the modal and restore it to the trigger on dismissal. Announce the question and consequences. Preserve standard button roles and descriptive accessible names.
- Dismiss the confirmation before starting the existing operation. Existing caller-level busy state and error/progress surfaces remain responsible for async feedback. Do not turn this reusable UI into a repository/service owner.
- Propose a quiet fade and minimal upward motion, around 160–200 ms; honor reduced motion. No stamp/drop celebration for deletion or overwrite.
- Do not change whether the underlying operation is immediate or deferred until save as part of visual unification.

## Flutter boundary (implemented)

`lib/widgets/zaidang_confirm_dialog.dart` exposes the reusable `ZaidangConfirmDialog` Widget and a `showZaidangConfirmDialog` helper returning `Future<bool>`; helper dismissals map to false. Required inputs are title, body, consequence and confirmLabel; optional inputs are cancelLabel, cancelSemanticLabel and showSparkle. Callers interpolate actual targets into localized copy; no target-label API or business callbacks are needed. The implementation uses stock `Dialog`, buttons, focus and navigation mechanisms with shared layout. Business logic remains in each page. Compatible shared defaults live in `DialogThemeData`; the revision-content viewer retains selectable scrollable content and its distinct close/restore controls.

The Widget accepts direct standard `showDialog<bool>` reuse, as explicitly requested by the user. Default cancellation takes focus. A resolved flag plus current-route check rejects repeated callbacks during exit. Labels are measured at the actual text scale to switch between row/column; exceptionally short windows allow whole-sheet scrolling. Motion uses the stock dialog transition at 180 ms and is disabled when the platform requests reduced motion.

Do not migrate the content viewer to a destructive-confirmation API. Avoid building a universal modal framework or adding an animation package.

## Sources and unresolved review

- Source note via MCP on 2026-09-05: same values as `lib/theme/zaidang_tokens.dart`.
- Code and behavior: `research/behavior-audit.md`.
- User review: v1 was too formal for an OC product. V2 shifts toward a creator's notebook, with shorter copy and softer shape. The user approved v2; implement this contract.
- Current preview: `research/confirmation-preview-v2.html`. The first preview remains in `research/confirmation-preview.html` for reference.
