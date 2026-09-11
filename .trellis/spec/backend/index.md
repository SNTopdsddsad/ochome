# Backend Development Guidelines

> Best practices for backend development in this project.

---

## Overview

崽档 has no server. "Backend" means the data layer of the Flutter app:
`lib/data/` (Drift database, models, repositories, providers, services) and the
non-widget half of `lib/features/backup/`. Base guidelines describe the
repeated patterns; feature specs (custom attributes, backup, assets,
relationships) carry the executable contracts for each area.

---

## Guidelines Index

| Guide | Description | Status |
|-------|-------------|--------|
| [Directory Structure](./directory-structure.md) | `lib/data/` folders, what each may import, how a new entity spreads across them | Active |
| [Database Guidelines](./database-guidelines.md) | Drift tables, `currentSchemaVersion` + staged `onUpgrade`, `mutate()` epoch gate, raw SQL boundaries | Active |
| [Role Custom Attributes](./role-custom-attributes.md) | Ordered attributes, whole-role preservation, migration and backup contracts | Active |
| [Backup and Restore](./backup-restore.md) | Account-wide snapshots, immutable media, recovery-only data switching and native contracts | Active |
| [Role Assets](./role-assets.md) | Asset ownership, file import, schema v8 and backup/restore contracts | Active |
| [Role Relationships](./role-relationships.md) | Directed single-row OC links, unified in schema v10, perspective helpers and backup validation | Active |
| [Worlds](./worlds.md) | World table, ordered entries JSON, `role.world_id` SET NULL, unified in schema v10 migration and backup | Active |
| [Error Handling](./error-handling.md) | `FormatException` / `StateError` / `BackupFailure` taxonomy, platform error translation, UI reaction matrix | Active |
| [Quality Guidelines](./quality-guidelines.md) | analyze/test/build_runner gate, forbidden and required data-layer patterns, review checklist | Active |
| [Logging Guidelines](./logging-guidelines.md) | `debugPrint`-only policy, the three call sites, what never to log | Active |

---

## Maintaining These Guidelines

- Document **actual conventions**; when the code changes, change the spec in
  the same commit (`Trellis:` module).
- Every rule points at a real file under `lib/` or `test/`.
- New data-layer features get a feature spec here with signatures, validation
  matrix and test points, following `role-relationships.md`.

---

**Language**: All documentation should be written in **English**.
