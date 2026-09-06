# Design: 首页底栏与 go_router

## Architecture

Keep imperative `Navigator.push` for object/return-value flows. Use go_router for the app tree, tab shell, and the three full-screen destinations that can be expressed as locations.

```
MaterialApp.router
  GoRouter (root navigator key)
    StatefulShellRoute.indexedStack
      branch 0  /archive   RoleListPage
      branch 1  /mine      MinePage
    /roles/new             RoleCreatePage()           parentNavigatorKey: root
    /roles/:id             RoleCreatePage(role)       parentNavigatorKey: root
    /backup                BackupRestorePage()        parentNavigatorKey: root
```

Root-level routes cover the shell, so create / edit / backup hide the tab bar. Pop returns to the live shell (IndexedStack keeps 档案 state).

Do not use nested `Navigator.push` for those three destinations: a push on the branch navigator would keep the tab bar visible.

## File boundaries

| File | Role |
|------|------|
| `lib/app_router.dart` | `createAppRouter()` factory. No global singleton. Each `MyApp` instance owns one `GoRouter`. |
| `lib/app.dart` | Stateful `MyApp`: create the router in `State`, `MaterialApp.router(routerConfig:)`. Theme unchanged. |
| `lib/pages/home_shell.dart` | Paper `Scaffold` + `NavigationBar`. Body is `StatefulNavigationShell`. |
| `lib/pages/mine_page.dart` | AppBar 「我的」, empty paper body. |
| `lib/pages/role_list_page.dart` | Replace the three `Navigator.push` calls with `context.push`. Keep AppBar 「角色」, FAB, backup icon. |
| `lib/theme/zaidang_theme.dart` | `NavigationBarThemeData` from `ZaidangTokens`. |
| `pubspec.yaml` | Exact-pin `go_router`. |

`RoleCreatePage` / `BackupRestorePage` constructors stay public so existing page tests can still pump them without a router.

## Contracts

### Router factory

```dart
GoRouter createAppRouter({
  GlobalKey<NavigatorState>? rootNavigatorKey,
  String initialLocation = '/archive',
});
```

Paths:

| Location | Page | Shell |
|----------|------|-------|
| `/archive` | `RoleListPage` | yes |
| `/mine` | `MinePage` | yes |
| `/roles/new` | `RoleCreatePage()` | no |
| `/roles/:id` | `RoleCreatePage(role: extra as Role)` | no |
| `/backup` | `BackupRestorePage()` | no |

Edit always receives the current `Role` as `state.extra` (same in-memory snapshot the list already has). Do not add a loading/error edit screen that re-fetches `getById` in this task. If `extra` is missing or not a `Role`, `go('/archive')`.

Unknown paths: go_router default error page is acceptable for this slice; do not design a branded 404.

### Shell chrome

- `NavigationBar` (Material 3), two destinations.
- Labels: 档案 / 我的.
- Icons: `Icons.folder_outlined` / `Icons.folder` and `Icons.person_outline` / `Icons.person`.
- Tab change: `navigationShell.goBranch(index)`. Do not `context.go` in a way that rebuilds the branch from scratch if `goBranch` already preserves state.
- System back on 我的: `PopScope` on the shell; if current branch is 我的, `goBranch(0)` and `canPop: false` for that case. If current branch is 档案, allow pop (app exit).

### List navigation

```dart
context.push('/backup');
context.push('/roles/new');
context.push('/roles/${role.id}', extra: role);
```

Export, cover preview, and description history stay `Navigator.of(context).push` inside `RoleCreatePage`.

### Theme

```dart
navigationBarTheme: NavigationBarThemeData(
  backgroundColor: tokens.bg,
  surfaceTintColor: Colors.transparent,
  elevation: 0,
  indicatorColor: Colors.transparent, // selected = accent icon/label only
  // selected icon+label: tokens.accent
  // unselected: tokens.inkSecondary
)
```

No red indicator pill, no accent bar fill. Height stays the stock NavigationBar height.

### Nested Scaffold / FAB

`HomeShell` and `RoleListPage` are both Scaffolds. The inner FAB must sit above the tab bar, not under it. Verify in a phone-size widget test (`Size(390, 844)`): FAB bottom < tab bar top. If MediaQuery padding is not applied, add shell `extendBody: false` (default) and do not wrap the list in a second bottom nav.

## Compatibility

- No database / backup format change.
- No iOS/Android URL-scheme or associated-domains work.
- `MyApp` tests that pump the real app go through the router; page-level tests that push `RoleCreatePage` directly are unchanged.
- Each `pumpWidget(MyApp())` must get a fresh `GoRouter` so tests do not share location.

## Trade-offs

- **StatefulShellRoute vs one IndexedStack + no go_router:** Rejected; user asked for go_router.
- **ShellRoute vs StatefulShellRoute:** ShellRoute disposes the inactive tab. R1 requires list state to survive 我的, so IndexedStack branches.
- **`/roles/:id` + extra vs load-by-id:** extra preserves today’s instant editor fill and avoids a new loading UI. Deep-link restore of an edit URL is out of scope.
- **go_router_builder:** extra codegen and another `build_runner` output. Manual `GoRoute` list is enough for five paths.
- **Moving backup to 我的:** rejected for this slice (R3).

## Rollback

Revert the router/shell/theme/pubspec files and restore `MyApp.home = RoleListPage()` plus the three `Navigator.push` calls. No data migration.

## Pin

Use the newest `go_router` that `flutter pub add` resolves on Flutter 3.47.2, then pin the exact version in `pubspec.yaml` (no `^`). If 18.x fails analysis, drop to the latest 17.x or 16.x that analyzes clean.
