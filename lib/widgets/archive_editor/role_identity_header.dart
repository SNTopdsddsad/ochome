import 'dart:io';

import 'package:flutter/material.dart';

import '../../theme/zaidang_radius.dart';
import '../../theme/zaidang_spacing.dart';
import '../../theme/zaidang_tokens.dart';
import '../../theme/zaidang_type.dart';
import '../archive_tag.dart';
import '../cover_file_view.dart';
import 'archive_card.dart';
import 'immersive_cover.dart';

/// 角色页立绘下方的纸面身份头：大头像压在立绘与纸面的交界上，右侧是名字、
/// 纸底标签、一句设定与「导出角色卡」。
///
/// 只收数据、回调向外抛；高度由页面按字号缩放算好传入（见 [heightFor]），
/// 这样 [ImmersiveCover] 的展开高度在整页 build 时就已确定。
class RoleIdentityHeader extends StatelessWidget
    implements PreferredSizeWidget {
  const RoleIdentityHeader({
    super.key,
    required this.name,
    required this.emptyName,
    required this.tags,
    required this.quote,
    required this.coverImg,
    required this.hasCover,
    required this.onPortraitTap,
    required this.onChangeCover,
    required this.onExport,
    required this.height,
    this.supportDirectory,
    this.portraitKey = const Key('role-create-cover-portrait'),
    this.changeKey = const Key('role-cover-change'),
    this.exportKey = const Key('role-card-export'),
  });

  /// 草稿名字，空时显示 [emptyName]。
  final String name;
  final String emptyName;

  /// 名字下方的纸底标签，如 种族 / 身份 / 性别；空列表不占位。
  final List<String> tags;

  /// 设定首行；空则不占位，非空时套 「」 显示。
  final String quote;

  final String coverImg;

  /// 立绘文件是否可读：决定头像是预览入口还是选图入口，以及是否出现更换角标。
  final bool hasCover;

  /// 点头像：有图时预览，无图时选图；`null` 表示当前不可用（保存中等）。
  final VoidCallback? onPortraitTap;

  /// 更换立绘；仅 [hasCover] 时渲染角标。
  final VoidCallback? onChangeCover;

  final VoidCallback? onExport;

  /// 整个身份头的高度，含压在立绘上的 [portraitOverlap]。
  final double height;

  final Future<Directory> Function()? supportDirectory;

  final Key portraitKey;
  final Key changeKey;
  final Key exportKey;

  /// 头像边长与压到立绘上的高度。
  static const double portraitSize = 112;
  static const double portraitOverlap = 56;

  /// 更换角标：视觉 28，命中区放大到系统最小点击目标；压出头像右下边缘 xs。
  static const double _badgeSize = 28;
  static const double _badgeIconSize = 16;
  static const double _badgeOverhang = ZaidangSpacing.xs;
  static const double _sparkleSize = 18;

  /// 导出按钮的视觉高度；`tapTargetSize.padded` 会把命中区补到 [kMinInteractiveDimension]。
  static const double _exportButtonHeight = 36;

  /// 文字列的名义高度（名字行 + 标签行 + 两行引文，含行间距），随字号缩放。
  static const double _textBlockHeight = 104;

  /// 文字列上方与立绘底边的间距、头像与导出按钮之间的间距、整块底部留白。
  static const double _textTopGap = ZaidangSpacing.sm;
  static const double _exportGap = ZaidangSpacing.xxs;
  static const double _bottomGap = ZaidangSpacing.md;

  /// 阴影透明度。
  static const double _shadowAlpha = 0.16;

  /// 按当前字号缩放算出身份头高度；左列（头像 + 导出按钮）固定，文字块跟字号走。
  static double heightFor(TextScaler scaler) {
    final textColumn =
        portraitOverlap + _textTopGap + scaler.scale(_textBlockHeight);
    const portraitColumn =
        portraitSize + _badgeOverhang + _exportGap + kMinInteractiveDimension;
    return (textColumn > portraitColumn ? textColumn : portraitColumn) +
        _bottomGap;
  }

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    final type = ZaidangType.of(context);
    final horizontal = archiveEditorHorizontalPadding(context);
    final displayName = name.trim().isEmpty ? emptyName : name.trim();

    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontal),
        child: ClipRect(
          // 极端字号下只裁切，不让 Column 报 overflow。
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minHeight: 0,
            maxHeight: double.infinity,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 左列：头像 + 与头像同宽的「导出角色卡」，名字行因此能占满右列。
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Portrait(
                      coverImg: coverImg,
                      hasCover: hasCover,
                      supportDirectory: supportDirectory,
                      onTap: onPortraitTap,
                      onChange: onChangeCover,
                      portraitKey: portraitKey,
                      changeKey: changeKey,
                    ),
                    const SizedBox(height: _exportGap),
                    // 视觉 36 高，命中区由 padded 补足；外面不能再套定高盒子，否则命中区被截。
                    OutlinedButton(
                      key: exportKey,
                      onPressed: onExport,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: tokens.accent,
                        disabledForegroundColor: tokens.inkSecondary,
                        side: BorderSide(
                          color: onExport == null
                              ? tokens.border
                              : tokens.accent,
                        ),
                        fixedSize: const Size(
                          portraitSize,
                          _exportButtonHeight,
                        ),
                        minimumSize: const Size(
                          portraitSize,
                          _exportButtonHeight,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: ZaidangSpacing.sm,
                        ),
                        tapTargetSize: MaterialTapTargetSize.padded,
                      ),
                      child: const Text(
                        '导出角色卡',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: ZaidangSpacing.md),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: portraitOverlap + _textTopGap,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                style: type.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: ZaidangSpacing.xs),
                            ExcludeSemantics(
                              child: Icon(
                                Icons.auto_awesome,
                                size: _sparkleSize,
                                color: tokens.accent,
                              ),
                            ),
                          ],
                        ),
                        if (tags.isNotEmpty) ...[
                          const SizedBox(height: ZaidangSpacing.sm),
                          Wrap(
                            spacing: ZaidangSpacing.xs,
                            runSpacing: ZaidangSpacing.xs,
                            children: [for (final tag in tags) ArchiveTag(tag)],
                          ),
                        ],
                        if (quote.isNotEmpty) ...[
                          const SizedBox(height: ZaidangSpacing.sm),
                          // 引文是身份头的正文，纸面上用 ink 才够对比度。
                          Text(
                            '「$quote」',
                            style: type.caption.copyWith(color: tokens.ink),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 头像 + 右下角更换角标。整体比头像大出 [RoleIdentityHeader._badgeOverhang]，
/// 让角标 48 的命中区完整落在自己的盒子里——Stack 外的区域收不到点击。
class _Portrait extends StatelessWidget {
  const _Portrait({
    required this.coverImg,
    required this.hasCover,
    required this.supportDirectory,
    required this.onTap,
    required this.onChange,
    required this.portraitKey,
    required this.changeKey,
  });

  final String coverImg;
  final bool hasCover;
  final Future<Directory> Function()? supportDirectory;
  final VoidCallback? onTap;
  final VoidCallback? onChange;
  final Key portraitKey;
  final Key changeKey;

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    const addLabel = '添加立绘';
    const portraitSize = RoleIdentityHeader.portraitSize;
    const boxSize = portraitSize + RoleIdentityHeader._badgeOverhang;
    final portraitLabel = hasCover ? '查看立绘' : addLabel;
    final image = hasCover
        ? CoverFileView(
            coverImg: coverImg,
            placeholder: const PortraitPlaceholder(
              compact: true,
              label: addLabel,
            ),
            // 正方形裁竖版立绘时留住头部，而不是切到躯干。
            alignment: Alignment.topCenter,
            supportDirectory: supportDirectory,
          )
        : const PortraitPlaceholder(compact: false, label: addLabel);

    return SizedBox.square(
      dimension: boxSize,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            width: portraitSize,
            height: portraitSize,
            child: Semantics(
              button: true,
              enabled: onTap != null,
              label: portraitLabel,
              child: Material(
                color: tokens.surface,
                elevation: 3,
                shadowColor: tokens.ink.withValues(
                  alpha: RoleIdentityHeader._shadowAlpha,
                ),
                borderRadius: ZaidangRadius.mdAll,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(ZaidangSpacing.xs),
                    child: ClipRRect(
                      borderRadius: ZaidangRadius.smAll,
                      child: KeyedSubtree(key: portraitKey, child: image),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (hasCover)
            Positioned(
              right: 0,
              bottom: 0,
              child: Tooltip(
                message: '更换立绘',
                excludeFromSemantics: true,
                child: Semantics(
                  button: true,
                  enabled: onChange != null,
                  label: '更换立绘',
                  child: Material(
                    key: changeKey,
                    type: MaterialType.transparency,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onChange,
                      child: SizedBox.square(
                        dimension: kMinInteractiveDimension,
                        child: Align(
                          alignment: Alignment.bottomRight,
                          child: DecoratedBox(
                            decoration: ShapeDecoration(
                              color: tokens.ink,
                              shape: CircleBorder(
                                side: BorderSide(color: tokens.surface),
                              ),
                            ),
                            child: SizedBox.square(
                              dimension: RoleIdentityHeader._badgeSize,
                              child: ExcludeSemantics(
                                child: Icon(
                                  Icons.photo_camera_outlined,
                                  size: RoleIdentityHeader._badgeIconSize,
                                  color: onChange == null
                                      ? tokens.inkSecondary
                                      : tokens.surface,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
