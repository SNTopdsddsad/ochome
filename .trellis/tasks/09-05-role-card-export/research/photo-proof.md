# Actual-photo composition review

Status: this cold-mat/bottom-caption proposal was subsequently rejected by the user (“可真丑呀”). The current direction is the user-selected 同人设定纸; see `../design.md` and `setting-sheet-template.html`.

2026-09-05. The user supplied `IMG_0031.HEIC` as the OC sample and answered the name question with **度漪**. No short identity or biography was supplied.

## Composition response

The source is a portrait photo of a complete poster: blue-black background, white clothing, existing headings/name and visible watermarks. The main-card proposal was revised from a top name masthead to **large intact image + narrow bottom name/stamp caption**, preserving the original artwork/photo text and image aspect ratio. Cool-white mat and blue-black typography fit this sample; warm mat, top/bottom name placement and serif/sans lettering remain optional design-review controls.

There are no invented role attributes in this proof. The first abstract “白鸦” placeholder character is not used for this user's sample. No artificial redraw, background removal, watermark removal or text removal was applied. The input file was not modified.

## Preview handling

- Direct `view_image` cannot display this HEIC container. Host `sips` conversion produced a black JPEG, so `heif-convert` decoded an upright PNG; a smaller JPEG display copy was then embedded locally in the conversation preview.
- The actual-photo HTML stays under the thread visualization directory as `role-card-photo.html`. It is below 1 MB, uses no external upload/fetch and contains only a local display copy.
- `photo-layout-template.html` stores the markup with `__OC_IMAGE_DATA_URL__` as an explicit image marker. User photo bytes/base64 are not copied into the repository or bundled as an app asset.
- The true Flutter HEIC decoder was separately tested successfully; see `heic-sample.md`. The black utility conversion is not treated as a failure of the planned app codec.

## Verification

- Inspected the rendered main card at approximately 736 and 320 CSS pixel host-content widths. Full image remains visible, bottom text/stamp fits and the original source markings are preserved.
- Verified the show-name control removes the generated name and generated name-bearing preview labels; generic artwork alt text does not reintroduce it. Existing source-image lettering naturally remains. The preview explains that boundary.
- Optional host Tweak controls are guarded; standalone inspection covered the default image-first cool-white layout and the ordinary show-name checkbox.
- Reset the temporary browser viewport after inspection. This is a composition preview, not a completed Flutter export feature or an iOS delivery test.

The task remains in planning for review of this actual-photo layout before implementation.
