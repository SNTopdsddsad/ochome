import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/role_desc_revision.dart';
import '../data/providers/role_desc_revisions_provider.dart';
import '../data/providers/role_repository_provider.dart';
import '../theme/zaidang_tokens.dart';
import '../widgets/zaidang_confirm_dialog.dart';
import '../widgets/zaidang_snack_bar.dart';

/// 单个角色的设定修订列表。点某一版可回看全文并恢复。
class RoleDescHistoryPage extends ConsumerWidget {
  const RoleDescHistoryPage({super.key, required this.roleId});

  final int roleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revisions = ref.watch(roleDescRevisionsProvider(roleId));
    final tokens = ZaidangTokens.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('设定修改历史')),
      body: revisions.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Text(
                '还没有修改记录',
                style: TextStyle(color: tokens.inkSecondary, fontSize: 14),
              ),
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              return _RevisionTile(
                revision: items[index],
                isCurrent: index == 0,
                onOpen: () =>
                    _openRevision(context, ref, items[index], index == 0),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('加载失败：$error', style: TextStyle(color: tokens.ink)),
        ),
      ),
    );
  }

  Future<void> _openRevision(
    BuildContext context,
    WidgetRef ref,
    RoleDescRevision revision,
    bool isCurrent,
  ) async {
    final tokens = ZaidangTokens.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: tokens.surface,
          title: Text(_formatTime(revision.createdAt)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: SelectableText(
                revision.content.isEmpty ? '（空）' : revision.content,
                style: TextStyle(color: tokens.ink, height: 1.5),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('关闭'),
            ),
            if (!isCurrent)
              TextButton(
                style: TextButton.styleFrom(foregroundColor: tokens.ink),
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await _confirmRestore(context, ref, revision);
                },
                child: const Text('恢复此版'),
              ),
          ],
        );
      },
    );
  }

  Future<void> _confirmRestore(
    BuildContext context,
    WidgetRef ref,
    RoleDescRevision revision,
  ) async {
    final confirmed = await showZaidangConfirmDialog(
      context: context,
      title: '换回这一版设定吗？',
      body: '将立即换回 ${_formatTime(revision.createdAt)} 的设定。还没保存的设定修改会丢失。',
      consequence: '已经存下的修改历史会保留。',
      cancelLabel: '先不换',
      cancelSemanticLabel: '先不换，取消恢复设定',
      confirmLabel: '恢复此版',
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    try {
      final role = await ref
          .read(roleRepositoryProvider)
          .restoreDescRevision(roleId: roleId, revisionId: revision.id);
      if (context.mounted) {
        Navigator.of(context).pop(role.desc);
      }
    } catch (error) {
      if (context.mounted) {
        showZaidangSnackBar(
          context,
          '恢复失败：$error',
          tone: ZaidangSnackBarTone.error,
        );
      }
    }
  }
}

class _RevisionTile extends StatelessWidget {
  const _RevisionTile({
    required this.revision,
    required this.isCurrent,
    required this.onOpen,
  });

  final RoleDescRevision revision;
  final bool isCurrent;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      title: Text(_formatTime(revision.createdAt)),
      subtitle: Text(
        _preview(revision.content),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: isCurrent
          ? Text(
              '当前',
              style: TextStyle(color: tokens.inkSecondary, fontSize: 13),
            )
          : null,
      onTap: onOpen,
    );
  }
}

String _formatTime(DateTime time) {
  final local = time.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

String _preview(String content) {
  final trimmed = content.trim();
  if (trimmed.isEmpty) {
    return '（空）';
  }
  return trimmed.replaceAll(RegExp(r'\s+'), ' ');
}
