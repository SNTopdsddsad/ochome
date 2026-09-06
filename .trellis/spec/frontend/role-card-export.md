# Role-card export

## Scope

The user-approved template is a fan-made character sheet: large artwork, a
deep-blue basic-information region, and setting sections on warm paper. With
only a short name and artwork, empty sections collapse into a larger image and
a vertical name rail. See the implemented feature under
`lib/features/role_card/`, reached from `RoleCreatePage`.

This contract covers content selection, page layout, painting, temporary PNG
jobs, preview state and Apple delivery. It does not change role persistence,
backup formats, artwork files or the app's global color tokens.

## Entry and content projection

- The editor's `role-card-export` action captures current controllers, cover
  path and ordered attributes synchronously into `RoleCardSnapshot`. It must
  not call `_submit`, reread an old saved role, write a repository or discard
  the editor on return. Guard both a pending save and duplicate route pushes.
- `RoleCardSelection` uses `RoleCardField` values and snapshot attribute
  indices. Duplicate attribute names remain independently selectable.
- Defaults include populated short basic fields, name and artwork; description
  and custom attributes require selection. Empty values do not create blank
  rows. A contentful attribute with a blank draft name gets the generic label
  `未命名属性`; this does not bypass repository validation when the role saves.
- `snapshot.select(selection)` returns `RoleCardContent`, containing only
  selected values. The renderer never receives the full snapshot or editor
  controllers. Selection UI may show unselected values so the user can choose;
  the generated preview, image semantics and delivery payload must not.
- Hiding a structured name cannot erase lettering inside the source image.
  Explain that distinction in the field picker, and preserve source pixels and
  watermarks. Do not add automatic OCR, redaction, background removal or facts
  inferred from a sample poster.

## Renderer API and ownership

```dart
final content = snapshot.select(selection);
final document = await const RoleCardRenderer().prepare(
  content,
  supportDirectory: optionalDirectoryLookup,
);
// Use one drawing document for CustomPaint preview and encoded output.
document.paintPage(canvas, pageIndex);
final bytes = await document.renderPng(pageIndex);
document.dispose(); // only after the last preview/export consumer is done
```

`RoleCardDocument.pageSize` is 480 × 640 logical units; each PNG is exactly
1440 × 1920. Template colors, fonts and text scaling are explicit, independent
of `Theme`, screen DPR, accessibility text scale or the preview viewport.
Surrounding controls remain responsive and accessible.

- Keep `TextPainter` layout and drawing nodes shared between preview and PNG.
  Do not build a separate Widget screenshot template for output.
- Paragraphs have no ellipsis/maxLines. Paginate complete measured line ranges
  and translate/clip the same paragraph. `textCoverage` records selected
  strings and their contiguous line coverage for verification.
- Keep normal headings with their first body line. Long names/basic values
  that do not fit the main slot are represented in full in flowing content;
  a main-slot “见续页” cue must not replace their complete text.
- A few graphemes can still shape into many lines (for example long joined
  sequences). Vertical name placement checks actual line count and height.
- Measure a continuation title once and reuse its fit decision/painter.
  Immediately dispose unused large title/profile candidates; never re-shape
  and retain an overflowing full name on every continuation page.
- Dispose every owned painter/image/codec/buffer/picture. A disposed document
  cannot be painted or encoded; route replacement must not dispose a document
  still leased to a PNG generation job.
- Resource bounds are explicit failures: currently 120,000 selected UTF-16
  units (including labels), 500 selected sections, 300 pages and 64 MiB source
  artwork. Do not silently cap a successful document or return partial output.

## Artwork and fonts

- Resolve relative/legacy absolute artwork through `CoverPath`. If artwork is
  hidden, do not read it. No selected artwork permits a text-only layout; a
  selected missing/corrupt/oversized image is a visible error that the user can
  resolve by replacing or hiding it.
- Decode the first frame at a bounded size (longest side at most 1920) and use
  codec-reported dimensions for fitting/orientation. The supplied HEIC decoded
  correctly through Flutter even when `sips` produced a black conversion; do
  not infer a new decoder dependency from a utility failure.
- Await `RoleCardFonts.ensureLoaded()` before measuring. Title uses bundled
  `SourceHanSerifCN-Bold`, with `RoleCardSans` fallback; body uses bundled
  `SourceHanSansSC-Regular`. Binaries/licenses/provenance are in
  `assets/fonts/role_card/` and remain unmodified.
- Font licenses remain in `assets/fonts/role_card/` and are registered with
  `LicenseRegistry` when `RoleCardFonts.ensureLoaded()` runs. Do not add an
  export-page license button or other in-flow license chrome.
- Common CJK metrics use the bundled fonts. Emoji/unsupported rare glyphs can
  use named system fallbacks (Apple Color Emoji, Noto Color Emoji, Segoe UI
  Emoji); do not promise byte-identical output for arbitrary Unicode across
  operating systems. Flutter tests use test fonts, so text-presence assertions
  alone do not prove an emoji glyph is visible. Any local system-font loading
  for raster QA must not copy that proprietary font into shipped assets.

## Jobs and UI lifetime

`RoleCardExportService.render` takes a page count, sequential page encoder,
cancellation predicate and progress callback. It writes `.part` files then
renames complete PNGs under:

`getTemporaryDirectory()/role-card-exports/job-*/zaidang-card-001.png`.

- Expose a job to platform delivery only after every expected page succeeds.
  Failures/cancellation remove that job's partial files.
- Use generic names/share metadata, never raw role names or private text.
  The share adapter also supplies generic numbered filename overrides.
- A busy operation freezes field changes and rejects repeated delivery taps.
  A selection generation ID rejects stale decode/layout results.
- Leaving during generation cancels before delivery; leaving during external
  consumption retains the document/files until the operation completes.
- `release(retainForShare: true)` keeps completed share files for a bounded
  period because consumers may outlive the share sheet. Later exports remove
  expired unleased `job-*` directories after one day. Never clean source-cover
  storage, backups, unrelated files or active leases. Cleanup failure must not
  retroactively turn a successful save into failure.

## Platform delivery

One injectable `RoleCardDelivery` handles save/share. The save channel is
`com.xuwudi.ochome/role_card_export`, method `saveImages`, arguments
`{'paths': List<String>}`. Results are `saved` with matching count and optional
directory, or `cancelled`. Invalid results or missing files are errors.

- iOS validates complete PNGs from one app-owned job before requesting
  PhotoKit `.addOnly`; it saves all assets in one `performChanges` batch and
  returns success only from completion. Keep source files. The Info.plist
  addition is `NSPhotoLibraryAddUsageDescription`; existing picker permissions
  and iCloud capabilities remain unchanged.
- macOS presents a directory-only sheet and uses
  `com.apple.security.files.user-selected.read-write`. Copy to an exclusive
  UUID staging directory, then move the whole directory on success. Never
  overwrite user files or clean any directory the operation did not create.
- Native validation normalizes paths/symlinks and requires real PNG files in
  one allowed job. `path_provider_foundation` uses NSCachesDirectory on iOS
  and appends the bundle ID on macOS; match those actual paths, not an assumed
  NSTemporaryDirectory-only root. Native result callbacks run once on main.
- Sharing uses pinned `share_plus`, ordered PNGs and a valid iPad origin rect.
  A plugin “success” can mean only that a share target was selected, especially
  on macOS/Android. Do not show a sent/completed success toast from that status;
  let the system UI report its result. Dismissed/unknown status is not failure.
- Save is offered on iOS/macOS; image sharing follows supported package
  targets. Do not advertise Linux file sharing. Flutter-generated desktop
  registrants must track dependency changes.

## Verification

Core checks live in `test/features/role_card/` and
`test/pages/role_card_export_page_test.dart`: complete selection/line coverage,
duplicate names, hidden-data isolation, image errors, real PNG dimensions,
draft preservation, stale generations, delivery results and job lifetimes.
Apple `RunnerTests` cover path/PNG validation and complete-directory copying.

Inspect real Flutter output with representative artwork, filled and sparse
data, long multi-page text and both preview themes. Run affected tests and
whole-project analysis; build affected platform targets. Serialize Flutter
tests and Apple builds: they share native-assets intermediates, and parallel
build/test commands can remove a test's NativeAssetsManifest mid-run.

A no-signing build is a compile/integration check, not proof of Photos
permission, sandbox or downstream sharing behavior. Existing iCloud signing
requirements must not be stripped to make local validation pass. Record the
specific real-device/runtime scenarios still unverified.
