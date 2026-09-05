# Role-card export verification

Date: 2026-09-05. Scope: implementation of the user-approved fan-made character
sheet, preview/field selection, fixed PNG jobs and platform delivery.

## Automated results

| Check | Result |
|---|---|
| `flutter test --no-pub` | 173 tests passed after the SnackBar follow-up |
| Final `test/pages/role_card_export_page_test.dart` rerun | 11 tests passed after the license entry was finalized |
| `flutter analyze` | No issues found |
| Format check over changed Dart feature/page/test files | 13 files, no formatting changes needed |
| `git diff --check` | Passed |
| Trellis context validation | Passed |
| iOS/macOS handler SDK type checks and plist/pbxproj lint | Passed |
| Native file-helper XCTest verification | 13 cases passed in a temporary macOS command-line host; not a live Photos/sandbox UI run |

Flutter coverage includes immutable selection and independently selectable
duplicate attributes; hidden values and hidden-image zero-read behavior;
continuous CJK/emoji/newline pagination; complete long names/values; actual PNG
dimensions and image edges; deliberate resource/decode failure; editor drafts
and zero repository writes; selection races; delivery cancellation/error/retry;
repeated taps; leave-during-generation/delivery lifetime; temporary-file
retention/cleanup; and narrow large-text controls.

## Build results

- **iOS:** `flutter build ios --debug --no-codesign --no-pub` succeeded for the
  final implementation, producing `build/ios/iphoneos/Runner.app`.
- **macOS:** the ordinary Flutter build encountered the existing requirement
  for a development certificate because Runner has iCloud entitlements. Kept
  all existing capabilities. A final serialized
  `xcodebuild -quiet -workspace macos/Runner.xcworkspace -scheme Runner
  -configuration Debug -destination 'platform=macOS,arch=arm64'
  -derivedDataPath build/macos-unsigned CODE_SIGNING_ALLOWED=NO
  CODE_SIGNING_REQUIRED=NO build` exited successfully.
- **Android:** `flutter build apk --debug --no-pub` succeeded, producing
  `build/app/outputs/flutter-apk/app-debug.apk`. The sharing package requires
  AGP 8.12.1+, so the project moved from 8.11.1 to 8.12.1. The current Flutter
  migrator added `android.builtInKotlin=false` and `android.newDsl=false`.
  Existing Gradle 8.14/Kotlin 2.2.20/Java 17 built successfully. Flutter emitted
  future-minimum-version warnings; a broader AGP 9 migration is not part of this
  feature.
- Windows/Linux generated registrants reflect the new dependency. Those
  platforms were not built here; Linux image sharing is deliberately disabled.

An early concurrent Apple build/UI-test run switched shared native-assets
intermediates and produced a missing manifest error. This was an environment
race, not an application test assertion; serialized reruns passed. Future
validation should serialize Flutter tests and platform builds.

## Visual and actual-code probes

- Direct Flutter decoding of the user's original `IMG_0031.HEIC` was upright
  and nonblack. The failing `sips` conversion was not used by the app renderer;
  no extra decoder dependency was added. Details: `research/heic-sample.md`.
- The actual renderer produced a 1440 × 1920 度漪 name-only card and a
  five-page rich-layout test fixture. All pages used the same drawing document
  as the preview and preserved the selected text line ranges.
- Inspected main, continuation and last pages, plus light/dark export UI
  screenshots. Common CJK typography, the full source image, watermark and
  control layout were readable and within bounds. The UI screenshot harness
  used the bundled Sans family for readable host-test UI text only; the app's
  global font was not changed.
- A separate temporary probe loaded the system Apple Color Emoji at runtime:
  explicit template fallback produced visible moon/ZWJ emoji, without copying
  proprietary fonts into the repo. Measured ink around title/mixed-font line
  clip boundaries was zero. Test-font tofu before that probe was not claimed
  to be the production OS rendering.
- The export page's `开源许可` action opened `LicensePage`, and the shipped
  `Source Han Sans` notice was reachable in a widget-level UI probe.

User-artwork PNGs and host screenshots remain in the conversation's private
output directory, outside repository assets. No user photograph/base64 was
added to a committed template or fixture. Test character text in rich-layout
fixtures is explicitly diagnostic and not the character's actual setting.

## Review fixes

1. Removed the generic “已完成分享操作” toast: some plugin targets report success
   before a message/email is actually sent. The system UI owns that outcome.
2. Reused the continuation-name measurement/fit decision and disposed unused
   large candidates instead of retaining them per page.
3. Guarded vertical names using shaped line count/height, not only grapheme
   count; long joined names use the complete continuation path.

See `research/check-review.md` for the independent inspection scope.

## Remaining release acceptance

These are explicitly **not verified** by the tests/builds above:

- Signed iOS device: PhotoKit add-only allow/deny/settings retry, complete
  multi-page Photos import, native save failure and real iPad share anchoring.
- Signed macOS app: actual directory-picker cancellation, sandbox write
  acceptance/failure, resulting destination inspection and real share targets.
- Device-specific HEIC variants/rare Unicode fallback and downstream delivery
  after a share target is selected.

No simulator was already booted when checked. No real user photo-library
write, external message or social post was performed. No remote push or
deployment is included in this verification.

## Follow-up: shared floating feedback

The user found default `_snack` feedback unattractive. Added the shared
`showZaidangSnackBar` helper/content Widget and global floating-paper theme,
then migrated export, backup, editor validation/save failures and history
restore errors. Success uses the small brand check; errors/info retain ink.

Seven new widget tests passed. The follow-up full Flutter suite passed **173**
tests, and whole-project analysis found no issues. Long-scroll/accessible
messages persist until closed; the reviewer-identified 4/5-second premature
timeout was fixed and regression-tested.

Inspected actual native SnackBar screenshots in both themes and both success
and error states. Captures used runtime-like shadows (`debugDisableShadows`
temporarily false and restored afterwards), with the bundled Sans family only
for readable host-test UI text. Production UI font selection is unchanged.

The earlier platform build results cover the export/native/dependency
implementation. This subsequent Dart-only notification polish was validated
with the widget suite and analyzer; no new native or dependency changes were
made in this follow-up.
