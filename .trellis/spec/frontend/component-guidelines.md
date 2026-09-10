# Component Guidelines

> How components are built in this project.

---

## Overview

<!--
Document your project's component conventions here.

Questions to answer:
- What component patterns do you use?
- How are props defined?
- How do you handle composition?
- What accessibility standards apply?
-->

(To be filled by the team)

---

## Component Structure

<!-- Standard structure of a component file -->

(To be filled by the team)

---

## Props Conventions

<!-- How props should be defined and typed -->

(To be filled by the team)

---

## Styling Patterns

### Visible copy

Prefer self-explanatory controls and meaningful data over explanatory text. Do
not add introductory paragraphs, repeated process/status descriptions or
implementation details to normal app states. Explain only when the user needs
to decide or act: destructive consequences, actionable errors and required
recovery steps. This applies to new UI and future refinements; it is not a
request to rewrite unrelated screens.


Colors come from [Theming](./theming.md) (崽档笔记《主题色与设计 Token》: 纸白 + 墨色 + 火漆红). Widgets read `Theme.of(context)` or `ZaidangTokens`; they do not hardcode hex.

Controls over user images must retain at least 3:1 icon contrast over both white
and black image regions. A translucent white fill does not protect a white icon
over white art. `CoverPreviewPage` uses `ZaidangTokens.dark.bg` at 80% opacity
behind its white close icon. Test the rendered control colors after alpha
compositing with both image extremes in light and dark themes; see
`test/pages/cover_preview_page_test.dart`.

---

## Accessibility

<!-- A11y requirements and patterns -->

For abbreviated button copy, set the accessible name independently of the
visible text while retaining the stock button's role, enabled state and tap
action. A `Tooltip` is not the button's semantic label:

```dart
Tooltip(
  message: '更换立绘',
  excludeFromSemantics: true,
  child: TextButton(
    onPressed: onPick,
    child: const Text('更换', semanticsLabel: '更换立绘'),
  ),
)
```

Verify the actual button semantics (`label`, `isButton`, `isEnabled`, and tap
action), not only `find.byTooltip`.

---

## Common Mistakes

<!-- Component-related mistakes your team has made -->

### Opening a preview while a form save is pending

`Navigator.pop()` pops the current top route, even when invoked with the context
of a form below it. Opening a preview while `RoleCreatePage._submit()` awaits the
repository makes save completion dismiss the preview and leave the saved form
open. On a new role this allows a second insertion.

While `_saving` is true, pass `null` for the preview callback so the control is
disabled, and also guard `_openCoverPreview()` itself. The guard handles a stale
callback invoked before the next widget rebuild. Preserve the disabled state in
the portrait's semantics.

Regression tests must delay both create and update completion, try opening the
preview before and after the disabled-state rebuild, then complete the save.
Assert that no preview was pushed, the form returned to the preceding route,
and exactly one role remains with the expected saved fields. See
`test/pages/role_create_page_cover_test.dart`.

## Local Image Gallery Contract

### Scope / Trigger

Apply when opening or modifying `CoverPreviewPage`. The user-approved gallery
uses `photo_view` for image gestures; role storage and image picking remain
single-cover operations.

### Signature

```dart
CoverPreviewPage(
  coverImages: ['covers/first.png', '/absolute/second.png'],
  initialIndex: 1,
  supportDirectory: optionalDirectoryLookup,
)
```

`coverImages` is `List<String>`, `initialIndex` is `int` (default zero), and
`supportDirectory` is an optional `Future<Directory> Function()`. The route
copies the list on entry; later input-list mutations do not change the session.
The role editor passes `coverImages: [_coverImg]`.

### Contracts

- `PhotoViewGallery.builder` owns horizontal paging and per-image gestures.
  Initial/minimum scale is `PhotoViewComputedScale.contained`; maximum is five
  times that scale. Do not add competing horizontal-drag or scale handlers.
- Single tap uses the library's `onTapUp` callback. Double tap zooms, and pinch
  and drag must never dismiss the route. Close/system back return only one level.
- Multi-image sessions show a one-based page count; single-image sessions omit
  it. The page-count overlay ignores pointer input.
- Resolve relative paths once using application support and `CoverPath.resolve`.
  Absolute paths do not require a support-directory lookup. Dispose the owned
  `PageController` when the route exits.

### Validation & Error Matrix

| Input / event | Expected behavior |
|---|---|
| Empty list | Show `暂无图片`; tap or close can exit |
| Index outside bounds | Clamp to the nearest valid index |
| Empty, missing or corrupt image | Show `图片无法加载`; allow paging and exit |
| Support lookup fails | Relative entries fail; absolute entries still work |
| Repeated exit callback | Do not pop the caller's route |

### Good / Base / Bad Cases

Good: multiple local paths plus a selected index; gestures handled by the gallery.
Base: the existing editor opens a one-element list with the same save guard.
Bad: adding an outer scale/drag recognizer or persisting gallery state into the
role's single `coverImg` field.

### Tests Required

`test/pages/cover_preview_page_test.dart` loads real portrait, landscape and
square fixtures before simulating gestures. Assert transformed image bounds,
page changes, single/double-tap separation, pinch and pan, all exit paths,
index bounds, empty/failed content, and close-icon contrast in both themes.
Precache successful `FileImage`s in `tester.runAsync` before route creation;
failed images must also be loaded in a real asynchronous scope. Allow the
double-tap recognition window and route animation to finish before asserting
single-tap dismissal.

### Wrong vs Correct

Wrong: `GestureDetector(onPanUpdate: ..., child: PhotoViewGallery(...))`.
Correct: configure `PhotoViewGalleryPageOptions` with `FileImage`, scale limits
and `onTapUp`, leaving its existing gesture recognizers in charge.

## Shared Archive Editor Widgets

The create/edit chrome (immersive blurred cover with calling card, pinned
identity, glass back/save buttons, paper `ArchiveCard`, `SectionLabel`,
`FieldRow`, `KeepAliveDetails`, content-width padding) lives in
`lib/widgets/archive_editor/`. Both `RoleCreatePage` and `WorldCreatePage`
compose these widgets; do not copy private variants back into a page. Pages pass
their own test keys (`heroKey`, `portraitKey`, `boxKey`) and copy nouns
(`coverNoun`, `emptyName`) so finders remain page-specific. See
[Worlds UI](./worlds.md).

## Editable Custom-Attribute Slivers

`RoleCreatePage` puts `SliverReorderableList` in the existing page scroll, with
`DecoratedSliver` using the same paper-card decoration as fixed fields. Do not
introduce a separately scrolling list inside the form. `WorldCreatePage` applies
the same pattern to 词条.

Each draft owns its name/content controllers, a `FocusNode` and a `UniqueKey`.
Keep that identity through rename, move and drag operations. The current Flutter
reorderable sliver wraps child keys in `GlobalObjectKey`; unwrap `.value` in
`findChildIndexCallback` before locating the draft. Comparing the wrapper directly
with the draft key always misses the entry.

Lazy rows can be unmounted when the user saves. Validate the entire controller
list and the fixed role-name controller, in addition to `FormState.validate()`.
Surface a visible error for an invalid offscreen name. Store immutable values
only after validation and disable both controls and stale mutation callbacks
while saving. Cancel an active reorder before submitting or structurally
changing the list.

After deletion, remove the row first and dispose its controllers after the
frame unmounts the old text fields. Returning from description history only
changes the description controller; custom-attribute drafts remain untouched.

For abbreviated icon actions, verify the resulting semantics label and tap
action on the actual `IconButton`. Explicit `Icon.semanticLabel` is used here;
finding a tooltip alone does not prove the button is accessible.

Regression tests must cover edit→reorder→save pairing, offscreen validation,
repeated inline addition with a keyboard, failed-save drafts, stale callbacks,
history return, and actual drag gestures in both themes. See
`test/pages/role_create_page_custom_attributes_test.dart` and
`test/pages/role_custom_attributes_keyboard_test.dart`. The persistence boundary
is documented in [Role Custom Attributes](../backend/role-custom-attributes.md).

## Reusable Confirmation Dialogs

Character-card export has a separate renderer/preview/lifetime contract in
[Role-card Export](./role-card-export.md). Do not render export images by
capturing the editor or repurpose this confirmation dialog as an export view.

Use `lib/widgets/zaidang_confirm_dialog.dart` for secondary confirmation. The
user-approved OC direction is **创作便笺**: soft corners, a small tilted notebook
mark and conversational copy. Avoid category mastheads, separate labeled target
sections and internal rules; they made the first proposal too formal.

The public `ZaidangConfirmDialog` Widget can be built directly inside a standard
`showDialog<bool>`. Prefer `showZaidangConfirmDialog` at page call sites:

```dart
final confirmed = await showZaidangConfirmDialog(
  context: context,
  title: '要删掉这条属性吗？',
  body: '「$name」和里面的内容会一起移除。',
  consequence: '保存角色后生效。',
  cancelLabel: '先留着',
  cancelSemanticLabel: '先留着，保留这条属性',
  confirmLabel: '删除属性',
);
if (!confirmed || !context.mounted) return;
// The caller owns the actual draft or persisted change.
```

### Contract

- Required inputs: `title`, `body`, `consequence`, `confirmLabel`. Optional:
  `cancelLabel` (default `取消`), `cancelSemanticLabel`, `showSparkle` (default
  true). The Widget also accepts a normal `key`; the helper takes `context` and
  returns `Future<bool>`.
- The Widget pops true only for the explicit action and false for cancel. The
  helper maps null from back/Escape/barrier dismissal to false. Cancel takes
  initial focus; route focus traversal is closed-loop. Repeated action callbacks
  during exit must not pop the caller's page.
- Dangerous actions use `ink` fill with `surface` text in both themes. The
  cancellation uses `bg`, `border` and `ink`. Essential body/consequence text
  also uses `ink`: light `inkSecondary` on `surface` is only about 3.8:1.
- Use 26 outer radius, 15 button radius and at least 48 logical pixel action
  height. Measure action labels with the effective text scaler before choosing
  a row or a vertical stack. Keep the standard cancel-then-confirm traversal
  order in both arrangements.
- Normally only the content scrolls and the buttons stay visible. Exceptionally
  short windows or huge action labels allow whole-sheet scrolling so every
  element remains reachable. Leave space inside the scroll viewport for the
  rotated mark/sparkle; outer padding alone does not prevent clipping.
- `showSparkle: false` is used for full-device overwrite. The accent sparkle is
  decorative brand detail, never a red danger cue. The notebook decoration is
  excluded from semantics. Button accessible names must include their visible
  wording and preserve the stock button role/action.
- The helper honors reduced motion. Keep async work, progress, errors and
  mounted/busy/stale-callback guards in the caller; never move repositories or
  cloud services into the shared Widget.

### Existing scenarios

| Scenario | Persistence boundary | Required copy |
|---|---|---|
| Custom attribute deletion | Remove draft, persist on role save | 保存角色后生效 |
| Description history restore | Immediately write saved description and replace editor description draft | Unsaved description changes will be lost; existing history stays |
| iCloud restore | Confirm after inspection, then prepare/commit full snapshot and covers | All local role data/history/art is replaced; no user undo |

The history-content viewer remains a selectable/scrollable `AlertDialog` with
its own read/close/restore controls. It only inherits compatible theme defaults.

### Validation

`test/widgets/zaidang_confirm_dialog_test.dart` covers direct Widget reuse,
helper confirmation/dismissal, focus safety, semantics, contrast and large-text
layouts. Page integration tests keep actual draft/persistence assertions in
`role_create_page_custom_attributes_test.dart` and verify the cloud confirmation
boundary/inspection cleanup with a service fake in `backup_restore_page_test.dart`.
Use stable action keys instead of binding tests to the old `TextButton` type or
generic “删除”/“恢复” labels.

## Floating Feedback

Use `showZaidangSnackBar(context, message, tone: ...)` from
`lib/widgets/zaidang_snack_bar.dart`. `ZaidangSnackBarTone` provides `info`,
`success` and `error`. The separate `ZaidangSnackBarContent` Widget is reusable
presentation; the helper owns queue, width and timing policy.

- Keep the native `SnackBar`/`ScaffoldMessenger` for live-region announcements,
  close control and lifecycle. Do not add a toast dependency or an unmanaged
  Overlay/timer implementation for ordinary feedback.
- The global theme uses a floating surface, ink text, thin token border,
  16-radius corners and restrained elevation. On desktop the helper caps width
  at 480; mobile uses native safe-area handling and 16-unit theme insets. Never
  provide both `width` and `margin` to a SnackBar.
- A success message has a small accent-colored check on a 10% tint; info and
  errors use ink icons. Essential copy stays ink, without a second title or
  a broad red/green background. Error/success comes from the actual operation,
  not from parsing its message string. Share cancellation/unknown completion
  remains silent.
- Clear stale queued messages before showing the latest one. Short messages
  normally last 4 seconds, errors 5; a caller can supply `duration`.
- In Flutter 3.47, a close icon alone does not prevent timeout. Set `persist`
  when `accessibleNavigation` is enabled or the scaled message needs scrolling.
  The helper measures with the same text style/scaler and a conservative text
  width; do not estimate fit by ASCII character count.
- The full Text remains in the widget/semantics tree. Very long content scrolls
  within a bounded height; never silently apply `maxLines`/ellipsis to the
  notification. Persistent notices can be closed with the native close control.
- Keep the original caller's mounted guards and business/error flow. A visual
  feedback wrapper must not change save/restore timing or imply success before
  the operation completes.

`test/widgets/zaidang_snack_bar_test.dart` covers light/dark surface readability,
close behavior, latest-message replacement, long text and accessible reading
without timeout, and desktop width. Existing save/export/backup tests retain
their data/result assertions.

For visual QA, Flutter widget tests set `debugDisableShadows=true`, which draws
physical elevation as an opaque outline. Temporarily use false when capturing
runtime-like shadow appearance, then restore the binding's previous value;
do not “fix” the production border based on that test-only outline.


## Dataset-dependent media

Default cover/gallery/role-card file reads resolve `getActiveDataDirectory()`.
Never retain a static Application Support data root across a restore epoch.
Explicit supportDirectory injection remains available for isolated tests.
Managed original files used by galleries, native previews and renderer decoding
are pinned until their asynchronous use ends. See [Backup UI](./backup-restore.md).
