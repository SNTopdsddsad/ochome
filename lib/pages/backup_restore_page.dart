import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/providers/backup_coordinator_provider.dart';
import '../data/services/icloud_container.dart';
import '../features/backup/backup_coordinator.dart';
import '../features/backup/backup_models.dart';
import '../features/backup/backup_protocol.dart';
import '../features/backup/widgets/backup_job_panel.dart';
import '../features/backup/widgets/backup_shared.dart';
import '../theme/zaidang_tokens.dart';
import '../widgets/zaidang_confirm_dialog.dart';
import '../widgets/storage_error_details.dart';
import 'backup_contents_page.dart';

class BackupRestorePage extends ConsumerWidget {
  const BackupRestorePage({super.key, this.icloudSupported});
  final bool? icloudSupported;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supported = icloudSupported ?? ICloudContainer.platformSupported;
    if (!supported) {
      return Scaffold(
        appBar: AppBar(title: const Text('备份与恢复')),
        body: const BackupBody(
          children: [BackupNotice('iCloud 备份仅在 iPhone 和 Mac 上可用')],
        ),
      );
    }
    return ref
        .watch(backupCoordinatorProvider)
        .when(
          data: (coordinator) => _BackupHome(
            key: ObjectKey(coordinator),
            coordinator: coordinator,
          ),
          loading: () => Scaffold(
            appBar: AppBar(title: const Text('备份与恢复')),
            body: const Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Scaffold(
            appBar: AppBar(title: const Text('备份与恢复')),
            body: BackupBody(
              children: [
                BackupNotice(
                  backupErrorMessage(error),
                  icon: Icons.error_outline,
                ),
                const BackupNotice('本机资料不会被自动清空。请重试或检查可用存储空间。'),
                FilledButton(
                  onPressed: () => ref.invalidate(backupCoordinatorProvider),
                  child: const Text('重新打开备份服务'),
                ),
              ],
            ),
          ),
        );
  }
}

class _BackupHome extends StatefulWidget {
  const _BackupHome({super.key, required this.coordinator});
  final BackupCoordinator coordinator;
  @override
  State<_BackupHome> createState() => _BackupHomeState();
}

class _BackupHomeState extends State<_BackupHome> {
  BackupCoordinator get _coordinator => widget.coordinator;
  StreamSubscription<BackupJobState>? _subscription;
  BackupJobState? _job;
  BackupAvailability? _availability;
  BackupHistory? _history;
  SnapshotContents? _current;
  bool _hasPrevious = false, _loading = true, _actionBusy = false;
  String? _cloudError, _localError, _actionError;
  int _loadGeneration = 0;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _job = _coordinator.currentJob;
    _subscription = _coordinator.watchJob().listen((job) {
      if (!mounted) return;
      final wasTerminal = _job?.isTerminal ?? true;
      final priorId = _job?.operationId;
      setState(() => _job = job);
      if (priorId != job.operationId && !job.isTerminal) _revealJob();
      if (job.isTerminal && (!wasTerminal || priorId != job.operationId)) {
        unawaited(_reload());
      }
    });
    unawaited(_reload());
  }

  @override
  void dispose() {
    _loadGeneration++;
    unawaited(_subscription?.cancel());
    _scrollController.dispose();
    super.dispose();
  }

  void _revealJob() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _scrollController.jumpTo(0);
      } else {
        unawaited(
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          ),
        );
      }
    });
  }

  bool get _running => _job != null && !_job!.isTerminal;
  bool get _switching => _job?.phase == BackupPhase.activating;

  Future<void> _reload() async {
    final generation = ++_loadGeneration;
    if (mounted) setState(() => _loading = true);
    BackupAvailability? availability;
    BackupHistory? history;
    SnapshotContents? contents;
    var previous = false;
    String? cloudError, localError;
    await Future.wait([
      (() async {
        try {
          availability = await _coordinator.availability();
          if (availability!.available) {
            history = await _coordinator.listBackups();
          } else {
            cloudError = availability!.message ?? 'iCloud 备份暂不可用，请检查账户、网络后重试。';
          }
        } catch (error) {
          cloudError = backupErrorMessage(error);
        }
      })(),
      (() async {
        try {
          contents = await _coordinator.currentContents();
        } catch (error) {
          localError = backupErrorMessage(error);
        }
        try {
          previous = _coordinator.previousExists;
        } catch (error) {
          localError ??= backupErrorMessage(error);
        }
        if (mounted && generation == _loadGeneration) {
          setState(() {
            _current = contents;
            _hasPrevious = previous;
            _localError = localError;
          });
        }
      })(),
    ]);
    if (!mounted || generation != _loadGeneration) return;
    setState(() {
      _availability = availability;
      _history = history;
      _current = contents;
      _hasPrevious = previous;
      _cloudError = cloudError;
      _localError = localError;
      _loading = false;
    });
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (_actionBusy) return;
    setState(() {
      _actionBusy = true;
      _actionError = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _actionError = backupErrorMessage(error));
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _startBackup() => _perform(() async {
    if (_running || _current == null) return;
    final contents = _current!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '这次会备份什么',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                BackupSummaryView(summary: contents.summary),
                BackupKeyValue('角色资产', _assetCountText(contents.summary)),
                const BackupNotice('只备份已保存资料。开始时会重新核对范围；本次上传量和复用量将在检查云端后显示。'),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('backup-start-confirm'),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('开始备份'),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('先不备份'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmed == true && mounted) await _coordinator.startBackup();
  });

  String _assetCountText(SnapshotSummary summary) => [
    for (final kind in ['image', 'video', 'audio', 'document'])
      '${summary.assetCountsByKind[kind] ?? 0} ${backupKindLabel(kind)}',
  ].join(' / ');

  Future<void> _cancelJob(BackupJobState job) => _perform(() async {
    final confirmed = await showZaidangConfirmDialog(
      context: context,
      title: '取消这次操作？',
      body: '会停止当前准备和传输。',
      consequence: '本机资料与之前完成的备份会保留。',
      confirmLabel: '确认取消',
      cancelLabel: '继续当前操作',
      showSparkle: false,
    );
    if (confirmed && mounted) await _coordinator.cancel(job.operationId);
  });

  Future<void> _reviewRestore(BackupJobState job) => _perform(() async {
    final preview = job.restorePreview;
    if (preview == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '用这份备份替换本机资料？',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 14),
                BackupKeyValue('备份内容时间', backupTime(job.contentCreatedAtUtc)),
                BackupKeyValue(
                  '来源设备',
                  job.descriptor?.deviceName ?? '旧版备份或来源未提供',
                ),
                BackupKeyValue(
                  '将恢复',
                  '${preview.incoming.summary.roleCount} 位角色 · ${preview.incoming.summary.originalFileCount} 份原文件',
                ),
                BackupKeyValue(
                  '本机替换范围',
                  preview.currentUnreadable || preview.current == null
                      ? '本机资料暂时无法读取，原文件会保留'
                      : '${preview.current!.summary.roleCount} 位角色 · ${preview.current!.summary.originalFileCount} 份原文件',
                ),
                BackupKeyValue('准备区所需空间', backupBytes(preview.additionalBytes)),
                const BackupKeyValue('恢复前副本', '保留最近一份，可再次切回'),
                if (preview.limitedIntegrity)
                  const BackupNotice('这是旧版备份，缺少历史内容摘要；已完成可用的结构与文件检查。'),
                const BackupNotice(
                  '本机的角色资料、设定历史、立绘和资产都会被替换。确认后才开始切换。',
                  icon: Icons.shield_outlined,
                ),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    key: const Key('backup-activate-confirm'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ZaidangTokens.of(context).ink,
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('确认替换并恢复'),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('先不恢复'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmed == true && mounted) {
      await _coordinator.confirmRestore(job.operationId);
    }
  });

  Future<void> _previous({required bool discard}) => _perform(() async {
    if (_running) return;
    final confirmed = await showZaidangConfirmDialog(
      context: context,
      title: discard ? '清理恢复前副本？' : '切回上次恢复前的资料？',
      body: discard ? '会删除本机保留的那份恢复前资料。' : '当前本机资料会被恢复前的副本替换，包括这期间的编辑。',
      consequence: discard ? '清理后无法再通过这份副本切回，当前资料不会删除。' : '当前资料会保留为新的恢复前副本。',
      confirmLabel: discard ? '清理副本' : '确认切回',
      cancelLabel: '先不操作',
      showSparkle: false,
    );
    if (!confirmed || !mounted) return;
    if (discard) {
      await _coordinator.discardPrevious();
    } else {
      await _coordinator.restorePrevious();
    }
  });

  Future<void> _openContents({
    SnapshotContents? contents,
    BackupSource? source,
  }) async {
    if (_switching) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => BackupContentsPage(
          title: source == null
              ? '本次资料目录'
              : source.legacy
              ? '旧版备份内容'
              : '备份详情',
          descriptor: source?.descriptor,
          loadContents: contents != null
              ? () async => contents
              : () => _coordinator.contentsFor(source!),
          onPrepareRestore: source == null || _running
              ? null
              : () async {
                  await _coordinator.prepareRestore(source);
                },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    final recoveryOnly = _coordinator.storage.isRecoveryOnly;
    return PopScope(
      canPop: !_switching && !recoveryOnly,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('备份与恢复'),
          actions: [
            IconButton(
              tooltip: '刷新备份状态',
              onPressed: _loading || _switching ? null : _reload,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: BackupBody(
          controller: _scrollController,
          children: [
            if (_coordinator.recoveryNotice != null)
              BackupNotice(
                _coordinator.recoveryNotice!.message,
                icon: Icons.info_outline,
              ),
            if (recoveryOnly)
              const BackupNotice(
                '本机资料暂时无法打开。原文件已保留，可以选择有效云端备份恢复。',
                icon: Icons.shield_outlined,
              ),
            if (recoveryOnly)
              StorageErrorDetails(error: _coordinator.storage.recoveryError),
            if (_job case final job?) ...[
              BackupJobPanel(
                job: job,
                onCancel: _actionBusy ? null : () => _cancelJob(job),
                onRetry: _actionBusy
                    ? null
                    : () => _perform(() => _coordinator.retry(job.operationId)),
                onReview: _actionBusy ? null : () => _reviewRestore(job),
                onContents: job.contents == null
                    ? null
                    : () => _openContents(contents: job.contents),
                onViewBackup: job.descriptor == null
                    ? null
                    : () => _openContents(
                        source: BackupSource.snapshot(job.descriptor!),
                      ),
              ),
              const SizedBox(height: 22),
            ],
            if ((_job?.cleanupPending ?? false) ||
                (_history?.retiredCount ?? 0) > 0)
              OutlinedButton(
                key: const Key('backup-retry-cleanup'),
                onPressed: _running || _actionBusy
                    ? null
                    : () => _perform(_coordinator.retryCleanup),
                child: const Text('重试空间清理'),
              ),
            if (_actionError != null)
              BackupNotice(_actionError!, icon: Icons.error_outline),
            if (_current case final contents?) ...[
              BackupSummaryView(summary: contents.summary, title: '本机已保存资料'),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _switching
                      ? null
                      : () => _openContents(contents: contents),
                  icon: const Icon(Icons.folder_open_outlined),
                  label: const Text('查看全部内容'),
                ),
              ),
            ],
            if (_localError != null)
              BackupNotice(_localError!, icon: Icons.error_outline),
            if (_loading && _current == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_cloudError != null)
              BackupNotice(_cloudError!, icon: Icons.cloud_off_outlined),
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('backup-start'),
              onPressed:
                  _running ||
                      _actionBusy ||
                      _current == null ||
                      _history == null ||
                      !(_availability?.available ?? false)
                  ? null
                  : _startBackup,
              child: const Text('备份到 iCloud'),
            ),
            const SizedBox(height: 9),
            Text(
              '完整记录已保存资料，只上传需要的文件。',
              textAlign: TextAlign.center,
              style: TextStyle(color: tokens.inkSecondary, fontSize: 12),
            ),
            const SizedBox(height: 26),
            const Text(
              '云端备份',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              '同一 iCloud 账户合计保留最近 3 份',
              style: TextStyle(color: tokens.inkSecondary, fontSize: 12),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: LinearProgressIndicator(),
              ),
            if (!_loading && _history != null && _history!.snapshots.isEmpty)
              const BackupNotice('账户中还没有已完成的新格式备份。'),
            for (final backup
                in _history?.snapshots ?? const <BackupDescriptor>[])
              ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 5),
                leading: const Icon(Icons.inventory_2_outlined),
                title: Text(backupTime(backup.createdAtUtc)),
                subtitle: Text(
                  '${backup.deviceName} · ${backup.roleCount} 位角色\n${backupBytes(backup.totalBytes)} · ${backup.fileCount} 份原文件',
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: _switching
                    ? null
                    : () =>
                          _openContents(source: BackupSource.snapshot(backup)),
              ),
            if ((_history?.retiredCount ?? 0) > 0)
              const BackupNotice('部分旧备份正在等待安全清理，可能暂时额外占用空间。'),
            if (_history?.legacyExists ?? false) ...[
              const Divider(height: 28),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history),
                title: const Text('旧版备份'),
                subtitle: const Text('先读取目录，检查后再选择恢复'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _switching
                    ? null
                    : () => _openContents(source: const BackupSource.legacy()),
              ),
            ] else if (_history != null && !_history!.legacyDiscoveryComplete)
              const BackupNotice('旧版备份仍在发现中，稍后可以刷新。'),
            if (_hasPrevious) ...[
              const Divider(height: 32),
              const Text(
                '本机恢复前副本',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
              ),
              const BackupNotice('保留最近一次恢复前的资料。切回会替换此后的编辑；清理可释放对应空间。'),
              OutlinedButton(
                key: const Key('backup-restore-previous'),
                onPressed: _running || _actionBusy
                    ? null
                    : () => _previous(discard: false),
                style: OutlinedButton.styleFrom(foregroundColor: tokens.ink),
                child: const Text('切回恢复前资料'),
              ),
              TextButton(
                key: const Key('backup-discard-previous'),
                onPressed: _running || _actionBusy
                    ? null
                    : () => _previous(discard: true),
                style: TextButton.styleFrom(foregroundColor: tokens.ink),
                child: const Text('清理恢复前副本'),
              ),
            ],
            if (!recoveryOnly && !Navigator.of(context).canPop()) ...[
              const SizedBox(height: 20),
              TextButton(
                onPressed: _switching
                    ? null
                    : () => GoRouter.of(context).go('/archive'),
                child: const Text('返回档案'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
