import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/world.dart';
import '../data/models/world_entry.dart';
import '../data/providers/world_repository_provider.dart';
import '../data/providers/worlds_provider.dart';
import '../data/services/cover_image_picker.dart';
import '../theme/zaidang_radius.dart';
import '../theme/zaidang_spacing.dart';
import '../theme/zaidang_system_ui.dart';
import '../theme/zaidang_tokens.dart';
import '../theme/zaidang_type.dart';
import '../widgets/archive_editor/archive_card.dart';
import '../widgets/archive_editor/glass_buttons.dart';
import '../widgets/archive_editor/immersive_cover.dart';
import '../widgets/archive_editor/pinned_identity.dart';
import '../widgets/cover_file_view.dart';
import '../widgets/role_list_tile.dart';
import '../widgets/section_label.dart';
import '../widgets/zaidang_confirm_dialog.dart';
import '../widgets/zaidang_snack_bar.dart';
import 'cover_preview_page.dart';

/// 新建 / 编辑世界观。传入 [world] 即为编辑，字段按原文回填。
///
/// 结构照 `RoleCreatePage`：沉浸封面 + 玻璃工具栏；编辑态分「详情 / 角色」页签。
class WorldCreatePage extends ConsumerStatefulWidget {
  const WorldCreatePage({
    super.key,
    this.world,
    this.picker,
    this.supportDirectory,
  });

  final World? world;

  /// 测试注入：替换系统相册选择器。
  final CoverImagePicker? picker;

  /// 测试注入：封面沙盒根目录；正式运行用系统 Application Support。
  final Future<Directory> Function()? supportDirectory;

  @override
  ConsumerState<WorldCreatePage> createState() => _WorldCreatePageState();
}

class _WorldCreatePageState extends ConsumerState<WorldCreatePage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final CoverImagePicker _picker = widget.picker ?? CoverImagePicker();

  late final TextEditingController _nameController;
  late final TextEditingController _summaryController;

  final _scrollController = ScrollController();
  late final TabController _detailTabs;
  ScrollPosition? _detailsScrollPosition;
  final _entriesKey = GlobalKey<SliverReorderableListState>();
  final _entries = <_EntryDraft>[];
  bool _validateEntries = false;

  late String _coverImg;

  /// 保存或删除进行中，表单与导航都锁住。
  bool _busy = false;
  bool _saving = false;
  bool _coverReadable = false;

  bool get _isEditing => widget.world != null;

  /// 聚焦字段时滚动到可见区所留的余量；编辑态顶部还要让开吸顶工具栏。
  static const double _fieldScrollInset = 80;
  static const double _fieldScrollTopInset = 128;

  EdgeInsets get _fieldScrollPadding => EdgeInsets.fromLTRB(
    _fieldScrollInset,
    _isEditing
        ? MediaQuery.viewPaddingOf(context).top + _fieldScrollTopInset
        : _fieldScrollInset,
    _fieldScrollInset,
    _fieldScrollInset,
  );

  @override
  void initState() {
    super.initState();
    _detailTabs = TabController(length: 2, vsync: this)
      ..addListener(_onDetailTabChanged);
    final world = widget.world;
    _nameController = TextEditingController(text: world?.name ?? '');
    _summaryController = TextEditingController(text: world?.summary ?? '');
    _coverImg = world?.coverImg ?? '';
    _entries.addAll((world?.entries ?? []).map(_EntryDraft.fromEntry));
    _nameController.addListener(_onIdentityChanged);
    _refreshCoverReadable();
  }

  void _onDetailTabChanged() {
    FocusManager.instance.primaryFocus?.unfocus();
    _entriesKey.currentState?.cancelReorder();
  }

  void _onIdentityChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_onIdentityChanged);
    _nameController.dispose();
    _summaryController.dispose();
    _detailTabs.dispose();
    _scrollController.dispose();
    for (final entry in _entries) {
      entry.dispose();
    }
    super.dispose();
  }

  Future<void> _pickCover() async {
    final path = await _picker.pickFromGallery();
    if (path == null || !mounted) {
      return;
    }
    setState(() {
      _coverImg = path;
    });
    await _refreshCoverReadable();
  }

  /// 打开全屏预览，只退出预览层，不提交表单、不改 [_coverImg]。
  Future<void> _openCoverPreview() async {
    if (_busy) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CoverPreviewPage(
          coverImages: [_coverImg],
          supportDirectory: widget.supportDirectory,
        ),
      ),
    );
  }

  Future<void> _refreshCoverReadable() async {
    final readable = await CoverFileView.exists(
      _coverImg,
      supportDirectory: widget.supportDirectory,
    );
    if (mounted && readable != _coverReadable) {
      setState(() {
        _coverReadable = readable;
      });
    }
  }

  Future<void> _submit() async {
    if (_busy) {
      return;
    }
    setState(() => _validateEntries = true);
    // Sliver 行可能在屏外未挂载，所以整份草稿都要校验。
    final fieldsValid =
        _formKey.currentState!.validate() &&
        _nameController.text.trim().isNotEmpty;
    final entriesValid = _entries.every(
      (entry) => entry.title.text.trim().isNotEmpty,
    );
    if (!fieldsValid || !entriesValid) {
      if (!entriesValid) {
        showZaidangSnackBar(context, '请填写每条词条的标题');
      }
      return;
    }
    _entriesKey.currentState?.cancelReorder();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _saving = true;
    });
    try {
      final repository = ref.read(worldRepositoryProvider);
      final name = _nameController.text.trim();
      final summary = _summaryController.text.trim();
      final entries = List<WorldEntry>.unmodifiable(
        _entries.map(
          (entry) => WorldEntry(
            title: entry.title.text.trim(),
            content: entry.content.text.trim(),
          ),
        ),
      );
      if (_isEditing) {
        await repository.update(
          World(
            id: widget.world!.id,
            name: name,
            summary: summary,
            coverImg: _coverImg,
            entries: entries,
          ),
        );
      } else {
        await repository.create(
          name: name,
          summary: summary,
          coverImg: _coverImg,
          entries: entries,
        );
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        showZaidangSnackBar(
          context,
          '保存失败：$error',
          tone: ZaidangSnackBarTone.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _saving = false;
        });
      }
    }
  }

  Future<void> _openMoreActions() async {
    if (_busy || !_isEditing) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final tokens = ZaidangTokens.of(context);
    final action = await showModalBottomSheet<_MoreAction>(
      context: context,
      backgroundColor: tokens.surface,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('world-delete-action'),
              leading: Icon(Icons.delete_outline, color: tokens.ink),
              title: Text('删除世界观', style: TextStyle(color: tokens.ink)),
              onTap: () => Navigator.of(context).pop(_MoreAction.delete),
            ),
            const SizedBox(height: ZaidangSpacing.sm),
          ],
        ),
      ),
    );
    if (action == _MoreAction.delete && mounted) {
      await _confirmDelete();
    }
  }

  Future<void> _confirmDelete() async {
    final world = widget.world;
    if (world == null || _busy) return;
    final name = _nameController.text.trim();
    final confirmed = await showZaidangConfirmDialog(
      context: context,
      title: '要删掉这个世界观吗？',
      body: name.isEmpty ? '这个世界观和里面的词条会一起移除。' : '「$name」和里面的词条会一起移除。',
      consequence: '归属它的角色不会被删除，只会解除归属。',
      cancelLabel: '先留着',
      cancelSemanticLabel: '先留着，保留这个世界观',
      confirmLabel: '删除世界观',
    );
    if (!confirmed || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(worldRepositoryProvider).delete(world.id);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        showZaidangSnackBar(
          context,
          '删除失败：$error',
          tone: ZaidangSnackBarTone.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    final mediaPadding = MediaQuery.paddingOf(context);
    final topInset = mediaPadding.top;
    final overlayStyle = zaidangSystemUiOverlayStyle(
      context,
      onDarkBackdrop: _coverImg.isNotEmpty,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: PopScope(
        canPop: !_busy,
        child: Scaffold(
          backgroundColor: tokens.bg,
          body: Form(
            key: _formKey,
            child: Stack(
              children: [
                MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  removeLeft: true,
                  removeRight: true,
                  child: AbsorbPointer(
                    absorbing: _busy,
                    child: _buildScroll(context, overlayStyle, topInset),
                  ),
                ),
                Positioned(
                  top: topInset + ZaidangSpacing.sm,
                  left: ZaidangSpacing.lg,
                  right: ZaidangSpacing.lg,
                  child: SizedBox(
                    height: glassButtonSize,
                    child: NavigationToolbar(
                      centerMiddle: true,
                      middleSpacing: ZaidangSpacing.md,
                      leading: GlassIconButton(
                        icon: Icons.arrow_back_ios_new,
                        iconSize: 16,
                        tooltip: '返回',
                        onPhoto: _coverImg.isNotEmpty,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      middle: _isEditing
                          ? AnimatedBuilder(
                              animation: _scrollController,
                              builder: (context, child) {
                                final collapseOffset =
                                    immersiveCoverHeight - topInset - 60;
                                final offset = _scrollController.hasClients
                                    ? _scrollController.offset
                                    : 0.0;
                                final opacity =
                                    ((offset - collapseOffset + 24) / 24).clamp(
                                      0.0,
                                      1.0,
                                    );
                                if (opacity == 0) {
                                  return const SizedBox.shrink();
                                }
                                return IgnorePointer(
                                  child: Opacity(
                                    opacity: opacity,
                                    child: child,
                                  ),
                                );
                              },
                              child: PinnedIdentity(
                                name: _nameController.text.trim(),
                                coverImg: _coverImg,
                                supportDirectory: widget.supportDirectory,
                                emptyName: '未命名世界观',
                                placeholderIcon: Icons.public_outlined,
                                boxKey: const Key('world-pinned-identity'),
                                portraitKey: const Key('world-pinned-portrait'),
                              ),
                            )
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isEditing) ...[
                            GlassIconButton(
                              key: const Key('world-more-action'),
                              icon: Icons.more_horiz,
                              iconSize: 20,
                              tooltip: '更多',
                              onPhoto: _coverImg.isNotEmpty,
                              onTap: _busy ? null : _openMoreActions,
                            ),
                            const SizedBox(width: ZaidangSpacing.sm),
                          ],
                          GlassSaveButton(
                            saving: _saving,
                            onPhoto: _coverImg.isNotEmpty,
                            onPressed: _busy ? null : _submit,
                          ),
                        ],
                      ),
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

  Widget _buildScroll(
    BuildContext context,
    SystemUiOverlayStyle overlayStyle,
    double topInset,
  ) {
    Widget cover({PreferredSizeWidget? tabs}) => ImmersiveCover(
      path: _coverImg,
      title: _nameController.text.trim(),
      coverNoun: '封面',
      overlayStyle: overlayStyle,
      hasCover: _coverReadable,
      supportDirectory: widget.supportDirectory,
      onPick: _pickCover,
      onPreview: _busy ? null : _openCoverPreview,
      bottom: tabs,
      toolbarHeight: topInset + 60,
      heroKey: const Key('world-create-cover-hero'),
      portraitKey: const Key('world-create-cover-portrait'),
    );
    if (!_isEditing) {
      return CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [cover(), _buildDetailsSliver(context)],
      );
    }
    final tokens = ZaidangTokens.of(context);
    return NestedScrollView(
      key: const Key('world-detail-nested-scroll'),
      controller: _scrollController,
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverOverlapAbsorber(
          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
          sliver: cover(
            tabs: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: ColoredBox(
                color: tokens.bg,
                child: TabBar(
                  key: const Key('world-detail-tabs'),
                  controller: _detailTabs,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: tokens.accent,
                  unselectedLabelColor: tokens.inkSecondary,
                  indicatorColor: tokens.accent,
                  dividerColor: tokens.border,
                  padding: const EdgeInsets.symmetric(
                    horizontal: ZaidangSpacing.sm,
                  ),
                  tabs: const [
                    Tab(text: '详情'),
                    Tab(text: '角色'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
      body: Builder(
        builder: (context) {
          final handle = NestedScrollView.sliverOverlapAbsorberHandleFor(
            context,
          );
          return NotificationListener<ScrollStartNotification>(
            onNotification: (notification) {
              if (notification.depth == 0 &&
                  notification.dragDetails != null &&
                  notification.metrics.axis == Axis.horizontal) {
                _onDetailTabChanged();
              }
              return false;
            },
            child: TabBarView(
              controller: _detailTabs,
              children: [
                KeepAliveDetails(
                  child: CustomScrollView(
                    key: const PageStorageKey('world-details-scroll'),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      SliverOverlapInjector(handle: handle),
                      SliverLayoutBuilder(
                        builder: (context, constraints) {
                          _detailsScrollPosition = Scrollable.of(context)
                              .position;
                          return _buildDetailsSliver(context);
                        },
                      ),
                    ],
                  ),
                ),
                _WorldRolesTab(
                  worldId: widget.world!.id,
                  overlapHandle: handle,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailsSliver(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final horizontal = archiveEditorHorizontalPadding(context);
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        horizontal,
        ZaidangSpacing.sm,
        horizontal,
        ZaidangSpacing.xxxl + bottomInset,
      ),
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isEditing ? '编辑世界观' : '新建世界观',
                  style: ZaidangType.of(context).title,
                ),
                const SizedBox(height: ZaidangSpacing.lg),
                _buildBasicCard(),
                const SizedBox(height: ZaidangSpacing.lg),
                _buildSummaryCard(),
                const SizedBox(height: ZaidangSpacing.lg),
              ],
            ),
          ),
          _buildEntries(tokens),
        ],
      ),
    );
  }

  Widget _buildBasicCard() => ArchiveCard(
    key: const Key('world-create-basic-card'),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('基本信息'),
        _field(
          controller: _nameController,
          label: '名称',
          hint: '这个世界叫什么',
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '请填写名称';
            }
            return null;
          },
        ),
      ],
    ),
  );

  Widget _buildSummaryCard() => ArchiveCard(
    key: const Key('world-create-summary-card'),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('简介'),
        _field(
          controller: _summaryController,
          hint: '一句话说清这个世界的底色',
          minLines: 3,
          maxLines: 8,
          textInputAction: TextInputAction.newline,
        ),
      ],
    ),
  );

  void _addEntry() {
    if (_busy) return;
    final entry = _EntryDraft();
    setState(() => _entries.add(entry));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _busy || !_entries.contains(entry)) return;
      // 先把新追加的 sliver 行滚进视口再请求焦点。
      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
      if (!mounted || _busy || !_entries.contains(entry)) return;
      if (_isEditing && _detailsScrollPosition != null) {
        await _detailsScrollPosition!.animateTo(
          _detailsScrollPosition!.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
      if (!mounted || _busy || !_entries.contains(entry)) return;
      entry.titleFocus.requestFocus();
    });
  }

  void _moveEntry(_EntryDraft entry, int offset) {
    if (_busy) return;
    final index = _entries.indexOf(entry);
    final destination = index + offset;
    if (index < 0 || destination < 0 || destination >= _entries.length) {
      return;
    }
    _entriesKey.currentState?.cancelReorder();
    setState(() {
      _entries.removeAt(index);
      _entries.insert(destination, entry);
    });
  }

  Future<void> _removeEntry(_EntryDraft entry) async {
    if (_busy || !_entries.contains(entry)) return;
    final title = entry.title.text.trim();
    final remove = await showZaidangConfirmDialog(
      context: context,
      title: '要删掉这条词条吗？',
      body: title.isEmpty ? '这条未命名词条和里面的内容会一起移除。' : '「$title」和里面的内容会一起移除。',
      consequence: '保存世界观后生效。',
      cancelLabel: '先留着',
      cancelSemanticLabel: '先留着，保留这条词条',
      confirmLabel: '删除词条',
    );
    if (remove != true || !mounted || _busy || !_entries.contains(entry)) {
      return;
    }
    _entriesKey.currentState?.cancelReorder();
    setState(() => _entries.remove(entry));
    // 旧 TextField 先卸载，再释放控制器。
    WidgetsBinding.instance.addPostFrameCallback((_) => entry.dispose());
  }

  Widget _addEntryButton() => TextButton.icon(
    key: const Key('world-entry-add'),
    onPressed: _busy ? null : _addEntry,
    icon: const Icon(Icons.add, size: 20),
    label: const Text('添加词条'),
  );

  Widget _buildEntries(ZaidangTokens tokens) {
    if (_entries.isEmpty) {
      return SliverToBoxAdapter(child: _addEntryButton());
    }
    return DecoratedSliver(
      key: const Key('world-create-entries-card'),
      decoration: archiveCardDecoration(tokens),
      sliver: SliverPadding(
        padding: const EdgeInsets.all(ZaidangSpacing.card),
        sliver: SliverMainAxisGroup(
          slivers: [
            const SliverToBoxAdapter(child: SectionLabel('词条')),
            SliverReorderableList(
              key: _entriesKey,
              itemCount: _entries.length,
              findChildIndexCallback: (key) {
                final draftKey = key is GlobalObjectKey ? key.value : key;
                final index = _entries.indexWhere(
                  (entry) => entry.key == draftKey,
                );
                return index < 0 ? null : index;
              },
              onReorderItem: (oldIndex, newIndex) {
                if (_busy) return;
                setState(
                  () => _entries.insert(newIndex, _entries.removeAt(oldIndex)),
                );
              },
              onReorderStart: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              proxyDecorator: (child, index, animation) => Material(
                color: tokens.surface,
                elevation: 4,
                borderRadius: ZaidangRadius.smAll,
                child: child,
              ),
              itemBuilder: (context, index) {
                final entry = _entries[index];
                final number = index + 1;
                return Padding(
                  key: entry.key,
                  padding: const EdgeInsets.only(bottom: ZaidangSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '词条 $number',
                              style: ZaidangType.of(context).micro,
                            ),
                          ),
                          ReorderableDragStartListener(
                            index: index,
                            enabled: !_busy,
                            child: Semantics(
                              label: '拖动第 $number 条词条排序',
                              enabled: !_busy,
                              child: Tooltip(
                                message: '拖动排序',
                                excludeFromSemantics: true,
                                child: SizedBox.square(
                                  dimension: 48,
                                  child: Icon(
                                    Icons.drag_handle,
                                    color: _busy
                                        ? tokens.inkSecondary
                                        : tokens.ink,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: '上移第 $number 条词条',
                            onPressed: _busy || index == 0
                                ? null
                                : () => _moveEntry(entry, -1),
                            icon: Icon(
                              Icons.arrow_upward,
                              size: 20,
                              semanticLabel: '上移第 $number 条词条',
                            ),
                          ),
                          IconButton(
                            tooltip: '下移第 $number 条词条',
                            onPressed: _busy || index == _entries.length - 1
                                ? null
                                : () => _moveEntry(entry, 1),
                            icon: Icon(
                              Icons.arrow_downward,
                              size: 20,
                              semanticLabel: '下移第 $number 条词条',
                            ),
                          ),
                          IconButton(
                            tooltip: '删除第 $number 条词条',
                            onPressed: _busy ? null : () => _removeEntry(entry),
                            color: tokens.ink,
                            icon: Icon(
                              Icons.delete_outline,
                              size: 20,
                              semanticLabel: '删除第 $number 条词条',
                            ),
                          ),
                        ],
                      ),
                      TextFormField(
                        controller: entry.title,
                        focusNode: entry.titleFocus,
                        enabled: !_busy,
                        decoration: const InputDecoration(
                          labelText: '词条标题',
                          hintText: '例如：地理、势力、魔法体系',
                        ),
                        textInputAction: TextInputAction.next,
                        scrollPadding: _fieldScrollPadding,
                        autovalidateMode: _validateEntries
                            ? AutovalidateMode.always
                            : AutovalidateMode.disabled,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? '请填写词条标题'
                            : null,
                      ),
                      const SizedBox(height: ZaidangSpacing.md),
                      TextFormField(
                        controller: entry.content,
                        enabled: !_busy,
                        decoration: const InputDecoration(
                          labelText: '词条内容',
                          hintText: '可以分行填写，也可以暂时留空',
                        ),
                        minLines: 3,
                        maxLines: 12,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        scrollPadding: _fieldScrollPadding,
                      ),
                    ],
                  ),
                );
              },
            ),
            SliverToBoxAdapter(child: _addEntryButton()),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    String? label,
    required String hint,
    int minLines = 1,
    int maxLines = 1,
    TextInputAction textInputAction = TextInputAction.next,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label, hintText: hint),
      minLines: minLines,
      maxLines: maxLines,
      textInputAction: textInputAction,
      keyboardType: maxLines > 1 ? TextInputType.multiline : TextInputType.text,
      scrollPadding: _fieldScrollPadding,
      validator: validator,
    );
  }
}

enum _MoreAction { delete }

/// 「角色」页签：归属这个世界观的角色只读列表，点击进角色编辑页。
class _WorldRolesTab extends ConsumerWidget {
  const _WorldRolesTab({required this.worldId, required this.overlapHandle});

  final int worldId;
  final SliverOverlapAbsorberHandle overlapHandle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ZaidangTokens.of(context);
    final roles = ref.watch(rolesInWorldProvider(worldId));
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    Widget centered(Widget child) =>
        SliverFillRemaining(hasScrollBody: false, child: Center(child: child));

    return CustomScrollView(
      key: const PageStorageKey('world-roles-scroll'),
      slivers: [
        SliverOverlapInjector(handle: overlapHandle),
        roles.when(
          data: (items) {
            if (items.isEmpty) {
              return centered(
                Text(
                  '还没有角色归属这个世界观',
                  style: ZaidangType.of(context).body
                      .copyWith(color: tokens.inkSecondary),
                ),
              );
            }
            return SliverPadding(
              padding: EdgeInsets.only(
                top: ZaidangSpacing.sm,
                bottom: ZaidangSpacing.xxxl + bottomInset,
              ),
              sliver: SliverList.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) =>
                    RoleListTile(role: items[index]),
              ),
            );
          },
          loading: () => centered(const CircularProgressIndicator()),
          error: (error, _) => centered(
            Text('加载失败：$error', style: TextStyle(color: tokens.ink)),
          ),
        ),
      ],
    );
  }
}

class _EntryDraft {
  _EntryDraft({String title = '', String content = ''})
    : title = TextEditingController(text: title),
      content = TextEditingController(text: content);

  factory _EntryDraft.fromEntry(WorldEntry entry) =>
      _EntryDraft(title: entry.title, content: entry.content);

  final key = UniqueKey();
  final titleFocus = FocusNode();
  final TextEditingController title;
  final TextEditingController content;

  void dispose() {
    titleFocus.dispose();
    title.dispose();
    content.dispose();
  }
}
