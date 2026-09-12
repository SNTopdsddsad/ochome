# 本地提交计划

用户已明确要求「代码 commit 到本地」，授权执行以下本地提交；不推送。
按 `.trellis/spec/frontend/git-commit.md` 分模块和功能拆分。

## 1. 应用: 调低角色详情页头图高度

- `lib/pages/role_create_page.dart`
- `lib/widgets/archive_editor/immersive_cover.dart`

## 2. 应用: 增加资产标签存储与备份校验

- `lib/data/database/app_database.dart`
- `lib/data/database/app_database.g.dart`
- `lib/data/database/tables/role_asset.dart`
- `lib/data/models/role_asset.dart`
- `lib/data/models/role_asset_tags.dart`
- `lib/data/repositories/drift_role_asset_repository.dart`
- `lib/data/repositories/role_asset_repository.dart`
- `lib/features/backup/snapshot_store.dart`

## 3. Android: 增加视频时长读取

- `android/app/src/main/kotlin/com/example/ochome/VideoThumbnailHandler.kt`

## 4. iOS: 增加视频时长读取

- `ios/Runner/VideoThumbnailHandler.swift`

## 5. 应用: 增加视频时长缓存

- `lib/data/services/video_thumbnail_service.dart`

## 6. 应用: 优化资产卡片并支持标签编辑

- `lib/pages/role_assets_tab.dart`
- `lib/theme/zaidang_asset_colors.dart`
- `lib/widgets/role_asset_card.dart`
- `lib/widgets/role_asset_tag.dart`
- `lib/widgets/role_asset_tags_dialog.dart`

## 7. 应用: 修复短提示在无障碍模式下不自动消失

- `lib/widgets/zaidang_snack_bar.dart`

## 8. 依赖: 声明安卓照片选择器平台接口依赖

- `pubspec.yaml`
- `pubspec.lock`

## 9. 应用: 修复安卓相册添加打开文件管理器

- `lib/data/services/role_asset_picker.dart`

## 10. 测试: 覆盖角色详情页紧凑头图布局

- `test/widget_test.dart`

## 11. 测试: 覆盖资产标签存储与备份校验

- `test/data/role_asset_tags_test.dart`
- `test/data/role_assets_test.dart`
- `test/data/storage_repository_isolation_test.dart`
- `test/fakes/fake_role_asset_repository.dart`
- `test/features/backup/backup_core_test.dart`

## 12. 测试: 覆盖视频时长读取与缓存

- `test/data/video_thumbnail_service_test.dart`
- `test/native/video_thumbnail_test.swift`

## 13. 测试: 覆盖资产卡片布局与标签编辑

- `test/pages/role_assets_tab_test.dart`
- `test/widgets/role_asset_card_test.dart`
- `test/widgets/role_asset_tags_dialog_test.dart`

## 14. 测试: 覆盖无障碍模式下短提示自动消失

- `test/widgets/zaidang_snack_bar_test.dart`

## 15. 测试: 覆盖安卓相册选择器行为

- `test/data/role_asset_picker_test.dart`

## 16. Trellis: 记录资产展示与系统交互约定

- `.trellis/spec/backend/backup-restore.md`
- `.trellis/spec/backend/database-guidelines.md`
- `.trellis/spec/backend/role-assets.md`
- `.trellis/spec/frontend/backup-restore.md`
- `.trellis/spec/frontend/component-guidelines.md`
- `.trellis/spec/frontend/role-assets.md`
- `.trellis/spec/frontend/theming.md`
- `.trellis/tasks/09-12-asset-cards-metadata/`

## 校验

完整测试 456 项通过，`flutter analyze` 与 `git diff --check` 通过。
提交前逐批检查暂存区，提交后核对提交记录与剩余工作区改动。

## 排除已有改动

- `ios/Podfile.lock`
- `devtools_options.yaml`

上述两个文件在本轮工作前已存在改动，不纳入本次提交。
