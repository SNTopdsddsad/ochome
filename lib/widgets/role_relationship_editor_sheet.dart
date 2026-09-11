// Hallmark · component: bottom sheet (关系便条) · genre: editorial
// theme: existing Zaidang paper / ink / seal red · motion: sheet default only
// states: default · pressed · focus · disabled · loading · error · selected · filled
// pre-emit critique: P4 H4 E4 S5 R5 V4
import 'dart:io';

import 'package:flutter/material.dart';

import '../data/models/role.dart';
import '../data/models/role_relationship.dart';
import '../theme/zaidang_radius.dart';
import '../theme/zaidang_spacing.dart';
import '../theme/zaidang_tokens.dart';
import '../theme/zaidang_type.dart';
import 'cover_file_view.dart';
import 'section_label.dart';

/// 编辑器产出：始终以当前角色为 `from` 视角描述。
class RoleRelationshipDraft {
  const RoleRelationshipDraft({
    required this.otherRoleId,
    required this.selfLabel,
    required this.otherLabel,
  });

  final int otherRoleId;

  /// 我是对方的 ___。
  final String selfLabel;

  /// 对方是我的 ___。
  final String otherLabel;
}

/// 打开关系便条。返回 `true` 表示已写入，`false`/`null` 表示未改动或取消。
Future<bool?> showRoleRelationshipEditor({
  required BuildContext context,
  required Role self,
  required List<Role> candidates,
  required bool Function() canSave,
  required Future<void> Function(RoleRelationshipDraft draft) onSave,
  RoleRelationship? initial,
  Future<Directory> Function()? supportDirectory,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // 点空白处走 maybePop，会被面板内 PopScope 在保存中拦住；
    // 下拉关闭直接 pop 绕过该守卫，所以不开。
    isDismissible: true,
    enableDrag: false,
    backgroundColor: ZaidangTokens.of(context).surface,
    constraints: const BoxConstraints(maxWidth: 560),
    shape: RoundedRectangleBorder(
      borderRadius: ZaidangRadius.lgTop,
      side: BorderSide(color: ZaidangTokens.of(context).border),
    ),
    builder: (_) => RoleRelationshipEditorSheet(
      self: self,
      candidates: candidates,
      initial: initial,
      canSave: canSave,
      onSave: onSave,
      supportDirectory: supportDirectory,
    ),
  );
}

/// 一张关系便条：先挑对方，再把两句话补完。
class RoleRelationshipEditorSheet extends StatefulWidget {
  const RoleRelationshipEditorSheet({
    super.key,
    required this.self,
    required this.candidates,
    required this.canSave,
    required this.onSave,
    this.initial,
    this.supportDirectory,
  });

  final Role self;

  /// 可选对方，不含 [self]。
  final List<Role> candidates;
  final bool Function() canSave;
  final Future<void> Function(RoleRelationshipDraft draft) onSave;

  /// 编辑已有关系时传入；为 `null` 表示新增。
  final RoleRelationship? initial;
  final Future<Directory> Function()? supportDirectory;

  @override
  State<RoleRelationshipEditorSheet> createState() =>
      _RoleRelationshipEditorSheetState();
}

class _RoleRelationshipEditorSheetState
    extends State<RoleRelationshipEditorSheet> {
  late int? _otherRoleId = _initialOtherRoleId();
  late final _selfLabel = TextEditingController(
    text: widget.initial?.selfLabel(widget.self.id) ?? '',
  );
  late final _otherLabel = TextEditingController(
    text: widget.initial?.otherLabel(widget.self.id) ?? '',
  );
  final _selfFocus = FocusNode();
  final _otherFocus = FocusNode();
  bool _saving = false;
  bool _resolved = false;

  /// 第一次提交后才开始逐字校验（touched 模式）。
  bool _touched = false;
  String? _saveError;

  int? _initialOtherRoleId() {
    final initial = widget.initial;
    if (initial == null) {
      return widget.candidates.length == 1 ? widget.candidates.single.id : null;
    }
    final other = initial.otherRoleId(widget.self.id);
    return widget.candidates.any((role) => role.id == other) ? other : null;
  }

  Role? get _other {
    for (final role in widget.candidates) {
      if (role.id == _otherRoleId) return role;
    }
    return null;
  }

  bool get _isEditing => widget.initial != null;

  bool get _selfLabelInvalid =>
      validateRelationshipLabel(_selfLabel.text) != null;
  bool get _otherLabelInvalid =>
      validateRelationshipLabel(_otherLabel.text) != null;

  bool get _atLengthCap =>
      _selfLabel.text.characters.length >= relationshipLabelMaxLength ||
      _otherLabel.text.characters.length >= relationshipLabelMaxLength;

  /// 一条共享的提示行，替代每个字段各自的报错，避免句子被撑开。
  String? get _hint {
    if (_saveError != null) return _saveError;
    // 触顶提示针对正在输入的字段，优先于提交后的整体校验。
    if (_atLengthCap) return '称呼最多 $relationshipLabelMaxLength 个字';
    if (_touched) {
      if (_otherRoleId == null) return '先选一位对方 OC';
      if (_selfLabelInvalid || _otherLabelInvalid) {
        return '两句话都要补完，才能记下这段关系';
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _selfLabel.addListener(_onTextChanged);
    _otherLabel.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    setState(() => _saveError = null);
  }

  @override
  void dispose() {
    _selfLabel.dispose();
    _otherLabel.dispose();
    _selfFocus.dispose();
    _otherFocus.dispose();
    super.dispose();
  }

  void _resolve(bool changed) {
    if (_resolved || ModalRoute.of(context)?.isCurrent == false) return;
    _resolved = true;
    Navigator.of(context).pop(changed);
  }

  void _select(int roleId) {
    if (_saving) return;
    setState(() {
      _otherRoleId = roleId;
      _saveError = null;
    });
  }

  void _swap() {
    if (_saving) return;
    final a = _selfLabel.text;
    _selfLabel.text = _otherLabel.text;
    _otherLabel.text = a;
  }

  bool _unchanged(RoleRelationshipDraft draft) {
    final initial = widget.initial;
    if (initial == null) return false;
    final self = widget.self.id;
    return initial.otherRoleId(self) == draft.otherRoleId &&
        initial.selfLabel(self) == draft.selfLabel &&
        initial.otherLabel(self) == draft.otherLabel;
  }

  Future<void> _submit() async {
    if (_saving ||
        _resolved ||
        !widget.canSave() ||
        ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    setState(() => _touched = true);
    if (_otherRoleId == null) return;
    if (_selfLabelInvalid) {
      _selfFocus.requestFocus();
      return;
    }
    if (_otherLabelInvalid) {
      _otherFocus.requestFocus();
      return;
    }
    final draft = RoleRelationshipDraft(
      otherRoleId: _otherRoleId!,
      selfLabel: normalizeRelationshipLabel(_selfLabel.text),
      otherLabel: normalizeRelationshipLabel(_otherLabel.text),
    );
    if (_unchanged(draft)) {
      _resolve(false);
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await widget.onSave(draft);
      if (mounted) _resolve(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = switch (error) {
            FormatException(:final message) => message,
            StateError(:final message) => message,
            _ => '没能保存这段关系，请再试一次',
          };
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    final type = ZaidangType.of(context);
    final other = _other;
    final otherName = other == null ? null : _displayName(other);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return PopScope(
      canPop: !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _resolved = true;
      },
      child: KeyedSubtree(
        key: const Key('role-relationship-editor'),
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              ZaidangSpacing.page,
              ZaidangSpacing.sm,
              ZaidangSpacing.page,
              ZaidangSpacing.xl,
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isEditing ? '修改关系' : '添加关系',
                        style: type.pageTitle,
                      ),
                    ),
                    IconButton(
                      key: const Key('role-relationship-cancel'),
                      tooltip: '关闭',
                      onPressed: _saving ? null : () => _resolve(false),
                      icon: Icon(Icons.close, color: tokens.ink, size: 22),
                    ),
                  ],
                ),
                const SizedBox(height: ZaidangSpacing.md),
                const SectionLabel('对方'),
                _CandidateStrip(
                  candidates: widget.candidates,
                  selectedId: _otherRoleId,
                  enabled: !_saving,
                  missing: _touched && _otherRoleId == null,
                  onSelect: _select,
                  supportDirectory: widget.supportDirectory,
                ),
                const SizedBox(height: ZaidangSpacing.xxl),
                const SectionLabel('关系'),
                _SentenceRow(
                  key: const Key('role-relationship-sentence-self'),
                  subject: _displayName(widget.self),
                  object: otherName,
                  blank: _Blank(
                    fieldKey: const Key('role-relationship-self-label'),
                    controller: _selfLabel,
                    focusNode: _selfFocus,
                    hint: '师父',
                    enabled: !_saving,
                    invalid: _touched && _selfLabelInvalid,
                    action: TextInputAction.next,
                    onSubmitted: (_) => _otherFocus.requestFocus(),
                  ),
                ),
                _SentenceRow(
                  key: const Key('role-relationship-sentence-other'),
                  subject: otherName,
                  object: _displayName(widget.self),
                  blank: _Blank(
                    fieldKey: const Key('role-relationship-other-label'),
                    controller: _otherLabel,
                    focusNode: _otherFocus,
                    hint: '徒弟',
                    enabled: !_saving,
                    invalid: _touched && _otherLabelInvalid,
                    action: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                const SizedBox(height: ZaidangSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _hint ?? '',
                          key: const Key('role-relationship-hint'),
                          style: type.caption.copyWith(color: tokens.ink),
                        ),
                      ),
                    ),
                    TextButton.icon(
                      key: const Key('role-relationship-swap'),
                      onPressed: _saving ? null : _swap,
                      style: TextButton.styleFrom(
                        foregroundColor: tokens.inkSecondary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: ZaidangSpacing.sm,
                        ),
                        minimumSize: const Size(44, 36),
                      ),
                      icon: const Icon(Icons.swap_vert, size: 18),
                      label: const Text('交换', semanticsLabel: '交换两句里的称呼'),
                    ),
                  ],
                ),
                const SizedBox(height: ZaidangSpacing.lg),
                FilledButton(
                  key: const Key('role-relationship-save'),
                  onPressed: _saving ? null : _submit,
                  // 只在保存中才禁用：正在工作的按钮保持满色，文字才够对比度。
                  style: FilledButton.styleFrom(
                    backgroundColor: tokens.accent,
                    foregroundColor: tokens.onAccent,
                    disabledBackgroundColor: tokens.accent,
                    disabledForegroundColor: tokens.onAccent,
                    minimumSize: const Size.fromHeight(48),
                    shape: const RoundedRectangleBorder(
                      borderRadius: ZaidangRadius.mdAll,
                    ),
                    textStyle: type.label,
                  ),
                  child: _saving
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: tokens.onAccent,
                              ),
                            ),
                            const SizedBox(width: ZaidangSpacing.md),
                            const Text('保存中…'),
                          ],
                        )
                      : Text(_isEditing ? '保存修改' : '记下这段关系'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 横向立绘小卡。选中态只改描边色与名字色，描边宽度恒定，不发生布局跳动。
class _CandidateStrip extends StatelessWidget {
  const _CandidateStrip({
    required this.candidates,
    required this.selectedId,
    required this.enabled,
    required this.missing,
    required this.onSelect,
    required this.supportDirectory,
  });

  final List<Role> candidates;
  final int? selectedId;
  final bool enabled;
  final bool missing;
  final ValueChanged<int> onSelect;
  final Future<Directory> Function()? supportDirectory;

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    final type = ZaidangType.of(context);
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: candidates.length,
        separatorBuilder: (_, _) => const SizedBox(width: ZaidangSpacing.md),
        itemBuilder: (context, index) {
          final role = candidates[index];
          final selected = role.id == selectedId;
          final name = _displayName(role);
          final borderColor = selected
              ? tokens.accent
              : missing
              ? tokens.ink
              : tokens.border;
          return Semantics(
            button: true,
            selected: selected,
            enabled: enabled,
            label: name,
            child: InkWell(
              key: Key('role-relationship-candidate-${role.id}'),
              onTap: enabled ? () => onSelect(role.id) : null,
              borderRadius: ZaidangRadius.mdAll,
              focusColor: tokens.accent.withValues(alpha: 0.12),
              child: Opacity(
                opacity: enabled ? 1 : 0.55,
                child: SizedBox(
                  width: 64,
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 74,
                        decoration: BoxDecoration(
                          color: tokens.bg,
                          borderRadius: ZaidangRadius.smAll,
                          border: Border.all(color: borderColor, width: 1.5),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: CoverFileView(
                          coverImg: role.coverImg,
                          supportDirectory: supportDirectory,
                          placeholder: Center(
                            child: Text(
                              name.characters.first,
                              style: type.subheading.copyWith(
                                color: selected
                                    ? tokens.accent
                                    : tokens.inkSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: ZaidangSpacing.sm),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: type.micro.copyWith(
                          color: selected ? tokens.ink : tokens.inkSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 「甲 是 乙 的 ____」。名字与填空共用同一字号，读起来是一句完整的话。
class _SentenceRow extends StatelessWidget {
  const _SentenceRow({
    super.key,
    required this.subject,
    required this.object,
    required this.blank,
  });

  /// `null` 表示对方尚未选择。
  final String? subject;
  final String? object;
  final Widget blank;

  @override
  Widget build(BuildContext context) {
    final particle = ZaidangType.of(context).bodyLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ZaidangSpacing.sm),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: ZaidangSpacing.sm,
        runSpacing: ZaidangSpacing.xs,
        children: [
          _Name(subject),
          Text('是', style: particle),
          _Name(object),
          Text('的', style: particle),
          blank,
        ],
      ),
    );
  }
}

class _Name extends StatelessWidget {
  const _Name(this.name);
  final String? name;

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 150),
      child: Text(
        name ?? '对方',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: ZaidangType.of(context).subheading
            .copyWith(color: name == null ? tokens.inkSecondary : tokens.ink),
      ),
    );
  }
}

/// 填空：只有一条下划线。所有状态下线宽恒定，靠颜色区分焦点与错误。
class _Blank extends StatelessWidget {
  const _Blank({
    required this.fieldKey,
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.enabled,
    required this.invalid,
    required this.action,
    required this.onSubmitted,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final bool enabled;
  final bool invalid;
  final TextInputAction action;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    final type = ZaidangType.of(context);
    UnderlineInputBorder line(Color color) =>
        UnderlineInputBorder(borderSide: BorderSide(color: color, width: 1.5));
    final restColor = invalid ? tokens.ink : tokens.border;
    return IntrinsicWidth(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 96, maxWidth: 220),
        child: TextField(
          key: fieldKey,
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          textInputAction: action,
          onSubmitted: onSubmitted,
          maxLength: relationshipLabelMaxLength,
          maxLines: 1,
          cursorColor: tokens.accent,
          style: type.subheading,
          decoration: InputDecoration(
            isDense: true,
            filled: false,
            counterText: '',
            hintText: hint,
            hintStyle: type.bodyLarge.copyWith(color: tokens.inkSecondary),
            contentPadding: const EdgeInsets.fromLTRB(
              ZaidangSpacing.xs,
              ZaidangSpacing.sm,
              ZaidangSpacing.xs,
              ZaidangSpacing.sm,
            ),
            border: line(restColor),
            enabledBorder: line(restColor),
            disabledBorder: line(tokens.border.withValues(alpha: 0.6)),
            focusedBorder: line(invalid ? tokens.ink : tokens.accent),
          ),
        ),
      ),
    );
  }
}

String _displayName(Role role) => role.name.trim().isEmpty ? '未命名' : role.name;
