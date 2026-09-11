# Logging Guidelines

> What 崽档 logs today, and the small set of rules that keeps it that way.

---

## Overview

崽档 is an offline-first personal app with no analytics or crash-reporting
SDK. Logging is deliberately minimal:

- No `Logger` package, no `dart:developer` `log`, no `print`.
- No global `FlutterError.onError`, `PlatformDispatcher.onError` or
  `runZonedGuarded` in `lib/main.dart`; startup failures are surfaced as UI
  (`AppStorageBootstrap` in `lib/bootstrap.dart`) rather than logged.
- The only logging primitive is `debugPrint`, and there are three call sites:

| Location | Message |
|----------|---------|
| `lib/bootstrap.dart` (inside `kDebugMode`) | `Local storage recovery: ${storage.recoveryError}` |
| `lib/bootstrap.dart` (inside `kDebugMode`, then rethrow) | `Local storage startup failed: $error` |
| `lib/pages/role_relationships_tab.dart` `_delete` | `delete relationship failed: $error\n$stackTrace` |

Nothing under `lib/data/**` or `lib/features/backup/**` logs. Errors there are
carried by exceptions (see `error-handling.md`) and by the Backup v3 job
model, which the UI renders.

---

## Log Levels

There are no levels. The convention is:

- **Debug-only diagnostics** — wrap in `if (kDebugMode)` when the message
  would be noisy or contains storage paths, as `bootstrap.dart` does.
- **Unexpected failure that the UI hides behind fixed copy** — a plain
  `debugPrint('<action> failed: $error\n$stackTrace')` next to the `catch`,
  as `role_relationships_tab.dart` does. Exception text contains no user
  content, so this one is not wrapped in `kDebugMode`.

If a real logging need appears (for example diagnosing backup jobs in the
field), add it as a design decision in `.trellis/spec/backend/backup-restore.md`
first; do not introduce a logger package ad hoc.

---

## Structured Logging

Not used. Messages are short English prefixes in the form
`<subject> <verb>: <payload>` so they are greppable in device logs:

```dart
debugPrint('delete relationship failed: $error\n$stackTrace');
```

Keep the prefix in English even though UI copy is Chinese — log lines are for
developers, not users.

---

## What to Log

- The raw exception and stack trace when a UI action swallows it and shows
  fixed copy instead (`没能删除这条关系，请再试一次`). Without the
  `debugPrint`, the failure is unrecoverable from a bug report.
- Startup storage state that changes routing (recovery-only), so a developer
  running the app can see why it opened on `/backup`.

Backup progress, phases and failures are **not** logged; they are modelled in
`BackupJob` / `BackupFailure` (`lib/features/backup/backup_models.dart`) and
displayed by `BackupJobPanel`. Tests observe them through the coordinator's
job stream (`waitForJob` in `test/fakes/backup_test_support.dart`).

---

## What NOT to Log

- User content: role names, descriptions, custom attributes, relationship
  labels, asset file names. The current call sites only print exception text
  and storage errors.
- Absolute filesystem paths in release builds. `DataStorage` errors include
  them, which is why the bootstrap prints are `kDebugMode`-only.
- Anything from inside repositories or services. Throw instead; let the
  action boundary decide whether to print.
- Success events (`saved`, `deleted`). They add noise and the widget tests
  already assert the visible feedback.
- Never use `print` — `flutter_lints` (`avoid_print`) flags it and
  `flutter analyze` must stay clean.
