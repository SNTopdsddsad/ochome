# Commit plan

Authorized by user request: `代码 commit` (2026-09-08).

1. `应用: 增加资产重命名并同步预览名称`
   - `lib/data/models/role_asset_name.dart`
   - `lib/data/repositories/drift_role_asset_repository.dart`
   - `lib/data/repositories/role_asset_repository.dart`
   - `lib/data/services/role_asset_opener.dart`
   - `lib/pages/role_assets_tab.dart`
   - `lib/pages/role_create_page.dart`
   - `lib/widgets/role_asset_rename_dialog.dart`
2. `iOS: 修复资产预览显示内部文件名`
   - `ios/Runner/RoleAssetPreviewHandler.swift`
   - `ios/Runner/AppDelegate.swift`
   - `ios/Runner.xcodeproj/project.pbxproj`
3. `测试: 验证资产重命名与系统预览标题`
   - `test/data/role_assets_test.dart`
   - `test/data/icloud_backup_service_test.dart`
   - `test/data/role_asset_opener_test.dart`
   - `test/fakes/fake_role_asset_repository.dart`
   - `test/pages/role_assets_tab_test.dart`
   - `ios/RunnerTests/RoleAssetPreviewTests.swift`
4. `Trellis: 记录资产重命名与预览标题规范`
   - `.trellis/spec/backend/role-assets.md`
   - `.trellis/spec/frontend/role-assets.md`
   - This task's PRD, design, implementation/check context, product suggestions,
     follow-up native contract, verification and commit plan, archived under
     `.trellis/tasks/archive/2026-09/09-08-asset-rename/`.

Keep the pre-existing `ios/Podfile.lock` CocoaPods tool-version change and empty
`devtools_options.yaml` outside this feature's commits. Do not push.

Validation: final Flutter analysis passed, 58 Dart tests and 11 iOS tests passed;
the native video title was visually verified and the profile app installed on
the user's iPhone. `git diff --check` passed before staging.
