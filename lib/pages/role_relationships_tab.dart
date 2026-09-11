import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/role.dart';
import '../data/models/role_relationship.dart';
import '../data/providers/role_relationships_provider.dart';
import '../data/providers/roles_provider.dart';
import '../theme/zaidang_radius.dart';
import '../theme/zaidang_spacing.dart';
import '../theme/zaidang_tokens.dart';
import '../theme/zaidang_type.dart';
import '../widgets/cover_file_view.dart';
import '../widgets/role_relationship_editor_sheet.dart';
import '../widgets/zaidang_confirm_dialog.dart';
import '../widgets/zaidang_snack_bar.dart';

enum _RelationshipAction { edit, delete }

/// 已保存角色的关系列表。结构与 [RoleAssetsTab] 一致，共享父级吸顶头图。
class RoleRelationshipsTab extends ConsumerStatefulWidget {
  const RoleRelationshipsTab({
    super.key,
    required this.roleId,
    required this.overlapHandle,
    required this.onBusyChanged,
    this.enabled = true,
    this.isEnabled,
    this.supportDirectory,
  });

  final int roleId;
  final SliverOverlapAbsorberHandle overlapHandle;
  final ValueChanged<bool> onBusyChanged;
  final bool enabled;

  /// Check parent save state even before its disabled-state rebuild.
  final bool Function()? isEnabled;

  /// 测试注入：对方封面所在沙盒根目录。
  final Future<Directory> Function()? supportDirectory;

  @override
  ConsumerState<RoleRelationshipsTab> createState() =>
      _RoleRelationshipsTabState();
}

class _RoleRelationshipsTabState extends ConsumerState<RoleRelationshipsTab>
    with AutomaticKeepAliveClientMixin {
  bool _busy = false;

  @override
  bool get wantKeepAlive => true;

  bool get _enabled => widget.enabled && (widget.isEnabled?.call() ?? true);

  bool get _canAct => _enabled && !_busy;

  void _setBusy(bool busy) {
    setState(() => _busy = busy);
    widget.onBusyChanged(busy);
  }

  Map<int, Role> _rolesById() => {
    for (final role in ref.read(rolesProvider).asData?.value ?? const <Role>[])
      role.id: role,
  };

  Future<void> _openEditor({RoleRelationship? initial}) async {
    if (!_canAct) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final roles = _rolesById();
    final self = roles[widget.roleId];
    if (self == null) return;
    final candidates = roles.values
        .where((role) => role.id != widget.roleId)
        .toList();
    if (candidates.isEmpty) {
      showZaidangSnackBar(context, '还没有其他 OC，先新建一个再来添加关系');
      return;
    }
    _setBusy(true);
    try {
      final repository = ref.read(roleRelationshipRepositoryProvider);
      final changed = await showRoleRelationshipEditor(
        context: context,
        self: self,
        candidates: candidates,
        initial: initial,
        supportDirectory: widget.supportDirectory,
        canSave: () => mounted && _enabled,
        onSave: (draft) async {
          // 抛错而不是静默返回：否则面板会把「什么都没写」报成保存成功。
          if (!mounted || !_enabled) {
            throw StateError('页面已停止编辑，请重新打开再试');
          }
          if (initial == null) {
            await repository.create(
              fromRoleId: self.id,
              toRoleId: draft.otherRoleId,
              fromLabel: draft.selfLabel,
              toLabel: draft.otherLabel,
            );
          } else {
            await repository.update(
              initial.copyWith(
                fromRoleId: self.id,
                toRoleId: draft.otherRoleId,
                fromLabel: draft.selfLabel,
                toLabel: draft.otherLabel,
              ),
            );
          }
        },
      );
      if (changed == true && mounted) {
        showZaidangSnackBar(context, initial == null ? '关系已添加' : '关系已更新');
      }
    } finally {
      if (mounted) _setBusy(false);
    }
  }

  Future<void> _showActions(
    RoleRelationship relationship,
    String otherName,
    BuildContext anchor,
  ) async {
    if (!_canAct) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _setBusy(true);
    try {
      final overlay =
          Navigator.of(context).overlay!.context.findRenderObject()
              as RenderBox;
      final button = anchor.findRenderObject()! as RenderBox;
      final action = await showMenu<_RelationshipAction>(
        context: context,
        position: RelativeRect.fromRect(
          Rect.fromPoints(
            button.localToGlobal(Offset.zero, ancestor: overlay),
            button.localToGlobal(
              button.size.bottomRight(Offset.zero),
              ancestor: overlay,
            ),
          ),
          Offset.zero & overlay.size,
        ),
        items: const [
          PopupMenuItem(
            value: _RelationshipAction.edit,
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 20),
                SizedBox(width: ZaidangSpacing.md),
                Text('修改'),
              ],
            ),
          ),
          PopupMenuItem(
            value: _RelationshipAction.delete,
            child: Row(
              children: [
                Icon(Icons.delete_outline, size: 20),
                SizedBox(width: ZaidangSpacing.md),
                Text('删除'),
              ],
            ),
          ),
        ],
      );
      if (!mounted || !_enabled || action == null) return;
      switch (action) {
        case _RelationshipAction.edit:
          // 释放当前 busy，交给编辑器自己管理。
          _setBusy(false);
          await _openEditor(initial: relationship);
        case _RelationshipAction.delete:
          await _delete(relationship, otherName);
      }
    } finally {
      if (mounted && _busy) _setBusy(false);
    }
  }

  Future<void> _delete(RoleRelationship relationship, String otherName) async {
    try {
      final confirmed = await showZaidangConfirmDialog(
        context: context,
        title: '删除这条关系？',
        body: '与「$otherName」的这条关系会从双方的档案里移除。',
        consequence: '删除立即生效，两位 OC 本身不受影响。',
        confirmLabel: '删除关系',
      );
      if (!confirmed || !mounted || !_enabled) return;
      final deleted = await ref
          .read(roleRelationshipRepositoryProvider)
          .delete(roleId: widget.roleId, relationshipId: relationship.id);
      if (mounted) {
        showZaidangSnackBar(context, deleted ? '关系已删除' : '这条关系已经不存在了');
      }
    } catch (error, stackTrace) {
      debugPrint('delete relationship failed: $error\n$stackTrace');
      if (mounted) {
        showZaidangSnackBar(
          context,
          '没能删除这条关系，请再试一次',
          tone: ZaidangSnackBarTone.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final relationships = ref.watch(roleRelationshipsProvider(widget.roleId));
    final roles = ref.watch(rolesProvider);
    final rolesById = {
      for (final role in roles.asData?.value ?? const <Role>[]) role.id: role,
    };
    final tokens = ZaidangTokens.of(context);
    final type = ZaidangType.of(context);
    final inset =
        ZaidangSpacing.page +
        ((MediaQuery.sizeOf(context).width - 600).clamp(0, double.infinity) /
            2);
    return CustomScrollView(
      key: const PageStorageKey('role-relationships-scroll'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverOverlapInjector(handle: widget.overlapHandle),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            inset,
            ZaidangSpacing.md,
            inset,
            ZaidangSpacing.sm,
          ),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: Text(switch (relationships.asData) {
                    AsyncData(:final value) => '${value.length} 条关系',
                    _ => '',
                  }, style: type.caption),
                ),
                TextButton.icon(
                  key: const Key('role-relationship-add'),
                  onPressed: _canAct ? _openEditor : null,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('添加关系'),
                ),
              ],
            ),
          ),
        ),
        ...relationships.when(
          data: (items) {
            if (items.isEmpty) {
              return <Widget>[
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(ZaidangSpacing.xxl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 40,
                          color: tokens.inkSecondary,
                        ),
                        const SizedBox(height: ZaidangSpacing.md),
                        Text('还没有关系', style: type.body),
                        const SizedBox(height: ZaidangSpacing.sm),
                        Text(
                          '记录这个 OC 与其他 OC 之间的关系，比如师徒、挚友、宿敌',
                          textAlign: TextAlign.center,
                          style: type.caption,
                        ),
                      ],
                    ),
                  ),
                ),
              ];
            }
            return <Widget>[
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  inset,
                  ZaidangSpacing.sm,
                  inset,
                  ZaidangSpacing.xxl + MediaQuery.paddingOf(context).bottom,
                ),
                sliver: SliverList.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final relationship = items[index];
                    final other =
                        rolesById[relationship.otherRoleId(widget.roleId)];
                    final otherName = other == null
                        ? '已删除的 OC'
                        : other.name.trim().isEmpty
                        ? '未命名'
                        : other.name;
                    return ListTile(
                      key: ValueKey('role-relationship-${relationship.id}'),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: ZaidangSpacing.sm,
                      ),
                      leading: _OtherPortrait(
                        role: other,
                        name: otherName,
                        supportDirectory: widget.supportDirectory,
                      ),
                      title: Text(
                        otherName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '我是 TA 的${relationship.selfLabel(widget.roleId)}'
                        ' · TA 是我的${relationship.otherLabel(widget.roleId)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: _canAct
                          ? () => _openEditor(initial: relationship)
                          : null,
                      trailing: Builder(
                        builder: (context) => IconButton(
                          tooltip: '更多操作：$otherName',
                          icon: Icon(
                            Icons.more_horiz,
                            size: 20,
                            semanticLabel: '更多操作：$otherName',
                          ),
                          onPressed: _canAct
                              ? () => _showActions(
                                  relationship,
                                  otherName,
                                  context,
                                )
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ];
          },
          loading: () => const <Widget>[
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
          error: (error, _) => <Widget>[
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('关系加载失败'),
                    TextButton(
                      onPressed: () => ref.invalidate(
                        roleRelationshipsProvider(widget.roleId),
                      ),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OtherPortrait extends StatelessWidget {
  const _OtherPortrait({
    required this.role,
    required this.name,
    required this.supportDirectory,
  });

  final Role? role;
  final String name;
  final Future<Directory> Function()? supportDirectory;

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    final placeholder = ColoredBox(
      color: tokens.surface,
      child: Center(
        child: Text(
          name.characters.first,
          style: ZaidangType.of(context).subheading
              .copyWith(color: tokens.inkSecondary),
        ),
      ),
    );
    return ClipRRect(
      borderRadius: ZaidangRadius.smAll,
      child: SizedBox(
        width: 44,
        height: 52,
        child: role == null
            ? placeholder
            : CoverFileView(
                coverImg: role!.coverImg,
                placeholder: placeholder,
                supportDirectory: supportDirectory,
              ),
      ),
    );
  }
}
