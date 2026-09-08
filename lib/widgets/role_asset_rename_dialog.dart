import 'package:flutter/material.dart';

import '../data/models/role_asset_name.dart';
import '../theme/zaidang_tokens.dart';

class RoleAssetRenameDialog extends StatefulWidget {
  const RoleAssetRenameDialog({
    super.key,
    required this.name,
    required this.relativePath,
    required this.canSave,
    required this.onSave,
  });

  final String name;
  final String relativePath;
  final bool Function() canSave;
  final Future<void> Function(String baseName) onSave;

  @override
  State<RoleAssetRenameDialog> createState() => _RoleAssetRenameDialogState();
}

class _RoleAssetRenameDialogState extends State<RoleAssetRenameDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = RoleAssetName(
    name: widget.name,
    relativePath: widget.relativePath,
  );
  late final _controller = TextEditingController(text: _name.baseName)
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: _name.baseName.length,
    );
  bool _saving = false;
  bool _resolved = false;
  String? _saveError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _resolve(bool changed) {
    if (_resolved || ModalRoute.of(context)?.isCurrent == false) return;
    _resolved = true;
    Navigator.of(context).pop(changed);
  }

  Future<void> _submit() async {
    if (_saving ||
        _resolved ||
        !widget.canSave() ||
        ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_name.renamed(_controller.text) == widget.name) {
      _resolve(false);
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await widget.onSave(_controller.text.trim());
      if (mounted) _resolve(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = error is FormatException ? error.message : '重命名失败，请重试';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    return PopScope(
      canPop: !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _resolved = true;
      },
      child: AlertDialog(
        key: const Key('role-asset-rename-dialog'),
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        title: const Text('重命名资产'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                key: const Key('role-asset-rename-name'),
                controller: _controller,
                autofocus: true,
                enabled: !_saving,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(labelText: '资产名称'),
                validator: RoleAssetName.validateBaseName,
                onFieldSubmitted: (_) => _submit(),
              ),
              if (_name.extension.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  '文件格式 ${_name.extension}（保留）',
                  key: const Key('role-asset-rename-extension'),
                  style: TextStyle(color: tokens.inkSecondary),
                ),
              ],
              if (_saveError != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(_saveError!, style: TextStyle(color: tokens.ink)),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const Key('role-asset-rename-cancel'),
            onPressed: _saving
                ? null
                : () {
                    if (!_saving) _resolve(false);
                  },
            style: TextButton.styleFrom(foregroundColor: tokens.ink),
            child: const Text('取消'),
          ),
          TextButton(
            key: const Key('role-asset-rename-save'),
            onPressed: _saving ? null : _submit,
            child: Text(_saving ? '保存中…' : '保存'),
          ),
        ],
      ),
    );
  }
}
