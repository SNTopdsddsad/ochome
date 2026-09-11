import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../theme/zaidang_radius.dart';
import '../theme/zaidang_spacing.dart';
import '../theme/zaidang_system_ui.dart';
import '../theme/zaidang_tokens.dart';
import '../theme/zaidang_type.dart';
import 'role_list_page.dart';
import 'world_view_page.dart';

/// 档案首页：大标题、搜索框、OC / 世界观 分段切换和备份入口，
/// 列表由两个页签各自渲染并共用同一个搜索词。
///
/// 头部拆成两段放在 [NestedScrollView] 的 header 里：标题区是 pinned 的
/// [SliverPersistentHeader]，上滑时大标题缩成一行小标题停在状态栏下方，
/// 副标题淡出、底下浮出一层毛玻璃；搜索框和页签随列表滚走。
/// 横屏、键盘弹起或系统大字号时都不会把列表挤到溢出。
class ArchivePage extends StatefulWidget {
  const ArchivePage({super.key});

  /// 浅色纸面上的手绘底图；深色模式只用纯色 `bg`，否则墨色文字会看不清。
  static const backgroundAsset = 'assets/images/role_bg.webp';

  @override
  State<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends State<ArchivePage>
    with SingleTickerProviderStateMixin {
  /// 分段切换和备份按钮的统一高度，与搜索框（含 48 的图标触控区）齐平；
  /// 标题收起后的顶栏也取这个高度。
  static const double _controlHeight = 48;

  /// 输入框聚焦描边宽度。
  static const double _focusedBorderWidth = 1.5;

  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
  );
  final _searchController = TextEditingController();

  /// 搜索框原文；归一化交给列表页，这里只决定清除按钮是否出现。
  var _query = '';

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => _query = value);
  }

  void _clearSearch() {
    // `clear()` 不会触发 onChanged，状态要自己同步。
    _searchController.clear();
    setState(() => _query = '');
  }

  /// 拖动头部或列表时收起键盘，和 `ScrollViewKeyboardDismissBehavior.onDrag` 同规则。
  bool _dismissKeyboardOnDrag(ScrollUpdateNotification notification) {
    final scope = FocusScope.of(context);
    if (notification.dragDetails != null &&
        !scope.hasPrimaryFocus &&
        scope.hasFocus) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: zaidangSystemUiOverlayStyle(context),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.bg,
          image: isLight
              ? const DecorationImage(
                  image: AssetImage(ArchivePage.backgroundAsset),
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                )
              : null,
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          // 不套 SafeArea：标题区自己吃掉状态栏高度，收起后的毛玻璃才能
          // 一直铺到屏幕顶边，而不是在状态栏下缘切出一条硬边。
          body: NotificationListener<ScrollUpdateNotification>(
            onNotification: _dismissKeyboardOnDrag,
            child: NestedScrollView(
              // 往回拖时头部先回来，搜索框和页签不用滚到顶才能用。
              floatHeaderSlivers: true,
              headerSliverBuilder: (context, _) => [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _ArchiveTitleDelegate(
                    metrics: _TitleMetrics.of(context),
                    tabController: _tabController,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      ZaidangSpacing.page,
                      ZaidangSpacing.sm,
                      ZaidangSpacing.page,
                      ZaidangSpacing.sm,
                    ),
                    child: ListenableBuilder(
                      listenable: _tabController,
                      builder: (context, _) => _buildControls(context),
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabController,
                children: [
                  RoleListPage(query: _query),
                  WorldViewPage(query: _query),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    final onWorlds = _tabController.index == 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSearchField(
          context,
          hint: onWorlds ? '搜索世界观名、简介或词条…' : '搜索角色名、标签或设定…',
        ),
        const SizedBox(height: ZaidangSpacing.md),
        Row(
          children: [
            Expanded(child: _buildSegments(context)),
            const SizedBox(width: ZaidangSpacing.sm),
            _buildBackupButton(context),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchField(BuildContext context, {required String hint}) {
    final tokens = ZaidangTokens.of(context);
    final type = ZaidangType.of(context);
    final border = OutlineInputBorder(
      borderRadius: ZaidangRadius.mdAll,
      borderSide: BorderSide(color: tokens.border),
    );

    return TextField(
      key: const Key('archive-search'),
      controller: _searchController,
      onChanged: _onSearchChanged,
      textInputAction: TextInputAction.search,
      style: type.body,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: type.body.copyWith(color: tokens.inkSecondary),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: ZaidangSpacing.lg,
          vertical: ZaidangSpacing.md,
        ),
        prefixIcon: Icon(Icons.search, color: tokens.inkSecondary),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                key: const Key('archive-search-clear'),
                tooltip: '清除搜索',
                icon: Icon(Icons.close, color: tokens.inkSecondary),
                onPressed: _clearSearch,
              ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(
            color: tokens.accent,
            width: _focusedBorderWidth,
          ),
        ),
      ),
    );
  }

  Widget _buildSegments(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    // 选中块的圆角与外框同心：外框 md 减去内边距。
    final innerRadius = BorderRadius.circular(
      ZaidangRadius.md - ZaidangSpacing.xs,
    );

    return Container(
      height: _controlHeight,
      padding: const EdgeInsets.all(ZaidangSpacing.xs),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border.all(color: tokens.border),
        borderRadius: ZaidangRadius.mdAll,
      ),
      child: TabBar(
        controller: _tabController,
        dividerHeight: 0,
        labelPadding: EdgeInsets.zero,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: tokens.accent,
          borderRadius: innerRadius,
        ),
        splashBorderRadius: innerRadius,
        labelColor: tokens.onAccent,
        unselectedLabelColor: tokens.inkSecondary,
        tabs: const [
          Tab(text: 'OC'),
          Tab(text: '世界观'),
        ],
      ),
    );
  }

  Widget _buildBackupButton(BuildContext context) {
    final tokens = ZaidangTokens.of(context);

    return IconButton(
      key: const Key('archive-backup'),
      tooltip: '备份与恢复',
      icon: const Icon(Icons.cloud_outlined),
      onPressed: () => context.push('/backup'),
      style: IconButton.styleFrom(
        foregroundColor: tokens.ink,
        backgroundColor: tokens.surface,
        fixedSize: const Size.square(_controlHeight),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: BorderSide(color: tokens.border),
        shape: const RoundedRectangleBorder(borderRadius: ZaidangRadius.mdAll),
      ),
    );
  }
}

/// 标题区展开 / 收起两态的尺寸，由字号刻度和系统字体缩放算出，
/// 不写死像素，大字号下也不会把标题挤出头部。
@immutable
class _TitleMetrics {
  const _TitleMetrics({
    required this.topPadding,
    required this.heroHeight,
    required this.captionHeight,
    required this.compactScale,
  });

  factory _TitleMetrics.of(BuildContext context) {
    final type = ZaidangType.of(context);
    return _TitleMetrics(
      topPadding: MediaQuery.paddingOf(context).top,
      heroHeight: _lineHeight(context, type.hero),
      captionHeight: _lineHeight(context, type.caption),
      compactScale: type.heading.fontSize! / type.hero.fontSize!,
    );
  }

  /// 状态栏高度；标题区替整页吃掉它，毛玻璃才能铺到屏幕顶边。
  final double topPadding;

  /// `hero` 一行的高度。
  final double heroHeight;

  /// `caption` 副标题一行的高度。
  final double captionHeight;

  /// 收起时大标题缩到 `heading` 字号的比例。
  final double compactScale;

  /// 展开态：上留白 + 大标题 + 间距 + 副标题 + 下留白。
  double get largeExtent =>
      ZaidangSpacing.lg +
      heroHeight +
      ZaidangSpacing.xs +
      captionHeight +
      ZaidangSpacing.sm;

  /// 收起态：与搜索框、页签同高的一条顶栏；大字号下按缩后的标题撑开。
  double get compactExtent => math.max(
    _ArchivePageState._controlHeight,
    heroHeight * compactScale + ZaidangSpacing.sm * 2,
  );

  double get minExtent => topPadding + compactExtent;

  double get maxExtent => topPadding + largeExtent;

  /// 展开态标题顶边。
  double get largeTitleTop => topPadding + ZaidangSpacing.lg;

  /// 收起态标题顶边：缩后的标题在顶栏里垂直居中。
  double get compactTitleTop =>
      topPadding + (compactExtent - heroHeight * compactScale) / 2;

  static double _lineHeight(BuildContext context, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: '我的', style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    try {
      return painter.height;
    } finally {
      painter.dispose();
    }
  }

  @override
  bool operator ==(Object other) {
    return other is _TitleMetrics &&
        other.topPadding == topPadding &&
        other.heroHeight == heroHeight &&
        other.captionHeight == captionHeight &&
        other.compactScale == compactScale;
  }

  @override
  int get hashCode =>
      Object.hash(topPadding, heroHeight, captionHeight, compactScale);
}

/// pinned 标题区：随 `shrinkOffset` 把大标题缩成小标题、淡出副标题，
/// 并在有内容滑到底下时浮出一层与纸面同色的毛玻璃。
class _ArchiveTitleDelegate extends SliverPersistentHeaderDelegate {
  const _ArchiveTitleDelegate({
    required this.metrics,
    required this.tabController,
  });

  /// 副标题在收起进度到这里时完全淡出，别拖到和小标题重叠。
  static const double _subtitleFadeEnd = 0.6;

  /// 毛玻璃参数与编辑页的玻璃按钮一致。
  static const double _frostBlur = 12;
  static const double _frostAlpha = 0.72;

  final _TitleMetrics metrics;
  final TabController tabController;

  @override
  double get minExtent => metrics.minExtent;

  @override
  double get maxExtent => metrics.maxExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final tokens = ZaidangTokens.of(context);
    final type = ZaidangType.of(context);
    final range = maxExtent - minExtent;
    final t = range <= 0 ? 1.0 : (shrinkOffset / range).clamp(0.0, 1.0);
    final titleTop = ui.lerpDouble(
      metrics.largeTitleTop,
      metrics.compactTitleTop,
      t,
    )!;
    final subtitleOpacity = (1 - t / _subtitleFadeEnd).clamp(0.0, 1.0);

    return ListenableBuilder(
      listenable: tabController,
      builder: (context, _) {
        final onWorlds = tabController.index == 1;
        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (t > 0)
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(
                      sigmaX: _frostBlur * t,
                      sigmaY: _frostBlur * t,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: tokens.bg.withValues(alpha: _frostAlpha * t),
                        border: Border(
                          bottom: BorderSide(
                            color: tokens.border.withValues(alpha: t),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: titleTop,
                left: ZaidangSpacing.page,
                right: ZaidangSpacing.page,
                child: Transform.scale(
                  scale: ui.lerpDouble(1, metrics.compactScale, t)!,
                  alignment: Alignment.topLeft,
                  child: _ArchiveTitle(onWorlds: onWorlds),
                ),
              ),
              Positioned(
                top: titleTop + metrics.heroHeight + ZaidangSpacing.xs,
                left: ZaidangSpacing.page,
                right: ZaidangSpacing.page,
                child: Opacity(
                  opacity: subtitleOpacity,
                  child: Text('记录、设定与灵感', style: type.caption),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  bool shouldRebuild(covariant _ArchiveTitleDelegate oldDelegate) {
    return oldDelegate.metrics != metrics ||
        oldDelegate.tabController != tabController;
  }
}

/// `我的` + accent 的 ` OC` / `世界观` + 装饰星标。
class _ArchiveTitle extends StatelessWidget {
  const _ArchiveTitle({required this.onWorlds});

  /// 标题旁的装饰星标尺寸。
  static const double _sparkleSize = 18;

  final bool onWorlds;

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    final type = ZaidangType.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Text.rich(
            TextSpan(
              style: type.hero,
              children: [
                const TextSpan(text: '我的'),
                TextSpan(
                  text: onWorlds ? '世界观' : ' OC',
                  style: type.hero.copyWith(color: tokens.accent),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: ZaidangSpacing.xs),
        Icon(Icons.auto_awesome, size: _sparkleSize, color: tokens.accent),
      ],
    );
  }
}
