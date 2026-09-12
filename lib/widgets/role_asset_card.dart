import 'package:flutter/material.dart';

import '../data/models/role_asset.dart';
import '../theme/zaidang_radius.dart';
import '../theme/zaidang_spacing.dart';
import '../theme/zaidang_tokens.dart';
import '../theme/zaidang_type.dart';
import 'role_asset_tag.dart';

/// 资产列表纸卡：左侧预览，右侧文件名、类型大小与导入时间。
class RoleAssetCard extends StatelessWidget {
  const RoleAssetCard({
    super.key,
    required this.asset,
    required this.thumbnail,
    required this.onTap,
    required this.onMore,
  });

  final RoleAsset asset;
  final Widget thumbnail;
  final VoidCallback? onTap;
  final ValueChanged<BuildContext>? onMore;

  /// 预览约占卡片三分之一；窄屏给文字留足空间，宽屏不无限放大。
  static const double _thumbnailFraction = 0.3;
  static const double _minThumbnailExtent = 88;
  static const double _maxThumbnailExtent = 112;

  /// 类型徽记与菜单图标；菜单仍使用系统 48px 命中区。
  static const double _kindBadgeExtent = 24;
  static const double _kindIconSize = 14;
  static const double _menuIconSize = 20;
  static const double _menuTitleInset =
      kMinInteractiveDimension - ZaidangSpacing.md;

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    final type = ZaidangType.of(context);
    final local = asset.createdAt.toLocal();
    final date =
        '${local.year}年${local.month}月${local.day}日  '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    return Material(
      color: tokens.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: ZaidangRadius.mdAll,
        side: BorderSide(color: tokens.border.withValues(alpha: 0.6)),
      ),
      child: Stack(
        children: [
          InkWell(
            key: ValueKey('role-asset-open-${asset.id}'),
            onTap: onTap,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final thumbnailExtent =
                    (constraints.maxWidth * _thumbnailFraction).clamp(
                      _minThumbnailExtent,
                      _maxThumbnailExtent,
                    );
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ZaidangSpacing.md,
                    vertical: ZaidangSpacing.sm,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox.square(
                        key: ValueKey('role-asset-preview-${asset.id}'),
                        dimension: thumbnailExtent,
                        child: thumbnail,
                      ),
                      const SizedBox(width: ZaidangSpacing.md),
                      Expanded(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: thumbnailExtent,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  right: _menuTitleInset,
                                ),
                                child: Tooltip(
                                  message: asset.name,
                                  excludeFromSemantics: true,
                                  child: Text(
                                    asset.name,
                                    style: type.subheading,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              const SizedBox(height: ZaidangSpacing.xs),
                              Row(
                                children: [
                                  ExcludeSemantics(
                                    child: Container(
                                      width: _kindBadgeExtent,
                                      height: _kindBadgeExtent,
                                      decoration: BoxDecoration(
                                        color: tokens.accent.withValues(
                                          alpha: 0.08,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        roleAssetKindIcon(asset.kind),
                                        size: _kindIconSize,
                                        color: tokens.accent,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: ZaidangSpacing.xs),
                                  Flexible(
                                    child: Text(
                                      '${asset.kind.label} · ${_formatBytes(asset.bytes)}',
                                      style: type.caption,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: ZaidangSpacing.xs),
                              Text(
                                date,
                                key: ValueKey('role-asset-date-${asset.id}'),
                                semanticsLabel: '导入时间：$date',
                                style: type.micro,
                              ),
                              if (asset.tags.isNotEmpty) ...[
                                const SizedBox(height: ZaidangSpacing.xs),
                                Wrap(
                                  spacing: ZaidangSpacing.xs,
                                  runSpacing: ZaidangSpacing.xs,
                                  children: [
                                    for (final tag in asset.tags)
                                      RoleAssetTag(tag),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Builder(
              builder: (context) => IconButton(
                key: ValueKey('role-asset-more-${asset.id}'),
                tooltip: '更多操作：${asset.name}',
                icon: Icon(
                  Icons.more_horiz,
                  size: _menuIconSize,
                  color: tokens.inkSecondary,
                ),
                onPressed: onMore == null ? null : () => onMore!(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 类型徽记与无预览时的占位图共用同一套图标。
IconData roleAssetKindIcon(RoleAssetKind kind) => switch (kind) {
  RoleAssetKind.image => Icons.image_outlined,
  RoleAssetKind.video => Icons.videocam_outlined,
  RoleAssetKind.audio => Icons.audio_file_outlined,
  RoleAssetKind.document => Icons.description_outlined,
};

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
