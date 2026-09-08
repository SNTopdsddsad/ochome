# Follow-up: renamed asset title in the iOS preview

## Cause and intended behavior
The asset list reads the editable database name, but `RoleAssetOpener` passes
only the immutable stored path to `open_file`. Its iOS implementation creates
`UIDocumentInteractionController` without setting `name`, so UIKit derives the
preview title from the internal filename. The user reported this on a video
after testing the renamed asset on their iPhone.

Keep the same system preview and original file URL, but explicitly supply the
current asset name. This also covers audio/documents using the same iOS route.
Do not copy large media, rename stored files or migrate database records.

## Contracts

- Dart: `Future<void> RoleAssetOpener.open(File file, {required String displayName})`.
- iOS channel: `com.xuwudi.ochome/role_asset_preview`, method `openPreview`,
  arguments `{path: String absoluteFilePath, displayName: String}`.
- Native validates nonempty arguments/readable file, creates and retains a
  `UIDocumentInteractionController(url: originalURL)`, and sets `name` to the
  passed display name before presenting the preview.
- A successful request completes with `true` when the preview closes. If
  `presentPreview` cannot preview this file, clean up and return `false`; Dart
  then calls the existing `OpenFile.open` fallback, retaining its share/open
  options. Keep one active request; busy/missing file/invalid arguments/no
  presenter return a useful `FlutterError`. Never leave a Future pending on
  immediate failure.
- UIKit interaction and Flutter result delivery are on the main thread.
  Resolve at most once and retain the controller until dismissal; do not allow
  a stale callback to end a later request.
- iOS uses this explicit-title route. Other platforms retain their current
  `OpenFile.open` behavior; this change does not promise control of a third-party
  application's own title or embedded media metadata.
- Preserve the UTI inferred from the original URL across setting the display
  name, so title changes cannot alter file-format routing.
- The page passes the latest `asset.name`, keeps `_busy` through preview
  dismissal, and shows meaningful channel/open errors through the existing UI.

## Verification matrix

| Scenario | Expected |
|---|---|
| Rename then open video/audio/document | Current name handed to iOS controller; original URL unchanged |
| Same immutable file opened after another rename | New request receives new title |
| Pending native preview | Parent actions remain blocked until dismissal |
| Missing file / invalid arguments / cannot present | Error and recoverable parent controls |
| Duplicate or stale dismiss callback | At most one result, no effect on a later preview |
| Other platform | Existing opener behavior and errors retained |

Good: set `controller.name = displayName` while keeping `controller.url`.
Base: open an imported video. Bad: create a full temporary copy just to give it
a user-facing filename, or only update the list label.

Tests cover Dart payload/error/wait behavior, page rename→open integration and
native controller title/URL/lifecycle. Compile and run native tests when the
available simulator allows, then rebuild and launch the user's iPhone in profile.

Reference: Apple's document interaction controller `name` property and local
open_file_ios 1.1.0 source; `QLPreviewItem.previewItemTitle` is an alternate
explicit-title API, but the existing document preview does not require switching
to a different viewer implementation.
