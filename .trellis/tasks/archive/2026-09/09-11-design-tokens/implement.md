# Implement: 字号 / 间距 / 圆角 Token

## 顺序

1. Token 文件：`lib/theme/zaidang_type.dart`、`zaidang_spacing.dart`、`zaidang_radius.dart`。
2. 主题：`lib/theme/zaidang_theme.dart` 接入（见 design.md），文件内字面量清零。
3. 共享组件：
   - 新建 `lib/widgets/section_label.dart`，`archive_card.dart` 移除 `SectionLabel`，更新 `role_create_page` / `world_create_page` 导入。
   - `role_relationship_editor_sheet.dart` 删除 `_SectionLabel`，改用 `SectionLabel`。
   - `archive_card.dart`、`immersive_cover.dart`、`pinned_identity.dart`、`glass_buttons.dart`
   - `zaidang_confirm_dialog.dart`、`zaidang_snack_bar.dart`、`role_list_tile.dart`、`role_asset_rename_dialog.dart`、`storage_error_details.dart`
   - `features/backup/widgets/backup_shared.dart`、`backup_job_panel.dart`
   - `features/role_card/role_card_field_picker.dart`、`lib/bootstrap.dart`
4. 页面（`lib/pages/`）：archive、backup_contents、backup_restore、cover_preview、role_assets_tab、role_card_export、
   role_create、role_desc_history、role_list、role_relationships_tab、world_create、world_view（home_shell / mine 无字面量）。
5. 测试：`test/theme/zaidang_type_test.dart`、`test/theme/design_token_guard_test.dart`。
6. 验证：`flutter analyze`、`flutter test`、`dart format .`。
7. Spec：`theming.md`、`quality-guidelines.md`、`component-guidelines.md`、`role-relationships.md`、`index.md`。

## 迁移速查

- 字号：按 design.md 表；`fontSize` / `fontWeight` 字面量 → 0。
- 间距：6/7/9→8、10→12、14→16、18→20、22→24、26→24、28→32、48→32；0 保留。
- 圆角：6/12→sm、14/15/18→md、20→lg、22→pill、26→lg。
- ListTile `contentPadding` 16×8 → 删除本地值（主题统一）。
- AppBar 标题 `TextStyle(fontSize: 17, w600)` → 删除本地样式（主题 `titleTextStyle`）。

## 验证命令

```bash
flutter analyze
flutter test
dart format --set-exit-if-changed lib test
rg -n "fontSize:" lib --glob '!lib/theme/**' --glob '!lib/features/role_card/role_card_renderer.dart' --glob '!lib/features/role_card/role_card_fonts.dart'
```

## 提交拆分（Phase 3.4 前确认）

1. `应用: 增加字号、间距与圆角设计 Token 并接入主题`
2. `应用: 共享组件与页面改用设计 Token`
3. `测试: 覆盖字号 Token 与字面量守卫`
4. `Trellis: 记录字号、间距与圆角规范`

## 实施记录（2026-09-11）

- 全部 14 个页面、共享组件、backup 组件、field picker、bootstrap 已迁移；`flutter analyze` 无问题，`flutter test` 393 通过（原 385 + 新增 8）。
- 守卫测试判定「间隔 SizedBox」的规则收窄为：**只有 `height:` / `width:` 之一、且没有 `child:`**。带 child 或双向尺寸的 `SizedBox` 视为尺寸容器，不检查；嵌套子树里的数字不再误报。实参按顶层逗号拆分后只看该参数本身。
- 非间距的尺寸常量统一抽成带注释的 `static const`：`_fieldScrollInset = 80` / `_fieldScrollTopInset = 128`（两个编辑页）、`_compactPreviewMinHeight = 240` / `_compactPreviewMaxHeight = 520`（导出页）。
- 编辑页顶部工具栏的 `Positioned(top: +8, left/right: 16)` 与 `middleSpacing: 12` 一并换成 `sm` / `lg` / `md`。
- `ThemeData` 会把默认 Typography（fontFamily / debugLabel）合并进 `textTheme`，所以测试比较 `textTheme.bodyMedium` 时逐字段断言 size / weight / height / color，不比较整个 `TextStyle`。
- `dart format lib test` 顺带重排了 7 个与本任务无关的文件（`lib/data/**`、`snapshot_store.dart`、`test/data/**`、`backup_core_test.dart`、`role_relationships_tab_test.dart`），已 `git checkout` 还原，未纳入本任务提交。
- 额外更新 `worlds.md` 的 archive_editor 签名块：`SectionLabel` 已移到 `lib/widgets/section_label.dart`。
