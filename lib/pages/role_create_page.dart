import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/role.dart';
import '../data/providers/role_repository_provider.dart';
import '../data/services/cover_image_picker.dart';
import '../theme/zaidang_tokens.dart';
import 'role_desc_history_page.dart';

/// 新建 / 编辑 OC 人设。传入 [role] 即为编辑，字段按原文回填。
class RoleCreatePage extends ConsumerStatefulWidget {
  const RoleCreatePage({super.key, this.role});

  final Role? role;

  @override
  ConsumerState<RoleCreatePage> createState() => _RoleCreatePageState();
}

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
  }

  @override
  void dispose() {
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
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑角色' : '新建角色'),
        // 保存放在导航栏右侧，避免滚到表单底部才能提交。
        actions: [
          TextButton(
            onPressed: _saving ? null : _submit,
            child: _saving
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
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 32 + bottomInset),
          children: [
            _CoverPicker(path: _coverImg, onTap: _pickCover),
            const SizedBox(height: 24),
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
            const SizedBox(height: 24),
            _DescSectionHeader(
              showHistory: _isEditing,
              onHistoryTap: _openDescHistory,
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

/// 立绘用 3:4 圆角方图，避免圆形头像看起来像通讯录。
class _CoverPicker extends StatelessWidget {
  const _CoverPicker({required this.path, required this.onTap});

  final String path;
  final VoidCallback onTap;

  static const double _width = 140;
  static const double _height = 186;

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    final file = File(path);
    final hasCover = path.isNotEmpty && file.existsSync();
    final label = hasCover ? '更换立绘' : '添加立绘';

    return Center(
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Tooltip(
          message: label,
          child: Material(
            color: tokens.surface,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: tokens.border),
            ),
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                width: _width,
                height: _height,
                child: hasCover
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(file, fit: BoxFit.cover),
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: _CoverBadge(tokens: tokens),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 36,
                            color: tokens.inkSecondary,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '添加立绘',
                            style: TextStyle(
                              color: tokens.inkSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CoverBadge extends StatelessWidget {
  const _CoverBadge({required this.tokens});

  final ZaidangTokens tokens;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surface.withValues(alpha: 0.92),
        shape: BoxShape.circle,
        border: Border.all(color: tokens.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          Icons.photo_camera_outlined,
          size: 16,
          color: tokens.ink,
        ),
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
