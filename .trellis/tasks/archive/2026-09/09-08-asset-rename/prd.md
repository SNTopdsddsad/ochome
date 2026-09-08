# Asset rename and experience suggestions

## Goal
Let users rename an imported asset from its row, and separately identify the most useful next improvements to the OC asset experience.

## Approved requirements
- The user accepted the proposed row overflow menu with Rename, retaining the file extension.
- Rename takes effect immediately and survives reopening; it does not require saving the role form.
- Preserve the original file, stored copy, kind, ordering, preview, backup identity and other role data.
- Keep deletion available through the menu with its existing confirmation.
- Empty or invalid names receive useful feedback. Cancellation makes no change, and pending/failing saves remain safe and recoverable.
- Offer prioritized product ideas grounded in the existing page and OC use cases; do not implement those additional ideas in this change.
- Follow-up bug report: on iPhone, the native video preview title must use the current asset display name, not the immutable internal filename. Apply the same title handoff to audio/documents that use this viewer.

## Acceptance criteria
- [x] Asset row → more → Rename opens a prefilled editor with a protected extension.
- [x] A successful rename updates the list and persisted metadata; the stored file and its contents are unchanged.
- [x] Repository updates are scoped to both role and asset id.
- [x] Tests cover validation, cancellation, pending/error recovery, unchanged name, extension handling and the existing delete flow.
- [x] Analysis and relevant tests pass.
- [x] A concise prioritized product exploration is delivered with assumptions clearly marked.
- [x] Opening an asset in the iOS system preview shows its current display name after rename, without copying or renaming the stored media file.

## Authorization
User: “可以的，添加这个功能。我还是感觉资产还是少了点什么东西？但是不太清楚，顺便帮我想一想”. Implementation of rename is authorized. Additional features are suggestions only.
