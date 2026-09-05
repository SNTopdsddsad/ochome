# User HEIC sample: Flutter codec verification

Date: 2026-09-05. Planning research only; no application/dependency/schema changes.

## Input and environment

- User-supplied source: `/Users/xuwudi/Downloads/IMG_0031.HEIC`, 3,739,250 bytes.
- Reference supplied by the main agent: `/Users/xuwudi/.codex/visualizations/2026/09/05/01a07006-8a1c-75a2-a09b-9bfbfbecc748/oc-sample-decoded.png`, decoded with libheif 1.23.2. The main agent observed that `sips` produced an apparently successful but black JPEG from this source.
- Executed the installed Flutter 3.47.2 / Dart 3.13.2 macOS **test engine**, using an external temporary test: `/private/tmp/ochome_heic_codec_probe_test.dart`.
- Both source HEIC and reference PNG were loaded directly through `ui.ImmutableBuffer.fromFilePath` → `ui.instantiateImageCodecWithSize` → first frame. The target callback preserved aspect ratio with a maximum dimension of 512. The test read actual RGBA bytes, encoded diagnostic thumbnails, and compared the two decoded pixel arrays.
- Command: `flutter test --no-pub --reporter expanded /private/tmp/ochome_heic_codec_probe_test.dart` from the project directory, using `/opt/homebrew/Caskroom/flutter/3.47.2/flutter/bin/flutter`. Flutter needed its ordinary SDK-cache stamp write permission to run. The probe passed.

## Observed result

| Measurement | Original HEIC through Flutter | Reference PNG through Flutter |
| --- | --- | --- |
| Intrinsic size reported by codec | 3024 × 4032 | 3024 × 4032 |
| Decoded thumbnail | 384 × 512 | 384 × 512 |
| Total pixels | 196,608 | 196,608 |
| Completely black RGB pixels | 0 | 0 |
| Nonzero RGB pixels | 196,608 | 196,608 |
| Fully opaque pixels | 196,608 | 196,608 |
| Mean RGB | 101.994, 102.851, 107.238 | 102.801, 102.663, 107.788 |

Mean absolute RGB difference between matching-size thumbnails: **1.3707869 on the 0–255 channel scale**. Both thumbnails were visually inspected and show the same upright, nonblack artwork. Flutter’s intrinsic dimensions already reflect the portrait orientation; rotating it again based only on the raw 4032 × 3024 metadata would be wrong for this path.

Temporary report: `/private/tmp/ochome-heic-probe-report.json`. Temporary thumbnails: `/private/tmp/ochome-heic-probe-source.png` and `/private/tmp/ochome-heic-probe-reference.png`. User image bytes/base64 and thumbnail assets were not written into the repository.

**Conclusion:** this original HEIC decodes correctly through the proposed Flutter codec path in this local test environment. The `sips` failure does not establish a Flutter decode failure, and it does not justify introducing a new HEIC decoder dependency.

## Existing picker behavior, verified from installed source

The locked platform implementations are `image_picker_ios 0.8.13+7` and `image_picker_macos 0.2.2+1` (see `pubspec.lock` and `.dart_tool/package_config.json`).

- iOS requests the current asset representation in `FLTImagePickerPlugin.m:104`, but this does **not** mean the Dart result preserves the original HEIC container. `FLTPHPickerSaveImageToPathOperation.m:128` begins `processImage`, which constructs a `UIImage` from the supplied bytes, then sends it to `FLTImagePickerPhotoAssetUtil.saveImageWithOriginalImageData`.
- `FLTImagePickerMetaDataUtil.m` recognizes JPEG/PNG/GIF in its MIME switch; HEIC follows `Other`. Its default conversion branch at line 92 uses `UIImageJPEGRepresentation`, while the default suffix is `.jpg` at line 12. Thus this installed iOS gallery path normally normalizes HEIC into JPEG before returning the picked file. This is code inspection, not an assertion that picking this exact sample was tested on an iPhone.
- macOS `image_picker_macos.dart:110` uses `fileSelector.openFile` and returns that file directly. It has no equivalent JPEG normalization; image options are documented in its source as ignored. A macOS-selected HEIC can therefore reach `CoverImagePicker.savePickedFile` unchanged.
- The app’s `lib/data/services/cover_image_picker.dart` copies the returned `XFile` bytes into `support/covers/` with its extension. It performs no additional decode/conversion. Historic/restored/raw HEIC covers still need the renderer’s existing normal decode/error path even if new iOS selections commonly become JPEG.

Installed-source root for the iOS files above: `/Users/xuwudi/.pub-cache/hosted/pub.dev/image_picker_ios-0.8.13+7/ios/image_picker_ios/Sources/image_picker_ios/`. macOS source: `/Users/xuwudi/.pub-cache/hosted/pub.dev/image_picker_macos-0.2.2+1/lib/image_picker_macos.dart`.

## Implementation implications and limits

1. Keep the planned bounded Flutter decode path. Treat codec-reported width/height as the source of truth for image fitting and downsampling; retain the same decoded image for preview and export.
2. Include this format/orientation case in manual iOS real-device validation, plus a macOS built-app check. **A passing headless Flutter test is not proof of iOS PhotoKit/image-picker behavior or a shipping macOS GPU path.** This test also does not guarantee every HEIC variant, HDR profile, or damaged file will decode.
3. Keep explicit decode-error handling. If a production platform actually fails a source, preserve the cover and show a replace/continue-without-artwork choice; do not silently export black content. Do not flag naturally black artwork as corrupt solely from pixel statistics—those statistics are diagnostic here because a known nonblack reference exists.
4. If a real-device failure is reproduced later, first compare the persisted file returned by the existing picker and test native normalization for that platform. Do not add a decoder library or change import quality speculatively. No fallback conversion or dependency upgrade was implemented in this research.
