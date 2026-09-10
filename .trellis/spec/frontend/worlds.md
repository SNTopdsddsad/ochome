# Worlds UI (世界观)

## 1. Scope / Trigger

Read this when changing `WorldViewPage`, `WorldCreatePage`, the shared editor widgets in `lib/widgets/archive_editor/`, `RoleListTile`, or the 世界观 selector inside `RoleCreatePage`. Persistence rules live in [Worlds (backend)](../backend/worlds.md); routes in [Navigation](./navigation.md).

## 2. Signatures

```dart
WorldViewPage()                                   // archive 世界观 tab, list + FAB
WorldCreatePage({World? world, CoverImagePicker? picker,
                 Future<Directory> Function()? supportDirectory})

// lib/widgets/archive_editor/ — shared by role and world editors
ImmersiveCover({path, title, subtitle = '', coverNoun = '立绘', overlayStyle,
                hasCover, onPick, onPreview, supportDirectory, bottom,
                toolbarHeight, heroKey, portraitKey})
PinnedIdentity({name, coverImg, supportDirectory, emptyName, placeholderIcon,
                boxKey, portraitKey})
GlassIconButton({icon, iconSize, tooltip, onPhoto, VoidCallback? onTap})
GlassSaveButton({saving, onPhoto, onPressed})
ArchiveCard / archiveCardDecoration / SectionLabel / FieldRow / KeepAliveDetails
archiveEditorHorizontalPadding(context)

// lib/widgets/role_list_tile.dart
RoleListTile({role})                               // pushes /roles/:id with extra
RoleCoverThumb({path, placeholderIcon = Icons.person_outline})
```

Providers: `worldRepositoryProvider` (keepAlive), `worldsProvider` (stream, gated by `databaseSwitchProvider`), `rolesInWorldProvider(worldId)` (stream family).

## 3. Contracts

### List (`WorldViewPage`)

- Mirrors `RoleListPage`: `ConsumerStatefulWidget` + keep-alive, `ListView.separated`, 56 px rounded cover thumb (`Icons.public_outlined` placeholder), title = name, subtitle = first line of 简介 (omitted when blank). Empty copy is `还没有世界观`; FAB tooltip `添加世界观`.
- Tap pushes `/worlds/:id` with the `World` as `extra`; FAB pushes `/worlds/new`. Each archive tab owns its own FAB — never two on screen.

### Editor (`WorldCreatePage`)

- Same chrome as the role editor: no AppBar, `ImmersiveCover` with `coverNoun: '封面'` (copy becomes 添加封面 / 查看封面 / 更换封面), glass back button, glass 保存, and — edit only — a glass `更多` button (`Key('world-more-action')`) left of 保存. Pinned identity uses `未命名世界观` and the globe icon.
- Create = single `CustomScrollView`. Edit = `NestedScrollView` with pinned tabs `详情 / 角色`, `SliverOverlapAbsorber/Injector`, `PageStorageKey`s and `KeepAliveDetails`, following the [Role Assets](./role-assets.md) scroll contract.
- 详情: title `新建世界观` / `编辑世界观`, 基本信息 card (名称, required, error `请填写名称`), 简介 card (multiline), then a 词条 `SliverReorderableList` in a `DecoratedSliver` using the same interactions as custom attributes: `词条 N` header, drag handle, up/down, delete via `showZaidangConfirmDialog` (`要删掉这条词条吗？` / consequence `保存世界观后生效。` / confirm `删除词条`), `添加词条` button (`Key('world-entry-add')`), title validator `请填写词条标题`, snack `请填写每条词条的标题` when an offscreen title is blank.
- 角色: read-only `rolesInWorldProvider(world.id)` list rendered with `RoleListTile`; empty copy `还没有角色归属这个世界观`. Tapping a role opens the role editor; membership is edited from the role side only.
- Delete: `更多` → bottom sheet `ListTile` (`Key('world-delete-action')`, ink icon and text) → `showZaidangConfirmDialog` with title `要删掉这个世界观吗？`, body naming the world, consequence `归属它的角色不会被删除，只会解除归属。`, cancel `先留着`, confirm `删除世界观`. On confirm call `WorldRepository.delete` and pop. The delete affordance is never accent red.
- A single `_busy` flag covers saving and deleting: it disables 保存, 更多, entry controls, the cover preview callback, and `PopScope.canPop`. Failed writes keep the draft and show `保存失败：…` / `删除失败：…` via `showZaidangSnackBar(tone: error)`.
- Cover picking reuses `CoverImagePicker.pickFromGallery()` and `CoverFileView.exists`; the world stores the same relative `covers/<file>` path as roles, so backup enumeration needs no change.

### Role editor selector (`RoleCreatePage`)

- Last row of the 基本信息 card: an `InputDecorator` labelled `世界观` (`Key('role-world-row')`) showing the world name (ink) or `未归属` (inkSecondary) with an expand chevron. It only `ref.watch`es `worldsProvider` when `_worldId != null`, so unassigned forms (and existing tests) never touch the world repository.
- Tap → `showModalBottomSheet` (`Key('role-world-picker')`): first item `不归属` (`role-world-option-none`), then one `ListTile` per world (`role-world-option-<id>`, cover thumb + name), selected item marked with an accent check; `还没有世界观` hint when the list is empty. Dismissing without a choice keeps the current value (`_WorldChoice` wrapper distinguishes "chose none" from "closed").
- Before saving, `_resolveWorldId()` calls `WorldRepository.getById`; a vanished world is written as `null` and the row falls back to `未归属`. The export snapshot (`RoleCardSnapshot`) does not include the world.

## 4. Validation & Error Matrix

| Action | Required outcome |
| --- | --- |
| Open 世界观 tab with no data | `还没有世界观` + `添加世界观` FAB; no `添加角色` FAB |
| Save world with blank name | Inline `请填写名称`; nothing written |
| Save with a blank entry title | Field error + snack; nothing written |
| Repository write fails | Draft intact, error snack, page stays |
| Edit → switch to 角色 → back to 详情 | Unsaved name/entries preserved |
| Delete → 先留着 | No repository call, page stays |
| Delete → 删除世界观 | World removed, roles remain detached, page pops |
| Role picker → 不归属 | Saves `worldId == null` |
| Role picker → close sheet | Previous selection kept |
| World deleted while role form open | Row shows `未归属`, save writes `null`, no error |

## 5. Good / Base / Bad Cases

- **Good:** New editor screens compose `archive_editor` widgets and pass their own `heroKey` / `portraitKey` / `boxKey` so tests stay per-page.
- **Base:** The role editor keeps its `role-*` keys and copy; extraction changed no behaviour.
- **Bad:** Copying `_ImmersiveCover` back into a page, giving the world page a Material AppBar, an accent-colored delete tile, editing membership from the world's 角色 tab, or a role form that opens the world repository for unassigned roles.

## 6. Tests Required

- `test/pages/world_view_page_test.dart`: empty state, row copy, route + extra, stream refresh.
- `test/pages/world_create_page_test.dart`: create with ordered entries, validation, failed-save draft retention, tabs + member list + role push, empty 角色 state, delete cancel/confirm in light and dark (ink delete icon), cover pick → `更换封面` and persisted path.
- `test/pages/role_create_page_world_test.dart`: default 未归属, pick and save, edit preselect + 不归属, dismiss keeps value, deleted world → null, empty-world hint.
- `test/pages/home_shell_test.dart` asserts the 世界观 tab copy/FAB and overrides `worldRepositoryProvider` alongside the role fake.
- Real file I/O inside `testWidgets` must go through `tester.runAsync`; awaiting `File.writeAsBytes` directly in the fake-async body deadlocks until the 10-minute timeout.

## 7. Wrong vs Correct

```dart
// Wrong: unconditional watch drags the world repository into every role form/test
final worlds = ref.watch(worldsProvider).value;

// Correct: subscribe only when the role actually has a world
if (_worldId != null) {
  final worlds = ref.watch(worldsProvider).value;
  ...
}
```
