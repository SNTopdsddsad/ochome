# App navigation

## Scope / Trigger

**Trigger**: Changing `MyApp`, `GoRouter`, the bottom tab shell, or any `context.push` / `Navigator.push` from `RoleListPage` / `RoleCreatePage`.

**Does not apply to**: role persistence, iCloud backup format, export-card layout.

## Signatures

```dart
GoRouter createAppRouter({
  GlobalKey<NavigatorState>? rootNavigatorKey,
  String initialLocation = '/archive',
});
```

Each `MyApp` instance owns one `GoRouter` created in `State`. Do not use a process-wide singleton; widget tests pump `MyApp` repeatedly.

## Contracts

| Location | Page | Tab bar |
|----------|------|---------|
| `/archive` | `ArchivePage` | yes (label **档案**, left-aligned AppBar tags **OC** / **世界观**, no title) |
| `/mine` | `MinePage` | yes (AppBar **我的**, empty body) |
| `/roles/new` | `RoleCreatePage()` | no (`parentNavigatorKey` = root) |
| `/roles/:id` | `RoleCreatePage(role: extra as Role)` | no |
| `/backup` | `BackupRestorePage()` | no |

- `ArchivePage` uses `DefaultTabController` and `TabBarView`, initially showing **OC** (`RoleListPage`). **世界观** (`WorldViewPage`) currently shows an empty state. The role FAB belongs only to the OC page; backup remains in the shared archive AppBar.
- Inner tabs are compact outlined text tags on the left of the AppBar, with a subtle accent tint for selection. There is no archive title, lower tab strip, shared track, shadow, or tag icon. The cloud action stays on the right. Keep stock `TabBar` semantics and swipe synchronization.
- `RoleListPage` keeps its state alive across inner tab switches, including its scroll position.
- Tabs use `StatefulShellRoute.indexedStack`. Switching 档案 / 我的 must not recreate the role list.
- The tab bar has a 1px top `Divider` (`tokens.border`) so the shell edge stays visible on paper. Do not use cool gray.
- Create / edit / backup are **root** routes so they cover the shell. Pushing them on a branch navigator would leave the tab bar visible.
- Edit always passes the list's `Role` as `extra`. Missing / wrong extra redirects to `/archive`. Do not add a `getById` loading editor unless a later task asks for deep links.
- Export, cover preview, and description history stay `Navigator.push` from the already full-screen editor.
- System back on 我的 returns to 档案 (`PopScope` + `goBranch(0)`). On 档案 at root, back may leave the app.

```dart
context.push('/backup');
context.push('/roles/new');
context.push('/roles/${role.id}', extra: role);
```

## Validation

| Check | Pass | Fail |
|-------|------|------|
| Launch | AppBar left tags OC / 世界观 + right cloud action + bottom tabs 档案 / 我的; OC selected | Missing inner tabs, or no bottom tab bar |
| Create/edit/backup | `NavigationBar` absent | Tab bar still on the form |
| 我的 | No FAB, no backup, no feature buttons | Settings/backup moved here without a task |
| Extra | Edit opens with the passed `Role` | Editor waits on `getById` |

## Wrong vs Correct

#### Wrong

```dart
// Branch push keeps the tab bar under RoleCreatePage
context.push('/roles/new'); // if /roles/new is nested under the 档案 branch
```

#### Correct

Root-level `/roles/new` and `/roles/:id` with `parentNavigatorKey: rootKey`.
