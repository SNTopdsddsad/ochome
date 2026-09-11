# Frontend Development Guidelines

> Best practices for frontend development in this project.

---

## Overview

Guidelines for the Flutter UI of 崽档: `lib/pages/`, `lib/widgets/`,
`lib/features/*/widgets/`, `lib/theme/` and `lib/app_router.dart`. Base
guidelines describe repeated patterns; feature specs carry the contracts
(keys, return values, busy semantics) other code depends on.

---

## Guidelines Index

| Guide | Description | Status |
|-------|-------------|--------|
| [Directory Structure](./directory-structure.md) | pages vs widgets vs features, naming, key conventions, how a new tab is added | Active |
| [Component Guidelines](./component-guidelines.md) | Widget file layout, props conventions, copy rules, image gallery, confirmations, feedback, attribute slivers | Active |
| [Role-card Export](./role-card-export.md) | Selected-content projection, fixed PNG layout, pagination, fonts and native delivery | Active |
| [Provider Guidelines](./hook-guidelines.md) | Riverpod declaration styles, repository + stream pair, dataset-switch invalidate lists, `AsyncValue` rendering | Active |
| [State Management](./state-management.md) | Widget state vs providers, busy/save gating across the detail page, `mounted` discipline | Active |
| [Quality Guidelines](./quality-guidelines.md) | analyze/test/format gate, forbidden UI patterns, widget test harness, review checklist | Active |
| [Theming](./theming.md) | 崽档火漆红 / 纸白 colour tokens from the SiYuan product note, plus the `ZaidangType` / `ZaidangSpacing` / `ZaidangRadius` scales and the literal guard test | Active |
| [Navigation](./navigation.md) | go_router tab shell, root create/edit/backup, archive OC / 世界观 tabs | Active |
| [Backup and Restore](./backup-restore.md) | App-owned jobs, historical contents, progress truth and dataset lifecycle | Active |
| [Role Assets](./role-assets.md) | Shared detail header, independent tab scroll state and local asset interactions | Active |
| [Role Relationships](./role-relationships.md) | 关系 tab, perspective wording, directed two-label editor and busy gating | Active |
| [Worlds UI](./worlds.md) | World list/editor, shared `archive_editor` widgets, entry slivers, delete flow and the role world selector | Active |
| [Type Safety](./type-safety.md) | Null safety, model vs Drift row isolation, `BackupJson` strict decoding, tolerated `!`/`dynamic` | Active |
| [Git Commit](./git-commit.md) | Chinese commit messages by module and feature | Active |

---

## Maintaining These Guidelines

- Document **actual conventions**; when the code changes, change the spec in
  the same commit (`Trellis:` module).
- Every rule points at a real file under `lib/` or `test/`.
- New screens or widgets with a contract get a feature spec here, following
  `role-relationships.md` (keys, hint priority, dismiss behaviour, tests).

---

**Language**: All documentation should be written in **English**.
