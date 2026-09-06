# 首页底栏与 go_router

## Goal

Replace the single-page home with a two-tab shell so the app can grow beyond the role list. Tabs are **档案** (current role list) and **我的** (blank placeholder). Navigation uses **go_router**. Create, edit, and backup stay full-screen pages that cover the tab bar.

## Background

- `lib/app.dart` currently sets `home: const RoleListPage()`. There is no route table and no `go_router` dependency.
- `RoleListPage` is the whole first screen: AppBar title 「角色」, cloud action to `BackupRestorePage`, FAB / row tap to `RoleCreatePage` via `Navigator.push`.
- Create, edit, backup, cover preview, description history, and role-card export are already full-screen `MaterialPageRoute`s.
- `test/widget_test.dart` pumps `MyApp` and asserts on 「角色」, the empty list, FAB, create, and edit.

## Requirements

- **R1 — Two-tab shell:** The app root is a persistent bottom tab shell with **档案** and **我的**. Launch opens 档案. Switching tabs does not recreate the role list from scratch (scroll / list state survives a round trip to 我的). Tab switches are not a back-stack of pages: from 我的, the Android system back button returns to 档案; from 档案 at root, back leaves the app.
- **R2 — 档案 content:** 档案 is the current role list unchanged in behavior: AppBar title stays **「角色」**, empty copy, list tiles, cover thumbs, FAB to create, row tap to edit, AppBar cloud action to backup/restore. The bottom tab label is **档案**, not 「角色」.
- **R3 — 我的 placeholder:** 我的 is a blank paper page with AppBar title **「我的」** and an empty body. No backup, settings, account, empty-state marketing copy, or other actions. Backup stays on 档案.
- **R4 — Full-screen flows hide the tab bar:** Create, edit, and backup open as new pages above the shell. The tab bar is not visible on those pages. Pop returns to the same tab.
- **R5 — go_router owns the tree:** `MaterialApp.router` plus a single `GoRouter`. Tab destinations are shell branches. Create / edit / backup are root-level routes so they cover the shell. Existing widget tests that construct `RoleCreatePage` / `BackupRestorePage` directly keep working.
- **R6 — Non-URL flows stay imperative:** Role-card export, cover preview, and description history remain `Navigator.push` from the already full-screen create/edit page (snapshot extra, preview path, history `pop` string). Do not invent URLs for those.
- **R7 — Theme:** Tab bar sits on paper (`bg`). Selected tab uses accent on icon + label only (5–10% area), not a red bar fill. Unselected uses `inkSecondary`. No `ColorScheme.fromSeed`.
- **R8 — No extras:** No new tabs, no deep-link scheme / universal-link work, no Web URL product requirement, no moving backup to 我的, no `go_router_builder` codegen.

## Acceptance Criteria

- [ ] **AC1 (R1, R2):** Cold start shows 档案 content with AppBar 「角色」 and both tab labels 档案 / 我的. Tapping 我的 then 档案 returns to the role list without an extra loading flash of the empty/list body.
- [ ] **AC2 (R2, R4):** FAB still opens 新建角色 full-screen; tab bar is gone; saving a named role pops back to 档案 and the new row is visible.
- [ ] **AC3 (R2, R4):** Tapping a role still opens 编辑角色 full-screen without the tab bar; saving edits returns to 档案 with the updated row.
- [ ] **AC4 (R2, R4):** 档案 cloud action still opens 备份与恢复 full-screen without the tab bar; back returns to 档案.
- [ ] **AC5 (R3):** 我的 shows AppBar 「我的」, no role list, no FAB, no backup entry, and no feature buttons.
- [ ] **AC6 (R5, R6):** Router table includes the shell and the create/edit/backup routes. Export, cover preview, and description history still open from the editor and still return correctly.
- [ ] **AC7 (R7):** Light and dark tab chrome use existing `ZaidangTokens`; selected state is accent, canvas stays paper.
- [ ] **AC8 (R1):** On 我的, a simulated system back shows 档案 again rather than leaving `MyApp`.

## Out of Scope

- Filling 我的 with settings, account, or backup.
- Additional tabs.
- Universal links / custom URL schemes / Web hosting.
- Changing role persistence, backup format, or create/edit form layout.
- Rewriting export / cover preview / history as URL routes.
- Renaming the 档案 AppBar from 「角色」 to 「档案」.

## Notes

- Pin `go_router` to an exact version compatible with Flutter 3.47.2 / Dart 3.13.2, same style as other `pubspec.yaml` pins.
- Complex task: `design.md` and `implement.md` required before `task.py start`.
