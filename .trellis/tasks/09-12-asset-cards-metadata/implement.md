# Implementation

- [x] Inspect reference, data contracts and current UI; first card layout scaffold.
- [x] Add tag schema/model/repository validation and backup coverage.
- [x] Add Android/Apple real video duration extraction and caching.
- [x] Add editable tag UI, card pills and real duration badge.
- [x] Migrate existing ListTile-based UI tests to card keys and validate busy/rename/open guards.
- [x] Test narrow/large-text cards, metadata/tag editing, migrations and backup round trips.
- [x] Run flutter analyze, full flutter test, relevant native tests and Android debug build.
- [x] Install additive development update, verify connected Android, review all changed contracts and record validation.

## Validation — 2026-09-12

- `flutter analyze`: no issues.
- `flutter test`: 450 tests passed. After the final review fixes, reran the
  affected card, tag-dialog and asset-tab suites: all 28 tests passed.
- Data implementer additionally verified 64 focused tag/repository/migration/
  backup tests and all 171 `test/data` cases.
- Video service: 13 tests passed. Standalone Swift native harness verified a
  real two-second video and broken-media fallback. Android Kotlin compilation
  and final `flutter build apk --debug --no-pub` passed. Full Apple Runner builds
  were not run.
- `git diff --check`: clean. Independent reviewer found no remaining issues
  after explicit blank-add validation, visible StateError guidance, and removal
  of duplicate menu semantics.
- Connected RMX5010 (`9228187b`): additive APK installation succeeded; schema 10
  user data opened under schema 11. Existing three image assets display square
  previews, filenames, kind/size, local import dates, and independent menus.
  Tag editor opens and cancels correctly. No sample tags or media were saved to
  the user's role; persisted tag and duration cases use isolated test fixtures.
- Screenshots: `/tmp/ochome-assets-cards-device.png` and
  `/tmp/ochome-assets-tag-editor-device.png`.

## Review fixes

- Kept explicit empty Add/IME validation separate from Save with no pending tag.
- Preserved repository StateError messages instead of masking recovery guidance.
- Kept the menu announcement only in its tooltip semantics and updated existing
  accessibility checks accordingly.
- Token guard interpreted the index arithmetic inside an EdgeInsets expression
  as a numeric spacing literal; moved the conditional outside the constructor.

Implementation and validation are complete. The user explicitly requested local
commits. The module/feature batches are recorded in `commit-plan.md`; unrelated
initial dirty files remain excluded, and no push is requested.

## Follow-up: short SnackBars do not expire

- Cause: the helper passed `accessibleNavigation || needsScrolling` as `persist`.
  The connected Android had a GKD accessibility service enabled, so short notices
  were configured to stay indefinitely. Flutter's timer explicitly returns when
  `SnackBar.persist` is true.
- [x] Restrict persistence to scrollable long messages; prove short-message
  timeout and explicit close under accessible navigation in widget regressions.
- [x] Update shared feedback/backup specs, review and run applicable checks.
- [x] Build the updated Android development APK; install if device is available.

Validation: 9 focused SnackBar tests and the full 452-test suite passed;
`flutter analyze` and `git diff --check` are clean. Independent review confirmed
the behavior against Flutter 3.47.2's native SnackBar timer, close and live-region
semantics. `flutter build apk --debug --no-pub` succeeded.

The phone disconnected after reading its accessibility settings. ADB listed no
devices after the build, so the SnackBar follow-up has not been installed on the
phone. The earlier asset-card/tag/duration build remains the last installed
version. Updated APK: `build/app/outputs/flutter-apk/app-debug.apk`.

## Follow-up: compact vertical asset spacing

- [x] Reduce card gaps from 12 to 8px, vertical padding from 12 to 8px, and
  metadata gaps from 8 to 4px. Remove the duplicate list-top padding while
  preserving preview dimensions, typography and menu touch targets.
- [x] Run existing layout/action regressions, static checks and review.
- [x] Sync to the connected Android and verify the visible result. Include the
  pending SnackBar timeout fix in this update.

Validation: 38 existing card/tag-dialog/asset-page/SnackBar/token-guard tests
passed; `flutter analyze` and `git diff --check` are clean. Independent review
found no overflow, touch-target or duplicated-spacing issues.

The phone reconnected. Hot reload through its existing Flutter debug session
returned `Success`, applying both the spacing change and prior SnackBar fix
without restarting the app or changing user data. The role's current `美照` tag
and filenames remain intact. Device screenshots before/after are
`/tmp/ochome-asset-spacing-before.png` and `/tmp/ochome-asset-spacing-after.png`.
The last standalone APK predates this spacing adjustment; the running debug app
and workspace sources contain the latest changes.

## Follow-up: Android gallery opens the file manager

- Cause confirmed on API 36: the running picker was
  `com.android.documentsui/.picker.PickActivity` with `ACTION_GET_CONTENT` and
  `*/*`. The pinned plugin's mixed-media path uses that intent while
  `useAndroidPhotoPicker` defaults to false, rather than switching by API level.
- [x] Opt into the Android Photo Picker before mixed-media selection; declare
  platform API dependencies at their already locked versions.
- [x] Cover platform selection/options, cancellation and failure behavior; run
  service/page regressions, analyze and review.
- [x] Sync to Android and confirm that the gallery entry opens the system photo
  picker; cancel without importing sample media or changing user data.

Validation: all 4 new picker tests and the full 456-test suite passed;
`flutter analyze` and `git diff --check` are clean. The new explicit dependencies
retain exactly the prior locked versions; `flutter pub get --offline` changed
only their direct/transitive classifications. Independent review found no issues.

Hot reload succeeded on the existing Android debug session. The gallery action
now sends `android.provider.action.PICK_IMAGES` to
`com.android.photopicker/.MainActivity`; visual inspection confirmed the native
photo/album UI with image/video filters and multiple-selection checkboxes.
Cancelled the picker without selecting or importing any media. Generic file
selection remains unchanged. This is a Dart-only update using the existing
native plugin, so no reinstall was needed.
