# Research: Drift snapshot backup vs live iCloud file sync

## Do not sync the live SQLite file

SQLite with WAL (`-wal`, `-shm`) plus iCloud Drive conflict copies (`ochome 2.sqlite`) corrupts the store. Backup must checkpoint (`PRAGMA wal_checkpoint(FULL)`), copy a snapshot, and leave the Application Support database as the only live file.

Drift stores schema in `PRAGMA user_version`, equal to `AppDatabase.schemaVersion` (currently 5 in `lib/data/database/app_database.dart`).

## Version gate

| Snapshot user_version vs app schemaVersion | Action |
|---|---|
| equal | replace local files, open |
| older and >= 3 | replace, let `onUpgrade` run |
| older than 3 | refuse — v3 does `deleteTable('role')` then empty `createTable` |
| newer | refuse — Drift cannot open a DB newer than the compiled schema; tell the user to update the app |

Read version from `manifest.json` and/or a read-only open of the snapshot **before** closing/replacing the live database.

## Cover originals

Covers live in `support/covers/` and are not blobs in SQLite. A useful backup is sqlite snapshot + original files. Upload incrementally by filename+size. Store `coverImg` as `covers/<file>` so restore works across sandbox paths.

## Apple surface

iCloud Documents ubiquity container; iOS and macOS. Items may be in the cloud only (`NSMetadataUbiquitousItemDownloadingStatus`). Restore must finish downloading before swap. Android has no iCloud.
