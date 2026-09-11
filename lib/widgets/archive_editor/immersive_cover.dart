import 'dart:io';
import 'dart:ui' as ui show ImageFilter, TileMode;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/zaidang_radius.dart';
import '../../theme/zaidang_spacing.dart';
import '../../theme/zaidang_tokens.dart';
import '../../theme/zaidang_type.dart';
import '../cover_file_view.dart';

/// 对齐 memory 详情页媒体头图（含顶部沉浸），约 352pt。
const double immersiveCoverHeight = 352;

const double _heroCapHeight = 18;

/// 左下角名片图，3:4。
const double _portraitWidth = 90;
const double _portraitHeight = 120;

/// 沉浸式头图：高斯模糊背景 + 左下角名片。角色页与世界观页共用。
///
/// [title] / [subtitle] 是名片文字；[coverNoun] 决定「添加立绘 / 添加封面」这类文案。
class ImmersiveCover extends StatelessWidget {
  const ImmersiveCover({
    super.key,
    required this.path,
    required this.title,
    required this.overlayStyle,
    required this.hasCover,
    required this.onPick,
    required this.onPreview,
    this.subtitle = '',
    this.coverNoun = '立绘',
    this.supportDirectory,
    this.bottom,
    this.toolbarHeight = 60,
    this.heroKey = const Key('role-create-cover-hero'),
    this.portraitKey = const Key('role-create-cover-portrait'),
  });

  final String path;
  final String title;
  final String subtitle;
  final String coverNoun;
  final SystemUiOverlayStyle overlayStyle;
  final bool hasCover;
  final VoidCallback onPick;
  final VoidCallback? onPreview;
  final Future<Directory> Function()? supportDirectory;
  final PreferredSizeWidget? bottom;
  final double toolbarHeight;

  /// 测试定位用的 key；两个编辑页各自传自己的前缀。
  final Key heroKey;
  final Key portraitKey;

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);

    return SliverAppBar(
      primary: false,
      pinned: bottom != null,
      floating: false,
      stretch: true,
      automaticallyImplyLeading: false,
      toolbarHeight: bottom == null ? 0 : toolbarHeight,
      collapsedHeight: bottom == null ? immersiveCoverHeight : toolbarHeight,
      expandedHeight:
          immersiveCoverHeight + (bottom?.preferredSize.height ?? 0),
      bottom: bottom,
      systemOverlayStyle: overlayStyle,
      // 吸顶后 FlexibleSpaceBar 会淡出头图，必须由 Material 遮住下方滚动内容。
      backgroundColor: bottom == null ? Colors.transparent : tokens.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      forceMaterialTransparency: bottom == null,
      clipBehavior: Clip.hardEdge,
      flexibleSpace: Padding(
        padding: EdgeInsets.only(bottom: bottom?.preferredSize.height ?? 0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final visible = bottom == null
                ? 1.0
                : ((constraints.maxHeight - toolbarHeight - 60) / 100).clamp(
                    0.0,
                    1.0,
                  );
            final onPaper =
                bottom != null && constraints.maxHeight <= toolbarHeight + 24;
            final paperStyle = Theme.of(context).brightness == Brightness.dark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: onPaper
                  ? paperStyle.copyWith(
                      statusBarColor: Colors.transparent,
                      systemNavigationBarColor: tokens.bg,
                    )
                  : overlayStyle,
              child: Stack(
                key: heroKey,
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: FlexibleSpaceBar(
                      collapseMode: CollapseMode.none,
                      stretchModes: const [StretchMode.zoomBackground],
                      background: _HeroBackdrop(
                        path: path,
                        supportDirectory: supportDirectory,
                      ),
                    ),
                  ),
                  Positioned(
                    left: ZaidangSpacing.lg,
                    right: ZaidangSpacing.lg,
                    bottom: _heroCapHeight + ZaidangSpacing.md,
                    child: IgnorePointer(
                      ignoring: visible < 1,
                      child: Opacity(
                        opacity: visible,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _CallingCard(
                            path: path,
                            title: title,
                            subtitle: subtitle,
                            coverNoun: coverNoun,
                            hasCover: hasCover,
                            supportDirectory: supportDirectory,
                            onPick: onPick,
                            onPreview: onPreview,
                            portraitKey: portraitKey,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: -1,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: tokens.bg,
                          borderRadius: ZaidangRadius.lgTop,
                        ),
                        child: const SizedBox(height: _heroCapHeight),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 钉在滚动层下面的模糊头图。下拉回弹时露出的是这张图，不是画布白边。
class _HeroBackdrop extends StatelessWidget {
  const _HeroBackdrop({required this.path, this.supportDirectory});

  final String path;
  final Future<Directory> Function()? supportDirectory;

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    final hasCover = path.isNotEmpty;
    final fill = ColoredBox(color: tokens.surface);
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        hasCover
            ? ImageFiltered(
                imageFilter: ui.ImageFilter.blur(
                  sigmaX: 6,
                  sigmaY: 6,
                  tileMode: ui.TileMode.clamp,
                ),
                child: Transform.scale(
                  scale: 1.04,
                  child: CoverFileView(
                    coverImg: path,
                    placeholder: fill,
                    supportDirectory: supportDirectory,
                  ),
                ),
              )
            : fill,
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: hasCover
                    ? [
                        ZaidangTokens.dark.bg.withValues(alpha: 0.22),
                        ZaidangTokens.dark.bg.withValues(alpha: 0.08),
                        ZaidangTokens.dark.bg.withValues(alpha: 0.48),
                      ]
                    : [
                        tokens.bg.withValues(alpha: 0.08),
                        tokens.bg.withValues(alpha: 0),
                        tokens.bg.withValues(alpha: 0.16),
                      ],
                stops: const [0, 0.42, 1],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CallingCard extends StatelessWidget {
  const _CallingCard({
    required this.path,
    required this.title,
    required this.subtitle,
    required this.coverNoun,
    required this.hasCover,
    required this.onPick,
    required this.onPreview,
    required this.portraitKey,
    this.supportDirectory,
  });

  final String path;
  final String title;
  final String subtitle;
  final String coverNoun;
  final bool hasCover;
  final VoidCallback onPick;
  final VoidCallback? onPreview;
  final Key portraitKey;
  final Future<Directory> Function()? supportDirectory;

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    final type = ZaidangType.of(context);
    final addLabel = '添加$coverNoun';
    final portrait = hasCover
        ? CoverFileView(
            coverImg: path,
            placeholder: _PortraitPlaceholder(
              tokens: tokens,
              compact: true,
              label: addLabel,
            ),
            supportDirectory: supportDirectory,
          )
        : _PortraitPlaceholder(tokens: tokens, compact: false, label: addLabel);
    final portraitLabel = hasCover ? '查看$coverNoun' : addLabel;
    final onPortraitTap = hasCover ? onPreview : onPick;
    final changeLabel = '更换$coverNoun';

    return Material(
      color: tokens.surface,
      elevation: 2,
      shadowColor: tokens.ink.withValues(alpha: 0.18),
      borderRadius: ZaidangRadius.smAll,
      child: Padding(
        padding: const EdgeInsets.all(ZaidangSpacing.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              button: true,
              enabled: onPortraitTap != null,
              label: portraitLabel,
              child: InkWell(
                onTap: onPortraitTap,
                borderRadius: ZaidangRadius.smAll,
                child: ClipRRect(
                  borderRadius: ZaidangRadius.smAll,
                  child: SizedBox(
                    key: portraitKey,
                    width: _portraitWidth,
                    height: _portraitHeight,
                    child: portrait,
                  ),
                ),
              ),
            ),
            if (title.isNotEmpty || subtitle.isNotEmpty || hasCover) ...[
              const SizedBox(width: ZaidangSpacing.md),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 168),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title.isNotEmpty)
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: type.subheading,
                      ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: ZaidangSpacing.xs),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: type.micro,
                      ),
                    ],
                    if (hasCover) ...[
                      const SizedBox(height: ZaidangSpacing.xs),
                      Tooltip(
                        message: changeLabel,
                        excludeFromSemantics: true,
                        child: TextButton(
                          onPressed: onPick,
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            minimumSize: const Size(0, 32),
                            padding: EdgeInsets.zero,
                            alignment: Alignment.centerLeft,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text('更换', semanticsLabel: changeLabel),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: ZaidangSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}

class _PortraitPlaceholder extends StatelessWidget {
  const _PortraitPlaceholder({
    required this.tokens,
    required this.compact,
    required this.label,
  });

  final ZaidangTokens tokens;
  final bool compact;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: tokens.bg,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: compact ? 22 : 28,
            color: tokens.inkSecondary,
          ),
          const SizedBox(height: ZaidangSpacing.sm),
          Text(label, style: ZaidangType.of(context).micro),
        ],
      ),
    );
  }
}

/// 页签内容保活，切页签不丢草稿与滚动位置。
class KeepAliveDetails extends StatefulWidget {
  const KeepAliveDetails({super.key, required this.child});
  final Widget child;

  @override
  State<KeepAliveDetails> createState() => _KeepAliveDetailsState();
}

class _KeepAliveDetailsState extends State<KeepAliveDetails>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
