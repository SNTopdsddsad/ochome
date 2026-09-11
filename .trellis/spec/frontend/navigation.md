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
| `/archive` | `ArchivePage` | yes (label **档案**; no AppBar — header `我的 OC` / `我的世界观`, search field, segmented **OC** / **世界观** control, cloud button) |
| `/mine` | `MinePage` | yes (AppBar **我的**, empty body) |
| `/roles/new` | `RoleCreatePage()` | no (`parentNavigatorKey` = root) |
| `/roles/:id` | `RoleCreatePage(role: extra as Role)` | no |
| `/worlds/new` | `WorldCreatePage()` | no (`parentNavigatorKey` = root) |
| `/worlds/:id` | `WorldCreatePage(world: extra as World)` | no |
| `/backup` | `BackupRestorePage()` | no |

- `ArchivePage` is a `StatefulWidget` that owns one `TabController` (length 2) and a `TextEditingController` for the search field. It has **no AppBar**: the header holds the `hero` title (`我的` in ink + ` OC` / `世界观` in accent, wrapped in `Flexible`, followed by a small accent `Icons.auto_awesome`), the `caption` line `记录、设定与灵感`, the search `TextField` (`Key('archive-search')`), and a row with the segmented `TabBar` plus the cloud `IconButton` (`Key('archive-backup')`, tooltip `备份与恢复`). Below it a `TabBarView` shows **OC** (`RoleListPage`) first and **世界观** (`WorldViewPage`) second. Each inner page owns its FAB (`添加角色` / `添加世界观`); backup stays in the shared header.
- The header is two slivers in a `NestedScrollView(floatHeaderSlivers: true)` whose body is the `TabBarView`; the inner `ListView`s inherit the nested primary controller. (1) A **pinned `SliverPersistentHeader`** (`_ArchiveTitleDelegate`) holds the title + subtitle and absorbs the status-bar padding itself — the page has **no `SafeArea`**. Its extents come from `_TitleMetrics` (`TextPainter` line heights of `hero` / `caption` under the current `TextScaler`, never hard-coded px): expanded = `lg + hero + xs + caption + sm`, collapsed = `max(48, hero × heading/hero + 2·sm)`. As `shrinkOffset` grows the single title widget is `Transform.scale`d from 1 to `heading.fontSize / hero.fontSize` (anchored top-left, vertically centred in the 48 px bar), the subtitle fades to 0 by 60 % of the range, and a `BackdropFilter` (blur 12, `bg` at 0.72 alpha, hairline `border` bottom — same recipe as the editor glass buttons) fades in underneath so list content scrolls under a frosted bar instead of through the title. The frost is only in the tree when `t > 0`. (2) A `SliverToBoxAdapter` with the search field and the segments row scrolls away with the list and floats back first on a downward drag. Keep one title `Text` (no large/compact crossfade): `find.text('我的 OC')` must stay `findsOneWidget` in every scroll state. This is what keeps landscape + keyboard (844×390 with a 200 px inset) and large text scales from overflowing — never go back to a fixed `Column` + `Expanded` header, and never let the title scroll off and get chopped at the safe-area line.
- Because there is no AppBar, `ArchivePage` wraps everything in `AnnotatedRegion<SystemUiOverlayStyle>` using `zaidangSystemUiOverlayStyle(context)` (dark icons on light paper, light icons in dark mode). Without it the light icons set by an editor with a cover would persist on the pale home. See [Theming](./theming.md#system-ui-overlay).
- The header re-renders through `ListenableBuilder(listenable: _tabController)`: the accent word and the search hint (`搜索角色名、标签或设定…` / `搜索世界观名、简介或词条…`) follow `TabController.index`.
- The segmented control is a stock `TabBar` inside a `surface` + `border` track (`ZaidangRadius.mdAll`, `ZaidangSpacing.xs` inset, 48 px). The selected tab is an `accent` fill with `onAccent` text; unselected labels are `inkSecondary`; the inner radius is `ZaidangRadius.md - ZaidangSpacing.xs` so the corners stay concentric. Keep stock `TabBar` semantics (`find.widgetWithText(Tab, 'OC')`) and swipe synchronization — do not replace it with a hand-rolled `SegmentedButton`.
- Search is client-side. `ArchivePage` passes the raw field text as `query` to both list pages; normalisation (`trim().toLowerCase()`) happens once inside `ArchiveListView`, so callers never have to pre-process. The clear button (`Key('archive-search-clear')`) appears whenever the field has any text (including whitespace). `TextEditingController.clear()` does not fire `onChanged`, so `_clearSearch` resets state itself. A `NotificationListener<ScrollUpdateNotification>` around the `NestedScrollView` unfocuses the field on any user drag (same rule as `ScrollViewKeyboardDismissBehavior.onDrag`), and `ArchiveListView` sets `onDrag` as well.
- The light theme paints `ArchivePage.backgroundAsset` (`assets/images/role_bg.webp`, ~33 KB WebP q85 of the 941×1672 paper) under a transparent `Scaffold`; dark mode uses plain `tokens.bg` because the pink paper would swallow light ink. Keep bundled art as WebP; the original PNG was 1.27 MB.
- The world editor's **角色** tab pushes `/roles/:id` with the tapped `Role` as `extra`, so a role can be opened from either list. See [Worlds](./worlds.md).
- `RoleListPage` keeps its state alive across inner tab switches, including its scroll position.
- Tabs use `StatefulShellRoute.indexedStack`. Switching 档案 / 我的 must not recreate the role list.
- `HomeShell`'s `Scaffold` sets `resizeToAvoidBottomInset: false`. Keyboard avoidance belongs to each branch page's own `Scaffold` (`ArchivePage`, `MinePage`): if the shell shrinks its body, the archive `DecoratedBox` that paints `role_bg.webp` shrinks with it and `BoxFit.cover` re-scales the paper, which reads as the whole background sliding up when the search field is focused. The shell body — and the paper — must keep its full height while the inner `NestedScrollView` loses the keyboard inset.
- Because the shell no longer resizes, it must also rewrite the `MediaQuery.viewInsets.bottom` it hands to the branches: `max(0, keyboard − (screen height − body height))`. The tab bar is already under the keyboard; passing the raw inset through makes the branch `Scaffold` subtract the bar height a second time, leaving a tab-bar-sized gap between the list/FAB and the keyboard.
- The tab bar has a 1px top `Divider` (`tokens.border`) so the shell edge stays visible on paper. Do not use cool gray.
- Create / edit / backup are **root** routes so they cover the shell. Pushing them on a branch navigator would leave the tab bar visible.
- Edit always passes the list's `Role` / `World` as `extra`. Missing / wrong extra redirects to `/archive`. Do not add a `getById` loading editor unless a later task asks for deep links.
- Export, cover preview, and description history stay `Navigator.push` from the already full-screen editor.
- System back on 我的 returns to 档案 (`PopScope` + `goBranch(0)`). On 档案 at root, back may leave the app.

```dart
context.push('/backup');
context.push('/roles/new');
context.push('/roles/${role.id}', extra: role);
context.push('/worlds/new');
context.push('/worlds/${world.id}', extra: world);
```

## Validation

| Check | Pass | Fail |
|-------|------|------|
| Launch | Header `我的 OC` + search + segmented OC / 世界观 + cloud button + bottom tabs 档案 / 我的; OC selected; no `AppBar` on `/archive` | Missing inner tabs, an `AppBar`, or no bottom tab bar |
| 世界观 tab | Header becomes `我的世界观`; empty state `还没有世界观` + FAB `添加世界观`; OC FAB absent | Placeholder text, or two FABs |
| Search | Typing filters the visible list; no match shows `没有匹配的角色` / `没有匹配的世界观`; clear restores the list; whitespace-only input keeps the list and still shows the clear button | Empty-data copy shown for a no-match query |
| Small viewport | 844×390 with a 200 px keyboard inset renders without `RenderFlex` overflow; dragging the header up reveals the list | Yellow/black overflow stripes, or a list pinned to zero height |
| Header scroll | Dragging the list up scrolls search + segments away while `我的 OC` stays pinned below the status bar, scaled to `20/26`, centred in a `47 + 48` px bar with the subtitle at opacity 0 and one `BackdropFilter` under it; dragging down restores scale 1, title top `47 + 16`, no `BackdropFilter`; dragging while typing dismisses the keyboard | Title chopped at the safe-area line, two title `Text`s during the transition, frost present at rest, segmented control only reachable at scroll offset 0 |
| Status bar | `AnnotatedRegion` under `ArchivePage` has `statusBarIconBrightness == Brightness.dark` in the light theme | Light icons persist after returning from an editor with a cover |
| Keyboard | With a 300 px bottom inset the `ArchivePage` / paper `DecoratedBox` rect is unchanged; `RoleListPage.bottom == viewHeight − 300` and the FAB sits `kFloatingActionButtonMargin` above that edge; an inset shorter than the tab bar leaves the branch untouched | Background image jumps or re-scales when the search field gains focus; list and FAB float a tab-bar height above the keyboard |
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


## Storage recovery routing

Production startup initializes DataStorage before business providers. Recovery-only
mode starts at `/backup` and redirects business routes there until a validated
dataset is activated. Every storage change event returns existing UI to `/backup`
so old editor/preview state cannot continue on a different data root. The backup
coordinator remains app-scoped across route changes; see [Backup UI](./backup-restore.md).
