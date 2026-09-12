# Role Asset Persistence

## Schema and ownership

- Schema version **8** adds `role_asset`: id, role_id, display name (initially the original name), kind,
  relative_path, bytes and created_at. `role_id` references `role(id)` with
  cascading delete and has an index; `relative_path` is unique.
- Schema version **11** adds `tags` as canonical JSON text with default `[]`.
  The migration probes the column because pre-v8 upgrades create the latest
  table definition and must not add it twice.
- Asset metadata belongs to `RoleAssetRepository`, separate from whole-role
  updates and description history. Only saved roles may import assets.
- Upgrade creates the new table and index without rewriting existing roles,
  covers, custom attributes or description history.

## Files

- `RoleAssetPicker.pickMedia()` enables `ImagePickerAndroid.useAndroidPhotoPicker`
  on the registered Android implementation before calling
  `pickMultipleMedia(requestFullMetadata: false)`. The mixed-media path in
  image_picker_android 0.8.13+21 otherwise uses `ACTION_GET_CONTENT`, regardless
  of the handset's recent Android version. Keep non-Android implementations and
  `pickFiles()` unchanged; cancellation returns an empty list and platform
  failures propagate into the existing page error/busy handling. Import platform
  APIs through explicit dependencies pinned to the already resolved versions.

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
- For deletion, scope the database query by role and asset id. Commit metadata
  deletion first, then delete the physical file (or defer while pinned). A failed
  database delete must leave the original file usable. Production mutations run
  through the dataset epoch gate; stale repositories cannot write after restore.
- Imported files use the shared bounded worker to copy and SHA-256 in one source
  pass, then remember the fingerprint only after successful publication. Hash
  caching is not a fresh file-health guarantee.
- Role deletion cascades metadata. Only referenced files enter v3 backups;
  unreferenced local copies are not made into cloud assets.

## Asset counts

```dart
Stream<Map<int, int>> watchAssetCounts();   // roleId -> count, unmodifiable
```

One grouped query (`SELECT role_id, COUNT(id) … GROUP BY role_id`) feeds the home
list's `N 份资产` meta through `roleAssetCountsProvider`
(`StreamProvider.autoDispose`, gated by `databaseSwitchProvider`, invalidated in
`closeDatabase`). Roles without assets are absent from the map — readers default
with `counts[id] ?? 0`. Do not open a `watchForRole` stream per list row: that
is N Drift streams fetching full rows to compute a length, all re-running on any
asset write.

| Event | Expected map |
|---|---|
| No assets | `{}` |
| Import 2 for A, 1 for B | `{A: 2, B: 1}`; C (no assets) absent |
| Delete one of A's | `{A: 1, B: 1}` |
| Delete role B (cascade) | `{A: 1}` |
| Mutation attempt on the emitted map | `UnsupportedError` |

## Backup and restore

The production contract is [Backup and Restore](./backup-restore.md). Format v3
uses full snapshot references, immutable file objects, exact SHA/length checks,
account-wide latest3 and dataset activation. The previous v2 single-slot sources
remain as compatibility fixtures only and must not be called by production UI.

Read-only legacy restoration supports schema 3–10, preserving ordered attributes,
role descriptions/revisions and assets; old snapshots without asset tables imply
an empty asset set. Unknown legacy file sizes must remain unknown in contents UI
until actual download verification. Pins protect preview/renderer/backup reads
from physical deletion and retired-dataset cleanup.

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

## Tags contract

```dart
const int roleAssetTagMaxCount = 8;
const int roleAssetTagMaxGraphemes = 16;
List<String> normalizeRoleAssetTags(Iterable<String> tags);
String encodeRoleAssetTags(Iterable<String> tags);
List<String> decodeRoleAssetTags(String source);

Future<void> updateTags({
  required int roleId,
  required int assetId,
  required List<String> tags,
});
```

`lib/data/models/role_asset_tags.dart` is the single validation owner. An empty
list is valid. Normalize each tag with `trim`, preserve first-seen order and
remove duplicates before enforcing at most 8 distinct tags. Reject an empty
individual tag and tags longer than 16 Unicode grapheme clusters with a
user-facing `FormatException`. Repository writes persist the canonical JSON
array immediately, scoped by both role and asset id, through `mutate` plus a
transaction. Missing/wrong-owner assets throw `StateError`; a canonical no-op
does not issue an update.

Database and backup reads use strict `decodeRoleAssetTags`: the payload must be
a canonical JSON string array within the same limits. Non-string values,
leading/trailing whitespace and duplicates are malformed stored data. Schema
3–10 backups migrate with empty tags; schema 11 backups validate tags before
review and preserve their order through restore.

| Input or state | Contract |
|---|---|
| `['  演出 ', '官方图', '演出']` | Persist `['演出', '官方图']` |
| `[]` | Valid; clears all tags |
| Empty/whitespace-only tag | `FormatException('标签不能为空')` |
| More than 16 grapheme clusters | `FormatException('每个标签最多 16 个字')` |
| More than 8 distinct normalized tags | `FormatException('每份资产最多 8 个标签')` |
| Missing asset or wrong role id | `StateError`; no other row changes |
| Malformed schema-11 backup tags | Reject before restore review |

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

## Video preview and duration cache

- First frames are derived data under the system cache's `video-thumbnails-v1/`,
  separate from asset originals and backup. Existing/restored videos generate
  their previews when first displayed; no schema column is needed.
- `VideoThumbnailService.thumbnailFor(File)` and `durationFor(File)` expose
  independently rebuildable thumbnail and duration metadata. Cache keys include
  the immutable asset filename, byte count and modification time. Duration uses
  a positive-millisecond sidecar in the same cache directory, so it survives
  service recreation without changing the asset schema or backup inventory.
- Reuse valid cached values and regenerate after cache eviction or a source
  change. Coalesce concurrent requests for the same file, serialize thumbnail
  decoding to limit memory use, and keep separate bounded session-only failure
  sets. An old cached thumbnail or a failed frame extraction must not prevent a
  readable video from returning its duration.
- The `com.xuwudi.ochome/video_thumbnail` channel's `firstFrame` method accepts
  absolute `videoPath` / `thumbnailPath` and `maxDimension` (320 for list covers).
  It returns a success boolean after writing a JPEG at time zero. Native code
  decodes off the UI thread and replies on the main thread. The channel's
  `duration` method accepts absolute `videoPath` and returns the media timeline's
  positive integer milliseconds, or null for missing, broken or unknown media;
  zero must never be presented as a real duration.
- Apple targets share `ios/Runner/VideoThumbnailHandler.swift` through an
  explicit macOS project reference. AVFoundation applies the track's preferred
  transform and bounds both dimensions, and reads the `AVAsset` duration.
  Android uses `MediaMetadataRetriever`, a scaled request on API 27+ and a
  proportional fallback on older APIs, plus `METADATA_KEY_DURATION` for time.
- Publish the cache image only after extraction succeeds; clean partial outputs
  on failure. Cache write failures may skip persistence but must not hide an
  already-read duration. Missing/unsupported media or platforms keep their
  generic icon and omit the duration badge.

`test/data/video_thumbnail_service_test.dart` covers cache reuse, invalidation,
coalescing, serialized work, positive duration and independent failure recovery.
The standalone native smoke test (`test/native/video_thumbnail_test.swift`)
creates a two-second red/blue video and verifies duration, first-frame color,
aspect ratio and portrait rotation.

## Validation

`test/data/role_assets_test.dart`: four kinds, role isolation, duplicate names,
temporary source removal, failed-copy/database rollback, scoped deletion,
missing files, unsafe paths, grouped asset counts following import / delete /
cascade, and v7 migration preserving existing content.
`test/data/icloud_backup_service_test.dart`: full asset round trip, restoration
without manifest/listing, truncated files, both-directory rollback, old backup
compatibility and unchanged-file upload skipping.

When building in-memory `XFile` fixtures on native platforms, use `path:`;
`name:` is ignored by the IO implementation of `XFile.fromData`.
