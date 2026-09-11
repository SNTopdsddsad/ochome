import 'dart:convert';

import 'package:flutter/material.dart';

import '../theme/zaidang_radius.dart';
import '../theme/zaidang_spacing.dart';
import '../theme/zaidang_tokens.dart';
import '../theme/zaidang_type.dart';
import 'archive_tag.dart';
import 'cover_file_view.dart';

/// 档案首页的列表卡：左侧立绘 / 封面，右侧名字、标签、一句设定和底部计数。
///
/// OC 列表与世界观列表共用。卡片只收数据，不读 provider；计数由页面算好传入。
class ArchiveListCard extends StatelessWidget {
  const ArchiveListCard({
    super.key,
    required this.coverImg,
    required this.title,
    required this.onTap,
    this.placeholderIcon = Icons.person_outline,
    this.tags = const [],
    this.summary = '',
    this.meta,
  });

  /// 立绘 / 封面路径，交给 [CoverFileView] 解析；空串走占位图标。
  final String coverImg;

  final IconData placeholderIcon;

  final String title;

  /// 名字下方的小标签，如 种族 / 身份 / 性别；空列表不占位。
  final List<String> tags;

  /// 设定或简介原文；卡片只显示 trim 后的第一行并套 「」，空白不占位。
  final String summary;

  /// 底部计数文案，如「1 份资产」。`null` 表示还没算出来，只保留箭头。
  final String? meta;

  final VoidCallback onTap;

  /// 立绘列宽，约占手机卡片三分之一。
  static const double _coverWidth = 120;

  /// 右侧内容最小高度，短设定的卡片也能撑出完整立绘。
  static const double _minContentHeight = 140;

  /// 底部计数前的小图标尺寸。
  static const double _metaIconSize = 16;

  /// 多行文本只取首行；兼容 `\r\n`，首尾空白一并去掉。
  static String firstLine(String text) =>
      LineSplitter.split(text.trim()).firstOrNull?.trim() ?? '';

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    final type = ZaidangType.of(context);
    final meta = this.meta;
    final summaryLine = firstLine(summary);
    final placeholder = ColoredBox(
      color: tokens.bg,
      child: Icon(placeholderIcon, color: tokens.inkSecondary),
    );

    return Material(
      color: tokens.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: ZaidangRadius.mdAll,
        side: BorderSide(color: tokens.border),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(ZaidangSpacing.md),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: ZaidangRadius.smAll,
                  child: SizedBox(
                    width: _coverWidth,
                    child: CoverFileView(
                      coverImg: coverImg,
                      placeholder: placeholder,
                    ),
                  ),
                ),
                const SizedBox(width: ZaidangSpacing.md),
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: _minContentHeight,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: type.heading,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (tags.isNotEmpty) ...[
                          const SizedBox(height: ZaidangSpacing.sm),
                          Wrap(
                            spacing: ZaidangSpacing.xs,
                            runSpacing: ZaidangSpacing.xs,
                            children: [for (final tag in tags) ArchiveTag(tag)],
                          ),
                        ],
                        if (summaryLine.isNotEmpty) ...[
                          const SizedBox(height: ZaidangSpacing.sm),
                          // 引文是卡片的正文，surface 上用 ink 才够 4.5:1。
                          Text(
                            '「$summaryLine」',
                            style: type.caption.copyWith(color: tokens.ink),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const Spacer(),
                        const SizedBox(height: ZaidangSpacing.sm),
                        Row(
                          children: [
                            if (meta != null) ...[
                              Icon(
                                Icons.description_outlined,
                                size: _metaIconSize,
                                color: tokens.inkSecondary,
                              ),
                              const SizedBox(width: ZaidangSpacing.xs),
                              Expanded(
                                child: Text(
                                  meta,
                                  style: type.micro,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ] else
                              const Spacer(),
                            Icon(
                              Icons.chevron_right,
                              color: tokens.inkSecondary,
                            ),
                          ],
                        ),
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
