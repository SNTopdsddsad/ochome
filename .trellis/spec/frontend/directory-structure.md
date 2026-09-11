# Directory Structure (UI Layer)

> Where screens, shared widgets, feature UI and theme live in 崽档.

---

## Overview

The UI is a single Flutter package using Riverpod 3 and go_router. Screens go
in `lib/pages/`, app-wide reusable chrome in `lib/widgets/`, and UI that only
makes sense inside one feature in `lib/features/<feature>/`. Theme tokens and
`ThemeData` live in `lib/theme/`. Routing is centralised in
`lib/app_router.dart`.

There is no localisation layer: all copy is hardcoded Chinese (no `.arb`, no
`intl`). See `component-guidelines.md` for copy rules.

---

## Directory Layout

```
lib/
  main.dart                 runApp(ProviderScope(child: AppStorageBootstrap()))
  bootstrap.dart            AppStorageBootstrap: storage init, loading/error MaterialApp, then MyApp
  app.dart                  MyApp: builds router, picks initial location (/archive or /backup)
  app_router.dart           createAppRouter(): shell + root routes
  app_version.dart
  theme/
    zaidang_tokens.dart     ZaidangTokens ThemeExtension (light/dark)
    zaidang_theme.dart      zaidangLightTheme()/zaidangDarkTheme() built from tokens
    zaidang_system_ui.dart  zaidangSystemUiOverlayStyle() for AppBar-less pages
  pages/                    one screen or tab body per file
    home_shell.dart         HomeShell: NavigationBar over StatefulShellRoute
    archive_page.dart       ArchivePage: NestedScrollView header (title + search + segmented OC / 世界观), owns TabController
    role_list_page.dart     RoleListPage(query) (keep-alive card list)
    world_view_page.dart    WorldViewPage(query)
    mine_page.dart
    role_create_page.dart   RoleCreatePage: create + edit, hosts tabs in edit mode
    role_assets_tab.dart    RoleAssetsTab
    role_relationships_tab.dart  RoleRelationshipsTab
    role_desc_history_page.dart
    cover_preview_page.dart
    role_card_export_page.dart
    backup_restore_page.dart
    backup_contents_page.dart
  widgets/                  shared, feature-agnostic
    zaidang_confirm_dialog.dart      showZaidangConfirmDialog
    zaidang_snack_bar.dart           showZaidangSnackBar + tones
    cover_file_view.dart             dataset-relative image view
    archive_list_view.dart           home list: hints, search filter, spacing, FAB inset
    archive_list_card.dart           home list card (cover + name + tags + summary + meta)
    archive_tag.dart                 paper chip used for card tags
    role_list_tile.dart              compact role row for the world editor's 角色 tab
    storage_error_details.dart       expandable raw error for startup failures
    role_asset_rename_dialog.dart
    role_relationship_editor_sheet.dart
  features/
    backup/widgets/         BackupJobPanel, backup_shared.dart (BackupBody, notices)
    role_card/              export pipeline + RoleCardFieldPicker sheet (no widgets/ subfolder)
test/
  pages/                    one *_test.dart per page/tab
  widgets/                  one per shared widget
  theme/zaidang_tokens_test.dart
  widget_test.dart          full-app smoke through MyApp + fake repository
  fakes/                    shared with data tests
```

---

## Module Organization

**`pages/`** — anything reachable by a route or hosted as a tab body.
Suffixes: `*Page` for screens, `*Tab` for bodies hosted inside
`RoleCreatePage`'s `NestedScrollView`, `HomeShell` for the shell. Pages own
their ephemeral state (`ConsumerStatefulWidget`) and talk to the data layer
only through providers. Private helper widgets (`_RoleTile`, `_ArchiveTab`,
`_HeroBackdrop`, `_OtherPortrait`) sit at the bottom of the same file until
a second page needs them.

**`widgets/`** — promoted when reused across pages or when the widget is a
product-wide primitive (confirmation dialog, snack bar, cover view). A widget
here must not import a page and must not depend on a specific provider;
dependencies arrive as constructor parameters or callbacks
(`showRoleRelationshipEditor(onSave:, canSave:, candidates:)`).

**`features/<name>/`** — used when a feature spans data and UI (backup) or is
a self-contained pipeline (role-card export). Feature widgets live in
`features/<name>/widgets/` when there are several; `role_card` keeps its single
sheet next to its services. Pages import from features; features do not import
pages.

**`theme/`** — the only place allowed to hold hex colours for app chrome.
`ZaidangTokens.of(context)` is the accessor; `Theme.of(context)` is used for
`textTheme`, `brightness` and `colorScheme.shadow`. The one exception is
`lib/features/role_card/role_card_renderer.dart`, whose palette is the export
card's own fixed design, not app chrome.

**Navigation** — go_router routes are registered once in `createAppRouter`:
`/archive` and `/mine` as shell branches, `/roles/new`, `/roles/:id` and
`/backup` on the root navigator. Routes use `path:` only (no `name:`);
`/roles/:id` requires `extra` to be a `Role` and redirects to `/archive`
otherwise. Secondary screens that are not deep-linkable (history, cover
preview, export, backup contents) are pushed with `Navigator.push` +
`MaterialPageRoute` from the owning page. Details in `navigation.md`.

---

## Naming Conventions

- Files `snake_case.dart`; the file name matches the primary public class
  (`role_relationships_tab.dart` → `RoleRelationshipsTab`).
- Public entry points for modals are functions, not widgets:
  `showZaidangConfirmDialog`, `showZaidangSnackBar`,
  `showRoleRelationshipEditor`. The widget class (`ZaidangConfirmDialog`,
  `RoleRelationshipEditorSheet`) stays public for tests.
- Widget test keys are kebab-case strings namespaced by feature:
  `'role-relationship-save'`, `'zaidang-confirm-dialog'`,
  `'role-create-cover-portrait'`, `'backup-job-panel'`.
- `PageStorageKey` strings follow `'<feature>-scroll'`
  (`'role-assets-scroll'`, `'role-relationships-scroll'`).
- Product-branded primitives are prefixed `Zaidang`.
- Tests mirror the source path: `lib/pages/x.dart` → `test/pages/x_test.dart`.

---

## Examples

Adding a new tab to the role detail page (the relationships tab is the
reference):

1. `lib/pages/role_<x>_tab.dart` — `ConsumerStatefulWidget` with
   `AutomaticKeepAliveClientMixin`, `PageStorageKey('role-<x>-scroll')`,
   `SliverOverlapInjector` first, props `roleId`, `enabled`, `isEnabled`,
   `onBusyChanged`.
2. Register it in `RoleCreatePage`'s `TabBar`/`TabBarView` in edit mode only
   and OR its busy flag into `_tabBusy`.
3. Modal editors go to `lib/widgets/` if generic, otherwise stay private in
   the tab file.
4. `test/pages/role_<x>_tab_test.dart` pumps `RoleCreatePage(role: ...)`
   inside `ProviderScope(overrides: [...fakes])` + `MaterialApp(theme: zaidangLightTheme())`.
5. Add `.trellis/spec/frontend/role-<x>.md` describing the tab contract.

Anti-patterns:

- A page importing `lib/data/database/` or a `Drift*Repository` class
  directly. Use the provider and the interface.
- Putting a feature-specific dialog in `lib/widgets/` "just in case". Promote
  on the second use.
- A shared widget reading `ref` for a specific provider; pass values in.
