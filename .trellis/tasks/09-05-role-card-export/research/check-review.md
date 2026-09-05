# Independent implementation review

Date: 2026-09-05. Reviewer: `trellis-check` (`role_card_check`).

Scope: current feature source, editor entry, Apple native handlers/registration,
dependency changes, fonts/provenance, and tests. This review did not run Flutter
or Xcode concurrently with the main validation work, did not modify user artwork
or font binaries, and did not commit anything. Test execution results belong to
the main validation record; reading a test is not evidence that it passed.

## Findings sent to the implementation owner

1. **Share-result copy (confirmed):** the installed `share_plus 13.3.0` macOS
   `SharePlusMacosSuccessDelegate.sharingServicePicker(_:didChoose:)` reports
   success as soon as a share service is selected. It does not wait for an email
   or message to be sent. The initial page text `已完成分享操作` therefore reports
   completion before the user can cancel that destination's composer. Use
   neutral target-opening text, or omit completion text for platforms with that
   result meaning. **Fixed and source-rechecked:** shared/cancelled/unknown
   results now produce no completion toast. The delivery status documents that
   the platform callback does not guarantee downstream delivery.
2. **Repeated long-name layout (confirmed code path):** the initial
   `_continuationHeader` creates and retains a newly measured full name on every
   continuation page, including when it does not fit and is never painted.
   A very long selected name is already rendered completely as a flowing body
   block. Repeating its unpainted title measurement for every page can amplify
   allowed input into substantial shaping work and retained memory. Reuse one
   measured heading/fit decision, or omit repeated name measurement after a
   known overflow. **Fixed and source-rechecked:** the renderer now caches the
   continuation-title fit result and immediately disposes unused candidates.
   Root's completed full suite includes the regression verification.
3. **Vertical-name fit (confirmed by renderer owner's raster/layout probe):**
   grapheme count alone does not bound shaped height. A long ZWJ sequence can
   count as a short name but shape into many visible lines; the initial sparse
   layout then clipped that name outside the page. **Fixed and source-rechecked:**
   the vertical rail now also requires the measured line count to match the
   grapheme count and the measured height to fit; otherwise the full name uses
   the regular header/continuation path. A regression test was added by the
   renderer owner and passed in root's completed full suite.

## Boundaries inspected without a further finding

- Draft entry reads strings and copies ordered attribute values synchronously;
  the immutable snapshot has no repository/controller reference. Entry is
  guarded against a pending role save and repeated push callbacks. Selection
  operates on snapshot indices, so duplicate custom-attribute names remain
  independently selectable.
- Hidden data is projected out before image loading, layout, preview semantics,
  and encoding. Generated filenames/share title are generic. Source artwork
  pixels may still contain text; the field picker explicitly explains this.
- `RoleCardDocument` is retained while an export is active, including after a
  route is removed; stale preparation results are disposed. Sequential PNG jobs
  are complete before delivery, remove incomplete jobs on failure/cancellation,
  and remain leased during native consumption. Shared jobs are retained for a
  bounded cleanup period. Cleanup errors do not retroactively invalidate a
  completed native save.
- Line fragments advance through measured paragraphs; oversized text/page
  limits fail explicitly before delivery. Overflowing basic fields and names
  are queued for full continuation. Coverage tests inspect contiguous line
  ranges; raster glyph-edge/emoji checks are separately owned by the renderer
  review and should be recorded with their actual results.
- iOS requests PhotoKit `.addOnly` only after an explicit save with validated
  files, uses one `performChanges` batch, preserves source files, and returns a
  saved result only after completion. The new handler is registered through the
  existing implicit-engine lifecycle and is included in target Sources.
- macOS uses a directory-only sheet, a user-selected read/write sandbox grant,
  unique exclusive staging, then a complete-directory move. Failure removes
  only that staging directory. Existing sandbox/iCloud entitlements are kept.
- Native source allowlists match the installed `path_provider_foundation 2.6.0`
  implementation: iOS uses `NSCachesDirectory`; macOS adds the app bundle ID to
  that cache directory. Both implementations normalize symlinks, require PNGs
  from one allowed job directory, and reject duplicates and missing files.
- `share_plus` supports files on the exposed iOS/macOS/Android/Windows targets;
  Linux is intentionally disabled. The package requires AGP 8.12.1+ and Gradle
  8.13+; the changes use AGP 8.12.1 with the existing Gradle 8.14 wrapper, Kotlin
  2.2.20 and Java 17 configuration.
- Local SHA-256 checks match every font and license hash documented in
  `assets/fonts/role_card/SOURCES.md`. Source assets are official unchanged
  binaries and include their OFL license texts. Unsupported Unicode and device
  fallback limitations are acknowledged in provenance; a pagination fixture
  containing an emoji alone does not prove a visible emoji glyph.
- The export AppBar now provides a font-license entry that loads the license
  registration before opening Flutter's LicensePage. Root's temporary real UI
  harness verified that Source Han Sans is visible there.

## Final verification handoff

Root reported the following completed checks after the fixes above:

- Full Flutter suite: **166 tests passed**, including long-name, ZWJ and emoji
  rendering regressions. Actual Chinese raster output and glyph clip boundaries
  were also inspected successfully.
- Follow-up page suite: **11 tests passed**; whole-project analysis passed again.
- Final iOS unsigned build succeeded. Final macOS one-time build with
  `CODE_SIGNING_ALLOWED=NO` exited **0**. These verify compilation, not real OS
  permission/entitlement behavior.

This brief closing source recheck found no additional definite defect. The
Android debug build is still in progress at this handoff; no Android build
success is claimed here. No build/test commands were repeated by this reviewer.

## Remaining verification limits

- A normal local macOS build is currently blocked by existing iCloud signing
  requirements without a development certificate. A no-signing compile check
  cannot establish entitlement or sandbox behavior. Do not remove the existing
  permissions to make that check pass.
- A properly signed iOS build on a real device still needs add-only permission
  allow/deny/settings-retry, complete multi-page Photos import, and save-error
  checks. iPad needs the real system share popover/orientation check.
- Signed macOS runtime needs folder-picker cancellation, write-denied/copy
  failure, completed destination inspection and a real share target test.
- Device-specific HEIC decoding, non-bundled glyph fallback and downstream
  share-target behavior remain outside mocked-channel or host renderer proof.
- Android/Windows file-sharing capability matches the dependency's documented
  matrix; Apple builds alone do not verify those platform builds/runtimes.

## Feedback adjustment: floating paper notices

Read-only follow-up review covered `zaidang_snack_bar.dart`, the shared
`snackBarTheme`, and the four page integrations. No Flutter tests/builds were
run by this reviewer. The theme uses the app's paper/ink tokens; the native
ScaffoldMessenger, close control and live-region wrapper remain in use. The
four page call sites preserve their mounted/error checks. No definite issue
was found in the desktop width cap, mobile safe-area behavior or latest-message
queue replacement.

One accessibility/long-message issue was forwarded to root: the initial helper
does not set `SnackBar.persist`, so the current Flutter 3.47 SDK defaults it to
`action != null`, which is false for this close-icon-only notice. The SDK timer
only checks `persist`; accessible navigation or scrolling does not stop the
4/5-second timeout. Thus a long scrollable error still disappears while a user
is reading it, including under accessible navigation. At minimum, persist
while accessible navigation is enabled; messages that actually need scrolling
also need enough reading time or manual dismissal. Resolution is pending in
this initial follow-up record. The root's six notice tests and page regression
results are not inferred from this source-only review.

## Final main-runner build update

After the review record was closed, the main runner completed the serialized Android debug APK build successfully (`flutter build apk --debug --no-pub`). This adds compile coverage, not Android runtime sharing or Apple permission acceptance. Final outcomes are recorded in `../verification.md`.

## Floating-feedback finding resolution

The helper now sets persist for accessibleNavigation and messages measured to exceed the scrollable body height. Shared measurement style/scaler is used instead of text length. The main runner verified the new persistent-reading tests, all 7 SnackBar cases, the full 173-test suite and analysis, and inspected runtime-shadow light/dark screenshots. No native/dependency changes were made for this follow-up.
