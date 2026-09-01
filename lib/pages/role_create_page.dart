import 'dart:ui' as ui show ImageFilter, TileMode;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/role.dart';
import '../data/providers/role_repository_provider.dart';
import '../data/services/cover_image_picker.dart';
import '../theme/zaidang_tokens.dart';
import '../widgets/cover_file_view.dart';
import 'role_desc_history_page.dart';

/// 新建 / 编辑 OC 人设。传入 [role] 即为编辑，字段按原文回填。
class RoleCreatePage extends ConsumerStatefulWidget {
  const RoleCreatePage({super.key, this.role});

  final Role? role;

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

class _RoleCreatePageState extends ConsumerState<RoleCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _picker = CoverImagePicker();

  late final TextEditingController _nameController;
  late final TextEditingController _sexController;
  late final TextEditingController _ageController;
  late final TextEditingController _birthdayController;
  late final TextEditingController _raceController;
  late final TextEditingController _occupationController;
  late final TextEditingController _descController;

  late String _coverImg;
  bool _saving = false;

  bool get _isEditing => widget.role != null;

  @override
  void initState() {
    super.initState();
    final role = widget.role;
    _nameController = TextEditingController(text: role?.name ?? '');
    _sexController = TextEditingController(text: role?.sex ?? '');
    _ageController = TextEditingController(text: role?.age ?? '');
    _birthdayController = TextEditingController(text: role?.birthday ?? '');
    _raceController = TextEditingController(text: role?.race ?? '');
    _occupationController = TextEditingController(text: role?.occupation ?? '');
    _descController = TextEditingController(text: role?.desc ?? '');
    _coverImg = role?.coverImg ?? '';
    _nameController.addListener(_onCallingCardChanged);
    _raceController.addListener(_onCallingCardChanged);
    _occupationController.addListener(_onCallingCardChanged);
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
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _saving) {
      return;
    }
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
        );
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失败：$error')));
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
    if (role == null) {
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
    final bottomInset = mediaPadding.bottom;
    final overlayStyle =
        (_coverImg.isNotEmpty ||
            Theme.of(context).brightness == Brightness.dark)
        ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: tokens.bg,
          )
        : SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: tokens.bg,
          );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
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
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    _ImmersiveCover(
                      path: _coverImg,
                      name: _nameController.text.trim(),
                      race: _raceController.text.trim(),
                      occupation: _occupationController.text.trim(),
                      overlayStyle: overlayStyle,
                      onPick: _pickCover,
                    ),
                    SliverToBoxAdapter(
                      child: ColoredBox(
                        color: tokens.bg,
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 32 + bottomInset),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: _contentMaxWidth,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  _cardInset,
                                  8,
                                  _cardInset,
                                  0,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      _isEditing ? '编辑角色' : '新建角色',
                                      style: TextStyle(
                                        color: tokens.ink,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _ArchiveCard(
                                      key: const Key('role-create-basic-card'),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          const _SectionLabel('基本信息'),
                                          _field(
                                            controller: _nameController,
                                            label: '名字',
                                            hint: '角色怎么称呼',
                                            validator: (value) {
                                              if (value == null ||
                                                  value.trim().isEmpty) {
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
                                    ),
                                    const SizedBox(height: 16),
                                    _ArchiveCard(
                                      key: const Key('role-create-desc-card'),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          _DescSectionHeader(
                                            showHistory: _isEditing,
                                            onHistoryTap: _openDescHistory,
                                          ),
                                          _field(
                                            controller: _descController,
                                            hint: '性格、外貌、背景都可以写在这里',
                                            minLines: 5,
                                            maxLines: 10,
                                            textInputAction:
                                                TextInputAction.newline,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: topInset + 8,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _GlassIconButton(
                      icon: Icons.arrow_back_ios_new,
                      iconSize: 16,
                      tooltip: '返回',
                      onPhoto: _coverImg.isNotEmpty,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    _GlassSaveButton(
                      saving: _saving,
                      onPhoto: _coverImg.isNotEmpty,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ],
          ),
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
      scrollPadding: const EdgeInsets.all(80),
      validator: validator,
    );
  }
}

/// 钉在滚动层下面的模糊头图。下拉回弹时露出的是这张图，不是画布白边。
class _HeroBackdrop extends StatelessWidget {
  const _HeroBackdrop({required this.path});

  final String path;

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
                  child: CoverFileView(coverImg: path, placeholder: fill),
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

/// 沉浸式头图：高斯模糊背景 + 左下角立绘名片。
class _ImmersiveCover extends StatelessWidget {
  const _ImmersiveCover({
    required this.path,
    required this.name,
    required this.race,
    required this.occupation,
    required this.overlayStyle,
    required this.onPick,
  });

  final String path;
  final String name;
  final String race;
  final String occupation;
  final SystemUiOverlayStyle overlayStyle;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    final hasCover = path.isNotEmpty;
    final label = hasCover ? '更换立绘' : '添加立绘';

    return SliverAppBar(
      primary: false,
      pinned: false,
      floating: false,
      stretch: true,
      automaticallyImplyLeading: false,
      toolbarHeight: 0,
      collapsedHeight: _heroHeight,
      expandedHeight: _heroHeight,
      systemOverlayStyle: overlayStyle,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      forceMaterialTransparency: true,
      clipBehavior: Clip.hardEdge,
      flexibleSpace: Stack(
        key: const Key('role-create-cover-hero'),
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: FlexibleSpaceBar(
              collapseMode: CollapseMode.none,
              stretchModes: const [StretchMode.zoomBackground],
              background: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onPick,
                child: _HeroBackdrop(path: path),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: _heroCapHeight + 12,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _CallingCard(
                path: path,
                name: name,
                race: race,
                occupation: occupation,
                label: label,
                onPick: onPick,
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
  }
}

class _CallingCard extends StatelessWidget {
  const _CallingCard({
    required this.path,
    required this.name,
    required this.race,
    required this.occupation,
    required this.label,
    required this.onPick,
  });

  final String path;
  final String name;
  final String race;
  final String occupation;
  final String label;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    final hasCover = path.isNotEmpty;
    final subtitle = [
      race,
      occupation,
    ].where((text) => text.isNotEmpty).join(' · ');
    final portrait = hasCover
        ? CoverFileView(
            coverImg: path,
            placeholder: _PortraitPlaceholder(tokens: tokens, compact: true),
          )
        : _PortraitPlaceholder(tokens: tokens, compact: false);

    return Material(
      color: tokens.surface,
      elevation: 2,
      shadowColor: tokens.ink.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                button: true,
                label: label,
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
              if (name.isNotEmpty || subtitle.isNotEmpty) ...[
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
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
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
  final VoidCallback onPressed;

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
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.border),
      ),
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
  final VoidCallback onHistoryTap;

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
