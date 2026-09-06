# Implement: 首页底栏与 go_router

## Checklist

1. Add and exact-pin `go_router` in `pubspec.yaml` / `pubspec.lock`.
2. Add `lib/app_router.dart` with `createAppRouter()`, root navigator key, `StatefulShellRoute.indexedStack`, and root-level `/roles/new`, `/roles/:id`, `/backup`.
3. Add `lib/pages/home_shell.dart` (NavigationBar + `goBranch` + 我的 back-to-档案 `PopScope`).
4. Add `lib/pages/mine_page.dart` (AppBar 「我的」, empty body).
5. Switch `lib/app.dart` to a Stateful `MaterialApp.router` that owns one `GoRouter` per instance.
6. Point `RoleListPage` backup / create / edit at `context.push`. Keep AppBar 「角色」.
7. Add `NavigationBarThemeData` in `lib/theme/zaidang_theme.dart` (paper canvas, accent selected icon/label, transparent indicator).
8. Extend `test/widget_test.dart` (or add `test/pages/home_shell_test.dart`) for: both tabs, AppBar 「角色」 vs tab 「档案」, 我的 blank, tab bar hidden on create/edit/backup, FAB above tab bar, system back from 我的 to 档案, list still visible after 我的 round trip.
9. Run existing `test/widget_test.dart` create/edit/history cases plus `flutter analyze`.
10. `dart format` on touched Dart files.

## Validation

```bash
flutter pub get
dart format lib/app.dart lib/app_router.dart lib/pages/home_shell.dart lib/pages/mine_page.dart lib/pages/role_list_page.dart lib/theme/zaidang_theme.dart test/widget_test.dart
flutter analyze
flutter test test/widget_test.dart
```

If a dedicated shell test file is added, include it in `flutter test`. Do not run the whole suite in parallel with an Apple build (native-assets lock). After the shell tests pass, run `flutter test` once more as the full-scope check.

Visual check (simulator or widget test geometry): phone frame, light and dark; FAB not covered by the tab bar; create page has no tab bar.

## Risky files

- `lib/app.dart` — every test that pumps `MyApp`.
- `lib/pages/role_list_page.dart` — wrong navigator (branch vs root) would leave the tab bar on create/edit.
- `lib/theme/zaidang_theme.dart` — accent area rule.

## Rollback

`git checkout` the files in the checklist. `flutter pub get` after restoring `pubspec.yaml` / lock. No database step.

## Before `task.py start`

- PRD, design, and this file match the locked copy: AppBar 「角色」, tab 「档案」, 我的 blank, go_router shell + three root routes.
- Curate `implement.jsonl` / `check.jsonl` (theming spec, this design, role-list/app files). Seed `_example` rows do not count.
