import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/models/role_asset_tags.dart';
import '../theme/zaidang_asset_colors.dart';
import '../theme/zaidang_spacing.dart';
import '../theme/zaidang_tokens.dart';
import '../theme/zaidang_type.dart';

/// 标签在对话框内编辑，保存后才写入资产；取消保留原值。
class RoleAssetTagsDialog extends StatefulWidget {
  const RoleAssetTagsDialog({
    super.key,
    required this.name,
    required this.tags,
    required this.canSave,
    required this.onSave,
  });

  final String name;
  final List<String> tags;
  final bool Function() canSave;
  final Future<void> Function(List<String> tags) onSave;

  @override
  State<RoleAssetTagsDialog> createState() => _RoleAssetTagsDialogState();
}

class _RoleAssetTagsDialogState extends State<RoleAssetTagsDialog> {
  /// 桌面限制编辑器宽度，手机由 Dialog 与安全区约束。
  static const double _maxWidth = 420;

  final _input = TextEditingController();
  late List<String> _tags = List.of(widget.tags);
  bool _saving = false;
  bool _resolved = false;
  String? _inputError;
  String? _saveError;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _resolve(bool changed) {
    if (_resolved || ModalRoute.of(context)?.isCurrent == false) return;
    _resolved = true;
    Navigator.of(context).pop(changed);
  }

  bool _addTag() {
    if (_saving || _resolved || !widget.canSave()) return false;
    try {
      final tags = normalizeRoleAssetTags([..._tags, _input.text]);
      setState(() {
        _tags = tags;
        _input.clear();
        _inputError = null;
      });
      return true;
    } on FormatException catch (error) {
      setState(() => _inputError = error.message);
      return false;
    }
  }

  Future<void> _submit() async {
    if (_saving ||
        _resolved ||
        !widget.canSave() ||
        ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    if (_input.text.trim().isNotEmpty && !_addTag()) return;
    if (listEquals(_tags, widget.tags)) {
      _resolve(false);
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await widget.onSave(List.unmodifiable(_tags));
      if (mounted) _resolve(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = switch (error) {
            FormatException(:final message) => message,
            StateError(:final message) => message,
            _ => '标签保存失败，请重试',
          };
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    final type = ZaidangType.of(context);
    return PopScope(
      canPop: !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _resolved = true;
      },
      child: Dialog(
        key: const Key('role-asset-tags-dialog'),
        insetPadding: const EdgeInsets.all(ZaidangSpacing.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(ZaidangSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('编辑标签', style: type.heading),
                const SizedBox(height: ZaidangSpacing.sm),
                Text(
                  widget.name,
                  style: type.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: ZaidangSpacing.lg),
                if (_tags.isNotEmpty) ...[
                  Wrap(
                    spacing: ZaidangSpacing.xs,
                    runSpacing: ZaidangSpacing.xs,
                    children: [
                      for (final tag in _tags)
                        InputChip(
                          key: ValueKey('role-asset-tag-$tag'),
                          label: Text(tag),
                          backgroundColor: ZaidangAssetColors.tagForeground(
                            context,
                            tag,
                          ).withValues(alpha: 0.08),
                          deleteButtonTooltipMessage: '移除标签：$tag',
                          onDeleted: _saving
                              ? null
                              : () {
                                  if (_saving ||
                                      _resolved ||
                                      !widget.canSave()) {
                                    return;
                                  }
                                  setState(
                                    () => _tags = [..._tags]..remove(tag),
                                  );
                                },
                        ),
                    ],
                  ),
                  const SizedBox(height: ZaidangSpacing.md),
                ],
                TextField(
                  key: const Key('role-asset-tag-input'),
                  controller: _input,
                  enabled: !_saving,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addTag(),
                  decoration: InputDecoration(
                    labelText: '新标签',
                    hintText: '例如：立绘、设定',
                    helperText:
                        '最多 $roleAssetTagMaxCount 个，每个最多 $roleAssetTagMaxGraphemes 字',
                    helperMaxLines: 2,
                    errorText: _inputError,
                    errorMaxLines: 2,
                    suffixIcon: IconButton(
                      key: const Key('role-asset-tag-add'),
                      tooltip: '添加标签',
                      icon: const Icon(Icons.add, semanticLabel: '添加标签'),
                      onPressed: _saving ? null : _addTag,
                    ),
                  ),
                ),
                if (_saveError != null) ...[
                  const SizedBox(height: ZaidangSpacing.md),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _saveError!,
                      key: const Key('role-asset-tags-error'),
                      style: type.body,
                    ),
                  ),
                ],
                const SizedBox(height: ZaidangSpacing.xl),
                Align(
                  alignment: Alignment.centerRight,
                  child: OverflowBar(
                    spacing: ZaidangSpacing.sm,
                    overflowSpacing: ZaidangSpacing.sm,
                    children: [
                      TextButton(
                        key: const Key('role-asset-tags-cancel'),
                        onPressed: _saving
                            ? null
                            : () {
                                if (!_saving) _resolve(false);
                              },
                        style: TextButton.styleFrom(
                          foregroundColor: tokens.ink,
                        ),
                        child: const Text('取消'),
                      ),
                      FilledButton(
                        key: const Key('role-asset-tags-save'),
                        onPressed: _saving ? null : _submit,
                        child: Text(_saving ? '保存中…' : '保存'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
