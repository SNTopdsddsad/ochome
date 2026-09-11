import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/role.dart';
import '../data/models/role_custom_attribute.dart';
import '../data/providers/role_repository_provider.dart';
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
import '../widgets/archive_editor/role_identity_header.dart';
import '../utils/text_lines.dart';
import '../widgets/cover_file_view.dart';
import '../widgets/role_list_tile.dart';
import '../widgets/zaidang_confirm_dialog.dart';
import '../widgets/zaidang_snack_bar.dart';
import '../features/role_card/role_card_content.dart';
import 'cover_preview_page.dart';
import 'role_card_export_page.dart';
import 'role_desc_history_page.dart';
import 'role_assets_tab.dart';
import 'role_relationships_tab.dart';

/// 新建 / 编辑 OC 人设。传入 [role] 即为编辑，字段按原文回填。
class RoleCreatePage extends ConsumerStatefulWidget {
  const RoleCreatePage({
    super.key,
    this.role,
    this.picker,
    this.supportDirectory,
  });

  final Role? role;

  /// 测试注入：替换系统相册选择器。
  final CoverImagePicker? picker;

  /// 测试注入：立绘沙盒根目录；正式运行用系统 Application Support。
  final Future<Directory> Function()? supportDirectory;

  @override
  ConsumerState<RoleCreatePage> createState() => _RoleCreatePageState();
}

class _RoleCreatePageState extends ConsumerState<RoleCreatePage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final CoverImagePicker _picker = widget.picker ?? CoverImagePicker();

  late final TextEditingController _nameController;
  late final TextEditingController _sexController;
  late final TextEditingController _ageController;
  late final TextEditingController _birthdayController;
  late final TextEditingController _raceController;
  late final TextEditingController _occupationController;
  late final TextEditingController _descController;

  /// 身份头展示所依赖的字段，合并成一个可监听对象，避免每次 build 重新订阅。
  late final Listenable _identityListenable;

  final _scrollController = ScrollController();
  late final TabController _detailTabs;
  ScrollPosition? _detailsScrollPosition;
  bool _assetBusy = false;
  bool _relationshipBusy = false;

  /// 任一子 Tab 正在弹窗或写库时，禁止保存和返回。
  bool get _tabBusy => _assetBusy || _relationshipBusy;
  final _attributesKey = GlobalKey<SliverReorderableListState>();
  final _attributes = <_CustomAttributeDraft>[];
  bool _validateAttributes = false;

  late String _coverImg;

  /// 所属世界观；`null` 为未归属。提交前会核对该世界观仍然存在。
  int? _worldId;
  bool _saving = false;
  bool _exportOpen = false;

  /// 立绘是否可读（路径非空且文件存在）。决定槽位是预览还是选图、是否出现「更换」。
  bool _coverReadable = false;

  bool get _isEditing => widget.role != null;

  /// 聚焦字段时滚动到可见区所留的余量；编辑态顶部还要让开吸顶工具栏。
  static const double _fieldScrollInset = 80;
  static const double _fieldScrollTopInset = 128;

  /// 角色简介文本框右下角引号装饰的尺寸与透明度。
  static const double _quoteMarkSize = 28;
  static const double _quoteMarkAlpha = 0.3;

  EdgeInsets get _fieldScrollPadding => EdgeInsets.fromLTRB(
    _fieldScrollInset,
    _isEditing
        ? MediaQuery.viewPaddingOf(context).top + _fieldScrollTopInset
        : _fieldScrollInset,
    _fieldScrollInset,
    _fieldScrollInset,
  );

  Future<void> _openRoleCardExport() async {
    if (_saving || _exportOpen) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _attributesKey.currentState?.cancelReorder();
    final snapshot = RoleCardSnapshot(
      name: _nameController.text,
      sex: _sexController.text,
      age: _ageController.text,
      birthday: _birthdayController.text,
      race: _raceController.text,
      occupation: _occupationController.text,
      desc: _descController.text,
      coverImg: _coverImg,
      customAttributes: [
        for (final attribute in _attributes)
          RoleCustomAttribute(
            name: attribute.name.text,
            content: attribute.content.text,
          ),
      ],
    );
    setState(() => _exportOpen = true);
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => RoleCardExportPage(
            snapshot: snapshot,
            supportDirectory: widget.supportDirectory,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _exportOpen = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _detailTabs = TabController(length: 3, vsync: this)
      ..addListener(_onDetailTabChanged);
    final role = widget.role;
    _nameController = TextEditingController(text: role?.name ?? '');
    _sexController = TextEditingController(text: role?.sex ?? '');
    _ageController = TextEditingController(text: role?.age ?? '');
    _birthdayController = TextEditingController(text: role?.birthday ?? '');
    _raceController = TextEditingController(text: role?.race ?? '');
    _occupationController = TextEditingController(text: role?.occupation ?? '');
    _descController = TextEditingController(text: role?.desc ?? '');
    _identityListenable = Listenable.merge([
      _nameController,
      _sexController,
      _raceController,
      _occupationController,
      _descController,
    ]);
    _coverImg = role?.coverImg ?? '';
    _worldId = role?.worldId;
    _attributes.addAll(
      (role?.customAttributes ?? []).map(_CustomAttributeDraft.fromAttribute),
    );
    // 名字还要喂给吸顶的 PinnedIdentity，所以保留页面级重建；身份头自己监听其余字段。
    _nameController.addListener(_onNameChanged);
    _refreshCoverReadable();
  }

  void _onDetailTabChanged() {
    FocusManager.instance.primaryFocus?.unfocus();
    _attributesKey.currentState?.cancelReorder();
  }

  void _onNameChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _sexController.dispose();
    _ageController.dispose();
    _birthdayController.dispose();
    _raceController.dispose();
    _occupationController.dispose();
    _descController.dispose();
    _detailTabs.dispose();
    _scrollController.dispose();
    for (final attribute in _attributes) {
      attribute.dispose();
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
    if (_saving) {
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
    if (_saving || _tabBusy) {
      return;
    }
    setState(() => _validateAttributes = true);
    // Sliver rows can be offscreen and unmounted, so validate the entire draft.
    final fieldsValid =
        _formKey.currentState!.validate() &&
        _nameController.text.trim().isNotEmpty;
    final attributesValid = _attributes.every(
      (attribute) => attribute.name.text.trim().isNotEmpty,
    );
    if (!fieldsValid || !attributesValid) {
      if (!attributesValid) {
        showZaidangSnackBar(context, '请填写每条自定义属性的名称');
      }
      return;
    }
    _attributesKey.currentState?.cancelReorder();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _saving = true;
    });
    try {
      final repository = ref.read(roleRepositoryProvider);
      final name = _nameController.text.trim();
      final sex = _sexController.text.trim();
      final age = _ageController.text.trim();
      final birthday = _birthdayController.text.trim();
      final race = _raceController.text.trim();
      final occupation = _occupationController.text.trim();
      final desc = _descController.text.trim();
      final customAttributes = List<RoleCustomAttribute>.unmodifiable(
        _attributes.map(
          (attribute) => RoleCustomAttribute(
            name: attribute.name.text.trim(),
            content: attribute.content.text.trim(),
          ),
        ),
      );
      // 编辑期间世界观可能已被删除；置空而不是让外键报错。
      final worldId = await _resolveWorldId();
      if (_isEditing) {
        await repository.update(
          Role(
            id: widget.role!.id,
            name: name,
            sex: sex,
            age: age,
            birthday: birthday,
            race: race,
            occupation: occupation,
            desc: desc,
            coverImg: _coverImg,
            customAttributes: customAttributes,
            worldId: worldId,
          ),
        );
      } else {
        await repository.create(
          name: name,
          sex: sex,
          age: age,
          birthday: birthday,
          race: race,
          occupation: occupation,
          desc: desc,
          coverImg: _coverImg,
          customAttributes: customAttributes,
          worldId: worldId,
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
          _saving = false;
        });
      }
    }
  }

  Future<int?> _resolveWorldId() async {
    final worldId = _worldId;
    if (worldId == null) return null;
    final exists = await ref.read(worldRepositoryProvider).getById(worldId);
    if (exists == null && mounted) {
      setState(() => _worldId = null);
    }
    return exists?.id;
  }

  Future<void> _pickWorld() async {
    if (_saving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final worlds = await ref.read(worldRepositoryProvider).list();
    if (!mounted) return;
    final tokens = ZaidangTokens.of(context);
    final picked = await showModalBottomSheet<_WorldChoice>(
      context: context,
      backgroundColor: tokens.surface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final maxHeight = MediaQuery.sizeOf(context).height * 0.7;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: ListView(
              key: const Key('role-world-picker'),
              shrinkWrap: true,
              children: [
                ListTile(
                  key: const Key('role-world-option-none'),
                  leading: Icon(
                    Icons.block_outlined,
                    color: tokens.inkSecondary,
                  ),
                  title: Text('不归属', style: TextStyle(color: tokens.ink)),
                  trailing: _worldId == null
                      ? Icon(Icons.check, color: tokens.accent)
                      : null,
                  onTap: () =>
                      Navigator.of(context).pop(const _WorldChoice(null)),
                ),
                if (worlds.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      ZaidangSpacing.lg,
                      ZaidangSpacing.sm,
                      ZaidangSpacing.lg,
                      ZaidangSpacing.lg,
                    ),
                    child: Text(
                      '还没有世界观',
                      style: ZaidangType.of(context).body
                          .copyWith(color: tokens.inkSecondary),
                    ),
                  ),
                for (final world in worlds)
                  ListTile(
                    key: Key('role-world-option-${world.id}'),
                    leading: SizedBox.square(
                      dimension: 40,
                      child: RoleCoverThumb(
                        path: world.coverImg,
                        placeholderIcon: Icons.public_outlined,
                      ),
                    ),
                    title: Text(
                      world.name,
                      style: TextStyle(color: tokens.ink),
                    ),
                    trailing: _worldId == world.id
                        ? Icon(Icons.check, color: tokens.accent)
                        : null,
                    onTap: () =>
                        Navigator.of(context).pop(_WorldChoice(world.id)),
                  ),
                const SizedBox(height: ZaidangSpacing.sm),
              ],
            ),
          ),
        );
      },
    );
    if (picked == null || !mounted || _saving) return;
    setState(() => _worldId = picked.worldId);
  }

  Widget _buildWorldRow() {
    final tokens = ZaidangTokens.of(context);
    final worldId = _worldId;
    String label;
    if (worldId == null) {
      label = '未归属';
    } else {
      // 只有真的有归属才订阅世界观列表，未归属的表单不碰世界观仓库。
      final worlds = ref.watch(worldsProvider).value;
      if (worlds == null) {
        label = '…';
      } else {
        final match = worlds.where((world) => world.id == worldId);
        label = match.isEmpty ? '未归属' : match.first.name;
      }
    }
    final assigned = worldId != null && label != '未归属';
    return Semantics(
      button: true,
      enabled: !_saving,
      label: '世界观：$label',
      child: InkWell(
        key: const Key('role-world-row'),
        onTap: _saving ? null : _pickWorld,
        borderRadius: ZaidangRadius.smAll,
        child: ArchiveFieldCell(
          icon: Icons.public_outlined,
          label: '世界观',
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: ZaidangSpacing.xs),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ZaidangType.of(context).bodyLarge.copyWith(
                      color: assigned ? tokens.ink : tokens.inkSecondary,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: tokens.inkSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 立绘下方的纸面身份头：只监听参与展示的字段，输入时不重建整页。
  PreferredSizeWidget _buildIdentityHeader(double height) {
    return PreferredSize(
      preferredSize: Size.fromHeight(height),
      child: ListenableBuilder(
        listenable: _identityListenable,
        builder: (context, _) {
          final locked = _saving || _tabBusy;
          return RoleIdentityHeader(
            name: _nameController.text,
            emptyName: _isEditing ? '未命名角色' : '新建角色',
            tags: [
              _raceController.text.trim(),
              _occupationController.text.trim(),
              _sexController.text.trim(),
            ].where((text) => text.isNotEmpty).toList(),
            quote: firstLine(_descController.text),
            coverImg: _coverImg,
            hasCover: _coverReadable,
            supportDirectory: widget.supportDirectory,
            onPortraitTap: locked
                ? null
                : _coverReadable
                ? _openCoverPreview
                : _pickCover,
            onChangeCover: locked ? null : _pickCover,
            onExport: locked || _exportOpen ? null : _openRoleCardExport,
            height: height,
          );
        },
      ),
    );
  }

  Future<void> _openDescHistory() async {
    final role = widget.role;
    if (role == null || _saving) {
      return;
    }
    final restored = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => RoleDescHistoryPage(roleId: role.id),
      ),
    );
    if (restored == null || !mounted) {
      return;
    }
    _descController.text = restored;
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
    final headerHeight = RoleIdentityHeader.heightFor(
      MediaQuery.textScalerOf(context),
    );
    // 身份头在立绘之下多占的高度；收起阈值要一起后移。
    final headerExtent = headerHeight - RoleIdentityHeader.portraitOverlap;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: PopScope(
        canPop: !_saving && !_tabBusy,
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
                    absorbing: _saving || _tabBusy,
                    child: _buildRoleScroll(
                      context,
                      overlayStyle,
                      topInset,
                      headerHeight,
                    ),
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
                                    immersiveCoverHeight +
                                    headerExtent -
                                    topInset -
                                    60;
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
                              ),
                            )
                          : null,
                      trailing: GlassSaveButton(
                        saving: _saving,
                        onPressed: _tabBusy ? null : _submit,
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
            child: Padding(
              padding: const EdgeInsets.only(bottom: ZaidangSpacing.lg),
              child: _buildBasicCard(),
            ),
          ),
          _buildCustomAttributes(tokens),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: ZaidangSpacing.lg),
              child: _buildDescCard(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleScroll(
    BuildContext context,
    SystemUiOverlayStyle overlayStyle,
    double topInset,
    double headerHeight,
  ) {
    Widget cover({PreferredSizeWidget? tabs}) => ImmersiveCover(
      path: _coverImg,
      title: _nameController.text.trim(),
      overlayStyle: overlayStyle,
      hasCover: _coverReadable,
      supportDirectory: widget.supportDirectory,
      onPick: _pickCover,
      onPreview: _saving ? null : _openCoverPreview,
      bottom: tabs,
      toolbarHeight: topInset + 60,
      // 角色页把立绘本身当头图：不模糊、不压暗，只在底部渐隐进纸面。
      backdropBlur: ImmersiveCover.noBlur,
      paperHeader: _buildIdentityHeader(headerHeight),
      paperHeaderOverlap: RoleIdentityHeader.portraitOverlap,
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
      key: const Key('role-detail-nested-scroll'),
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
                  key: const Key('role-detail-tabs'),
                  controller: _detailTabs,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: tokens.accent,
                  unselectedLabelColor: tokens.inkSecondary,
                  indicatorSize: TabBarIndicatorSize.label,
                  indicator: UnderlineTabIndicator(
                    borderSide: BorderSide(color: tokens.accent, width: 3),
                    borderRadius: ZaidangRadius.smAll,
                  ),
                  dividerColor: tokens.border,
                  padding: const EdgeInsets.symmetric(
                    horizontal: ZaidangSpacing.sm,
                  ),
                  tabs: const [
                    Tab(text: '详情'),
                    Tab(text: '资产'),
                    Tab(text: '关系'),
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
                    key: const PageStorageKey('role-details-scroll'),
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
                RoleAssetsTab(
                  roleId: widget.role!.id,
                  overlapHandle: handle,
                  enabled: !_saving,
                  isEnabled: () => !_saving,
                  onBusyChanged: (busy) {
                    if (mounted) setState(() => _assetBusy = busy);
                  },
                ),
                RoleRelationshipsTab(
                  roleId: widget.role!.id,
                  overlapHandle: handle,
                  enabled: !_saving,
                  isEnabled: () => !_saving,
                  supportDirectory: widget.supportDirectory,
                  onBusyChanged: (busy) {
                    if (mounted) setState(() => _relationshipBusy = busy);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBasicCard() => ArchiveCard(
    key: const Key('role-create-basic-card'),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ArchiveCardHeader(
          icon: Icons.description_outlined,
          title: '基础设定',
          caption: '关于这个角色',
        ),
        FieldRow(
          left: _cellField(
            fieldKey: const Key('role-field-name'),
            icon: Icons.person_outline,
            controller: _nameController,
            label: '名字',
            hint: '角色怎么称呼',
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '请填写名字';
              }
              return null;
            },
          ),
          right: _cellField(
            fieldKey: const Key('role-field-sex'),
            icon: Icons.wc_outlined,
            controller: _sexController,
            label: '性别',
            hint: '女 / 非二元 / 不明',
          ),
        ),
        const SizedBox(height: ZaidangSpacing.md),
        FieldRow(
          left: _cellField(
            fieldKey: const Key('role-field-age'),
            icon: Icons.calendar_today_outlined,
            controller: _ageController,
            label: '年龄',
            hint: '十七、外表 20、不详',
          ),
          right: _cellField(
            fieldKey: const Key('role-field-birthday'),
            icon: Icons.cake_outlined,
            controller: _birthdayController,
            label: '生日',
            hint: '三月三日、第三历春、未知',
          ),
        ),
        const SizedBox(height: ZaidangSpacing.md),
        FieldRow(
          left: _cellField(
            fieldKey: const Key('role-field-race'),
            icon: Icons.eco_outlined,
            controller: _raceController,
            label: '种族',
            hint: '人类、兽人、吸血鬼',
          ),
          right: _cellField(
            fieldKey: const Key('role-field-occupation'),
            icon: Icons.badge_outlined,
            controller: _occupationController,
            label: '身份',
            hint: '学生、骑士、无所属',
          ),
        ),
        const SizedBox(height: ZaidangSpacing.md),
        _buildWorldRow(),
      ],
    ),
  );

  Widget _buildDescCard() {
    final tokens = ZaidangTokens.of(context);
    return ArchiveCard(
      key: const Key('role-create-desc-card'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ArchiveCardHeader(
            icon: Icons.history_edu_outlined,
            title: '角色简介',
            caption: '性格、外貌、背景',
          ),
          Stack(
            children: [
              TextFormField(
                key: const Key('role-field-desc'),
                controller: _descController,
                decoration: InputDecoration(
                  hintText: '性格、外貌、背景都可以写在这里',
                  contentPadding: const EdgeInsets.fromLTRB(
                    ZaidangSpacing.lg,
                    ZaidangSpacing.lg,
                    ZaidangSpacing.xxxl + ZaidangSpacing.sm,
                    ZaidangSpacing.lg,
                  ),
                ),
                minLines: 5,
                maxLines: 10,
                textInputAction: TextInputAction.newline,
                keyboardType: TextInputType.multiline,
                scrollPadding: _fieldScrollPadding,
              ),
              // 右下角的火漆红引号只是装饰，不挡输入也不进语义树。
              Positioned(
                right: ZaidangSpacing.md,
                bottom: ZaidangSpacing.md,
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: Icon(
                      Icons.format_quote,
                      size: _quoteMarkSize,
                      color: tokens.accent.withValues(alpha: _quoteMarkAlpha),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_isEditing)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: ZaidangSpacing.xs),
                child: TextButton(
                  onPressed: _saving ? null : _openDescHistory,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    minimumSize: const Size(44, 44),
                  ),
                  child: const Text('修改历史'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _addAttribute() {
    if (_saving) return;
    final attribute = _CustomAttributeDraft();
    setState(() => _attributes.add(attribute));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _saving || !_attributes.contains(attribute)) return;
      // Build the newly appended sliver row before asking its field for focus.
      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
      if (!mounted || _saving || !_attributes.contains(attribute)) return;
      if (_isEditing && _detailsScrollPosition != null) {
        await _detailsScrollPosition!.animateTo(
          _detailsScrollPosition!.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
      if (!mounted || _saving || !_attributes.contains(attribute)) return;
      attribute.nameFocus.requestFocus();
    });
  }

  void _moveAttribute(_CustomAttributeDraft attribute, int offset) {
    if (_saving) return;
    final index = _attributes.indexOf(attribute);
    final destination = index + offset;
    if (index < 0 || destination < 0 || destination >= _attributes.length) {
      return;
    }
    _attributesKey.currentState?.cancelReorder();
    setState(() {
      _attributes.removeAt(index);
      _attributes.insert(destination, attribute);
    });
  }

  Future<void> _removeAttribute(_CustomAttributeDraft attribute) async {
    if (_saving || !_attributes.contains(attribute)) return;
    final name = attribute.name.text.trim();
    final remove = await showZaidangConfirmDialog(
      context: context,
      title: '要删掉这条属性吗？',
      body: name.isEmpty ? '这条未命名属性和里面的内容会一起移除。' : '「$name」和里面的内容会一起移除。',
      consequence: '保存角色后生效。',
      cancelLabel: '先留着',
      cancelSemanticLabel: '先留着，保留这条属性',
      confirmLabel: '删除属性',
    );
    if (remove != true ||
        !mounted ||
        _saving ||
        !_attributes.contains(attribute)) {
      return;
    }
    _attributesKey.currentState?.cancelReorder();
    setState(() => _attributes.remove(attribute));
    // The old TextFields must unmount before their controllers are disposed.
    WidgetsBinding.instance.addPostFrameCallback((_) => attribute.dispose());
  }

  Widget _addAttributeButton() => TextButton.icon(
    key: const Key('role-custom-attribute-add'),
    onPressed: _saving ? null : _addAttribute,
    icon: const Icon(Icons.add, size: 20),
    label: const Text('添加自定义属性'),
  );

  Widget _buildCustomAttributes(ZaidangTokens tokens) {
    if (_attributes.isEmpty) {
      return SliverToBoxAdapter(child: _addAttributeButton());
    }
    return DecoratedSliver(
      key: const Key('role-create-custom-attributes-card'),
      decoration: archiveCardDecoration(tokens),
      sliver: SliverPadding(
        padding: const EdgeInsets.all(ZaidangSpacing.card),
        sliver: SliverMainAxisGroup(
          slivers: [
            const SliverToBoxAdapter(
              child: ArchiveCardHeader(
                icon: Icons.bookmark_border,
                title: '自定义属性',
              ),
            ),
            SliverReorderableList(
              key: _attributesKey,
              itemCount: _attributes.length,
              findChildIndexCallback: (key) {
                final draftKey = key is GlobalObjectKey ? key.value : key;
                final index = _attributes.indexWhere(
                  (attribute) => attribute.key == draftKey,
                );
                return index < 0 ? null : index;
              },
              onReorderItem: (oldIndex, newIndex) {
                if (_saving) return;
                setState(
                  () => _attributes.insert(
                    newIndex,
                    _attributes.removeAt(oldIndex),
                  ),
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
                final attribute = _attributes[index];
                final number = index + 1;
                return Padding(
                  key: attribute.key,
                  padding: const EdgeInsets.only(bottom: ZaidangSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '属性 $number',
                              style: ZaidangType.of(context).micro,
                            ),
                          ),
                          ReorderableDragStartListener(
                            index: index,
                            enabled: !_saving,
                            child: Semantics(
                              label: '拖动第 $number 条属性排序',
                              enabled: !_saving,
                              child: Tooltip(
                                message: '拖动排序',
                                excludeFromSemantics: true,
                                child: SizedBox.square(
                                  dimension: 48,
                                  child: Icon(
                                    Icons.drag_handle,
                                    color: _saving
                                        ? tokens.inkSecondary
                                        : tokens.ink,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: '上移第 $number 条属性',
                            onPressed: _saving || index == 0
                                ? null
                                : () => _moveAttribute(attribute, -1),
                            icon: Icon(
                              Icons.arrow_upward,
                              size: 20,
                              semanticLabel: '上移第 $number 条属性',
                            ),
                          ),
                          IconButton(
                            tooltip: '下移第 $number 条属性',
                            onPressed:
                                _saving || index == _attributes.length - 1
                                ? null
                                : () => _moveAttribute(attribute, 1),
                            icon: Icon(
                              Icons.arrow_downward,
                              size: 20,
                              semanticLabel: '下移第 $number 条属性',
                            ),
                          ),
                          IconButton(
                            tooltip: '删除第 $number 条属性',
                            onPressed: _saving
                                ? null
                                : () => _removeAttribute(attribute),
                            color: tokens.ink,
                            icon: Icon(
                              Icons.delete_outline,
                              size: 20,
                              semanticLabel: '删除第 $number 条属性',
                            ),
                          ),
                        ],
                      ),
                      TextFormField(
                        controller: attribute.name,
                        focusNode: attribute.nameFocus,
                        enabled: !_saving,
                        decoration: const InputDecoration(
                          labelText: '属性名称',
                          hintText: '例如：魔法属性',
                        ),
                        textInputAction: TextInputAction.next,
                        scrollPadding: _fieldScrollPadding,
                        autovalidateMode: _validateAttributes
                            ? AutovalidateMode.always
                            : AutovalidateMode.disabled,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? '请填写属性名称'
                            : null,
                      ),
                      const SizedBox(height: ZaidangSpacing.md),
                      TextFormField(
                        controller: attribute.content,
                        enabled: !_saving,
                        decoration: const InputDecoration(
                          labelText: '属性内容',
                          hintText: '可以分行填写，也可以暂时留空',
                        ),
                        minLines: 2,
                        maxLines: 6,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        scrollPadding: _fieldScrollPadding,
                      ),
                    ],
                  ),
                );
              },
            ),
            SliverToBoxAdapter(child: _addAttributeButton()),
          ],
        ),
      ),
    );
  }

  /// 基础设定里的单个字段格：图标 + 标签由格子画，输入框本身无边框。
  Widget _cellField({
    required Key fieldKey,
    required IconData icon,
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
  }) {
    return ArchiveFieldCell(
      icon: icon,
      label: label,
      child: TextFormField(
        key: fieldKey,
        controller: controller,
        decoration: archiveCellInputDecoration(context, hint: hint),
        style: ZaidangType.of(context).bodyLarge,
        textInputAction: TextInputAction.next,
        keyboardType: TextInputType.text,
        scrollPadding: _fieldScrollPadding,
        validator: validator,
      ),
    );
  }
}

/// 底部弹层的选择结果；包一层是为了把「选了不归属」与「直接关掉弹层」区分开。
class _WorldChoice {
  const _WorldChoice(this.worldId);
  final int? worldId;
}

class _CustomAttributeDraft {
  _CustomAttributeDraft({String name = '', String content = ''})
    : name = TextEditingController(text: name),
      content = TextEditingController(text: content);

  factory _CustomAttributeDraft.fromAttribute(RoleCustomAttribute attribute) =>
      _CustomAttributeDraft(name: attribute.name, content: attribute.content);

  final key = UniqueKey();
  final nameFocus = FocusNode();
  final TextEditingController name;
  final TextEditingController content;

  void dispose() {
    nameFocus.dispose();
    name.dispose();
    content.dispose();
  }
}
