# Role Detail and Assets

## Scope

`RoleCreatePage` retains the single-scroll create form. Existing roles have
**详情 / 资产 / 关系** below their shared cover. Asset and relationship changes
persist immediately (relationships: [Role Relationships](./role-relationships.md));
the top Save action still saves the role form and returns to the preceding page.

## Scroll contract

- Use `NestedScrollView` with one pinned, collapsible cover `SliverAppBar`.
  The photo stays `immersiveCoverHeight` (352) tall; below it, inside the same
  `flexibleSpace`, sits the paper identity header (`ImmersiveCover.paperHeader`,
  see below), so the expanded height is
  `352 + ImmersiveCover.paperHeaderExtent + 48`; its bottom contains the tabs.
  When collapsed, the cover reserves the status-bar inset plus 60 pixels for
  the existing glass controls, then 48 pixels for the tab bar.
- Collapse order matters: the identity header is anchored to the **bottom** of
  the flexible space (`Positioned(bottom: 0)`) and the photo fills whatever is
  left (`photoHeight = maxHeight - paperHeaderExtent`, top-aligned so the face
  stays). Scrolling therefore shortens the photo first while the header rides
  up intact, then the header fades over the last 100 px before the pinned
  toolbar (same `visible` curve and `IgnorePointer` as the calling card) so the
  pinned identity can take over. Never anchor the header to the top of the
  flexible space: the sliver clips from the bottom, so a small scroll would
  chop the header while the photo stays whole.
- In the last 24 pixels of cover collapse, reveal a 32px circular portrait and
  the current draft name centered in the toolbar using `NavigationToolbar`.
  The threshold is `collapseOffset = immersiveCoverHeight + headerExtent -
  topInset - 60` where `headerExtent = RoleIdentityHeader.heightFor(textScaler)
  - RoleIdentityHeader.portraitOverlap`. Keep this identity on both tabs,
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
- Wrap that header in `SliverOverlapAbsorber`. Every inner `CustomScrollView`
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
  `ensureVisible` alignment can land behind that header. Use
  `Scrollable.ensureVisible(element, alignment: 1)` to reveal a control at the
  bottom edge instead. Tests that tap list rows while a floating snack bar is
  showing must first collapse the header (`outerController.jumpTo(max)`, see
  `_assetsCollapsed` in `role_assets_tab_test.dart`); with the header expanded
  the first rows of the 资产 tab sit under the snack bar on a 390×844 phone.

## Identity header

- `RoleIdentityHeader` (`lib/widgets/archive_editor/role_identity_header.dart`)
  is passed to `ImmersiveCover.paperHeader` wrapped in
  `PreferredSize(child: ListenableBuilder(Listenable.merge([name, sex, race,
  occupation, desc])))`, with `paperHeaderOverlap: RoleIdentityHeader.
  portraitOverlap` and `backdropBlur: 0` (the photo path renders the 立绘
  crisp, top-aligned and fading into paper; see [Theming](./theming.md)).
  Typing in those fields rebuilds only
  the header; the page keeps a page-level listener on the name controller for
  `PinnedIdentity`.
- Height is fixed per build: the page computes
  `RoleIdentityHeader.heightFor(MediaQuery.textScalerOf(context))` and passes it
  both to the widget and to `PreferredSize`, so the sliver's `expandedHeight`
  is known before layout. The header clips (`OverflowBox` + `ClipRect`) instead
  of overflowing when content exceeds that height.
- Layout: left column = 112px portrait (surface frame, `mdAll`, shadow,
  `Key('role-create-cover-portrait')`; upper 56px ride on the photo) with a
  same-width `OutlinedButton` `导出角色卡` (`Key('role-card-export')`, 36px
  visual via `fixedSize`, `tapTargetSize.padded` so the hit box is
  `kMinInteractiveDimension`; never wrap it in a fixed-height box or the padded
  target is clipped) below it; right column starts 8px under the photo edge
  with `title` name + accent `Icons.auto_awesome`, `ArchiveTag` chips for
  non-empty 种族 / 身份 / 性别, and the first line of 设定 (`firstLine` from
  `lib/utils/text_lines.dart`) in `「」` (`caption` size, `ink`, 2 lines). Empty
  name shows `新建角色` (create) or `未命名角色` (edit); empty tags / quote take
  no space.
- Portrait tap previews when `hasCover`, otherwise picks (`添加立绘`
  placeholder). With a cover, the 28px camera badge `Key('role-cover-change')`
  sits on a transparent 48px `Material` (`kMinInteractiveDimension`) aligned
  to its bottom-right, so the whole hit box counts and the visual circle still
  overhangs the portrait corner by `xs`. The portrait box is therefore
  `112 + xs` square: hit testing stops at a `Stack`'s bounds, so a hit area
  that pokes outside the box would silently lose that strip. The badge exposes
  `更换立绘` as a real button (`Semantics(button, enabled, label)` +
  `Tooltip(excludeFromSemantics: true)`). All three callbacks are `null` while
  `_saving || _tabBusy`, which also disables their semantics.
  `role_identity_header_test.dart` asserts both tap boxes ≥ 48 and that the
  badge box is contained in the portrait box.
- The world editor does not use this header; its `ImmersiveCover` keeps the
  calling card and the plain 352px expanded height.

## Detail form

- No title row. 基础设定 = `ArchiveCard` with `ArchiveCardHeader(Icons.
  description_outlined, '基础设定', caption: '关于这个角色')` and `FieldRow`s of
  `ArchiveFieldCell`s: (名字 | 性别), (年龄 | 生日), (种族 | 身份), then the
  full-width 世界观 cell (`Key('role-world-row')`). Field keys are
  `role-field-<name|sex|age|birthday|race|occupation|desc>`; tests locate inputs
  by key, never by `widgetWithText(TextFormField, '名字')`. The name validator
  `请填写名字` renders inside its cell.
- 自定义属性 keeps its `DecoratedSliver` / `SliverReorderableList` mechanics; only
  its `SectionLabel` became `ArchiveCardHeader(Icons.bookmark_border, '自定义属性')`.
- 角色简介 = `ArchiveCardHeader(Icons.history_edu_outlined, '角色简介', caption:
  '性格、外貌、背景')`, the multiline field in the themed outlined box with a
  decorative `Icons.format_quote` (accent 0.3, `IgnorePointer` +
  `ExcludeSemantics`) bottom-right, and — edit only — a right-aligned
  `TextButton('修改历史')` under the box.
- Tabs keep `Key('role-detail-tabs')`, `indicatorSize: label` with a 3px accent
  `UnderlineTabIndicator`, and the opaque `tokens.bg` backing.

## Asset interactions

- **添加资产** offers the system photo/media picker or file picker. **全部 / 图片 /
  视频 / 音频 / 文档** filter the role-owned list. Display saved names and sizes;
  names initially come from the imported files.
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

## Asset rename interaction

- Each row has an accessible overflow menu with **重命名 / 删除**. Tapping the
  row still opens the file; deletion retains its existing confirmation.
- Prefill and select the editable basename. Show the stored extension separately
  as read-only text, preserving matching display suffix case. Files whose stored
  paths have no extension keep their entire names editable across repeat renames.
  Follow the [repository rename contract](../backend/role-assets.md#rename-contract)
  and share its name validation instead of defining another UI-only policy.
- Use a stock themed, scrollable dialog that accommodates the keyboard and large
  text. Show validation next to the input. Keep entered text when a write fails,
  allowing retry or cancellation. Success closes only the rename dialog.
- Treat the menu, editor and pending write as asset work in the parent's busy
  contract. Block duplicate submissions and parent save/navigation races. The
  idle editor can be cancelled; a pending write must not be dismissed in a way
  that allows its completion to pop another route.
- `RoleAssetsTab.isEnabled` supplies a live check of the parent's save state
  (`() => !_saving`) in addition to the rendered `enabled` flag. Consult it in
  operation callbacks so a stale callback cannot open a dialog between a parent
  save starting and the next rebuild.
- Rename persists immediately through `RoleAssetRepository.rename`; it never
  submits the role form. Unchanged input or cancellation leaves stored data
  untouched, and stream updates refresh the row while retaining filter/scroll.
- UI regression coverage includes both themes, protected extension, invalid
  input, cancellation, failed-write retry, pending navigation/action guards,
  unchanged name, preservation of unsaved role fields and menu-based deletion.
- Preview format checks use immutable `relativePath`, not the editable display
  name. A renamed title must never change whether a file uses the image gallery
  or the platform opener.
- Pass the current `asset.name` separately as `displayName` when invoking
  `RoleAssetOpener.open`. A correct list label alone does not complete rename:
  the iOS system preview header must receive the same current name. Keep the
  original file path as the data source and wait for preview dismissal before
  releasing the parent busy guard.

## Validation

`test/pages/role_assets_tab_test.dart` covers both themes, pinned controls,
draft/scroll preservation, file import/filter/open, failure/cancellation,
pending-import navigation guards, confirmed deletion and gallery return.
Run existing cover/custom-attribute/keyboard tests after scroll changes.
The pinned-header regression compares rendered header pixels before and after
continued inner scrolling on both tabs in both themes; geometry alone does not
detect content painting through a transparent header.
