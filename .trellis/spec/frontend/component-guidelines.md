# Component Guidelines

> How components are built in this project.

---

## Overview

Widgets in 崽档 are plain Flutter classes; there is no component library
beyond Material widgets restyled through `lib/theme/`. The conventions are:

- Screens are `ConsumerStatefulWidget`/`ConsumerWidget` in `lib/pages/`;
  reusable chrome is in `lib/widgets/`; feature-only UI stays in
  `lib/features/<name>/`. See `directory-structure.md`.
- Modals are exposed as `show*` functions that return a typed `Future`
  (`showZaidangConfirmDialog` → `bool`, `showRoleRelationshipEditor` →
  `bool?`), with the widget class kept public for tests.
- Copy is Chinese, terse, and only explains decisions or consequences (see
  "Visible copy" below). Ellipsis is `…`, quotes are `「」`.
- Colour comes from `ZaidangTokens.of(context)`; borders keep a constant
  width across states and change only colour, so layouts never shift.
- Accessibility is part of the definition of done: stable `Key`s, semantic
  labels for abbreviated buttons, `liveRegion` for inline hints, ≥3:1 contrast
  for controls over user images, ≥4.5:1 for text.
- The reference implementations for a new interactive widget are
  `lib/widgets/role_relationship_editor_sheet.dart` (sheet with validation,
  busy state and semantics) and `lib/widgets/zaidang_confirm_dialog.dart`
  (modal with typed result and double-pop guard).

---

## Component Structure

A widget file is laid out top to bottom as:

1. Imports, then an optional file doc comment (`///`) in Chinese describing
   the product behaviour (the relationship sheet carries its Hallmark design
   stamp here).
2. Public constants or small data classes the caller needs
   (`RoleRelationshipDraft`, `ZaidangSnackBarTone`).
3. The public `show*` function that configures the route
   (`showModalBottomSheet<bool>(isScrollControlled: true, useSafeArea: true,
   isDismissible: true, enableDrag: false, constraints: maxWidth 560, ...)`)
   and returns the typed result.
4. The public widget class with a `const` constructor and `final` fields.
5. Its `State`: controllers and flags first, lifecycle (`initState`,
   `dispose`), then action methods (`_select`, `_swap`, `_submit`,
   `_resolve`), then `build`, then small `_build*` helpers.
6. Private helper widgets (`_CandidateStrip`, `_SentenceRow`, `_Blank`,
   `_NotebookMark`) at the bottom of the same file. They are promoted to their
   own file only when a second page needs them — `SectionLabel` went through
   exactly that and now lives in `lib/widgets/section_label.dart`; reuse it
   instead of adding a `_SectionLabel`.

`build` wraps the content in this order when the widget can be dismissed
while writing: `PopScope(canPop: !_saving)` → `KeyedSubtree(key:)` →
`AnimatedPadding(bottom: viewInsets)` → `SingleChildScrollView`. Do not use
`Semantics(scopesRoute: true)` without `explicitChildNodes`; it asserts in
tests.

---

## Props Conventions

- Constructors are `const` with named parameters; `required` for anything
  without a sensible default, `super.key` first.
- Data in, callbacks out. Widgets receive domain models
  (`Role self`, `List<Role> candidates`, `RoleRelationship? initial`) and
  emit through typed callbacks (`Future<void> Function(RoleRelationshipDraft)
  onSave`, `ValueChanged<bool> onBusyChanged`). Shared widgets never read a
  provider for a specific entity; the page does and passes values down.
- Predicates that must be re-evaluated after an `await` are functions, not
  booleans: `bool Function() canSave`, `bool Function() isEnabled`. A plain
  `bool enabled` is fine only for immediate rendering.
- Test/injection seams are optional constructor parameters with production
  defaults: `RoleCreatePage(picker:, supportDirectory:)`,
  `RoleAssetOpener(channel:)`, `supportDirectory` threaded into
  `CoverFileView` so tests can point at a temp directory.
- `CoverFileView(coverImg, placeholder, fit = cover, alignment = center,
  supportDirectory)`: pass `Alignment.topCenter` wherever a tall 立绘 is
  cropped into a wide or square box that should keep the face (role hero,
  identity-header portrait); list thumbnails and world covers stay centered.
- Copy is passed as `String` (`title`, `body`, `consequence`, `confirmLabel`)
  and never as a `Widget` tree, so the dialog controls typography and
  semantics. Optional labels default in the constructor
  (`cancelLabel = '取消'`).
- Return values of modals are documented on the `show*` function:
  `true` = wrote, `false`/`null` = cancelled or unchanged.

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

Type, spacing and radius come from the same file's scales: `ZaidangType.of(context).<role>` for every `TextStyle`, `ZaidangSpacing` for every `EdgeInsets` / gap / `Wrap` spacing, `ZaidangRadius` for every corner. A widget never writes `fontSize:`, `EdgeInsets.all(16)` or `BorderRadius.circular(8)`; `test/theme/design_token_guard_test.dart` enforces this for `lib/**` outside the theme folder and the export renderer.

Controls over user images must retain at least 3:1 icon contrast over both white
and black image regions. A translucent white fill does not protect a white icon
over white art. `CoverPreviewPage` uses `ZaidangTokens.dark.bg` at 80% opacity
behind its white close icon. Test the rendered control colors after alpha
compositing with both image extremes in light and dark themes; see
`test/pages/cover_preview_page_test.dart`.

---

## Accessibility

For abbreviated or icon-only controls, set the accessible name independently
of the visible content while retaining a button role, enabled state and tap
action. A `Tooltip` is not the button's semantic label:

```dart
Tooltip(
  message: '更换立绘',
  excludeFromSemantics: true,
  child: Semantics(
    button: true,
    enabled: onChange != null,
    label: '更换立绘',
    child: Material(
      key: const Key('role-cover-change'),
      type: MaterialType.transparency,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onChange,
        // 命中区 48，视觉圆 28 贴右下角
        child: SizedBox.square(
          dimension: kMinInteractiveDimension,
          child: Align(
            alignment: Alignment.bottomRight,
            child: ExcludeSemantics(child: /* 28px circle + icon */),
          ),
        ),
      ),
    ),
  ),
)
```

Verify the actual button semantics (`label`, `isButton`, `isEnabled`, and tap
action), not only `find.byTooltip`. Text-labelled buttons can use
`Text(..., semanticsLabel: ...)` instead of the `Semantics` wrapper. Small
visuals still need a `kMinInteractiveDimension` hit box, and that box must lie
inside its parent's bounds — `RenderBox.hitTest` rejects points outside the
parent even with `Clip.none`. Assert the size with `tester.getSize(...)`.

---

## Common Mistakes

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

The create/edit chrome (immersive blurred cover with calling card or paper
identity header, pinned identity, glass back button, accent save pill, paper
`ArchiveCard`, `ArchiveCardHeader`, `ArchiveFieldCell`, `FieldRow`,
`KeepAliveDetails`, content-width padding) lives in
`lib/widgets/archive_editor/`; the shared `SectionLabel` (`sectionLabel` role,
default `ZaidangSpacing.sm` bottom padding) lives one level up in
`lib/widgets/section_label.dart` because sheets and pickers use it too, and
`ArchiveTag` (paper chip: `bg` fill, `border` hairline, `micro` ink) lives in
`lib/widgets/archive_tag.dart` because list cards and the identity header both
use it. Both `RoleCreatePage` and `WorldCreatePage` compose these widgets; do
not copy private variants back into a page. `archiveEditorCardInset` is
`ZaidangSpacing.page`, `ArchiveCard` pads `ZaidangSpacing.card` and rounds
`ZaidangRadius.smAll`; the hero paper cap uses `ZaidangRadius.lgTop`. Pages pass
their own test keys (`heroKey`, `portraitKey`, `boxKey`) and copy nouns
(`coverNoun`, `emptyName`) so finders remain page-specific. See
[Worlds UI](./worlds.md).

- `ArchiveCardHeader({icon, title, caption, trailing})`: 32px accent-10% tinted
  `smAll` square with an 18px accent icon, `subheading` title, optional `caption`
  right-aligned and/or a `trailing` widget; `md` bottom padding replaces the
  `SectionLabel` inside redesigned cards. Captions are one short Chinese phrase
  (`关于这个角色`, `性格、外貌、背景`), never pronouns or English. With a caption
  the title is a plain (non-flex) `Text` and the caption is the only `Expanded`
  child: a loose `Flexible` next to an `Expanded` leaves its unused share as
  trailing free space, so the caption would float mid-row instead of hugging
  the edge (`archive_card_test.dart` asserts `caption.right == header.right`).
- `ArchiveFieldCell({icon, label, child})`: `bg` fill, `smAll`, 1px border that
  is `bg` (invisible) at rest and `accent` while any descendant has focus
  (`Focus(canRequestFocus: false, skipTraversal: true, onFocusChange)`); header
  row = 16px accent icon + `micro` label. Inner `TextFormField`s use
  `archiveCellInputDecoration(context, hint: …)` — `filled: false`, `isDense`,
  `UnderlineInputBorder(BorderSide.none)` at rest, an `ink` underline on error;
  the error text comes from the theme's `micro` ink `errorStyle`. Cells are
  inline editors: they never open a dialog to edit a value.
- `RoleIdentityHeader` is role-only; see [Role Assets](./role-assets.md#identity-header)
  for its layout, callbacks and height contract. `ImmersiveCover.paperHeader`
  is the only way to put content between the photo and the tabs — do not add a
  second sliver above the tabs, it breaks the overlap-absorber contract.

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
- Use `ZaidangRadius.lgAll` (26) for the sheet, `ZaidangRadius.mdAll` (16) for
  the action buttons and at least 48 logical pixel action height. Title is
  `heading`, body is `body.copyWith(height: 1.8)` (the one sanctioned
  line-height override, for the 便笺 feel), actions are `label`. Measure action
  labels with the effective text scaler before choosing a row or a vertical
  stack. Keep the standard cancel-then-confirm traversal order in both
  arrangements.
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
- The global theme uses a floating surface, `body` ink text, thin token
  border, `ZaidangRadius.mdAll` corners and restrained elevation. On desktop
  the helper caps width at 480; mobile uses native safe-area handling and
  `ZaidangSpacing.lg` theme insets. Never provide both `width` and `margin` to
  a SnackBar.
- A success message has a small accent-colored check on a 10% tint; info and
  errors use ink icons. Essential copy stays ink, without a second title or
  a broad red/green background. Error/success comes from the actual operation,
  not from parsing its message string. Share cancellation/unknown completion
  remains silent.
- Clear stale queued messages before showing the latest one. Short messages
  normally last 4 seconds, errors 5; a caller can supply `duration`.
- In Flutter 3.47, a close icon alone does not prevent timeout. Set `persist`
  only when the scaled message needs scrolling. Short notices retain their
  normal/default or caller-supplied timeout even with `accessibleNavigation`:
  Android automation services can enable this flag without the user asking for
  permanent feedback. Keep native live-region announcements and the close
  control. The helper measures with the same text style/scaler and a conservative
  text width; do not estimate fit by ASCII character count.
- The full Text remains in the widget/semantics tree. Very long content scrolls
  within a bounded height; never silently apply `maxLines`/ellipsis to the
  notification. Persistent notices can be closed with the native close control.
- Keep the original caller's mounted guards and business/error flow. A visual
  feedback wrapper must not change save/restore timing or imply success before
  the operation completes.

`test/widgets/zaidang_snack_bar_test.dart` covers light/dark surface readability,
close behavior, latest-message replacement, persistent long text, short-message
timeouts with accessible navigation, and desktop width. Existing save/export/backup tests retain
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
