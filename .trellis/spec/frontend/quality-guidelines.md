# Quality Guidelines (UI Layer)

> Lint, testing and review expectations for pages and widgets.

---

## Overview

Before a UI change is committed:

```bash
flutter analyze        # must report "No issues found!"
flutter test           # full suite; page tests live in test/pages, widgets in test/widgets
dart format .          # standard formatter, trailing commas as emitted
```

Lint is `package:flutter_lints/flutter.yaml` (6.0.0) plus the `riverpod_lint`
plugin declared in `analysis_options.yaml`, with no rule overrides and no
suppressions in hand-written code. There is no CI or pre-commit hook; the
developer runs the commands locally. Commit messages follow
[Git Commit](./git-commit.md).

Design and copy rules are in `component-guidelines.md` and `theming.md`; this
file lists what a reviewer checks.

---

## Forbidden Patterns

- **Hex colours or Material palette colours (`Colors.red`, `Colors.grey`)
  in pages/widgets.** Read `ZaidangTokens.of(context)` or
  `Theme.of(context)`. `Colors.transparent` for status bars / surface tints
  and `Colors.white` for an icon composited over user images are the accepted
  exceptions; the only allowed hex outside `lib/theme/` is the role-card
  export renderer.
- **`ColorScheme.fromSeed`, Material 3 tonal defaults, or stock `AlertDialog`
  for confirmations.** Use `showZaidangConfirmDialog`; the two remaining
  `AlertDialog`s (asset rename, revision viewer) are legacy, not a licence.
- **Explanatory paragraphs, repeated status text, `...` instead of `…`,
  English UI copy, italic headers.** See "Visible copy" in
  `component-guidelines.md`.
- **Actions without a busy guard.** Every async button needs both a disabled
  state and an early `return` on the flag (`state-management.md`).
- **`Navigator`/`setState`/snack bar after `await` without `mounted`.**
- **Drag-dismissible sheets that also use `PopScope` to block closing.**
- **Importing `lib/data/database/` or a `Drift*Repository` in UI.**
- **Text-only finders for interactive controls in tests** when the widget
  can carry a `Key`. Use `Key('feature-action')`; text finders are fine for
  asserting copy.
- **Golden tests and `debugDisableShadows`.** Not used; verify colours and
  contrast numerically (`zaidang_tokens_test.dart`,
  `cover_preview_page_test.dart`) instead of pixel snapshots.
- **`Tooltip` as the accessible name.** Set `semanticsLabel` on the visible
  text and `excludeFromSemantics: true` on the tooltip.

---

## Required Patterns

- Colours from tokens; text sizes may be literal (`TextStyle(fontSize: 17)`)
  but weights and colours come from tokens/`textTheme`.
- Every interactive control that a test or screen reader needs has a stable
  `Key('<feature>-<action>')` and a `tooltip` or `semanticsLabel` when the
  visible label is an icon or abbreviation.
- Modals return a typed result (`bool` for "did it write",
  `RoleCardSelection?` for a pick); callers treat `null` as cancel and only
  show success feedback on `true`.
- Feedback via `showZaidangSnackBar(context, message, tone:)`; destructive
  confirmations via `showZaidangConfirmDialog` with `consequence` copy in
  `「」` quotes.
- Inline validation hints use `Text(key: Key('<feature>-hint'))` inside a
  `Semantics(liveRegion: true)`; hint priority is documented in the feature
  spec (`role-relationships.md`).
- Tabs hosted in `RoleCreatePage` implement `AutomaticKeepAliveClientMixin`,
  a `PageStorageKey`, `SliverOverlapInjector`, and the
  `enabled`/`isEnabled`/`onBusyChanged` trio.
- Dataset-relative images render through `CoverFileView`, never a raw
  `Image.file` on a stored path.
- Each new page/widget gets a feature spec under `.trellis/spec/frontend/`
  when it introduces a contract other code depends on (keys, return values,
  busy semantics).

---

## Testing Requirements

Harness (see `test/pages/role_relationships_tab_test.dart`,
`test/pages/role_assets_tab_test.dart`, `test/widget_test.dart`):

```dart
await tester.pumpWidget(
  ProviderScope(
    overrides: [
      roleRepositoryProvider.overrideWithValue(fakeRoles),
      roleRelationshipRepositoryProvider.overrideWithValue(fakeRelationships),
    ],
    child: MaterialApp(theme: zaidangLightTheme(), home: RoleCreatePage(role: role)),
  ),
);
```

- Set `tester.view.physicalSize` / `devicePixelRatio = 1` for layout-sensitive
  pages and reset with `addTearDown(tester.view.resetPhysicalSize)` and
  `addTearDown(tester.view.resetDevicePixelRatio)`.
- Inject fakes from `test/fakes/` through provider overrides or constructor
  parameters (`RoleCreatePage(picker:, supportDirectory:)`); never touch the
  real database in a widget test.
- Use `tester.runAsync` when the widget reads real files (cover images,
  export PNGs, storage bootstrap).
- Assert behaviour, not structure: visible copy, `Key` presence,
  `onPressed == null` for disabled buttons, `WidgetStateProperty.resolve({WidgetState.disabled})`
  for styled disabled states, fake call counters (`createCalls`, `renameCalls`)
  to prove no write happened.
- Cover the busy contract for any new async action: hold the fake with a
  `Completer` (`pendingSave`, `pendingImport`), then assert the page save is
  disabled, back is blocked (`PopScope`), and barrier taps do not close the
  modal; then complete and assert feedback.
- Cover semantics where a control has a custom label
  (`tester.getSemantics`, `find.bySemanticsLabel`).
- Descriptions may be English or Chinese; recent UI tests are Chinese
  sentences (`'空态、添加关系并按视角显示文案'`), older ones English with
  Chinese product nouns. Match the file you are editing.
- One test file per page/widget mirroring the `lib/` path; `group()` is rare.

---

## Code Review Checklist

- [ ] `flutter analyze` clean, `flutter test` green, formatter run.
- [ ] No hex/`Colors.*` outside `lib/theme/` and the export renderer.
- [ ] Copy is Chinese, uses `…` and `「」`, and explains only decisions and
      consequences.
- [ ] Every async action: disabled state + early return + `mounted` after
      `await` + `finally` that clears busy.
- [ ] Modals: typed result, `PopScope` when a write may be in flight,
      `enableDrag: false` if `PopScope` is used, `_resolved` double-pop guard.
- [ ] Stable `Key`s on new controls; semantics for icon/abbreviated buttons;
      live-region hints.
- [ ] Providers consumed with `watch` in `build` and `read` in callbacks;
      new streams gated and invalidated per `hook-guidelines.md`.
- [ ] Widget test added/updated with fakes, covering success, validation
      hint, busy gating and cancel-without-write.
- [ ] Feature spec in `.trellis/spec/frontend/` updated; index status
      adjusted.
- [ ] Commit split by module (`应用:` / `测试:` / `Trellis:`), Chinese one-liner.

---

## Git Commits

提交文案与拆分规则见 [Git Commit](./git-commit.md)：中文、`模块: 功能声明`、一模块一功能一次提交。
