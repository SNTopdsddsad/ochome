import 'dart:io';
import 'dart:ui' as ui show ImageFilter, TileMode;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/role.dart';
import '../data/models/role_custom_attribute.dart';
import '../data/providers/role_repository_provider.dart';
import '../data/services/cover_image_picker.dart';
import '../theme/zaidang_tokens.dart';
import '../widgets/cover_file_view.dart';
import '../widgets/zaidang_confirm_dialog.dart';
import '../widgets/zaidang_snack_bar.dart';
import '../features/role_card/role_card_content.dart';
import 'cover_preview_page.dart';
import 'role_card_export_page.dart';
import 'role_desc_history_page.dart';
import 'role_assets_tab.dart';

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

/// 表单栏上限。hero 全宽铺顶，不跟这个宽度走。
const double _contentMaxWidth = 440;

/// 卡片相对表单栏的左右留白。
const double _cardInset = 20;

/// 对齐 memory 详情页媒体头图（含顶部沉浸），约 352pt。
const double _heroHeight = 352;

const double _heroCapHeight = 18;

const double _glassButtonSize = 44;

/// 左下角名片立绘，3:4。
const double _portraitWidth = 90;
const double _portraitHeight = 120;

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

  final _scrollController = ScrollController();
  late final TabController _detailTabs;
  ScrollPosition? _detailsScrollPosition;
  bool _assetBusy = false;
  final _attributesKey = GlobalKey<SliverReorderableListState>();
  final _attributes = <_CustomAttributeDraft>[];
  bool _validateAttributes = false;

  late String _coverImg;
  bool _saving = false;
  bool _exportOpen = false;

  /// 立绘是否可读（路径非空且文件存在）。决定槽位是预览还是选图、是否出现「更换」。
  bool _coverReadable = false;

  bool get _isEditing => widget.role != null;

  EdgeInsets get _fieldScrollPadding => EdgeInsets.fromLTRB(
    80,
    _isEditing ? MediaQuery.viewPaddingOf(context).top + 128 : 80,
    80,
    80,
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
    _detailTabs = TabController(length: 2, vsync: this)
      ..addListener(_onDetailTabChanged);
    final role = widget.role;
    _nameController = TextEditingController(text: role?.name ?? '');
    _sexController = TextEditingController(text: role?.sex ?? '');
    _ageController = TextEditingController(text: role?.age ?? '');
    _birthdayController = TextEditingController(text: role?.birthday ?? '');
    _raceController = TextEditingController(text: role?.race ?? '');
    _occupationController = TextEditingController(text: role?.occupation ?? '');
    _descController = TextEditingController(text: role?.desc ?? '');
    _coverImg = role?.coverImg ?? '';
    _attributes.addAll(
      (role?.customAttributes ?? []).map(_CustomAttributeDraft.fromAttribute),
    );
    _nameController.addListener(_onCallingCardChanged);
    _raceController.addListener(_onCallingCardChanged);
    _occupationController.addListener(_onCallingCardChanged);
    _refreshCoverReadable();
  }

  void _onDetailTabChanged() {
    FocusManager.instance.primaryFocus?.unfocus();
    _attributesKey.currentState?.cancelReorder();
  }

  void _onCallingCardChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_onCallingCardChanged);
    _raceController.removeListener(_onCallingCardChanged);
    _occupationController.removeListener(_onCallingCardChanged);
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
    if (_saving || _assetBusy) {
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
    final overlayStyle =
        (_coverImg.isNotEmpty ||
            Theme.of(context).brightness == Brightness.dark)
        ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: tokens.bg,
            systemNavigationBarIconBrightness:
                Theme.of(context).brightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark,
          )
        : SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: tokens.bg,
            systemNavigationBarIconBrightness:
                Theme.of(context).brightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark,
          );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: PopScope(
        canPop: !_saving && !_assetBusy,
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
                    absorbing: _saving || _assetBusy,
                    child: _buildRoleScroll(context, overlayStyle, topInset),
                  ),
                ),
                Positioned(
                  top: topInset + 8,
                  left: 16,
                  right: 16,
                  child: SizedBox(
                    height: _glassButtonSize,
                    child: NavigationToolbar(
                      centerMiddle: true,
                      middleSpacing: 12,
                      leading: _GlassIconButton(
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
                                    _heroHeight - topInset - 60;
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
                              child: _PinnedRoleIdentity(
                                name: _nameController.text.trim(),
                                coverImg: _coverImg,
                                supportDirectory: widget.supportDirectory,
                              ),
                            )
                          : null,
                      trailing: _GlassSaveButton(
                        saving: _saving,
                        onPhoto: _coverImg.isNotEmpty,
                        onPressed: _assetBusy ? null : _submit,
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
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        _cardInset +
            ((MediaQuery.sizeOf(context).width - _contentMaxWidth).clamp(
                  0,
                  double.infinity,
                ) /
                2),
        8,
        _cardInset +
            ((MediaQuery.sizeOf(context).width - _contentMaxWidth).clamp(
                  0,
                  double.infinity,
                ) /
                2),
        32 + bottomInset,
      ),
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  children: [
                    Text(
                      _isEditing ? '编辑角色' : '新建角色',
                      style: TextStyle(
                        color: tokens.ink,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextButton.icon(
                      key: const Key('role-card-export'),
                      onPressed: _saving || _exportOpen
                          ? null
                          : _openRoleCardExport,
                      icon: const Icon(Icons.style_outlined, size: 18),
                      label: const Text('导出角色卡'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildBasicCard(),
                const SizedBox(height: 16),
              ],
            ),
          ),
          _buildCustomAttributes(tokens),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
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
  ) {
    Widget cover({PreferredSizeWidget? tabs}) => _ImmersiveCover(
      path: _coverImg,
      name: _nameController.text.trim(),
      race: _raceController.text.trim(),
      occupation: _occupationController.text.trim(),
      overlayStyle: overlayStyle,
      hasCover: _coverReadable,
      supportDirectory: widget.supportDirectory,
      onPick: _pickCover,
      onPreview: _saving ? null : _openCoverPreview,
      bottom: tabs,
      toolbarHeight: topInset + 60,
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
                  indicatorColor: tokens.accent,
                  dividerColor: tokens.border,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tabs: const [
                    Tab(text: '详情'),
                    Tab(text: '资产'),
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
                _KeepAliveDetails(
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
                  onBusyChanged: (busy) {
                    if (mounted) setState(() => _assetBusy = busy);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBasicCard() => _ArchiveCard(
    key: const Key('role-create-basic-card'),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('基本信息'),
        _field(
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
        const SizedBox(height: 12),
        _FieldRow(
          left: _field(
            controller: _sexController,
            label: '性别',
            hint: '女 / 非二元 / 不明',
          ),
          right: _field(
            controller: _ageController,
            label: '年龄',
            hint: '十七、外表 20、不详',
          ),
        ),
        const SizedBox(height: 12),
        _field(
          controller: _birthdayController,
          label: '生日',
          hint: '三月三日、第三历春、未知',
        ),
        const SizedBox(height: 12),
        _FieldRow(
          left: _field(
            controller: _raceController,
            label: '种族',
            hint: '人类、兽人、吸血鬼',
          ),
          right: _field(
            controller: _occupationController,
            label: '身份',
            hint: '学生、骑士、无所属',
          ),
        ),
      ],
    ),
  );

  Widget _buildDescCard() => _ArchiveCard(
    key: const Key('role-create-desc-card'),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DescSectionHeader(
          showHistory: _isEditing,
          onHistoryTap: _saving ? null : _openDescHistory,
        ),
        _field(
          controller: _descController,
          hint: '性格、外貌、背景都可以写在这里',
          minLines: 5,
          maxLines: 10,
          textInputAction: TextInputAction.newline,
        ),
      ],
    ),
  );

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
      decoration: _archiveCardDecoration(tokens),
      sliver: SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        sliver: SliverMainAxisGroup(
          slivers: [
            const SliverToBoxAdapter(child: _SectionLabel('自定义属性')),
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
                borderRadius: BorderRadius.circular(8),
                child: child,
              ),
              itemBuilder: (context, index) {
                final attribute = _attributes[index];
                final number = index + 1;
                return Padding(
                  key: attribute.key,
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '属性 $number',
                              style: TextStyle(
                                color: tokens.inkSecondary,
                                fontSize: 12,
                              ),
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
                      const SizedBox(height: 12),
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

/// 吸顶时保留角色识别信息，长名字截断，不挤占两侧操作按钮。
class _PinnedRoleIdentity extends StatelessWidget {
  const _PinnedRoleIdentity({
    required this.name,
    required this.coverImg,
    this.supportDirectory,
  });

  final String name;
  final String coverImg;
  final Future<Directory> Function()? supportDirectory;

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: DecoratedBox(
        key: const Key('role-pinned-identity'),
        decoration: BoxDecoration(
          color: tokens.bg.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipOval(
                child: SizedBox.square(
                  dimension: 32,
                  child: CoverFileView(
                    key: const Key('role-pinned-portrait'),
                    coverImg: coverImg,
                    supportDirectory: supportDirectory,
                    placeholder: ColoredBox(
                      color: tokens.surface,
                      child: Icon(
                        Icons.person_outline,
                        size: 20,
                        color: tokens.inkSecondary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  name.isEmpty ? '未命名角色' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 沉浸式头图：高斯模糊背景 + 左下角立绘名片。
class _ImmersiveCover extends StatelessWidget {
  const _ImmersiveCover({
    required this.path,
    required this.name,
    required this.race,
    required this.occupation,
    required this.overlayStyle,
    required this.hasCover,
    required this.onPick,
    required this.onPreview,
    this.supportDirectory,
    this.bottom,
    this.toolbarHeight = 60,
  });

  final String path;
  final String name;
  final String race;
  final String occupation;
  final SystemUiOverlayStyle overlayStyle;
  final bool hasCover;
  final VoidCallback onPick;
  final VoidCallback? onPreview;
  final Future<Directory> Function()? supportDirectory;
  final PreferredSizeWidget? bottom;
  final double toolbarHeight;

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
      collapsedHeight: bottom == null ? _heroHeight : toolbarHeight,
      expandedHeight: _heroHeight + (bottom?.preferredSize.height ?? 0),
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
                key: const Key('role-create-cover-hero'),
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
                    left: 16,
                    right: 16,
                    bottom: _heroCapHeight + 12,
                    child: IgnorePointer(
                      ignoring: visible < 1,
                      child: Opacity(
                        opacity: visible,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _CallingCard(
                            path: path,
                            name: name,
                            race: race,
                            occupation: occupation,
                            hasCover: hasCover,
                            supportDirectory: supportDirectory,
                            onPick: onPick,
                            onPreview: onPreview,
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
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
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

class _KeepAliveDetails extends StatefulWidget {
  const _KeepAliveDetails({required this.child});
  final Widget child;

  @override
  State<_KeepAliveDetails> createState() => _KeepAliveDetailsState();
}

class _KeepAliveDetailsState extends State<_KeepAliveDetails>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _CallingCard extends StatelessWidget {
  const _CallingCard({
    required this.path,
    required this.name,
    required this.race,
    required this.occupation,
    required this.hasCover,
    required this.onPick,
    required this.onPreview,
    this.supportDirectory,
  });

  final String path;
  final String name;
  final String race;
  final String occupation;
  final bool hasCover;
  final VoidCallback onPick;
  final VoidCallback? onPreview;
  final Future<Directory> Function()? supportDirectory;

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    final subtitle = [
      race,
      occupation,
    ].where((text) => text.isNotEmpty).join(' · ');
    final portrait = hasCover
        ? CoverFileView(
            coverImg: path,
            placeholder: _PortraitPlaceholder(tokens: tokens, compact: true),
            supportDirectory: supportDirectory,
          )
        : _PortraitPlaceholder(tokens: tokens, compact: false);
    final portraitLabel = hasCover ? '查看立绘' : '添加立绘';
    final onPortraitTap = hasCover ? onPreview : onPick;

    return Material(
      color: tokens.surface,
      elevation: 2,
      shadowColor: tokens.ink.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              button: true,
              enabled: onPortraitTap != null,
              label: portraitLabel,
              child: InkWell(
                onTap: onPortraitTap,
                borderRadius: BorderRadius.circular(6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    key: const Key('role-create-cover-portrait'),
                    width: _portraitWidth,
                    height: _portraitHeight,
                    child: portrait,
                  ),
                ),
              ),
            ),
            if (name.isNotEmpty || subtitle.isNotEmpty || hasCover) ...[
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 168),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (name.isNotEmpty)
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.inkSecondary,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                    if (hasCover) ...[
                      const SizedBox(height: 4),
                      Tooltip(
                        message: '更换立绘',
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
                          child: const Text('更换', semanticsLabel: '更换立绘'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _PortraitPlaceholder extends StatelessWidget {
  const _PortraitPlaceholder({required this.tokens, required this.compact});

  final ZaidangTokens tokens;
  final bool compact;

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
          const SizedBox(height: 6),
          Text(
            '添加立绘',
            style: TextStyle(
              color: tokens.inkSecondary,
              fontSize: compact ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.iconSize,
    required this.tooltip,
    required this.onPhoto,
    required this.onTap,
  });

  final IconData icon;
  final double iconSize;
  final String tooltip;
  final bool onPhoto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    final fillAlpha = onPhoto ? 0.34 : 0.72;
    return Tooltip(
      message: tooltip,
      child: ClipOval(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Material(
            color: tokens.ink.withValues(alpha: fillAlpha),
            shape: CircleBorder(
              side: BorderSide(
                color: ZaidangTokens.light.surface.withValues(alpha: 0.18),
              ),
            ),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox.square(
                dimension: _glassButtonSize,
                child: Icon(
                  icon,
                  size: iconSize,
                  color: ZaidangTokens.light.surface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassSaveButton extends StatelessWidget {
  const _GlassSaveButton({
    required this.saving,
    required this.onPhoto,
    required this.onPressed,
  });

  final bool saving;
  final bool onPhoto;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    final fillAlpha = onPhoto ? 0.34 : 0.72;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.ink.withValues(alpha: fillAlpha),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: ZaidangTokens.light.surface.withValues(alpha: 0.18),
            ),
          ),
          child: TextButton(
            onPressed: saving ? null : onPressed,
            style: TextButton.styleFrom(
              foregroundColor: tokens.accent,
              disabledForegroundColor: tokens.inkSecondary,
              minimumSize: const Size(44, _glassButtonSize),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: saving
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('保存中…'),
                    ],
                  )
                : const Text('保存'),
          ),
        ),
      ),
    );
  }
}

/// 档案分组：纸面填充 + 描边，圆角与输入框一致。
class _ArchiveCard extends StatelessWidget {
  const _ArchiveCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    return DecoratedBox(
      decoration: _archiveCardDecoration(tokens),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: child,
      ),
    );
  }
}

class _DescSectionHeader extends StatelessWidget {
  const _DescSectionHeader({
    required this.showHistory,
    required this.onHistoryTap,
  });

  final bool showHistory;
  final VoidCallback? onHistoryTap;

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '设定',
              style: TextStyle(
                color: tokens.inkSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (showHistory)
            TextButton(
              onPressed: onHistoryTap,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                minimumSize: const Size(44, 44),
              ),
              child: const Text('修改历史'),
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          color: tokens.inkSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }
}

BoxDecoration _archiveCardDecoration(ZaidangTokens tokens) => BoxDecoration(
  color: tokens.surface,
  borderRadius: BorderRadius.circular(8),
  border: Border.all(color: tokens.border),
);

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
