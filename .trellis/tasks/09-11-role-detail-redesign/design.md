# 技术设计：角色详情页改版

参考稿：`research/design-reference.jpg`。取舍见 `prd.md`。

## 1. 边界

- 只改 UI 层：`lib/pages/role_create_page.dart`、`lib/widgets/archive_editor/*`、
  新增 `lib/widgets/archive_tag.dart`。数据模型、仓库、provider、路由不动。
- `ImmersiveCover` / `GlassSaveButton` 为角色页与世界观页共享：新增能力全部走
  可选参数，默认值保持世界观页现状；保存按钮配色两页一并变更。

## 2. 滚动结构（不变的契约 + 新槽位）

```
NestedScrollView（编辑）/ CustomScrollView（新建）
└─ SliverOverlapAbsorber
   └─ ImmersiveCover = SliverAppBar(pinned: bottom != null)
      ├─ flexibleSpace: Stack
      │   ├─ 立绘（有槽位时 top = 0，height = maxHeight - paperHeaderExtent，直出、顶对齐；无槽位仍 Positioned.fill 模糊）
      │   ├─ 纸面块：top = photoHeight - _heroCapHeight，bottom = -1
      │   ├─ paperHeader：bottom = 0，height = preferredSize.height，Opacity(visible) + IgnorePointer
      │   └─ _CallingCard：仅 paperHeader == null 时渲染
      └─ bottom: TabBar（编辑）
expandedHeight = immersiveCoverHeight
               + (paperHeader.preferredSize.height - paperHeaderOverlap)
               + bottom.preferredSize.height
```

- 收起顺序：身份头锚在 Stack 底部、立绘填满剩余高度，所以上滑先把立绘从底部裁短
  （顶对齐留住脸），身份头完整地跟着页签上移，最后 100px 用名片同一条 `visible`
  曲线淡出，让位给 `PinnedIdentity`。下拉回弹时 maxHeight 变大，立绘拉高、身份头下移。
  ⚠️ 第一版把身份头锚在顶部（`top = photoHeight - overlap`），结果 Stack 收缩时
  `Clip.hardEdge` 先裁掉的是身份头——稍微一滑头像/标签就消失而立绘还在，已改。
- `toolbarHeight` / `collapsedHeight` / `SliverOverlapInjector` 不变，因此
  `_fieldScrollTopInset = 128` 也不变。
- `PinnedIdentity` 出现阈值：`collapseOffset = immersiveCoverHeight + headerExtent
  - topInset - 60`，其中 `headerExtent = header 高度 - 头像重叠量`。

## 3. 组件签名

```dart
// lib/widgets/archive_editor/immersive_cover.dart
ImmersiveCover({
  ..., // 现有参数不变
  PreferredSizeWidget? paperHeader,   // 纸面身份头；null 时沿用名片
  double paperHeaderOverlap = 0,      // 身份头顶部压到立绘上的高度
  double backdropBlur = 6,            // 模糊 sigma；角色页传 0，立绘直出、顶对齐、底部渐隐进纸面
})
PortraitPlaceholder({tokens, compact, label})   // 原 _PortraitPlaceholder 公开

// lib/widgets/archive_editor/role_identity_header.dart
class RoleIdentityHeader extends StatelessWidget implements PreferredSizeWidget {
  RoleIdentityHeader({
    required String name, required String emptyName,
    required List<String> tags, required String quote,   // quote 为设定首行，空则不占位
    required String coverImg, required bool hasCover,
    required VoidCallback? onPortraitTap,   // 有图=预览，无图=选图；null 表示禁用
    required VoidCallback? onChangeCover,   // 仅 hasCover 时显示角标
    required VoidCallback? onExport,
    required double height,                 // 页面用 heightFor(textScaler) 算好传入
    Future<Directory> Function()? supportDirectory,
    Key portraitKey = Key('role-create-cover-portrait'),
    Key changeKey = Key('role-cover-change'),
    Key exportKey = Key('role-card-export'),
  });
  static const double portraitSize = 112;
  static const double portraitOverlap = 56;
  static double heightFor(TextScaler scaler);   // 固定 chrome + 按字号缩放的文字块
}

// lib/widgets/archive_editor/archive_card.dart
ArchiveCardHeader({required IconData icon, required String title, String? caption, Widget? trailing})
ArchiveFieldCell({required IconData icon, required String label, required Widget child})
InputDecoration archiveCellInputDecoration({required String hint})  // 无边框，错误态 ink 下划线

// lib/widgets/archive_tag.dart（由 ArchiveListCard._Tag 提升）
ArchiveTag(String label)
```

## 4. 身份头布局

```
Padding(horizontal: archiveEditorHorizontalPadding)
Row(top)
├─ 左列 Column(min, start)
│   ├─ 头像盒 116×116（112 + 角标外溢 xs）
│   │   ├─ 头像 112×112：surface 底 + mdAll 圆角 + 阴影，内 Padding(xs) 后 ClipRRect(smAll)
│   │   │   ├─ hasCover: CoverFileView(topCenter)；点击 → onPortraitTap（语义 查看立绘）
│   │   │   └─ 无图:    PortraitPlaceholder(label: 添加立绘)；点击 → onPortraitTap
│   │   └─ hasCover: 右下 48×48 透明 Material 命中区，视觉 28 圆形 ink + 相机图标贴其右下
│   │                → onChangeCover（语义 更换立绘）。命中区必须落在头像盒内，Stack 外收不到点击
│   └─ xxs 间距 + OutlinedButton 导出角色卡：fixedSize 112×36，tapTargetSize.padded 补到 48 高
└─ Expanded 文字列，top padding = portraitOverlap + sm（正好落在纸面上）
    ├─ Row: Flexible(名字 title, 1 行) · 星芒 18 accent（ExcludeSemantics）
    ├─ tags 非空: Wrap(ArchiveTag…)
    └─ quote 非空: 「quote」 caption ink, 2 行
```

> 实现时把「导出角色卡」从名字行移到头像下方：390 宽屏上名字行只剩约 70px，
> 连回退文案 `新建角色` 都会被省略；按钮放头像下既不增高也不挤名字。

- 文字列包在 `OverflowBox(alignment: topLeft, maxHeight: ∞)` 内：极端字号下只会被
  裁切，不会抛 RenderFlex overflow。
- 高度：`heightFor(scaler) = max(portraitOverlap + sm + scaler.scale(_textBlock),
  portraitSize + xs + xxs + 48) + md`，`_textBlock`（104）为名字行 + 标签行 + 两行引文的
  名义高度；页面在 build 里用 `MediaQuery.textScalerOf(context)` 计算并传给 header
  与 `PreferredSize`。2x 字号下两行引文仍在头内（有测试）。
- 页面用 `PreferredSize(child: ListenableBuilder(listenable: _identityListenable))` 包裹，
  `_identityListenable = Listenable.merge([name, sex, race, occupation, desc])` 在
  initState 建一次，输入时只重建头部。名字仍保留页面级监听，供
  `PinnedIdentity` 使用。

## 5. 字段格

- `ArchiveFieldCell`：`StatefulWidget`，`Focus(canRequestFocus: false,
  skipTraversal: true, onFocusChange)` 跟踪子输入框焦点；`bg` 填充、`smAll`、
  `Border.all` 宽度恒为 1，颜色 `bg`（未聚焦，隐形）→ `accent`（聚焦）。
- 顶行 `Icon(16, accent)` + `micro` 标签；下方为 child。
- 内嵌 `TextFormField` 用 `archiveCellInputDecoration`：`filled: false`、
  `isDense`、`UnderlineInputBorder(BorderSide.none)`，错误态
  `UnderlineInputBorder(ink)`，错误文案由主题 `micro` ink 呈现。
- 世界观整行：`InkWell(key: role-world-row)` → `ArchiveFieldCell(icon: public,
  label: 世界观, child: Row[值, chevron])`；`_pickWorld` 与 `_WorldChoice` 不变。
- 字段键：`role-field-name / sex / age / birthday / race / occupation / desc`。

## 6. 卡片

- 基础设定：`ArchiveCardHeader(Icons.description_outlined, '基础设定', caption:
  '关于这个角色')`；`FieldRow`（名字|性别）（年龄|生日）（种族|身份）+ 世界观整行。
- 自定义属性：`SectionLabel` → `ArchiveCardHeader(Icons.bookmark_border,
  '自定义属性')`；`SliverReorderableList` 与行内控件不变。
- 角色简介：`ArchiveCardHeader(Icons.history_edu_outlined, '角色简介', caption:
  '性格、外貌、背景')`；`Stack[DecoratedBox(surface + border, smAll) > TextFormField
  (无边框), Positioned 右下 Icons.format_quote accent 0.3 (ExcludeSemantics +
  IgnorePointer)]`；编辑态下方右对齐 `TextButton('修改历史')`。
- TabBar：`indicatorSize: label`、`indicator: UnderlineTabIndicator(accent)`、
  `dividerColor: Colors.transparent`；外层 `ColoredBox(tokens.bg)` 保留。

## 7. 保存按钮

`GlassSaveButton`：去掉 BackdropFilter，`ShapeDecoration(color: accent, StadiumBorder)`；
文字 / 进度条 `onAccent`；`onPressed == null` 或 `saving` 时填充降到 accent 0.55。
`Key` / 文案 / `find.widgetWithText(TextButton, '保存')` 不变。

## 8. 兼容与回滚

- 世界观页：不传 `paperHeader`，`backdropBlur` 默认 6，行为像素级不变（保存按钮除外）。
- 回滚点：每个组件独立提交；页面接线是最后一步，可单独回退到旧 `_buildDetailsSliver`。
