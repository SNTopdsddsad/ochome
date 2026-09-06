# Role Detail and Assets

## Scope

`RoleCreatePage` retains the single-scroll create form. Existing roles have
**详情 / 资产** below their shared cover. Asset changes persist immediately;
the top Save action still saves the role form and returns to the preceding page.

## Scroll contract

- Use `NestedScrollView` with one pinned, collapsible cover `SliverAppBar`.
  Its expanded cover stays 352 logical pixels; its bottom contains the two tabs.
  When collapsed, the cover reserves the status-bar inset plus 60 pixels for
  the existing glass controls, then 48 pixels for the tab bar.
- In the last 24 pixels of cover collapse, reveal a 32px circular portrait and
  the current draft name centered in the toolbar using `NavigationToolbar`.
  Keep this identity on both tabs,
  hide it when expanded, and ellipsize long names within the available width.
  A subtle paper background keeps the text readable over any cover image.
- The visible cover layout owns an `AnnotatedRegion<SystemUiOverlayStyle>`:
  expanded photos retain light status-bar text, while pinned paper uses dark
  icons on the light theme and light icons on the dark theme. Set both Android
  `statusBarIconBrightness` and iOS `statusBarBrightness` through the matching
  overlay preset; these two brightness fields have opposite semantics.
  Do not let the original photo style keep overriding the collapsed header.
- The pinned `SliverAppBar` must have an opaque `tokens.bg` Material and must
  not force Material transparency. `FlexibleSpaceBar` fades out its background
  on collapse, so an image alone cannot shield the toolbar from scrolling
  content. Retain transparency only for the non-pinned create header.
- Wrap that header in `SliverOverlapAbsorber`. Both inner `CustomScrollView`s
  use `SliverOverlapInjector` and inherit the nested primary controller. Do not
  give either inner scroll view an independent controller.
- Keep each tab alive and give it a different `PageStorageKey`. Form controllers
  remain page-owned. Switching tabs must retain unsaved text and scroll offsets.
- Programmatically adding an attribute first collapses the shared header and
  then scrolls the **detail position**, not the primary controller shared by
  both tabs. Text fields reserve the pinned header in their scroll padding.
- Only horizontal page-drag notifications with `depth == 0` and non-null
  `dragDetails` can cancel reordering/unfocus the form. Text fields emit their
  own horizontal scroll notifications, sometimes during layout; handling those
  as page gestures causes `setState during layout` and cancels valid drags.
- UI tests must drag inside visible body content. The inner scroll viewport
  can extend underneath the pinned header; its geometric center and a default
  `ensureVisible` alignment can land behind that header.

## Asset interactions

- **添加资产** offers the system photo/media picker or file picker. **全部 / 图片 /
  视频 / 音频 / 文档** filter the role-owned list. Display original names and sizes.
- Standard raster images reuse `CoverPreviewPage`, including swipe and zoom.
  Other image formats, video, audio and documents use `RoleAssetOpener` and the
  platform's file-opening UI. Surface missing files or missing apps visibly.
- Video rows lazily request a first-frame thumbnail through
  `videoThumbnailServiceProvider`. Keep a play badge on the preview, and keep
  the tile's open action pointing to the original video. Extraction errors use
  the existing movie icon; thumbnail work must never block asset import.
- Import is an all-or-nothing batch. Disable repeat actions, role Save, and
  leaving the role while import, confirmation or gallery opening is active.
  Disable asset operations while role Save is pending. Always restore controls
  after cancellation, failure or return from preview.
- Deletion uses `showZaidangConfirmDialog`. It removes the imported copy and
  metadata immediately, without modifying the source selected by the user.
- Keep picker/opener/repository injectable through providers. Tests must not
  invoke native pickers or depend on the user's real database.

## Validation

`test/pages/role_assets_tab_test.dart` covers both themes, pinned controls,
draft/scroll preservation, file import/filter/open, failure/cancellation,
pending-import navigation guards, confirmed deletion and gallery return.
Run existing cover/custom-attribute/keyboard tests after scroll changes.
The pinned-header regression compares rendered header pixels before and after
continued inner scrolling on both tabs in both themes; geometry alone does not
detect content painting through a transparent header.
