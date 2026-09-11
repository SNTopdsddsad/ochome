# State Management

> Which state lives in widgets, which lives in Riverpod, and how busy/save
> gating works across the role detail page.

---

## Overview

崽档 splits state along one line:

- **Riverpod** (`lib/data/providers/`) owns anything derived from the
  database or a service: role lists, per-role streams, repositories, the
  backup coordinator, the dataset-switch flag.
- **Widget state** (`ConsumerStatefulWidget` / `StatefulWidget` fields) owns
  everything that dies with the screen: text controllers, focus, tab and
  scroll controllers, unsaved form drafts, `_saving`/`_busy` flags, dialog
  resolution guards.

There is no global UI store, no `ChangeNotifier` view models, and no state
persisted outside SQLite except scroll positions via `PageStorageKey`.
Provider conventions are in `hook-guidelines.md`; this file covers the widget
side and the boundaries.

---

## State Categories

| Category | Where | Reference |
|----------|-------|-----------|
| Persisted domain data | Drift via repository providers | `rolesProvider`, `roleRelationshipsProvider(roleId)` |
| Dataset lifecycle | `databaseSwitchProvider`, `backupCoordinatorProvider` | `lib/data/providers/` |
| Form draft (unsaved role) | `TextEditingController`s + `_attributes` list on `RoleCreatePage` | `lib/pages/role_create_page.dart` |
| In-flight action | `bool _saving`, `_busy`, `_importing`, `_actionBusy` | create page, tabs, export page, backup home |
| Cross-widget busy | `_assetBusy`, `_relationshipBusy` → `_tabBusy` on the parent; children call `onBusyChanged` | `role_create_page.dart`, `role_assets_tab.dart`, `role_relationships_tab.dart` |
| Modal result | `Navigator.pop(value)` + `_resolved` guard | `zaidang_confirm_dialog.dart`, `role_asset_rename_dialog.dart`, `role_relationship_editor_sheet.dart` |
| Scroll / tab retention | `AutomaticKeepAliveClientMixin`, `PageStorageKey`, `TabController` | list page, both tabs, `_KeepAliveDetails` |
| Ephemeral filter | `_filter` on `RoleAssetsTab` | `role_assets_tab.dart` |

Widget base class by need: `ConsumerStatefulWidget` when the screen both
watches providers and holds local state (create page, list page, tabs);
`ConsumerWidget` when it only watches (`RoleDescHistoryPage`,
`BackupRestorePage` shell); `StatefulWidget` when it needs no provider at all
(`CoverPreviewPage`, `RoleCardExportPage`, `BackupContentsPage`);
`StatelessWidget` for pure layout (`ArchivePage`, `MinePage`, `HomeShell`).

---

## When to Use Global State

Put state in a provider only when at least one is true:

- It comes from the database or a service (streams, repositories).
- More than one route needs the same instance (backup coordinator, dataset
  switch flag).
- Tests need to swap it (`ProviderScope(overrides: [...])`).

Everything else stays in the widget. Concretely, the relationship editor's
selected counterpart, label text, `_touched`, `_saveError` and `_saving` are
all `State` fields; only the candidate list and the repository come from
providers via the caller.

**Busy gating pattern (the one cross-widget state).** `RoleCreatePage` in edit
mode hosts tabs that can run their own writes. The parent must not save while
a tab is importing, and a tab must not act while the parent is saving:

- Parent → child: `enabled: !_saving` and `isEnabled: () => !_saving` (a
  function so async callbacks re-check after `await`).
- Child → parent: `onBusyChanged(bool)`; the parent stores
  `_assetBusy`/`_relationshipBusy`, and `_tabBusy` ORs them.
- Parent gates: `PopScope(canPop: !_saving && !_tabBusy)`,
  `AbsorbPointer(absorbing: _saving || _tabBusy)`, save button
  `onPressed: _tabBusy ? null : _submit`, early `return` at the top of
  `_submit` / `_openRoleCardExport` / cover preview.
- Child gates: `_canAct` before any action, `_setBusy(true)` in a
  `try/finally`, and modals receive `canSave: () => mounted && _enabled`.
  When the page has stopped editing mid-save, the editor's `onSave` throws
  `StateError('页面已停止编辑，请重新打开再试')` rather than silently
  succeeding.

---

## Server State

There is no server; the analogue is Drift stream state, rendered as
`AsyncValue`. Conventions:

- `ref.watch` in `build`; `ref.read` in callbacks.
- Render `.when(...)` for whole-page states, or `switch (x.asData)` /
  `asData?.value` when part of the UI should stay put while data loads
  (the relationships header shows `''` while loading, not a spinner).
- Never copy stream data into `setState` fields for editing unless the screen
  is a draft editor (the create page copies the `Role` into controllers once
  in `initState` and treats the DB as the source only on save).
- After a write, rely on the stream; do not `invalidate`/`refresh` for
  freshness. `ref.invalidate` is for explicit retry buttons and for the
  dataset-switch sequence in `backup_coordinator_provider.dart`.
- Backup job progress is a `Stream<BackupJob>` from the coordinator; the home
  page subscribes in `initState`, tracks a generation counter to ignore stale
  events, and cancels in `dispose`.

**After every `await`, check `mounted`** (or `context.mounted` in
`ConsumerWidget` callbacks) before `setState`, `Navigator`, snack bars, or
reading `widget.*`. The create page also re-checks business preconditions
after dialogs: `if (remove != true || !mounted || _saving || !_attributes.contains(draft)) return;`.

---

## Common Mistakes

- Starting a second action while one is in flight because a button was not
  disabled and the method lacks an early `return`. Both are required; tests
  such as `test/pages/role_relationships_tab_test.dart` hold a write with
  `pendingSave` and assert the page's save is disabled and back is blocked.
- Letting a modal pop twice (button + barrier, or button + `PopScope`). Use
  the `_resolved` flag and `ModalRoute.of(context)?.isCurrent` check from
  `ZaidangConfirmDialog._resolve`.
- Enabling drag-to-dismiss on a sheet that has `PopScope(canPop: !_saving)`.
  Drag bypasses `PopScope`; the relationship sheet sets `enableDrag: false`
  and keeps `isDismissible: true` because barrier taps go through `maybePop`.
- Passing `enabled` as a plain bool into an async child flow and never
  re-reading it. Pass `isEnabled: () => ...` and call it after each `await`.
- Forgetting `onBusyChanged(false)` in a `finally`; the parent stays locked
  and back navigation is blocked forever.
- Keeping form drafts in a provider. Drafts are per-screen and must be
  discarded on pop; controllers on the `State` do that for free.
- `setState` after `dispose` from a late stream event. Track the subscription
  and cancel it in `dispose`, and guard with `mounted`.
