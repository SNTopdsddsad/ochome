# 执行计划：角色详情页改版

按顺序执行；每步后 `flutter analyze` 应无问题。

1. [x] `ArchiveTag`：新建 `lib/widgets/archive_tag.dart`，`ArchiveListCard` 改用；
       `test/widgets/archive_list_card_test.dart` 断言不变。
2. [x] `archive_card.dart`：新增 `ArchiveCardHeader`、`ArchiveFieldCell`、
       `archiveCellInputDecoration`；尺寸用命名常量。
3. [x] `immersive_cover.dart`：`paperHeader` / `paperHeaderOverlap` / `backdropBlur`；
       公开 `PortraitPlaceholder`；无槽位路径逐行保持原状。
4. [x] `role_identity_header.dart`：按 design.md 第 4 节实现，含 `heightFor`。
5. [x] `glass_buttons.dart`：`GlassSaveButton` 改 accent 实心。
6. [x] `role_create_page.dart`：
   - 去掉 race / occupation 的页面级监听；`_buildIdentityHeader()` 返回
     `PreferredSize(ListenableBuilder(RoleIdentityHeader))`。
   - `cover()` 传槽位、`backdropBlur`；`collapseOffset` 加 `headerExtent`。
   - `_buildDetailsSliver` 去掉标题行；`_buildBasicCard` / `_buildDescCard` /
     自定义属性卡头按 design.md 第 6 节；`_field` 改为 `_cellField`（带 key、icon、label）。
   - TabBar 样式。
7. [x] 测试：
   - 改：`test/widget_test.dart`（hero 高度、`基础设定` / `角色简介`、
     `Key('role-field-name')`、`编辑角色` → `Key('role-detail-nested-scroll')`）、
     `test/pages/home_shell_test.dart`、`test/pages/role_create_page_cover_test.dart`
     （`更换` → `role-cover-change` + 语义 `更换立绘`）、所有
     `widgetWithText(TextFormField, '名字')` → `byKey(role-field-name)`。
   - 新：`test/widgets/role_identity_header_test.dart`、`test/widgets/archive_card_test.dart`。
   - 复核：`role_assets_tab_test.dart` 吸顶像素回归、`world_create_page_test.dart`。
8. [x] `flutter analyze` / `flutter test` / `dart format .`。
9. [x] 规范：`role-assets.md`（滚动契约 + 身份头）、`worlds.md`（签名）、
       `component-guidelines.md`（共享组件）、`theming.md`（Create/edit 行、保存按钮）。
10. [ ] 提交拆分：`应用: 抽出 ArchiveTag 与卡片/字段格组件` ·
        `应用: 立绘头图支持纸面身份头` · `应用: 角色详情页改为身份头 + 分区卡布局` ·
        `测试: 覆盖身份头与字段格` · `Trellis: 记录角色详情页布局契约`。

验证命令：

```bash
flutter analyze
flutter test
dart format --set-exit-if-changed lib test
```
