# Type Safety

> Dart null-safety and type conventions as practised in 崽档.

---

## Overview

The project is sound null-safe Dart (SDK constraint in `pubspec.yaml`,
`flutter_lints` 6). There is no TypeScript; the concerns this file covers are
model immutability, keeping Drift row types out of the UI, strict JSON
decoding, and where `!`, `dynamic` and casts are tolerated.

---

## Type Organization

- **Domain models** live in `lib/data/models/` as `const` classes with
  `final` fields and value equality (`==`/`hashCode`): `Role`,
  `RoleCustomAttribute`, `RoleDescRevision`, `RoleAsset`,
  `RoleRelationship`. `copyWith` exists only where edits need it
  (`RoleRelationship`); do not add one speculatively.
- **Value objects** encapsulate validation: `RoleAssetName`
  (`lib/data/models/role_asset_name.dart`) has a factory constructor and
  `renamed()` that throws `FormatException`. Enums carry their Chinese label
  (`RoleAssetKind`).
- **Generated Drift row types** (`Role`, `RoleAsset`… inside
  `app_database.g.dart`) share names with the models. Repositories import
  `app_database.dart as db` and only ever expose the model. Tests that need
  both `hide Role` on the database import. UI files never import the database.
- **Riverpod providers** are typed by the interface
  (`Provider<RoleRelationshipRepository>`), never the Drift class.
- **Feature models** (`BackupJob`, `BackupFailure`, `BackupPhase`,
  `RoleCardSelection`) sit inside their feature folder
  (`lib/features/backup/backup_models.dart`, `lib/features/role_card/`).
- **Theme** is a typed `ThemeExtension`: `ZaidangTokens` is `@immutable`
  with `copyWith`/`lerp`, obtained via `ZaidangTokens.of(context)` with a light
  fallback.
- **Route payloads** are typed at the router: `/roles/:id` checks
  `state.extra is Role` and redirects otherwise before the single
  `state.extra! as Role` cast in `lib/app_router.dart`.

---

## Validation

Validation is data-layer code that throws typed exceptions (see
`backend/error-handling.md`); widgets display the message.

- **User input**: helper next to the model, e.g. `normalizeRelationshipLabel`
  trims, rejects empty, and enforces `relationshipLabelMaxLength` using
  `characters.length` (grapheme clusters, package `characters`), throwing
  `FormatException` with Chinese copy. The sheet imports the same constant
  for its `maxLength` and inline hint so the two cannot disagree.
- **Stored JSON**: `DriftRoleRepository._decodeAttributes` checks the decoded
  shape (`is List`, each `is Map`) and throws `FormatException('自定义属性必须是数组')`
  rather than casting.
- **Backup metadata**: `BackupJson` in `lib/features/backup/backup_protocol.dart`
  is the only decoder. Each accessor (`string`, `integer`, `boolean`, `list`,
  `uuid`, `hash`, `time`, `logicalPath`, `format`) validates type and range and
  throws `FormatException`; there are no defaults or coercions. New backup
  fields go through `BackupJson`, not `as` casts on `Map<String, dynamic>`.
- **Storage pointer / manifest**: `DataStorage` and `BackupManifest` parse
  with the same throw-on-mismatch approach; a bad pointer becomes
  recovery-only mode instead of a crash.
- **Widgets** may duplicate a check for instant feedback (the sheet's
  `_atLengthCap`), but the repository call remains the authority and the
  widget catches `FormatException(:final message)` to show whatever the data
  layer says.

---

## Common Patterns

- `switch` expressions with patterns for `AsyncValue` and enums:
  `switch (relationships.asData) { AsyncData(:final value) => ..., _ => '' }`,
  tone switches in `zaidang_snack_bar.dart`, phase switches in
  `backup_job_panel.dart`, `on FormatException catch (e)` /
  `FormatException(:final message)` destructuring in the relationship sheet.
- `late final` for controllers and routers initialised in `initState`
  (`MyApp._router`, `RoleCreatePage` controllers, `BackupCompletionFeedback._subscription`).
- `sealed class` for the legacy `BackupException` hierarchy so `switch` is
  exhaustive; new failure types prefer a single class with a `code` field
  (`BackupFailure`) over a hierarchy.
- Nullable optionals with `?.` and `??` for optional UI data
  (`name ?? '对方'` in the relationship sheet), and `asData?.value` for
  "not loaded yet".
- Explicit generic arguments on modals: `showModalBottomSheet<bool>`,
  `showDialog<bool>`; callers compare with `== true` because dismissal yields
  `null`. `showZaidangConfirmDialog` normalises to `bool` (`confirmed ?? false`).
- Function-typed props for late re-evaluation: `bool Function() canSave`,
  `bool Function() isEnabled`, `Future<void> Function(RoleRelationshipDraft) onSave`.

---

## Forbidden Patterns

- **`dynamic` in app code.** The only sanctioned uses are
  `ThemeExtension<dynamic>` in `zaidang_theme.dart` and the JSON decode
  boundary inside `BackupJson`/`DataStorage`/`_decodeAttributes`, where the
  value is type-checked immediately.
- **`as` casts on decoded JSON** (`json['name'] as String`). Use `BackupJson`
  or an `is` check that throws `FormatException`.
- **`!` on values that can legitimately be null at runtime.** Accepted uses
  are the router cast after an `is` guard, `widget.role!.id` inside edit-only
  code paths that are unreachable when `role == null`, `Color.lerp(...)!` on
  two non-null colours, `formKey.currentState!` after the form is built, and
  `textTheme.bodyLarge!` in the theme builder. Do not add `!` to silence the
  analyzer on provider data — pattern-match the `AsyncValue` instead.
- **Exposing Drift row classes or `*Companion`s** past the repository.
- **Records as public API types.** Return a small class or use named
  parameters; records appear only as local destructuring.
- **`extension type`s** — not used; introduce one only with a spec update.
- **Mutable model fields or `List` fields without defensive copies.** Models
  are `const`; `Role.customAttributes` is compared element-wise in `==`.
- **Suppressing lints** with `// ignore:`. Hand-written `lib/` has none; the
  only `ignore_for_file` lines are in generated code.
