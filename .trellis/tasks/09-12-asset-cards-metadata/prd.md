# Asset cards with tags and video duration

## Requirements
- Match the supplied asset-list reference: rounded paper cards, large left preview, right filename, kind/size, local import timestamp, tag pills, and top-right overflow menu.
- Preserve single-line horizontal type filters and all existing open/rename/delete/gallery behavior.
- User explicitly requested editable asset tags and actual video duration in the same change.
- Tags are per asset, ordered, editable from the overflow menu, and persisted immediately without submitting the role form. Empty tags are allowed; support at most 8 distinct tags of at most 16 grapheme clusters each. Trim whitespace and reject invalid input visibly.
- Display real video duration on its preview, formatted mm:ss or h:mm:ss. Missing/unsupported metadata must not invent a duration or block opening the original file.
- Existing data must migrate without losing names, media paths, timestamps, roles, or relationships. Tags must survive backup and restore.
- Support light/dark themes, narrow phones, large text, and existing save/import/busy navigation guards.
- Follow-up: normal short SnackBars must auto-dismiss even when Android
  accessibility services enable accessible navigation. Keep the existing
  four-second normal/five-second error durations, explicit duration overrides,
  manual close and native announcements. Only messages that require scrolling
  remain persistent.
- Follow-up: tighten vertical asset-card spacing. Keep the large previews and
  readable metadata, reduce stacked internal/external padding, and preserve
  large-text layout, tags, duration and menu touch targets.
- Follow-up: Android **从相册添加** must use the system photo picker for mixed
  image/video multi-selection on supported devices, while **从文件添加** keeps the
  generic file picker. Preserve cancellation, errors, busy guards and other
  platforms. Use the installed plugin capability without upgrading dependencies.

## Acceptance
- Native Android preview shows the redesigned asset list.
- Labels can be added/removed/saved/cancelled and survive reopening.
- Video duration comes from a real media file and is retained through cache hits; preview failures degrade safely.
- Repository/migration/backup tests, UI interaction tests, native tests and static analysis pass.
