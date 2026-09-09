import 'dart:async';

import 'package:flutter/material.dart';

import '../features/backup/backup_coordinator.dart';
import '../features/backup/backup_models.dart';
import '../features/backup/backup_protocol.dart';
import '../features/backup/widgets/backup_job_panel.dart';
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
    this.coordinator,
    this.onReviewRestore,
    this.onCancelJob,
  });
  final Future<SnapshotContents> Function() loadContents;
  final BackupDescriptor? descriptor;
  final String title;
  final Future<void> Function()? onPrepareRestore;
  final BackupCoordinator? coordinator;
  final Future<void> Function(BackupJobState)? onReviewRestore;
  final Future<void> Function(BackupJobState)? onCancelJob;
  @override
  State<BackupContentsPage> createState() => _BackupContentsPageState();
}

class _BackupContentsPageState extends State<BackupContentsPage> {
  late Future<SnapshotContents> _contents = widget.loadContents();
  StreamSubscription<BackupJobState>? _jobSubscription;
  BackupJobState? _job;
  String? _trackedOperationId;
  String? _observedReadyOperationId;
  bool _starting = false;
  bool _jobActionBusy = false;
  String? _error;
  int _tab = 0;
  int _page = 0;
  static const _pageSize = 30;

  @override
  void initState() {
    super.initState();
    _observeCoordinator();
  }

  @override
  void didUpdateWidget(BackupContentsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coordinator != widget.coordinator ||
        oldWidget.descriptor?.snapshotId != widget.descriptor?.snapshotId) {
      _jobSubscription?.cancel();
      _job = null;
      _trackedOperationId = null;
      _observedReadyOperationId = null;
      _observeCoordinator();
    }
  }

  void _observeCoordinator() {
    final coordinator = widget.coordinator;
    if (coordinator == null) return;
    final current = coordinator.currentJob;
    if (current != null && _matchesBackup(current)) {
      _job = current;
      _trackedOperationId = current.operationId;
      if (current.phase == BackupPhase.readyForReview) {
        // Reopening a ready job must still require a fresh user action.
        _observedReadyOperationId = current.operationId;
      }
    }
    _jobSubscription = coordinator.watchJob().listen(_onJobChanged);
  }

  bool _matchesBackup(BackupJobState job) {
    if (job.kind != BackupJobKind.restore) return false;
    if (job.operationId == _trackedOperationId) return true;
    final expected = widget.descriptor?.snapshotId;
    return expected != null && job.descriptor?.snapshotId == expected;
  }

  void _onJobChanged(BackupJobState next) {
    if (!_matchesBackup(next) || !mounted) return;
    final newlyReady =
        next.phase == BackupPhase.readyForReview &&
        _observedReadyOperationId != next.operationId;
    if (next.phase == BackupPhase.readyForReview) {
      _observedReadyOperationId = next.operationId;
    }
    setState(() {
      _job = next;
      _trackedOperationId = next.operationId;
      _starting = false;
    });
    if (newlyReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _reviewRestore(next, automatic: true);
      });
    }
  }

  @override
  void dispose() {
    _jobSubscription?.cancel();
    super.dispose();
  }

  Future<void> _prepareRestore() async {
    if (_starting || _hasActionableJob || widget.onPrepareRestore == null) {
      return;
    }
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      await widget.onPrepareRestore!();
      if (!mounted) return;
      final current = widget.coordinator?.currentJob;
      if (current != null && current.kind == BackupJobKind.restore) {
        _trackedOperationId = current.operationId;
        _onJobChanged(current);
      }
    } catch (error) {
      if (mounted) setState(() => _error = backupErrorMessage(error));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _reviewRestore(
    BackupJobState job, {
    bool automatic = false,
  }) async {
    if (_jobActionBusy || widget.onReviewRestore == null) return;
    if (job.phase != BackupPhase.readyForReview) return;
    if (automatic && ModalRoute.of(context)?.isCurrent != true) return;
    setState(() {
      _jobActionBusy = true;
      _error = null;
    });
    try {
      await widget.onReviewRestore!(job);
    } catch (error) {
      if (mounted) setState(() => _error = backupErrorMessage(error));
    } finally {
      if (mounted) setState(() => _jobActionBusy = false);
    }
  }

  Future<void> _cancelJob(BackupJobState job) async {
    final cancel = widget.onCancelJob;
    if (_jobActionBusy || cancel == null) return;
    await _runJobAction(() => cancel(job));
  }

  Future<void> _retryJob(BackupJobState job) async {
    final coordinator = widget.coordinator;
    if (_jobActionBusy || coordinator == null) return;
    await _runJobAction(() async {
      await coordinator.retry(job.operationId);
      if (!mounted) return;
      final current = coordinator.currentJob;
      if (current != null && current.kind == BackupJobKind.restore) {
        _trackedOperationId = current.operationId;
        _onJobChanged(current);
      }
    });
  }

  Future<void> _runJobAction(Future<void> Function() action) async {
    setState(() {
      _jobActionBusy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = backupErrorMessage(error));
    } finally {
      if (mounted) setState(() => _jobActionBusy = false);
    }
  }

  bool get _activationInProgress => _job?.phase == BackupPhase.activating;

  bool get _hasActionableJob {
    final phase = _job?.phase;
    return phase != null &&
        phase != BackupPhase.completed &&
        phase != BackupPhase.cancelled;
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_activationInProgress,
    child: Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !_activationInProgress,
        centerTitle: true,
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
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
          final pages = (roles.length / _pageSize).ceil().clamp(1, 100000);
          return BackupBody(
            children: [
              if (descriptor != null) ...[
                Text(
                  backupDateLabel(descriptor.createdAtUtc),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${descriptor.createdAtUtc.toLocal().year} 年 · 来自 ${descriptor.deviceName}',
                  style: TextStyle(color: backupSecondaryColor(context)),
                ),
                const SizedBox(height: 24),
              ],
              Divider(height: 1, color: ZaidangTokens.of(context).border),
              const SizedBox(height: 18),
              _BackupFacts(
                roleCount: contents.summary.roleCount,
                fileCount: contents.summary.originalFileCount,
                bytes:
                    descriptor?.totalBytes ??
                    contents.summary.knownLogicalDataBytes,
              ),
              const SizedBox(height: 18),
              Divider(height: 1, color: ZaidangTokens.of(context).border),
              BackupDisclosure(
                key: const Key('backup-contents-disclosure'),
                title: '查看备份内容',
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final (index, label) in [(0, '角色资料'), (1, '文件分类')])
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
                    for (final role
                        in roles.skip(_page * _pageSize).take(_pageSize))
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
                            builder: (_) => _BackupRoleContents(
                              contents: contents,
                              role: role,
                            ),
                          ),
                        ),
                      ),
                  ] else
                    _BackupFileSummary(files: files),
                  if (_tab == 0 && pages > 1)
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
                ],
              ),
              if (_job case final job? when _hasActionableJob) ...[
                const SizedBox(height: 32),
                BackupJobPanel(
                  job: job,
                  onCancel: _jobActionBusy || widget.onCancelJob == null
                      ? null
                      : () => _cancelJob(job),
                  onRetry: _jobActionBusy || widget.coordinator == null
                      ? null
                      : () => _retryJob(job),
                  onReview: _jobActionBusy || widget.onReviewRestore == null
                      ? null
                      : () => _reviewRestore(job),
                ),
              ],
              if (_error != null)
                BackupNotice(_error!, icon: Icons.error_outline),
              if (widget.onPrepareRestore != null && !_hasActionableJob) ...[
                const SizedBox(height: 28),
                FilledButton(
                  key: const Key('backup-prepare-restore'),
                  onPressed: _starting ? null : _prepareRestore,
                  style: backupPrimaryStyle(context),
                  child: Text(_starting ? '正在准备…' : '恢复这份备份'),
                ),
              ],
            ],
          );
        },
      ),
    ),
  );
}

class _BackupFacts extends StatelessWidget {
  const _BackupFacts({
    required this.roleCount,
    required this.fileCount,
    required this.bytes,
  });
  final int roleCount;
  final int fileCount;
  final int? bytes;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 24,
    runSpacing: 10,
    children: [
      Text('$roleCount 个角色', style: const TextStyle(fontSize: 15)),
      Text('$fileCount 个文件', style: const TextStyle(fontSize: 15)),
      Text(backupBytes(bytes), style: const TextStyle(fontSize: 15)),
    ],
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
  @override
  Widget build(BuildContext context) {
    final role = widget.role;
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
          _BackupFileSummary(files: _files),
        ],
      ),
    );
  }
}

/// Each frozen original-file entry contributes once, regardless of its owners.
class _BackupFileSummary extends StatelessWidget {
  const _BackupFileSummary({required this.files});
  final List<SnapshotContentFile> files;

  @override
  Widget build(BuildContext context) {
    const kinds = ['cover', 'image', 'video', 'audio', 'document'];
    final counts = <String, int>{};
    for (final file in files) {
      final kind = kinds.contains(file.kind) ? file.kind : 'document';
      counts.update(kind, (count) => count + 1, ifAbsent: () => 1);
    }
    if (counts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('暂无文件'),
      );
    }
    return Column(
      children: [
        for (final kind in kinds)
          if (counts.containsKey(kind))
            BackupKeyValue(
              backupKindLabel(kind),
              '${counts[kind]} 个',
              key: ValueKey('backup-file-category-$kind'),
            ),
      ],
    );
  }
}
