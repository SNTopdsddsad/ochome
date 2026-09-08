# Verification — 2026-09-08

## Completed

- `flutter analyze`: passed.
- `flutter test test/data/role_assets_test.dart test/data/icloud_backup_service_test.dart test/pages/role_assets_tab_test.dart`: 46 passed (12 repository, 19 backup, 15 page tests).
- Independent read-only review and `git diff --check`: passed after fixing mutable-title extension inference.
- Temporary light/dark dialog renders: reviewed at mobile size with a 300px keyboard inset; text, field, extension information and actions fit. Screenshot-only test code was removed. Preview files are ephemeral `/tmp/ochome-asset-rename-light.png` and `/tmp/ochome-asset-rename-dark.png`.
- `flutter run --profile -d 00008150-000A42A93688C01C -t lib/main.dart --no-pub`: Xcode build completed in 29.9s, installed and launched on 徐无敌的iPhone; Dart VM Service became available. The running process remains available for user testing.

## Covered behavior

- Role-scoped name-only updates, watched list refresh and persistence.
- Unchanged file bytes/path, kind, ownership, creation time and ordering.
- Protected stored suffix/case; repeated renames of extensionless, dotted and unusual-suffix filenames.
- Invalid names, no-op unchanged names, failed database writes and retry.
- Overflow menu deletion, cancellation, save pending guards and live parent save-state checks before rebuild.
- Renaming cannot change preview/open routing; unsaved role form state is retained.
- Renamed metadata survives backup/restore while unchanged files skip upload.

## Scope and follow-up

User confirmed a mix of reference images, video and audio. The separate
`asset-experience-ideas.md` prioritizes usage tags and quick video/audio preview;
those suggestions are not implemented in this change.

No commits were made. Existing `ios/Podfile.lock` and `devtools_options.yaml`
changes were present before this task and were preserved. Actual user-data
renaming was not performed during device installation; the feature is ready
for the user's in-app check.

## Follow-up: native preview title

The user found the video preview still showed an internal filename. The list
had been renamed correctly, but the default `OpenFile.open` call received only
the stored path. Added a narrow iOS preview channel setting
`UIDocumentInteractionController.name` to the current asset name while retaining
the original URL and its inferred UTI. No media copies or storage renames.

- `flutter analyze`: final code passed (8.5s).
- Relevant Dart suite: 58 passed; after final native error-code alignment,
  the 8 opener tests passed again.
- `xcodebuild test` on the iOS 26.4 simulator: all 11 RunnerTests passed,
  including 6 native preview title/URL/UTI/lifecycle/error/main-thread cases.
  Result bundle: `/tmp/ochome-native-preview-tests.xcresult`.
- Actual UI check via Simulator: a fresh test-only installation received one
  synthetic 2-second MP4. Renamed `原始视频.mp4` through the asset menu to
  `Title sync verified.mp4`, opened the system preview, and inspected the
  rendered header plus accessibility label: both showed
  **Title sync verified.mp4**. Closing restored Save/Add/filter/menu controls.
- A read-only database/file check confirmed the display name changed while
  `role_assets/internal-preview-fixture.mp4`, its 2979-byte size and SHA-256
  content remained unchanged. This fixture was confined to the newly installed
  simulator; no user iPhone asset was renamed for testing.
- Third-party applications reached through fallback sharing/opening still
  decide their own titles. The verified fix is the in-app iOS system preview.
- Final iPhone deployment: profile build completed in 39.4s. `flutter run`
  could not discover its Dart VM Service, so the same completed profile app
  was installed explicitly with `devicectl device install app` and launched
  with `device process launch --terminate-existing`. Both succeeded; the
  running process matched the newly installed bundle. The app is running in
  profile mode without a Flutter debugging-service attachment.
- Shut down the temporary simulator used for the visual check. No commits.

## Commit completion

User requested commits on 2026-09-08. Application: `baa2872`; iOS: `e6f1cd6`; tests: `1701728`. Task and specifications are archived in the accompanying Trellis commit. The prior uncommitted-state notes above describe the implementation checkpoints. No push was requested or performed.
