# Role Asset Persistence

## Schema and ownership

- Schema version **8** adds `role_asset`: id, role_id, original name, kind,
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
