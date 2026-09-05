# Character-card export design

Status: approved on 2026-09-05. The user accepted the fan-made character-sheet composition (“这个我喜欢！”) and asked how to implement its export. Implement the described main-card/continuation flow.

## Product flow

`Role editor → 导出角色卡 → choose visible content / preview every page → 保存图片 or 分享`.

The export entry snapshots the **currently edited values**, including a newly picked cover and unsaved ordered attributes. It does not call the role save method, create/update a role, change history or pop the editor. Returning restores the same editing session. Disable entry during role save and guard repeated pushes. A later list shortcut could use a saved-data snapshot, but is not needed for this release.

Use a compact preview page with page swiping and a visible page count. Keep field selection in a separate sheet/panel so the card remains the main surface. Fixed fields and each individual custom attribute are selectable. The bottom actions show the actual destination: iOS “保存图片”, macOS “保存到文件夹”, plus “分享”. The output is a group of PNG images, not a generated PDF or role-data archive.

Proposed privacy defaults: select the cover, name and populated short basic fields; leave description and custom attributes off until selected. Empty optional fields have no empty rows. The concept preview starts with example fields selected only to demonstrate the two-page design; those mock defaults are not the proposed shipping privacy defaults.

## First template: 同人设定纸 (current proposal)

Ratio **3:4**, output **1440 × 1920 PNG per page**. Use one fixed logical design size of 480 × 640, exported at 3×. Output colors remain stable in app light/dark mode.

The user rejected the cold-white mat plus bottom name caption and chose a **fan-made character sheet with clear information sections**. The previous framed-poster proof is superseded; do not implement it as the approved direction.

Main card, when selected content is sufficiently populated:

- A strong name heading and quiet template label establish the sheet's typography. Use ink-blue hierarchy and restrained rules on warm paper; avoid a separate bottom nameplate.
- Artwork takes roughly two thirds of the body width; a narrower right column holds selected short basic information. A bottom row holds selected setting/custom-attribute sections or the start of long sections.
- Show the entire selected image with contain-fit, respecting its aspect ratio and original lettering/watermarks. No automated cutout, redraw or background removal. The supplied poster is not an isolated transparent character image; do not design overlap effects that would require one.
- Use actual nonempty selected values. The proof's “—” and ruled blanks only explain region placement and are never filler text added to a real export.
- Keep the image as the dominant body block. Long values/setting sections continue onto matching pages at a readable size; the main sheet must not become a wall of tiny text.

Sparse-data adaptation:

- Currently only “度漪” and the artwork are supplied. Omit empty information/story regions and expand the artwork to about 78–82% of the body width, with a narrow vertical name rail.
- This is an adaptive state of the same template, not a second shipping template. Do not make the actual export look like an empty form merely to preserve the section map.
- The review prototype has separate “设定纸分区” and “仅现有资料” views to distinguish layout scaffolding from the actual available data.

Both states use a small corner “崽档” seal and consistent sheet typography/rules. Page numbers and continuation hints appear only when real content creates continuation pages; no fake archive IDs, author credits or role facts.

Continuation pages:

- Repeat the selected name only if it is visible; hiding it removes it from every header.
- Group selected description/custom-attribute content with short section labels, matching paper and typography, and consistent page numbering.
- Use a stable readable font size, paragraph spacing and margins. Keep headings with a following line; continue long sections on as many pages as necessary.
- Long selected names or basic values that cannot fit their main-card slots must be fully represented on a continuation page. The main card can explicitly point to continued content, but must not silently use ellipses or omit the full value.

The current sheet proposes warm paper (`#F4F1E9`), ink blue (`#223B56`) and quiet blue-gray rules (`#B7C0C8`), with the note's seal red. The populated-layout proof groups artwork and basic information within a deep-blue body area (`#1B2B42`), using light type there to connect to the supplied image's tone. The sparse-data state omits that information band along with empty regions. A silver/ink-blue paper tone is available only as a design-review comparison. These are **template colors**, not app tokens or a confirmed multi-template/customization feature.

The user supplied `/Users/xuwudi/Downloads/IMG_0031.HEIC` and confirmed the role name **度漪**. It is a portrait photo of a finished poster with a dark blue background, white costume, embedded titles/name and visible watermarks. The sheet retains the full image. No identity, race or biography is inferred from the printed poster text. The note's ten reference titles remain unseen and are not claimed as reproduced references.

The current actual-photo proof is `role-character-sheet.html` in the conversation's visualization directory. `research/setting-sheet-template.html` records its literal layout with an image marker; `photo-layout-template.html` is the rejected earlier proof. User photo bytes are not embedded in repository assets or committed fixtures. These are composition studies, not the implemented Flutter export path.

Typography: select a note-approved open-source font during visual review, then verify its upstream license and bundle the necessary font/license assets. Do not depend on OS fallback metrics for final pagination. A single family is preferable if it can support the chosen title/body hierarchy without excessive font payload. Final font choice and artwork balance remain review items.

## Visibility and snapshot boundaries

Use an immutable `RoleCardSnapshot` copied synchronously before asynchronous work. It contains strings, the cover path and an immutable ordered attribute list, without a repository/provider reference.

`RoleCardSelection` uses fixed-field identifiers and attribute snapshot indices/IDs, never names as keys (duplicate names are valid). Project the snapshot into `SelectedRoleCardContent` **before** layout, semantics, image loading or sharing. The painter/platform adapter should not receive hidden values.

Generic filenames such as `zaidang-card-<job>-001.png` and a generic share title avoid name leaks. Do not attach role text as a separate share message. Hiding artwork means no file reads or decodes. Regenerating selection invalidates all old previews/jobs; stale asynchronous results cannot replace current content or be delivered externally.

The supplied poster exposes an important boundary: hiding the structured name cannot erase lettering already in the artwork. Explain this next to field selection, and retain image pixels/watermarks. Do not claim automatic redaction or introduce OCR/background removal. Generated image alt text should be generic and never reinsert a hidden field value.

## Renderer

Implement a small feature-specific document pipeline, not a general template editor:

`Snapshot + Selection → SelectedContent → RoleCardDocument → shared page painter → preview / PNG encoder`.

- Explicit template dimensions/styles/colors/locale/text scale. `CustomPaint` preview scales this same drawing document; `PictureRecorder` and a fixed Canvas scale produce the final PNGs.
- Measure paragraphs once using `TextPainter` without `maxLines`/ellipsis. Partition complete visual lines using their baselines/ascent/descent into contiguous page segments. Paint the same paragraph translated/clipped per segment; do not slice raw UTF-16 strings to simulate pagination.
- Require advancing line ranges and complete coverage. Report a clear resource/layout failure before delivery if input cannot be processed; do not impose a silent page cap.
- Resolve cover files with existing `CoverPath`. Decode once at an appropriate bounded size, preserve aspect ratio/transparency/orientation, reuse the image and release codec/buffer/image resources deliberately.
- Include the user's HEIC orientation case in verification. The host Flutter test engine correctly decoded it as portrait 3024×4032; system `sips` conversion produced a black image in the same environment. Do not infer a production decode failure or add a new library from that utility failure. See `research/heic-sample.md`; iOS device verification remains separate.
- Missing cover is a deliberate text-led variant of the same template. If a selected image is missing/corrupt, show the problem and require the user to replace or hide it before exporting; no silent empty-image success.
- Encode one page at a time, write a complete job of numbered PNGs into app-owned temporary storage, release each raster promptly and only enable delivery when all expected pages are ready.

## Delivery and platform boundaries

Proposed implementation, based on the primary-source research in `research/export-pipeline.md`:

- iOS: a separate narrow PhotoKit MethodChannel saves all PNGs in one `performChanges` transaction. Request `.addOnly` permission only after the user taps save; add the appropriate usage description. No new minimum OS is needed for the project's iOS 15 target.
- macOS: a native directory picker with `user-selected.read-write`, then stage/copy the complete job to a unique subdirectory and rename it on success. Preserve the app sandbox and avoid broad Pictures/Downloads permissions. Cancellation is not failure.
- System sharing: pin the verified compatible `share_plus` version during implementation; provide PNG files and an iPad origin rectangle. Share cancellation/unknown completion must not claim a social post succeeded. Recheck Android build compatibility before touching dependency configuration; unsupported save platforms still need deliberate UI behavior.

Use an injectable delivery service that reports saved/cancelled/permission-denied/failed distinctly and reports the actual desktop destination. Validate all files before starting native save. No actual external delivery is performed as part of planning or automated tests.

Jobs own their temporary files and hold them while native save/share consumes them. Avoid deletion on route pop or immediately when a share sheet opens. Clean incomplete jobs and expire old unleased jobs on later exports. Cleanup errors must not turn a successful save into a reported failure.

## Files and responsibilities

- `lib/features/role_card/`: snapshot/selection/content models, document/layout, painter, image loader, PNG job generation, delivery adapters and reusable preview/field-selection widgets.
- `lib/pages/role_card_export_page.dart`: route and interaction composition, using existing app tokens for chrome.
- `lib/features/role_card/role_card_delivery.dart`: injectable save/share interface and MethodChannel/plugin implementation.
- `lib/pages/role_create_page.dart`: one guarded entry that snapshots current drafts.
- iOS/macOS native handlers, registration, usage descriptions/entitlements and project source entries.

Keep this single feature module organization, without duplicate service layers. No database migration, persistence of export configuration, paywall, OCR, auto-color extraction, extra templates or avatar generation.

## Review gate

The composition and use case have been approved. Use Source Han Serif for the strong name heading and Source Han Sans for readable data/body copy, verifying and bundling upstream font/license assets before rendering. Use the proposed conservative field defaults and current-draft snapshot behavior; production code must omit the proof's empty placeholder rows.
