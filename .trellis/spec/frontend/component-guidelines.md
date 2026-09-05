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
