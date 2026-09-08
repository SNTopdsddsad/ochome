# Role Asset Persistence

## Schema and ownership

- Schema version **8** adds `role_asset`: id, role_id, display name (initially the original name), kind,
  relative_path, bytes and created_at. `role_id` references `role(id)` with
  cascading delete and has an index; `relative_path` is unique.
- Asset metadata belongs to `RoleAssetRepository`, separate from whole-role
  updates and description history. Only saved roles may import assets.
- Upgrade creates the new table and index without rewriting existing roles,
  covers, custom attributes or description history.

## Files

- Store immutable copies in Application Support `role_assets/<random-id>.<ext>`.
  Never persist picker temporary paths. Names shown in the UI are stored
  separately, so duplicate source names cannot overwrite one another.
- Copy `XFile.openRead()` as a stream into a hidden pending file, check its
  expected length, then rename it to the final path. Close the output sink on
  success and failure; preserve the original copy error if closing an already
  failed sink also throws. Avoid loading full videos into memory.
- Copy the entire batch before registering it in one database transaction.
  If any copy or registration fails, clean up all new files from that batch.
- Validate relative paths as a flat file under `role_assets/`; refuse absolute,
  traversal, nested or hidden paths. Missing files must report an error.
- For deletion, scope the database query by both role id and asset id. Rename
  the file aside first and roll it back if metadata deletion fails. A hidden
  cleanup file must never be backed up. Role deletion cascades metadata; backup
  only includes referenced files, so unreferenced local copies are excluded.

## Backup and restore

- Manifest format **2** adds `assets` alongside `covers`; old manifests without
  assets remain readable. The SQLite snapshot is authoritative for asset paths
  and sizes, so restoration does not depend on manifest presence or cloud listing.
- Backup only uploads files referenced by the snapshot. Reject missing or
  size-mismatched local assets, and skip re-uploading immutable files of equal
  remote size. Prune old remote assets only after database/manifest upload.
- Download referenced assets into the restore staging directory and verify exact
  byte counts before touching live data. Zero-byte documents are valid.
- Replace covers, assets, then SQLite; if replacement fails, roll back both file
  directories. Restoring a pre-v8 backup uses an empty asset directory and the
  ordinary schema migration, preventing newer local assets attaching to old ids.
- `LocalFileStore` supplies shared directory replacement/rollback behavior;
  `CoverStore` and `RoleAssetStore` choose their own directory names.

## Rename contract

### Scope and signature

Renaming an imported asset is an immediate metadata operation, independent of
the role form. No schema or backup-format version change is needed.

```dart
Future<void> rename({
  required int roleId,
  required int assetId,
  required String baseName,
});
```

### Persistence and validation

Read the asset using both ids, trim the requested basename and retain the
extension identified by immutable `relativePath`, preserving display suffix
case when it matches. Update only `name`; never rename
the immutable stored file or the user's source. Preserve kind, path, size,
creation time and ordering. A watched asset list must reflect the new name.
Use one domain-owned validation policy for both the editor and repository.
`RoleAssetName(name: ..., relativePath: ...)` in
`lib/data/models/role_asset_name.dart` owns name splitting and validation.

The stored suffix is the stable format authority. If it is empty, the complete
display name stays editable: `README` → `draft.v2` → `final` yields `final`.
Do not reinterpret a dot added to a display name as a protected extension on
the next rename. Imports with suffixes outside the store's safe 1–12 ASCII
alphanumeric rule likewise have no stored extension and keep the whole title
editable.

| Input or state | Contract |
|---|---|
| `draft.PNG` with basename `新立绘` | Save `新立绘.PNG` |
| Leading/trailing spaces | Trim before comparison and persistence |
| Unicode, spaces within a name, interior dots | Accept |
| Empty/whitespace-only basename, `.` or `..` | Reject with `FormatException` |
| Slash, backslash or control characters | Reject with `FormatException` |
| Same resulting name | No database update |
| Missing asset or wrong role id | Fail with `StateError`; do not modify another role |
| Extensionless stored file | Entire name remains editable, including added interior dots |
| Persistence failure | Propagate to the editor; retain the previous metadata |

### Examples and verification

Good: rename `draft.PNG` to `新立绘.PNG` while the asset path and bytes stay
identical. Base: an unchanged submission succeeds without issuing an update.
Bad: changing `relativePath` to match the display name breaks immutable-file
identity and backup reuse.

```dart
// Wrong: rename physical storage to match a user-facing label.
await file.rename(newDisplayName);
// Correct: let the repository preserve extension and scope the name-only write.
await repository.rename(roleId: role.id, assetId: asset.id, baseName: '新立绘');
```

Repository tests must verify role isolation, normalization/invalid input,
unchanged submissions, repeated renames of extensionless files, extension
handling, stream updates and unchanged file
contents/identity. The SQLite snapshot carries the renamed display name through
backup/restore; an unchanged asset file remains eligible for upload reuse.

## Named iOS file preview

### Scope and signatures

The native iOS preview title must follow asset rename independently of immutable
file storage. The default `open_file` API accepts only a path, so its default
preview otherwise exposes the random internal filename.

```dart
Future<void> RoleAssetOpener.open(File file, {required String displayName});
// MethodChannel: com.xuwudi.ochome/role_asset_preview
// Method: openPreview
// Arguments: {path: absoluteFilePath, displayName: currentAssetName}
// Result: true after dismissal, false when native preview is unsupported.
```

### Native and fallback contract

- Use `UIDocumentInteractionController` with the original file URL. Set `name`
  after creating the URL-backed controller and retain the URL-inferred UTI.
  Do not copy or rename media just to change the system preview title.
- Retain controller, presenting view controller and one pending callback through
  the native preview. Run UIKit operations/results on the main thread; finish
  once on dismissal and ignore stale controller callbacks.
- A `false` result releases the native pending state and lets Dart invoke the
  existing `OpenFile.open` fallback for unsupported files. Other platforms
  continue using their existing opener. Third-party app titles or media-embedded
  metadata are outside this iOS preview-title contract.
- Invalid arguments, missing files, busy state and a missing presenter fail
  visibly. Never leave the Future pending after immediate failure. The Dart
  page retains its normal `finally` cleanup and mounted guards.

### Validation and examples

| State | Expected |
|---|---|
| Same path, newly renamed video/audio/document | Controller receives latest display name and same URL |
| Preview open | Dart Future remains pending and parent actions stay disabled |
| Preview dismissed | Complete once; next preview can open |
| Unsupported native preview | Return false and use existing fallback |
| Invalid/missing/busy/no presenter | Useful error, recoverable state |
| Old/duplicate dismissal | Does not complete a newer request |

Good: `controller.name = displayName` while its URL remains the stored asset.
Base: open one saved video. Bad: pass only the stored filename, or copy an entire
large video into a renamed temporary file before each open.

Tests must assert the page's rename→open payload, service result/error/fallback
behavior and native controller title/URL/UTI/lifecycle. Verify the actual system
preview title with a test fixture; a mock payload alone cannot prove UIKit's
displayed result.

## Video preview cache

- First frames are derived data under the system cache's `video-thumbnails-v1/`,
  separate from asset originals and backup. Existing/restored videos generate
  their previews when first displayed; no schema column is needed.
- Cache keys include the immutable asset filename, byte count and modification
  time. Reuse nonempty cached files and regenerate after cache eviction or a
  source change. Coalesce requests for the same file and serialize decoding to
  limit memory use; keep a bounded session-only failure set.
- The `com.xuwudi.ochome/video_thumbnail` channel's `firstFrame` method accepts
  absolute `videoPath` / `thumbnailPath` and `maxDimension` (320 for list covers).
  It returns a success boolean after writing a JPEG at time zero. Native code
  decodes off the UI thread and replies on the main thread.
- Apple targets share `ios/Runner/VideoThumbnailHandler.swift` through an
  explicit macOS project reference. AVFoundation applies the track's preferred
  transform and bounds both dimensions. Android uses `MediaMetadataRetriever`,
  a scaled request on API 27+ and a proportional fallback on older APIs.
- Publish the cache image only after extraction succeeds; clean partial outputs
  on failure. Missing/unsupported media or platforms keep their generic icon.

`test/data/video_thumbnail_service_test.dart` covers cache reuse, invalidation,
coalescing, serialized work and failure recovery. The standalone native smoke
test (`test/native/video_thumbnail_test.swift`) creates a red/blue two-frame
video and verifies first-frame color, aspect ratio and portrait rotation.

## Validation

`test/data/role_assets_test.dart`: four kinds, role isolation, duplicate names,
temporary source removal, failed-copy/database rollback, scoped deletion,
missing files, unsafe paths and v7 migration preserving existing content.
`test/data/icloud_backup_service_test.dart`: full asset round trip, restoration
without manifest/listing, truncated files, both-directory rollback, old backup
compatibility and unchanged-file upload skipping.

When building in-memory `XFile` fixtures on native platforms, use `path:`;
`name:` is ignored by the IO implementation of `XFile.fromData`.
