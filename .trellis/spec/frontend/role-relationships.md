# Role Relationships Tab

## Scope

`RoleCreatePage` shows a third **关系** tab for saved roles only. It follows the
[Role Detail and Assets](./role-assets.md) scroll contract exactly: a
`CustomScrollView` with `SliverOverlapInjector`, its own `PageStorageKey`
(`role-relationships-scroll`), `AutomaticKeepAliveClientMixin`, and the shared
primary controller. Widgets: `lib/pages/role_relationships_tab.dart`,
`lib/widgets/role_relationship_editor_sheet.dart`.

## Interaction contract

- Header: `N 条关系` plus `添加关系` (`Key('role-relationship-add')`). With no
  other saved OC, tapping add shows a snackbar (`还没有其他 OC…`) instead of an
  empty picker.
- List rows show the counterpart's name and portrait (`CoverFileView`, initial
  letter placeholder) and one subtitle built from the perspective helpers:
  `我是 TA 的{selfLabel} · TA 是我的{otherLabel}`. Never phrase a row from the
  stored `from`/`to` orientation; the same row appears on both roles' pages.
- Row tap opens the editor prefilled; `more_horiz` opens 修改 / 删除. Deletion
  uses `showZaidangConfirmDialog` and states that both OCs keep their data.
- Editor (`showRoleRelationshipEditor` → `RoleRelationshipEditorSheet`): a
  modal bottom sheet (`surface`, 26 top radius, `border` hairline, max width
  560) styled as a 关系便条. It is **not** an `AlertDialog` and must not
  regress to a dropdown + labeled text fields. Tapping the barrier closes it
  (discarding input, no write); the barrier goes through `maybePop`, so the
  sheet's `PopScope(canPop: !_saving)` still blocks it while saving. Keep
  `enableDrag: false`: the sheet's drag-to-close pops directly and would bypass
  that guard.
  - **对方**: horizontal strip of 56×74 portrait cards (12 radius, 64-wide
    column, 100-tall strip)
    (`Key('role-relationship-candidate-<id>')`, `CoverFileView` with initial
    placeholder) excluding the current role. Selected card: `accent` border and
    `ink` name; unselected: `border` + `inkSecondary`. Border width is constant
    (1.5) in every state so selection never shifts layout. Preselect when there
    is exactly one candidate or when editing.
  - **关系**: two fill-in-the-blank sentences
    (`Key('role-relationship-sentence-self'|'other')`):
    `{我} 是 {对方} 的 ____` and `{对方} 是 {我} 的 ____`. Names, particles and
    the blank share one 17px ink style so each row reads as a sentence; an
    unselected counterpart renders as `对方` in `inkSecondary`. Blanks are
    `TextField`s with only an `UnderlineInputBorder` (1.5 constant width;
    `border` at rest, `accent` focused, `ink` when invalid), max 30 chars, no
    counter, hints `师父` / `徒弟`.
  - `交换` (`Key('role-relationship-swap')`) swaps the two labels.
  - One shared hint line (`Key('role-relationship-hint')`, live region, `ink`)
    replaces per-field error text. Priority: repository error → length cap
    (`称呼最多 30 个字`, shown whenever a blank reaches
    `relationshipLabelMaxLength`, because `maxLength` enforces silently) →
    touched-mode validation (`先选一位对方 OC`, `两句话都要补完，才能记下这段关系`),
    which only appears after the first submit. Typing clears a repository error.
  - Primary action is a full-width 48px accent `FilledButton`
    (`记下这段关系` / `保存修改`; `保存中…` with an inline 16px indicator while
    saving). It is disabled only while saving and keeps the full `accent` fill
    then — a dimmed accent drops `onAccent` text to ~2.4:1. Close is the header
    `IconButton` (`Key('role-relationship-cancel')`, tooltip `关闭`). An
    unchanged submission closes without writing. Selecting a card does not
    steal focus into a blank.
- Save always writes from the current role's perspective
  (`from = self`, `to = counterpart`), including on update. The tab's `onSave`
  throws `StateError` when the tab is unmounted or disabled instead of
  returning silently, so the sheet never reports a write that did not happen.
  Repository errors stay inside the sheet on the hint line
  (`FormatException`/`StateError` message, otherwise
  `没能保存这段关系，请再试一次`); the sheet is not dismissed on failure and
  cannot be popped while saving.
- Delete uses the repository's `bool` result: `关系已删除` when a row was
  removed, `这条关系已经不存在了` when it was already gone. Failures show a fixed
  error snackbar (`没能删除这条关系，请再试一次`) and log the exception; raw
  exception text is never shown. The header count is blank while loading
  rather than `0 条关系`.
- Busy propagation: the tab reports busy via `onBusyChanged` while a sheet or
  write is in flight. `RoleCreatePage` combines asset and relationship busy
  flags into `_tabBusy`, which disables Save, blocks pop and absorbs pointer
  events on the form. Do not add a third independent flag; extend `_tabBusy`.
- Counterpart data comes from `rolesProvider` (all roles); relationships never
  cache names. A counterpart missing from the list renders as `已删除的 OC`.

## Test keys

`role-relationship-add`, `role-relationship-editor`,
`role-relationship-candidate-<roleId>`, `role-relationship-sentence-self`,
`role-relationship-sentence-other`, `role-relationship-self-label`,
`role-relationship-other-label`, `role-relationship-swap`,
`role-relationship-hint`, `role-relationship-save`, `role-relationship-cancel`,
`ValueKey('role-relationship-<id>')`, tooltip `更多操作：<counterpart name>`.

## Validation

`test/pages/role_relationships_tab_test.dart` with
`test/fakes/fake_role_relationship_repository.dart`. Any test that opens
`RoleCreatePage` for a saved role must override
`roleRelationshipRepositoryProvider`, or the lazily-built tab will try to open
the real database.
