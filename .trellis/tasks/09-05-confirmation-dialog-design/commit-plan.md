# 本地提交计划

代码、回归验证与规范更新已完成。用户于 2026-09-05 明确授权“commit 然后归档”，按下列顺序本地提交，再完成任务归档与会话记录；不推送远端。

## 1. 应用: 增加可复用的创作便笺确认弹窗

- `lib/widgets/zaidang_confirm_dialog.dart`
- `lib/pages/role_create_page.dart`
- `lib/pages/role_desc_history_page.dart`
- `lib/pages/backup_restore_page.dart`
- `lib/theme/zaidang_theme.dart`

## 2. 测试: 验证确认弹窗交互与恢复流程

- `test/widgets/zaidang_confirm_dialog_test.dart`
- `test/pages/role_create_page_custom_attributes_test.dart`
- `test/pages/backup_restore_page_test.dart`

## 3. Trellis: 记录创作便笺设计与复用规范

- `.trellis/spec/frontend/component-guidelines.md`
- `.trellis/spec/frontend/theming.md`
- `.trellis/spec/frontend/index.md`
- `.trellis/tasks/09-05-confirmation-dialog-design/task.json`
- `.trellis/tasks/09-05-confirmation-dialog-design/prd.md`
- `.trellis/tasks/09-05-confirmation-dialog-design/design.md`
- `.trellis/tasks/09-05-confirmation-dialog-design/implement.md`
- `.trellis/tasks/09-05-confirmation-dialog-design/implement.jsonl`
- `.trellis/tasks/09-05-confirmation-dialog-design/check.jsonl`
- `.trellis/tasks/09-05-confirmation-dialog-design/commit-plan.md`
- `.trellis/tasks/09-05-confirmation-dialog-design/research/behavior-audit.md`
- `.trellis/tasks/09-05-confirmation-dialog-design/research/preview-validation.md`
- `.trellis/tasks/09-05-confirmation-dialog-design/research/confirmation-preview.html`
- `.trellis/tasks/09-05-confirmation-dialog-design/research/confirmation-preview-v2.html`

## 保留且不纳入提交的已有文件

- `.vscode/`
- `CLAUDE.md`

## 验证依据

- `flutter test`：124 项通过。
- 审查补充 3 项边界回归后，共享组件 16 项测试全部通过。
- `flutter analyze`：No issues found。
- 八个变更 Dart 文件格式检查、`git diff --check`、Trellis context validation 通过。
- 检查真实 Flutter 深浅色、整库覆盖及 2× 字体截图。未调用真实 iCloud 写入。
