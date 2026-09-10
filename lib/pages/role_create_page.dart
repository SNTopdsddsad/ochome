import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/role.dart';
import '../data/models/role_custom_attribute.dart';
import '../data/providers/role_repository_provider.dart';
import '../data/services/cover_image_picker.dart';
import '../theme/zaidang_tokens.dart';
import '../widgets/archive_editor/archive_card.dart';
import '../widgets/archive_editor/glass_buttons.dart';
import '../widgets/archive_editor/immersive_cover.dart';
import '../widgets/archive_editor/pinned_identity.dart';
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
                    height: glassButtonSize,
                    child: NavigationToolbar(
                      centerMiddle: true,
                      middleSpacing: 12,
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
                              ),
                            )
                          : null,
                      trailing: GlassSaveButton(
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
    final horizontal = archiveEditorHorizontalPadding(context);
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, 32 + bottomInset),
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
    Widget cover({PreferredSizeWidget? tabs}) => ImmersiveCover(
      path: _coverImg,
      title: _nameController.text.trim(),
      subtitle: [
        _raceController.text.trim(),
        _occupationController.text.trim(),
      ].where((text) => text.isNotEmpty).join(' · '),
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
        const SectionLabel('基本信息'),
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
        FieldRow(
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
        FieldRow(
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

  Widget _buildDescCard() => ArchiveCard(
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
      decoration: archiveCardDecoration(tokens),
      sliver: SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        sliver: SliverMainAxisGroup(
          slivers: [
            const SliverToBoxAdapter(child: SectionLabel('自定义属性')),
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
