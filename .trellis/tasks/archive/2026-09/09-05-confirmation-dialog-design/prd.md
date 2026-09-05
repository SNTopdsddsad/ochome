# 统一二次确认弹窗设计

## Goal

Give 崽档's secondary confirmation dialogs a warm, approachable creative-notebook identity for OC creators, consistent with the SiYuan note 《主题色与设计 Token》 (v1, 2026-08-31). The user approved the v2 preview on 2026-09-05 (“这个可以”); implement and validate that direction.

## Requirements

- Use the note's light/dark semantic colors, paper-and-ink proportions and destructive-action contract.
- Reflect the user's review: the first archive-slip direction felt too formal for an OC product. Use softer geometry, a compact notebook motif and conversational copy; remove bureaucratic headings and excessive section divisions.
- Unify the three existing confirmations: custom-attribute deletion, description-history restoration and iCloud overwrite restoration.
- Expose a standalone reusable `ZaidangConfirmDialog` Widget and a convenience opening helper, as explicitly requested by the user: “单独设置成一个 可以复用的weight”. Keep business effects outside the Widget.
- Make the action target, affected data and moment of effect understandable before confirmation.
- Keep destructive/replacement actions ink-colored. Never use the brand red or member gold as a danger signal.
- Give cancellation a clear but subordinate appearance; it must not inherit a stronger red emphasis than the actual action.
- Use concrete action labels instead of generic “确定”.
- Preserve the distinction between saved history and unsaved editor content; avoid promising recovery that the app does not provide.
- Support dark mode, narrow screens, long names, text scaling and keyboard/screen-reader operation.
- Record the design as a Trellis task, as explicitly approved by the user on 2026-09-05.

## Acceptance Criteria

- [x] Read the source note through SiYuan MCP and identify the governing tokens.
- [x] Inventory current dialogs and verify their real data effects.
- [x] Produce one recommended visual direction with light/dark and scenario previews.
- [x] Specify shared structure, action hierarchy, copy and accessibility requirements.
- [x] User reviews the direction before starting implementation.
- [x] Implementation replaces the three confirmation call sites and passes the planned checks.

## Notes

- Source: siyuan://blocks/20260831132039-dnb277v
- The revision-content viewer is a fourth AlertDialog but is not a secondary confirmation; preserve its content-reading role.
- User review on 2026-09-05: “会不会太正式了点，这个是 oc 用的”. The second design proposal responds to this feedback.
- Approval on 2026-09-05: “这个可以”. Continue into implementation of v2.
- Implementation and validation are complete. On 2026-09-05 the user authorized local commits and task archival (“commit 然后归档”); the commit-review gate is satisfied.
