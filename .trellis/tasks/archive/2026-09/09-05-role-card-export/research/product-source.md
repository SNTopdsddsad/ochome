# Product source and confirmed scope

Read through SiYuan MCP on 2026-09-05:

- `/需求讨论/OC 档案馆 · 立项调研与产品简报`, root ID `20260829172436-s1l4xy5`.
- Its children `立项调研数据`, `发展路线`, `开发前准备清单`.
- The existing `主题色与设计 Token` note and frontend theme spec apply to app chrome, not the export template palette.

## Binding product direction

The brief scopes MVP export to **one polished template**, per-field visibility controls and a corner product watermark. The main distribution loop is users sharing cards themselves. Rendering and data stay local; the product has no AI content features or hosted-data dependency. The roadmap is iOS first, with multiple templates, template marketplaces and structured card exchange deferred.

The preparation checklist calls for a visual layout review before renderer implementation. Use a commercially usable font selected from the note's candidates (Source Han Sans/Serif or LXGW WenKai), with source/license verified before adding assets. The current app has no bundled export fonts.

The research note's aesthetic section describes large character artwork, grouped fields, restrained whitespace and some professional reference-card elements. It lists ten example post titles but provides neither image attachments nor recoverable cache paths. This session has not viewed those ten images; do not claim to match them exactly.

Color swatches are suggested in the research note, not a confirmed MVP requirement. Automatic palette extraction, radar charts, multi-character cards, many templates, payment gates and a free-form template editor are not part of this implementation scope unless the user explicitly adds them.

## User decisions

- New feature requested as the most important task at this stage: add character-card export.
- User chose: **sharing first, artwork-led fixed-ratio main card, long content on continuation pages**.
- Prior design feedback: OC UI should feel approachable; the formal archive-slip treatment for confirmations was rejected in favor of a softer creator-notebook tone. This informs proposals, but does not mean the export template must reproduce the app/dialog layout.

## Repository baseline

- Baseline commit: `079b326`; only unrelated untracked `.vscode/` and `CLAUDE.md` existed before this task.
- `Role` currently includes name, sex, age, birthday, race, occupation, description, a single cover path and ordered custom attributes.
- Role editing is explicit-save; history restoration has a separate immediate-write boundary. Export must not accidentally expose stale values or discard unsaved drafts.
- Cover paths support both relative `covers/...` paths and legacy absolute paths. Export must reuse that resolver contract.
- Existing sharing-like native code is for iCloud backup export, not character-card image output.
