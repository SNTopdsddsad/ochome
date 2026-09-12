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
/// 传入 [paperHeader] 时名片不再渲染，改由头图下方的纸面身份头承担识别信息。
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
    this.coverHeight = immersiveCoverHeight,
    this.paperHeader,
    this.paperHeaderOverlap = 0,
    this.backdropBlur = defaultBackdropBlur,
    this.heroKey = const Key('role-create-cover-hero'),
    this.portraitKey = const Key('role-create-cover-portrait'),
  });

  /// 背景模糊的默认 sigma，以及「立绘直出」的取值。
  static const double defaultBackdropBlur = 6;
  static const double noBlur = 0;

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

  /// 展开时的图片区高度，不包含身份头与页签。
  final double coverHeight;

  /// 头图下方纸面上的身份头；高度计入展开高度。收起时它贴着页签整体上移、
  /// 立绘从底部被裁短，最后 100px 淡出让位给吸顶身份。
  final PreferredSizeWidget? paperHeader;

  /// [paperHeader] 顶部压到立绘上的高度（如大头像的上半），这部分不额外增加展开高度。
  final double paperHeaderOverlap;

  /// 背景模糊 sigma；传 0 时立绘直出不模糊（角色页把立绘本身当头图）。
  final double backdropBlur;

  /// 测试定位用的 key；两个编辑页各自传自己的前缀。
  final Key heroKey;
  final Key portraitKey;

  /// 身份头在立绘之下额外占用的高度。
  double get paperHeaderExtent {
    final header = paperHeader;
    if (header == null) {
      return 0;
    }
    assert(
      paperHeaderOverlap >= 0 &&
          paperHeaderOverlap <= header.preferredSize.height,
      'paperHeaderOverlap 必须在 0 与身份头高度之间，否则展开高度会小于立绘高度',
    );
    return header.preferredSize.height - paperHeaderOverlap;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    final paperHeader = this.paperHeader;

    return SliverAppBar(
      primary: false,
      pinned: bottom != null,
      floating: false,
      stretch: true,
      automaticallyImplyLeading: false,
      toolbarHeight: bottom == null ? 0 : toolbarHeight,
      collapsedHeight: bottom == null
          ? coverHeight + paperHeaderExtent
          : toolbarHeight,
      expandedHeight:
          coverHeight + paperHeaderExtent + (bottom?.preferredSize.height ?? 0),
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
            // 身份头贴着页签、立绘填满剩余高度：收起时先从底部裁掉立绘（顶对齐留住脸），
            // 身份头整体上移后再淡出；下拉回弹时立绘拉高、身份头随之下移。
            final photoHeight = paperHeader == null
                ? coverHeight
                : (constraints.maxHeight - paperHeaderExtent).clamp(
                    0.0,
                    double.infinity,
                  );
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
                  if (paperHeader == null)
                    Positioned.fill(
                      child: FlexibleSpaceBar(
                        collapseMode: CollapseMode.none,
                        stretchModes: const [StretchMode.zoomBackground],
                        background: _HeroBackdrop(
                          path: path,
                          blurSigma: backdropBlur,
                          supportDirectory: supportDirectory,
                        ),
                      ),
                    )
                  else
                    // 竖版立绘顶对齐留住脸，底部渐隐进纸面而不是压一层暗色。
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: photoHeight,
                      child: _HeroBackdrop(
                        path: path,
                        blurSigma: backdropBlur,
                        alignment: Alignment.topCenter,
                        paperFade: tokens.bg,
                        supportDirectory: supportDirectory,
                      ),
                    ),
                  if (paperHeader == null)
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
                  if (paperHeader == null)
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
                    )
                  else ...[
                    // 纸面从立绘底部的圆角盖一直铺到底，下拉回弹时随之拉长。
                    Positioned(
                      left: 0,
                      right: 0,
                      top: photoHeight - _heroCapHeight,
                      bottom: -1,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: tokens.bg,
                            borderRadius: ZaidangRadius.lgTop,
                          ),
                        ),
                      ),
                    ),
                    // 锚在底部：收起时随页签一起上移，最后 100px 与名片同样淡出，让位给吸顶身份。
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: paperHeader.preferredSize.height,
                      child: IgnorePointer(
                        ignoring: visible < 1,
                        child: Opacity(opacity: visible, child: paperHeader),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 钉在滚动层下面的头图。下拉回弹时露出的是这张图，不是画布白边。
///
/// [blurSigma] > 0 时是模糊背景（世界观页）；为 0 时立绘直出。传 [paperFade]
/// 时底部渐隐到纸色、顶部只留一层薄纱护住状态栏与玻璃按钮，不再整体压暗。
class _HeroBackdrop extends StatelessWidget {
  const _HeroBackdrop({
    required this.path,
    required this.blurSigma,
    this.alignment = Alignment.center,
    this.paperFade,
    this.supportDirectory,
  });

  final String path;
  final double blurSigma;
  final Alignment alignment;
  final Color? paperFade;
  final Future<Directory> Function()? supportDirectory;

  /// 模糊时略放大，遮住边缘被拉出的透明毛边。
  static const double _blurBleedScale = 1.04;

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    final hasCover = path.isNotEmpty;
    final fill = ColoredBox(color: tokens.surface);
    final photo = CoverFileView(
      coverImg: path,
      placeholder: fill,
      alignment: alignment,
      supportDirectory: supportDirectory,
    );
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        if (!hasCover)
          fill
        else if (blurSigma > 0)
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
              sigmaX: blurSigma,
              sigmaY: blurSigma,
              tileMode: ui.TileMode.clamp,
            ),
            child: Transform.scale(scale: _blurBleedScale, child: photo),
          )
        else
          photo,
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: _scrim(tokens, hasCover)),
          ),
        ),
      ],
    );
  }

  LinearGradient _scrim(ZaidangTokens tokens, bool hasCover) {
    final paper = paperFade;
    if (paper != null) {
      final veil = hasCover ? ZaidangTokens.dark.bg : tokens.bg;
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          veil.withValues(alpha: hasCover ? 0.18 : 0.08),
          veil.withValues(alpha: 0),
          paper.withValues(alpha: 0),
          paper.withValues(alpha: 0.55),
        ],
        stops: const [0, 0.3, 0.62, 1],
      );
    }
    return LinearGradient(
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
            placeholder: PortraitPlaceholder(compact: true, label: addLabel),
            supportDirectory: supportDirectory,
          )
        : PortraitPlaceholder(compact: false, label: addLabel);
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

/// 没有立绘 / 封面时的纸色占位：相机图标 + 「添加立绘」一类文案。名片与身份头共用。
class PortraitPlaceholder extends StatelessWidget {
  const PortraitPlaceholder({
    super.key,
    required this.compact,
    required this.label,
  });

  /// 紧凑版给已有立绘但文件缺失的小图位，图标更小。
  final bool compact;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
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
