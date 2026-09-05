# 角色卡导出：本地提交计划

实现、审查修复和自动化验证已完成。用户于 2026-09-05 授权“commit 到本地”，按下列模块完成本地提交。不推送、不部署、不归档；签名设备验收仍在 `verification.md` 中明确列出。

## 1. 资源: 增加角色卡离线字体与授权文件

- `assets/fonts/role_card/SourceHanSerifCN-Bold.otf`
- `assets/fonts/role_card/SourceHanSansSC-Regular.otf`
- `assets/fonts/role_card/source-han-serif-LICENSE.txt`
- `assets/fonts/role_card/source-han-sans-LICENSE.txt`
- `assets/fonts/role_card/SOURCES.md`

原始字体合计约 27.30 MiB，使用官方未修改字体；用户打样照片不纳入仓库。

## 2. 依赖: 增加角色卡图片分享插件

- `pubspec.yaml`
- `pubspec.lock`

## 3. Android: 适配图片分享插件构建

- `android/settings.gradle.kts`
- `android/gradle.properties`

## 4. 应用: 统一悬浮便笺操作提示

- `lib/widgets/zaidang_snack_bar.dart`
- `lib/theme/zaidang_theme.dart`
- `lib/pages/backup_restore_page.dart`
- `lib/pages/role_desc_history_page.dart`

先提交共用组件及已有页面接入；编辑页中的提示接入随下一条导出入口一并提交，避免同一文件拆分出不完整版本。

## 5. 应用: 增加角色卡导出与分页预览

- `lib/features/role_card/role_card_content.dart`
- `lib/features/role_card/role_card_renderer.dart`
- `lib/features/role_card/role_card_fonts.dart`
- `lib/features/role_card/role_card_field_picker.dart`
- `lib/features/role_card/role_card_export_service.dart`
- `lib/features/role_card/role_card_delivery.dart`
- `lib/pages/role_card_export_page.dart`
- `lib/pages/role_create_page.dart`

## 6. iOS: 增加角色卡相册批量保存

- `ios/Runner/RoleCardExportHandler.swift`
- `ios/Runner/AppDelegate.swift`
- `ios/Runner/Info.plist`
- `ios/Runner.xcodeproj/project.pbxproj`

## 7. 桌面: 增加角色卡文件保存与分享集成

- `macos/Runner/RoleCardExportHandler.swift`
- `macos/Runner/MainFlutterWindow.swift`
- `macos/Runner/DebugProfile.entitlements`
- `macos/Runner/Release.entitlements`
- `macos/Runner.xcodeproj/project.pbxproj`
- `macos/Flutter/GeneratedPluginRegistrant.swift`
- `linux/flutter/generated_plugin_registrant.cc`
- `linux/flutter/generated_plugins.cmake`
- `windows/flutter/generated_plugin_registrant.cc`
- `windows/flutter/generated_plugins.cmake`

## 8. 测试: 验证便笺提示与可访问阅读

- `test/widgets/zaidang_snack_bar_test.dart`

## 9. 测试: 验证角色卡排版与保存分享流程

- `test/features/role_card/role_card_content_test.dart`
- `test/features/role_card/role_card_renderer_test.dart`
- `test/features/role_card/role_card_export_service_test.dart`
- `test/features/role_card/role_card_delivery_test.dart`
- `test/pages/role_card_export_page_test.dart`
- `ios/RunnerTests/RunnerTests.swift`
- `macos/RunnerTests/RunnerTests.swift`

## 10. Trellis: 记录角色卡导出实现与验证

- `.trellis/spec/frontend/role-card-export.md`
- `.trellis/spec/frontend/component-guidelines.md`
- `.trellis/spec/frontend/theming.md`
- `.trellis/spec/frontend/index.md`
- `.trellis/spec/frontend/git-commit.md`
- `.trellis/tasks/09-05-role-card-export/` 本任务的需求、设计、实现计划、上下文清单、研究与验证记录、HTML 版式源码和本提交计划；HTML 中没有打样照片字节。

## 验证结果

- 便笺反馈修正后 Flutter 全量测试 173 项通过；7 项新提示测试通过。
- 全项目静态分析、格式检查、`git diff --check` 和任务上下文验证通过。
- iOS/macOS 最终无签名构建及 Android 调试 APK 构建通过。
- 原生文件处理的 13 项宿主 XCTest 通过。
- 已查看真实度漪 PNG、多页排版、深浅色导出 UI 和字体许可入口。
- 已查看深浅色成功/错误便笺提示的真实运行时阴影效果；可滚长消息与无障碍导航不会被自动计时关闭。
- 未声称完成签名 Apple 设备上的相册授权、真实系统保存或分享目标验收。

## 保留且不纳入提交

- `.vscode/`
- `CLAUDE.md`
- 对话输出目录中的用户照片、生成的角色卡 PNG，以及 `/private/tmp` 中的临时验证脚本和图片。

## 本地执行记录

| 提交 | 内容 |
|---|---|
| `f31bf8e` | 资源: 增加角色卡离线字体与授权文件 |
| `6ab3570` | 依赖: 增加角色卡图片分享插件 |
| `dd7b2f9` | Android: 适配图片分享插件构建 |
| `7ea9beb` | 应用: 统一悬浮便笺操作提示 |
| `5bfbdb6` | 应用: 增加角色卡导出与分页预览 |
| `8cc2da8` | iOS: 增加角色卡相册批量保存 |
| `2683520` | 桌面: 增加角色卡文件保存与分享集成 |
| `f19e20e` | 测试: 验证便笺提示与可访问阅读 |
| `1e848fd` | 测试: 验证角色卡排版与保存分享流程 |
| 本文件所在提交 | Trellis: 记录角色卡导出实现与验证 |

## 归档记录

10 次本地工作提交完成后，用户于 2026-09-05 明确要求归档。本任务已移入 `archive/2026-09/`；发布前签名设备验收项目继续保留，未推送远端。
