import 'package:flutter/material.dart';

import '../features/backup/backup_protocol.dart';
import '../features/backup/widgets/backup_shared.dart';
import '../theme/zaidang_tokens.dart';

/// A frozen contents index; never joins a historical backup to current role data.
class BackupContentsPage extends StatefulWidget {
  const BackupContentsPage({
    super.key,
    required this.loadContents,
    this.descriptor,
    this.title = '备份内容',
    this.onPrepareRestore,
  });
  final Future<SnapshotContents> Function() loadContents;
  final BackupDescriptor? descriptor;
  final String title;
  final Future<void> Function()? onPrepareRestore;
  @override
  State<BackupContentsPage> createState() => _BackupContentsPageState();
}

class _BackupContentsPageState extends State<BackupContentsPage> {
  late Future<SnapshotContents> _contents = widget.loadContents();
  bool _starting = false;
  String? _error;
  int _tab = 0;
  int _page = 0;
  static const _pageSize = 30;

  Future<void> _prepareRestore() async {
    if (_starting || widget.onPrepareRestore == null) return;
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      await widget.onPrepareRestore!();
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) setState(() => _error = backupErrorMessage(error));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: FutureBuilder<SnapshotContents>(
      future: _contents,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return BackupBody(
            children: [
              BackupNotice(
                backupErrorMessage(snapshot.error!),
                icon: Icons.error_outline,
              ),
              FilledButton(
                onPressed: () =>
                    setState(() => _contents = widget.loadContents()),
                child: const Text('重新读取目录'),
              ),
            ],
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final contents = snapshot.requireData;
        final descriptor = widget.descriptor;
        final roles = contents.roles;
        final files = contents.files;
        final itemCount = _tab == 0 ? roles.length : files.length;
        final pages = (itemCount / _pageSize).ceil().clamp(1, 100000);
        return BackupBody(
          children: [
            if (descriptor != null) ...[
              Text(
                backupTime(descriptor.createdAtUtc),
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                descriptor.deviceName,
                style: TextStyle(color: ZaidangTokens.of(context).inkSecondary),
              ),
              const SizedBox(height: 16),
            ],
            BackupSummaryView(summary: contents.summary),
            const BackupNotice('目录显示这份资料中的角色和原始文件。浏览目录不会改变恢复范围。'),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final (index, label) in [
                  (0, '角色资料'),
                  (1, '文件清单'),
                  (2, '时间记录'),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: _tab == index,
                    onSelected: (_) => setState(() {
                      _tab = index;
                      _page = 0;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_tab == 0) ...[
              if (roles.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('这份资料中没有角色')),
                ),
              for (final role in roles.skip(_page * _pageSize).take(_pageSize))
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  leading: const Icon(Icons.person_outline),
                  title: Text(role.name),
                  subtitle: Text(
                    '${role.customAttributeNamesInOrder.length} 项属性 · ${role.revisionCount} 版历史 · ${files.where((file) => file.roleIds.contains(role.roleId)).length} 份原文件',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) =>
                          _BackupRoleContents(contents: contents, role: role),
                    ),
                  ),
                ),
            ] else if (_tab == 1) ...[
              if (files.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('没有立绘或资产文件')),
                ),
              for (final file in files.skip(_page * _pageSize).take(_pageSize))
                _BackupFileTile(file: file, roles: roles),
            ] else ...[
              BackupKeyValue('备份内容时间', backupTime(descriptor?.createdAtUtc)),
              BackupKeyValue(
                '云端完成确认时间',
                backupTime(descriptor?.completedAtUtc),
              ),
              if (descriptor != null) ...[
                BackupKeyValue('来源设备', descriptor.deviceName),
                BackupKeyValue('创建版本', descriptor.appVersion),
              ],
              const BackupNotice('时间按当前设备时区显示。未取得完成回执时不推算完成时间。'),
            ],
            if (_tab != 2 && pages > 1)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    tooltip: '上一页',
                    onPressed: _page == 0
                        ? null
                        : () => setState(() => _page--),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('第 ${_page + 1} / $pages 页'),
                  IconButton(
                    tooltip: '下一页',
                    onPressed: _page + 1 >= pages
                        ? null
                        : () => setState(() => _page++),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            if (_error != null)
              BackupNotice(_error!, icon: Icons.error_outline),
            if (widget.onPrepareRestore != null) ...[
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: _starting ? null : _prepareRestore,
                style: OutlinedButton.styleFrom(
                  foregroundColor: ZaidangTokens.of(context).ink,
                ),
                child: Text(_starting ? '正在准备…' : '下载并检查这份备份'),
              ),
              const BackupNotice('此操作先下载和检查，完成后仍需你确认才会替换本机资料。'),
            ],
          ],
        );
      },
    ),
  );
}

class _BackupRoleContents extends StatefulWidget {
  const _BackupRoleContents({required this.contents, required this.role});
  final SnapshotContents contents;
  final SnapshotRole role;
  @override
  State<_BackupRoleContents> createState() => _BackupRoleContentsState();
}

class _BackupRoleContentsState extends State<_BackupRoleContents> {
  late final List<SnapshotContentFile> _files = widget.contents.files
      .where((file) => file.roleIds.contains(widget.role.roleId))
      .toList(growable: false);
  int _page = 0;
  static const _pageSize = 30;
  @override
  Widget build(BuildContext context) {
    final role = widget.role;
    final pages = (_files.length / _pageSize).ceil().clamp(1, 100000);
    return Scaffold(
      appBar: AppBar(
        title: Text(role.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: BackupBody(
        children: [
          const BackupKeyValue('基础资料与设定', '完整内容已包含'),
          BackupKeyValue('设定历史', '${role.revisionCount} 版'),
          BackupKeyValue(
            '自定义属性',
            '${role.customAttributeNamesInOrder.length} 项',
          ),
          if (role.customAttributeNamesInOrder.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(role.customAttributeNamesInOrder.join(' · ')),
            ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              '立绘与资产 · ${_files.length} 份',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
          for (final file in _files.skip(_page * _pageSize).take(_pageSize))
            _BackupFileTile(file: file, roles: widget.contents.roles),
          if (pages > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: '上一页',
                  onPressed: _page == 0 ? null : () => setState(() => _page--),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('第 ${_page + 1} / $pages 页'),
                IconButton(
                  tooltip: '下一页',
                  onPressed: _page + 1 >= pages
                      ? null
                      : () => setState(() => _page++),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _BackupFileTile extends StatelessWidget {
  const _BackupFileTile({required this.file, required this.roles});
  final SnapshotContentFile file;
  final List<SnapshotRole> roles;
  @override
  Widget build(BuildContext context) {
    final owners = roles
        .where((r) => file.roleIds.contains(r.roleId))
        .map((r) => r.name)
        .join('、');
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Icon(backupKindIcon(file.kind)),
      title: Text(
        file.displayName,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${backupKindLabel(file.kind)} · ${file.knownBytes == null ? '大小待检查' : backupBytes(file.knownBytes)}\n$owners',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: true,
      onTap: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.displayName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                BackupKeyValue('所属角色', owners),
                BackupKeyValue('类型', backupKindLabel(file.kind)),
                BackupKeyValue(
                  '原始文件大小',
                  file.knownBytes == null
                      ? '大小待检查'
                      : backupBytes(file.knownBytes),
                ),
                const BackupNotice('这里展示备份目录中的文件信息。恢复前会检查实际文件内容。'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
