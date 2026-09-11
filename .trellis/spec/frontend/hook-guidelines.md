# Provider Guidelines (Riverpod)

> 崽档 has no React hooks; the equivalent unit of shared stateful logic is a
> Riverpod provider. This file covers how providers are declared, consumed and
> reset.

---

## Overview

All app-wide reactive state and every data-layer dependency reaches widgets
through Riverpod 3 (`flutter_riverpod` 3.4, `riverpod_annotation` 4). Providers
live in `lib/data/providers/`. Two declaration styles coexist and both are
accepted:

| Style | Files | When |
|-------|-------|------|
| Codegen `@riverpod` / `@Riverpod(keepAlive: true)` with committed `.g.dart` | `app_database_provider.dart`, `role_repository_provider.dart`, `roles_provider.dart`, `role_desc_revisions_provider.dart` | the original role/database wiring |
| Hand-written `Provider`, `StreamProvider.autoDispose.family`, `FutureProvider`, `NotifierProvider` | `role_assets_provider.dart`, `role_relationships_provider.dart`, `backup_coordinator_provider.dart`, `database_switch_provider.dart`, `backup_completion_feedback_provider.dart`, `icloud_backup_provider.dart` | everything added since |

New feature providers follow the hand-written style used by assets and
relationships; regenerate `.g.dart` only when touching an existing codegen
provider. `analysis_options.yaml` enables the `riverpod_lint` plugin, so
`flutter analyze` reports misuse such as `ref.watch` inside callbacks.

---

## Custom Hook Patterns

The repeated shape for a persisted entity is two providers per file:

```dart
final roleRelationshipRepositoryProvider = Provider<RoleRelationshipRepository>(
  (ref) => DriftRoleRelationshipRepository(ref.watch(appDatabaseProvider)),
);

final roleRelationshipsProvider = StreamProvider.autoDispose
    .family<List<RoleRelationship>, int>((ref, roleId) {
  if (ref.watch(databaseSwitchProvider)) return const Stream.empty();
  return ref.watch(roleRelationshipRepositoryProvider).watchForRole(roleId);
});
```

Rules embodied by that shape:

- The repository provider returns the **interface** type so widget tests can
  `overrideWithValue(FakeRoleRelationshipRepository())`.
- Watch providers are `autoDispose` and `family` keyed by the entity id, so a
  closed detail page drops its Drift subscription.
- Every watch provider returns `Stream.empty()` while
  `databaseSwitchProvider` is `true`. This is what lets
  `backup_coordinator_provider.dart` close the database during a restore.
- Services that wrap platform channels get plain `Provider`s next to the
  repository (`roleAssetPickerProvider`, `roleAssetOpenerProvider`,
  `videoThumbnailServiceProvider`).
- `databaseSwitchProvider` is a `NotifierProvider<bool>` with `begin()` /
  `complete()`; nothing else should flip it.

**Dataset switch contract.** `backupCoordinatorProvider` builds the
`BackupCoordinator` with two callbacks. `closeDatabase` sets the switch,
invalidates `rolesProvider`, `roleAssetsProvider`, `roleDescRevisionsProvider`
and `roleRelationshipsProvider` (Drift `close()` waits for stream
subscriptions to cancel), then closes the database. `reopenDatabase`
invalidates `appDatabaseProvider` and every repository provider, forces the
new connection open with a raw `SELECT`, clears `imageCache`, then calls
`complete()`. **Any new stream or repository provider must be added to both
lists**; forgetting it either hangs the restore or leaves a repository bound
to the closed database.

---

## Data Fetching

There is no network. "Fetching" is subscribing to a Drift stream through a
provider and rendering `AsyncValue`:

- In `build`, `ref.watch(roleRelationshipsProvider(widget.roleId))` and then
  either `.when(data:, loading:, error:)` (list pages, history page, backup
  home) or a pattern match for partial UI, e.g. the header count in
  `role_relationships_tab.dart`:

```dart
switch (relationships.asData) {
  AsyncData(:final value) => '${value.length} 条关系',
  _ => '',
}
```

- Retry after an error is `ref.invalidate(<provider>)` behind a button
  (`role_assets_tab.dart`, `role_relationships_tab.dart`,
  `backup_restore_page.dart`).
- Mutations use `ref.read(<repository>Provider)` inside the callback, never
  `ref.watch`. Success feedback is `showZaidangSnackBar`; the list updates
  through the stream, so callers do not refetch.
- Candidate lists for pickers are read from an already-watched provider with
  `asData?.value` and treated as "not loaded yet" when null.
- `FutureProvider` (`backupCoordinatorProvider`) is used for one-time async
  construction; it is not `autoDispose` because the coordinator owns the job
  stream for the app's lifetime.

---

## Naming Conventions

- `<subject>RepositoryProvider` → interface instance.
- `<subject>sProvider` (plural) → `StreamProvider` of a list
  (`rolesProvider`, `roleAssetsProvider`, `roleRelationshipsProvider`).
- `<service>Provider` → plain service instance (`roleAssetPickerProvider`).
- `<feature>CoordinatorProvider` / `<feature>TransportProvider` for the backup
  orchestration objects.
- Codegen functions are lower camel (`roles`, `appDatabase`) and generate
  `rolesProvider`, `appDatabaseProvider`.
- Family parameters are the domain id (`int roleId`), not a model object, so
  keys stay stable across rebuilds.

---

## Common Mistakes

- Adding a stream provider and not gating it on `databaseSwitchProvider` or
  not adding it to the `closeDatabase` invalidate list. Symptom: restore hangs
  on `database.close()` while a hidden route still holds the stream.
- `ref.watch` inside `onPressed`/`onSave`. Use `ref.read`; `riverpod_lint`
  flags this.
- Holding a `WidgetRef`-obtained repository across a dataset switch. Read it
  at action time; after a restore the old instance is bound to a closed
  database and `mutate` throws `资料已经切换，请重新打开页面后操作`.
- Keying a family by `Role` instead of `role.id`; equality churn recreates the
  stream on every edit.
- Overriding a concrete `Drift*Repository` in tests. Override the provider
  with the fake implementing the interface
  (`roleRelationshipRepositoryProvider.overrideWithValue(fake)`), as in
  `test/pages/role_relationships_tab_test.dart`.
- Manually calling `ref.refresh` after a write to "make the list update". The
  Drift stream already emits; the extra refresh flashes the loading state.
