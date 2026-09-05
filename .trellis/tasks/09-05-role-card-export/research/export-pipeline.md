# Role-card export pipeline research

Date: 2026-09-05. Phase: planning only. No application, test, schema, or native code was changed for this research.

## Confirmed product input

- The user chose sharing an OC: artwork first, a fixed-ratio main card, and continuation pages for long content.
- The task context supplied by the main agent fixes the first release to one refined template, selectable field visibility, a small 崽档 stamp, local rendering, iOS first, and PNG saving plus the system share sheet.
- No AI generation, promotional AI illustration, multiple templates, structured-data export, or payment work belongs in this task.
- The exported composition should have its own visual design; the application’s paper-colored form appearance is not the poster specification.
- Exact aspect ratio, dimensions, artwork placement, field defaults, and typography remain design decisions. Numbers below are recommendations, not additional confirmed requirements.

## Existing code and preservation boundaries

| Area | Evidence | Consequence |
| --- | --- | --- |
| Entry | `lib/pages/role_list_page.dart`: `_RoleTile.onTap` opens `RoleCreatePage(role: role)` | There is no independent saved-role detail screen. Put the first export entry on the editor, near its existing save action. |
| Draft | `lib/pages/role_create_page.dart`: controllers, `_attributes`, `_coverImg` own current edits | Exporting `widget.role` or rereading the repository would export stale saved values. |
| Save | `_submit()` validates all attribute drafts, trims outer whitespace, performs repository create/update, then pops the editor | Do not reuse `_submit()` as an export prerequisite: it changes persistence and navigation. |
| Cover selection | `CoverImagePicker.savePickedFile` copies selected bytes to application support before assigning a relative path | An unsaved draft’s newly selected cover is already locally readable. Export does not need to save the role first. |
| Cover resolution | `lib/data/services/cover_path.dart`: `CoverPath.resolve` accepts both `covers/...` and historical absolute paths | Reuse this resolver and the injectable support-directory pattern. Do not concatenate absolute legacy paths to the support directory. |
| Attribute identity | `RoleCustomAttribute` contains only `name` and `content`; spec permits duplicate names and ordered values | Visibility identity must not use the attribute name as a map key. |
| Description history | `_openDescHistory()` updates only the description controller after a restore | Snapshot the current controller value; exporting must not restore or rewrite history. |

Recommended entry behavior:

1. On “导出角色卡”, finish any current IME composition/unfocus and cancel an active reorder, then synchronously copy the current values into an immutable `RoleCardSnapshot`. Include an immutable ordered attribute list. Do this before any asynchronous work.
2. Push the export preview route over the existing editor. Returning from preview leaves every editor controller, attribute order, cover choice, and scroll position intact.
3. No repository write or role-list refresh is needed. The export page can quietly say that it uses current editing content; exporting does not promise the role was saved.
4. Allow new-role drafts to use the same route. For visible empty required presentation fields, supply a deliberate template fallback or request the necessary text within the editor. Do not invoke whole-form persistence validation merely to export hidden fields.
5. Disable the entry while `_saving` and guard against duplicate route pushes. If a list shortcut is added later, it should explicitly create a snapshot of saved data and reuse the same export page.

## Recommended rendering contract

Use a document pipeline with a single source of layout truth:

```text
editor values → immutable snapshot + visibility selection
              → selected presentation content
              → measured RoleCardDocument (ordered pages and drawing nodes)
              → the same page painter
                 ├─ scaled CustomPaint preview
                 └─ PictureRecorder → PNG files → save/share adapter
```

Separate snapshot/selection, layout, painting, encoding, and platform delivery enough to test their contracts. This can remain a small feature module; it does not require a general template engine or a database migration.

### Fixed output and preview parity

- Select one logical card size and one export scale in the approved design. An example is 480 × 640 logical units, scaled by 3 to 1440 × 1920 PNG. Do not treat this example as an approved ratio.
- The renderer must use explicit template colors, text styles, locale, direction, line height, and `TextScaler.noScaling`; it must not read `MediaQuery.devicePixelRatio`, text scaling, or the surrounding `Theme` for poster layout. The preview controls still follow application accessibility settings and dark mode.
- Build each `PictureRecorder`, scale its `Canvas` by the fixed export scale, paint the same document page, call `endRecording()`, then `picture.toImage(pixelWidth, pixelHeight)` and `image.toByteData(format: ui.ImageByteFormat.png)`. A null byte result is an export failure, not an empty file.
- The local SDK documents that `Picture.toImage(width, height)` returns those exact pixel dimensions and clips outside those bounds: `/opt/homebrew/Caskroom/flutter/3.47.2/flutter/bin/cache/pkg/sky_engine/lib/ui/painting.dart:8449`.
- Keep the preview on the same layout and painter. Do not implement one Widget tree for preview and a separate hand-positioned image renderer. If absolute raster parity becomes necessary, display scaled generated PNGs; the cost is encoding latency and more cache work.
- Dispose `TextPainter`, `ui.Image`, `Codec`, and `Picture` when their document/job is replaced. The local `TextPainter` contract explicitly supports repeated painting after one layout and requires disposal: `packages/flutter/lib/src/painting/text_painter.dart:570` under that SDK.
- Explicit styles remove device settings from layout, but system font fallback can still differ between iOS/macOS or OS versions. Do not promise byte-identical text rasterization across those platforms. A licensed bundled font is the option if cross-device type metrics must be fixed; bundle size and glyph coverage must then be evaluated.

### Complete text pagination

Long descriptions are not the only long text: names, fixed property values, attribute names, and attribute contents are unconstrained strings in the current model. The layout must explicitly handle each one.

Recommended algorithm:

1. Create selected text blocks in their intended source order. Each block retains its field identity, original full string, label, and explicit style. Hide empty optional values without leaving a decorative empty row.
2. Measure body blocks with a fixed body width using `TextPainter.layout`; do not set `maxLines` or `ellipsis` on content that must be exported completely.
3. Read `computeLineMetrics()` only after layout. Partition its ordered visual lines into the available page height, reserving header/footer/label space. Keep a heading with at least its first content line. Start a new page when necessary.
4. Store each page segment as a reference to its measured paragraph and a contiguous complete-line range with source vertical coordinates. Paint the paragraph translated into that page and clipped to the segment. Using the same measured paragraph avoids substring-based UTF-16 cuts, altered shaping, and lost hard line breaks. Continuation body regions should have equal widths to make paragraph reuse possible.
5. Use ascent, descent, and baseline measurements to contain full glyphs. Test line-boundary clipping with CJK punctuation, emoji, and fallback fonts. Do not assume `fontSize × lineCount` describes the occupied height.
6. Require monotonically advancing line ranges; each selected source line must be consumed exactly once. If a line cannot fit an empty body region, report a layout error instead of looping or clipping it silently. Blank lines and trailing hard breaks should follow a documented normalization rule; do not trim every page fragment.
7. An intentionally shortened title/metadata treatment on the main card must preserve the complete selected value elsewhere, or have an explicit product rule. Do not use ellipsis as a substitute for continuation.

The SDK’s `computeLineMetrics()` returns metrics in line order and includes baseline, ascent, descent, and height; implementation is at `packages/flutter/lib/src/painting/text_painter.dart:1783`. `getLineBoundary` is available if range-based pagination is chosen, but manual string slicing needs extra care around newlines and grapheme clusters. The complete-paragraph drawing approach avoids that additional text mutation.

Avoid an arbitrary hidden page cap. For unusually large input, either finish all pages sequentially or present an explicit resource/layout failure before any external save begins. A document’s page list must never silently omit selected content.

### Visibility must apply before all outputs

- Create a `SelectedRoleCardContent` boundary before layout; painters and platform adapters should not receive the full raw role.
- Use a fixed-field enum and immutable snapshot attribute indices or generated stable IDs. Identically named attributes can be independently hidden.
- Apply visibility to main cards, continuation headers, labels, repeated metadata, preview semantics, file names, share titles, and any thumbnails. Hiding a name while retaining it in `character-name-01.png` is still a leak.
- Prefer generic numbered filenames such as `zaidang-card-<job>-001.png` and a generic share title. Never attach description text as share-sheet text when the selected artifact is an image.
- If artwork is hidden, do not decode it. Empty selections still render intentional template decoration/the stamp and any product-required fallback, without resurrecting hidden fields.
- A visibility change invalidates layout/render caches. Use a monotonically increasing generation ID, discard stale asynchronous results, and disable save/share until the preview represents the current selection.

## Artwork loading and memory

Recommended loader sequence:

1. Resolve with `CoverPath.resolve`, distinguish “no artwork selected” from “selected file is missing/unreadable/corrupt”, and preserve that state in the preview.
2. Load a file-backed `ui.ImmutableBuffer`, then use `ui.instantiateImageCodecWithSize` to choose a decode size from intrinsic dimensions. For a contain-fit image region, the scale is `min(1, regionPixelWidth / sourceWidth, regionPixelHeight / sourceHeight)`; preserve aspect ratio and clamp each dimension to at least one. A deliberate cover/crop design needs its own target-size calculation.
3. Decode only the first frame for animated sources unless the product explicitly adds animation. Dispose the codec after taking ownership of its frame image.
4. Reuse the decoded cover for all document pages. Do not decode a full 40-megapixel source just to draw a small card, and do not retain all full-size raster pages simultaneously.

The installed `instantiateImageCodecWithSize` contract exposes intrinsic dimensions in `getTargetSize`, accepts proportional downsampling, reports decode failures asynchronously, and takes ownership of its input buffer. It is present at `bin/cache/pkg/sky_engine/lib/ui/painting.dart:2545`. If lower-level `ImageDescriptor` handling is used instead, explicitly dispose both descriptor and buffer.

PNG encoding creates a new image from the drawn result, so the source file/EXIF metadata is not separately attached. Composite transparent artwork against the intentional poster background. Test JPEG orientation and transparent PNGs against actual rendering; do not add manual rotation assumptions without a failing fixture.

For a missing or corrupt selected cover, show a clear preview status with a intentional no-artwork composition. Let the user explicitly continue with that preview or return to replace the artwork. Do not silently emit a card lacking the selected image.

Render and write pages sequentially, update progress between pages, and release each raster image/byte buffer immediately. A 1440 × 1920 RGBA page alone is about 10.5 MiB, before PNG and GPU allocations. Keep UI engine painting on the main isolate; ordinary I/O can be asynchronous. A `compute` isolate is not a drop-in host for `dart:ui` text and painting objects.

## Platform delivery: recommended first-release choice

**Recommendation: one thin iOS PhotoKit batch-save channel, a macOS native directory-save adapter, and `share_plus` for system sharing.** This keeps atomic multi-page photo saving under our control on iOS, permits desktop PNG inspection without Photos permission, and delegates share-sheet presentation/lifecycle to a maintained cross-platform plugin. Keep the export channel separate from the existing iCloud channel.

### Existing native integration

- `ios/Runner/AppDelegate.swift` uses the implicit Flutter engine lifecycle. Register a new handler from `didInitializeImplicitFlutterEngine`, beside `ICloudChannelHandler`, using the existing messenger pattern.
- `macos/Runner/MainFlutterWindow.swift` registers handlers using the Flutter engine binary messenger after plugin registration.
- Both Xcode projects explicitly list Swift file references/build sources. Adding a Swift file also requires adding it to the target’s Sources phase.
- Actual deployment settings are iOS 15.0 and macOS 12.0 in the respective `project.pbxproj` files. The iOS Podfile platform line is commented; do not infer the deployment target from that comment.
- The installed SDK is Flutter 3.47.2 / Dart 3.13.2, verified from `bin/cache/flutter.version.json`. Existing dependencies include `path_provider: 2.1.6`; there is no share/gallery-saving plugin today.

### Save all pages to Photos

Expose a narrow injectable `saveImages(List<String> paths)` service. Before requesting Photos access, validate that all generated PNG files exist and the complete render job succeeded. Keep the ordered file list stable until completion.

On iOS, query authorization for `.addOnly`; request that same level only when a user presses “保存图片” and the status is undetermined. Do not request permission when opening the editor/preview or when sharing files. If access is denied or restricted, retain the preview and show a useful save message; sharing remains available. Apple recommends permission requests in direct response to relevant user actions, and distinguishes add-only access from limited read/write access. [Apple privacy guidance](https://developer.apple.com/documentation/PhotoKit/delivering-an-enhanced-privacy-experience-in-your-photos-app?language=objc), [add-only access](https://developer.apple.com/documentation/photos/phaccesslevel/addonly).

After authorization, call one `PHPhotoLibrary.shared().performChanges` for the complete ordered set. Within it, create one `PHAssetCreationRequest.forAsset()` per PNG and add its file URL as `.photo`. Keep `shouldMoveFile` false/default so the same generated files remain available for sharing. Report success only from the completion callback with `success == true`; never immediately after enqueueing requests. Apple documents combining changes as a single atomic update. [Batch changes](https://developer.apple.com/documentation/photokit/requesting-changes-to-the-photo-library?changes=_3), [file-resource import/error behavior](https://developer.apple.com/documentation/photos/phassetcreationrequest/addresource%28with%3Afileurl%3Aoptions%3A%29).

Add `NSPhotoLibraryAddUsageDescription` to iOS Info.plist, with wording such as “用于将你导出的角色卡保存到相册”. Preserve the existing cover-picker description. [Apple usage-description key](https://developer.apple.com/documentation/bundleresources/information-property-list/nsphotolibraryaddusagedescription?changes=_10&language=objc).

Availability was also verified in local Xcode `Photos.framework/Headers/PHPhotoLibrary.h`: access-level authorization is available from iOS 14/macOS 11, below this app’s deployment targets. `PHAssetCreationRequest` is available from iOS 9/macOS 10.15. No minimum-OS increase is needed for these APIs.

Native callbacks must resolve each MethodChannel call once, dispatch Flutter results to the main thread, and distinguish `permissionDenied`, `restricted`, invalid/missing files, platform unsupported, and save errors. A Photos failure must not produce “已保存 N 张”. No user album is required for v1, and Photos presentation order is not a contractual guarantee; numbered visible page labels preserve reading order.

### macOS development save

Use the existing `MainFlutterWindow` messenger registration pattern for a narrow native method that receives the completed PNG list and presents an `NSOpenPanel` configured for one directory (`canChooseDirectories = true`, `canChooseFiles = false`, `allowsMultipleSelection = false`). Present it as a sheet attached to the Flutter window. Cancellation returns a distinct cancelled result with zero copies; a chosen directory initiates the copy, and only finished copies produce a saved result. [Apple OpenPanel contract](https://developer.apple.com/documentation/appkit/nsopenpanel?changes=_3), [sheet completion API](https://developer.apple.com/documentation/appkit/nssavepanel/beginsheetmodal%28for%3Acompletionhandler%3A%29).

The checkout already enables the macOS app sandbox but **does not currently contain** `com.apple.security.files.user-selected.read-write` in either DebugProfile or Release entitlements. Add that narrow entitlement for destination directories chosen by the user. Do not disable the sandbox or add broad Pictures/Downloads access. The official entitlement matrix identifies it as access to files selected through Open/Save dialogs. [Apple file entitlements](https://developer.apple.com/documentation/bundleresources/security-entitlements?language=objc).

Copy into a uniquely named job subdirectory inside the chosen directory, using a temporary staging name, then rename the subdirectory after every numbered PNG copy succeeds. This avoids overwriting existing user files and reduces visible partial results. On failure, remove only that job’s staging directory and report the error. Keep the directory access alive during copying; no persistent bookmark is needed if the adapter completes all copying in the same selection operation. Return the final folder path for a useful desktop result message. Native code should perform file work off the main thread and deliver the Flutter result on main.

Alternative, not selected for first release: reuse the PhotoKit batch implementation on macOS. The OS deployment target supports it, but it also requires the macOS Photos Library entitlement and a Photos usage description. Those permissions are unnecessary for development validation when a directory export is available. [Apple macOS Photos capability](https://developer.apple.com/documentation/avfoundation/saving-captured-photos?language=objc).

### System share

The publisher’s current official package page reports **`share_plus 13.3.0`**. It supports file sharing on iOS/macOS and requires Flutter ≥3.38.1, Dart ≥3.10, iOS ≥13, and macOS ≥10.15, compatible with this checkout. Use the current `SharePlus.instance.share(ShareParams(files: ...))` API; provide generated file paths and a button-origin rectangle for iPad presentation. Handle `dismissed` quietly, `unavailable` as unknown completion, and exceptions as failures. A positive share result must not be described as a confirmed social post. Avoid sending image-plus-description text. [Official package documentation](https://pub.dev/packages/share_plus).

Apple’s native completion callback reports whether the activity completed, whether the sheet was dismissed without a service, and an optional activity error. It reports the local activity result, not independently verified downstream delivery. [Apple share completion contract](https://developer.apple.com/documentation/uikit/uiactivityviewcontroller/completionwithitemshandler-swift.typealias).

Pin the selected package version to match this repository’s existing exact-version dependency style and update the lockfile during implementation. Its Android build requirements are newer than basic Flutter requirements, so inspect Android Gradle/Kotlin compatibility before adding the package even though iOS ships first. Do not promise Linux file sharing; the package’s platform matrix excludes it.

### Alternatives and tradeoffs

1. **Canvas document vs widget screenshot:** Canvas gives fixed geometry, complete pagination, and preview/export reuse; it needs deliberate typography and accessibility semantics on the preview wrapper. Capturing a `RepaintBoundary` is shorter initially but depends on a fully mounted/painted tree and complicates offscreen continuation pages.
2. **Native batch PhotoKit vs gallery plugin:** The official **`gal 2.3.3`** page supports iOS 11+, macOS 11+, Android 21+, and Windows 10+, with access-denied, storage, format, and unexpected errors. Its documented image API is per-file `putImage`/`putImageBytes`. Sequential multi-page saves therefore require partial-success reporting and safe retry behavior; no batch-atomicity contract is documented. That makes it less suitable than one PhotoKit transaction for this Apple-first multi-page feature. [Official Gal documentation](https://pub.dev/packages/gal).
3. **macOS Photos parity vs folder export:** Sharing the PhotoKit path reduces duplicated save logic, but introduces desktop photo-library permission. The recommended directory adapter adds a small amount of native copy/cancellation handling and produces directly inspectable PNGs. Keep the Flutter delivery interface abstract enough that each platform reports its actual save destination.

## Temporary files and job lifecycle

- Use an application-owned subdirectory of `getTemporaryDirectory`, with a unique job directory and ascending page filenames. Do not use role-cover storage, backups, or application support as permanent export storage.
- Write each output first to a `.part` file, then rename after a successful flush. Pass files externally only when every expected page is complete.
- Hold the job while PhotoKit imports it or a share operation is active. Do not remove paths as soon as the share sheet opens or when the export route disposes.
- Clean incomplete/cancelled generation jobs immediately when no consumer holds them. Retain completed share files for a short bounded period and remove stale, unleased job directories on the next startup/export; unknown share completion must not cause premature deletion.
- Cancel/replace generation through an epoch or cancellation token checked between asynchronous steps. Stale images and layouts must be disposed even if their widget is no longer mounted.
- Guard save/share from duplicate taps. Keep native-save failure, user-dismissed sharing, rendering failure, and cleanup failure distinct. Cleanup failure must not retroactively report that a successful photo save failed.

## Required verification boundaries

| Case | Evidence to collect |
| --- | --- |
| Draft preservation | Enter/export/return with unsaved fixed fields, reordered/duplicate-name attributes, restored description, and a newly selected cover; repository write count remains zero and controllers retain drafts. |
| Hidden fields | Put unique sentinel text in every field; inspect all document nodes, page headers, semantics, filenames, share payloads, and preview thumbnails. Hidden sentinel values never leave the selection boundary. Include independently hidden duplicate-name attributes and hidden artwork (zero image reads). |
| Long content | Fit one line exactly, overflow by one line, one huge paragraph, many short fields, multiline names/values, empty lines, CJK, emoji/ZWJ sequences, RTL, and trailing newlines. Assert ordered contiguous line-range coverage and no source omission, overflow, or non-advancing pagination. |
| Fixed export | Vary viewport, app dark/light theme, device DPR, and text scale. Decode PNGs and assert fixed dimensions and the same document geometry; compare actual rendered fixtures where useful. |
| Artwork | No cover, relative path, historical absolute path, missing file, corrupt bytes, huge source, transparent PNG, EXIF-oriented JPEG, and animated source. Verify deliberate fallback and decode-size limits. |
| Multi-page batch | Do not invoke delivery until all PNGs exist. Inject failure on page 2, native save failure, and duplicate taps. Assert no partial external invocation and correct retry state. |
| Permissions/share | iOS real device: allow add-only, deny, deny then change Settings, share cancellation, share success/error, iPad popover. macOS built app: directory cancellation, complete multi-PNG copy, same-name collision avoidance, copy failure, sharing, and Debug/Release sandbox access; mock channel tests alone cannot establish OS permission behavior. |
| Cleanup/races | Close or regenerate during decode/encode; retain files during native consumption; clear stale unleased job directories; preserve current leased jobs; cleanup failure does not mask the primary result. |

Use the existing fake-repository and injectable-directory style. Add meaningful layout/selection/adapter tests and a small set of image fixtures, then run the repository’s normal Flutter tests and analysis. Build both iOS and macOS after native/plugin changes. Visual QA of at least one short card and a multi-page long card on the actual Flutter renderer remains necessary; an HTML concept preview is not rendering validation.

## Remaining decisions for the design review

- Main-card ratio/output pixel size, portrait-fit policy, and readable body type size.
- Whether a long main-card title/metadata is continued elsewhere or expanded within reserved space.
- Initial visibility defaults, and which fallback appears when the user hides all optional content.
- The main agent will select an open-source font from the product notes after visual review and verify its license. Until that selection is made, no bundled font or cross-device glyph-metric guarantee is assumed.

These are design/product choices. They do not require starting implementation to resolve.
