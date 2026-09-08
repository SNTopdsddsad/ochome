# Rename contract

## Data boundary
Add `Future<void> rename({required int roleId, required int assetId, required String baseName})` to `RoleAssetRepository`. Look up the current asset by both ids. Trim the supplied basename, preserve the extension identified by immutable `relativePath` (keeping the display suffix case when it matches), and update only `name`. The immutable `relativePath`, bytes, kind, id and createdAt remain unchanged. No schema or backup format change is needed. Same-name submissions are no-ops. Missing/wrong-role assets fail with a useful StateError.

An empty stored suffix means the complete display name is editable, including names with interior dots. `README` → `draft.v2` → `final` must produce `final`, not `final.v2`. Import strips unusual suffixes outside its safe 1–12 ASCII-alphanumeric rule; those files likewise have no protected extension. Do not infer a newly protected extension from a mutable title.

Reject empty basenames, `.`/`..`, slash, backslash and control characters with a FormatException. Unicode and interior dots are permitted. UI and repository must agree on validation without parallel inconsistent policies. Extensionless filenames remain supported. Avoid manipulating actual asset files or source files.

## UI boundary
Replace the trailing delete icon with an accessible overflow menu containing Rename and Delete. Keep tap-to-open behavior. Rename presents a stock themed, keyboard-safe dialog using the existing paper/ink tokens, with a preselected basename and a fixed extension displayed separately. Parent busy/enabled guards must cover menus, dialogs and save. Avoid duplicate submission and route pops, retain a recoverable error state, and preserve role drafts and scroll state. Prefer keeping entered text for retry on failure.

## Validation matrix
| Input/state | Result |
|---|---|
| `old.PNG` → `新立绘` | `新立绘.PNG`, same file and metadata except name |
| same basename / cancellation | no persistence change |
| empty, whitespace, path separator or control character | visible validation, no write |
| extensionless file / Unicode / multiple dots | useful editable title, final extension protected when present |
| wrong role / missing id | failure, no unrelated row modification |
| write pending | no duplicate actions or navigation races |
| write error | keep entered value available and allow retry/cancel |

Good: update the role-scoped name column and let the watched query refresh. Base: rename one saved asset. Bad: rename its physical path or call a whole-role save.

## Affected files and patterns
`lib/pages/role_assets_tab.dart` already owns immediate asset operations and busy guards. `DriftRoleAssetRepository.delete` demonstrates role-scoped queries. `test/fakes/fake_role_asset_repository.dart` and existing repository/page tests provide test seams. Any new dialog/model helper may be added within these areas. Update frontend/backend role-assets specs to record the final contract.
