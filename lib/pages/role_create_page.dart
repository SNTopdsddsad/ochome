import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/role.dart';
import '../data/providers/role_repository_provider.dart';
import '../data/services/cover_image_picker.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑角色' : '新建角色'),
        // 保存放在导航栏右侧，避免滚到表单底部才能提交。
        actions: [
          TextButton(
            onPressed: _saving ? null : _submit,
            child: Text(_saving ? '保存中…' : '保存'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickCover,
                child: CircleAvatar(
                  radius: 44,
                  backgroundImage: _coverImg.isEmpty
                      ? null
                      : FileImage(File(_coverImg)),
                  child: _coverImg.isEmpty
                      ? const Icon(Icons.add_a_photo, size: 28)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(child: Text('立绘')),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '名字',
                hintText: '角色怎么称呼',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请填写名字';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sexController,
              decoration: const InputDecoration(
                labelText: '性别',
                hintText: '女 / 非二元 / 不明',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ageController,
              decoration: const InputDecoration(
                labelText: '年龄',
                hintText: '十七、外表 20、不详',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _birthdayController,
              decoration: const InputDecoration(
                labelText: '生日',
                hintText: '三月三日、第三历春、未知',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _raceController,
              decoration: const InputDecoration(
                labelText: '种族',
                hintText: '人类、兽人、吸血鬼',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _occupationController,
              decoration: const InputDecoration(
                labelText: '身份',
                hintText: '学生、骑士、无所属',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: '设定',
                hintText: '性格、外貌、背景都可以写在这里',
                alignLabelWithHint: true,
              ),
              maxLines: 6,
            ),
          ],
        ),
      ),
    );
  }
}
