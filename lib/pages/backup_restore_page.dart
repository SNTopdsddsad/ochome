import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/providers/backup_coordinator_provider.dart';
import '../data/providers/backup_completion_feedback_provider.dart';
import '../data/services/icloud_container.dart';
import '../features/backup/backup_coordinator.dart';
import '../features/backup/backup_models.dart';
import '../features/backup/backup_protocol.dart';
import '../features/backup/widgets/backup_job_panel.dart';
import '../features/backup/widgets/backup_shared.dart';
import '../theme/zaidang_tokens.dart';
import '../widgets/zaidang_confirm_dialog.dart';
import '../widgets/zaidang_snack_bar.dart';
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
            feedback: ref.watch(backupCompletionFeedbackProvider(coordinator)),
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
  const _BackupHome({
    super.key,
    required this.coordinator,
    required this.feedback,
  });
  final BackupCoordinator coordinator;
  final BackupCompletionFeedback feedback;
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
  bool _loading = true, _actionBusy = false;
  String? _cloudError, _localError, _actionError;
  String? _dismissedJobId;
  String? _historyAccountId;
  int _loadGeneration = 0;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _job = _coordinator.currentJob;
    widget.feedback.addListener(_showCompletion);
    _showCompletion();
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
    widget.feedback.removeListener(_showCompletion);
    unawaited(_subscription?.cancel());
    _scrollController.dispose();
    super.dispose();
  }

  void _showCompletion() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final job = widget.feedback.takeCompletion();
      if (job == null) return;
      showZaidangSnackBar(context, switch (job.kind) {
        BackupJobKind.backup => '备份已完成',
        BackupJobKind.restore => '资料已恢复',
        BackupJobKind.cleanup => '空间清理已完成',
      }, tone: ZaidangSnackBarTone.success);
    });
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
        if (mounted && generation == _loadGeneration) {
          setState(() {
            _current = contents;
            _localError = localError;
          });
        }
      })(),
    ]);
    if (!mounted || generation != _loadGeneration) return;
    setState(() {
      _availability = availability;
      if (history != null) {
        _history = history;
        _historyAccountId = availability?.accountId;
      } else if (availability?.errorCode == 'account_unavailable' ||
          (availability?.accountId != null &&
              _historyAccountId != null &&
              availability!.accountId != _historyAccountId)) {
        _history = null;
        _historyAccountId = null;
      }
      _current = contents;
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
      if (mounted) {
        setState(() => _actionError = backupErrorMessage(error));
        if (ModalRoute.of(context)?.isCurrent == false) {
          showZaidangSnackBar(
            context,
            _actionError!,
            tone: ZaidangSnackBarTone.error,
          );
        }
      }
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _startBackup() => _perform(() async {
    if (_running ||
        _current == null ||
        _coordinator.storage.isRecoveryOnly ||
        !(_availability?.available ?? false)) {
      return;
    }
    await _coordinator.startBackup();
  });

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
    final currentJob = _coordinator.currentJob;
    final preview = currentJob?.restorePreview;
    if (currentJob?.operationId != job.operationId ||
        !(currentJob?.requiresConfirmation ?? false) ||
        preview == null) {
      return;
    }
    final time = currentJob!.contentCreatedAtUtc;
    final summary = preview.incoming.summary;
    final confirmed = await showZaidangConfirmDialog(
      context: context,
      title: '替换本机资料？',
      body:
          '${time == null ? '所选备份' : '${backupDateLabel(time, includeYear: true)} 的备份'}\n'
          '来自 ${currentJob.descriptor?.deviceName ?? '来源未提供'} · '
          '${summary.roleCount} 个角色 · ${summary.originalFileCount} 个文件'
          '${preview.limitedIntegrity ? '\n\n备份缺少历史内容摘要，已完成可用的结构与文件检查。' : ''}'
          '${preview.currentUnreadable ? '\n本机资料暂时无法读取，无法统计当前范围。' : ''}',
      consequence: '本机现有的角色资料、设定历史、立绘和资产将被替换。恢复后无法撤销。',
      confirmLabel: '确认恢复',
      cancelLabel: '暂不恢复',
      showSparkle: false,
    );
    if (confirmed && mounted) {
      await _coordinator.confirmRestore(job.operationId);
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
          title: source == null ? '本次资料目录' : '备份详情',
          descriptor: source?.descriptor,
          coordinator: source == null ? null : _coordinator,
          onReviewRestore: _reviewRestore,
          onCancelJob: _cancelJob,
          loadContents: contents != null
              ? () async => contents
              : () => _coordinator.contentsFor(source!),
          onPrepareRestore: source == null || _running
              ? null
              : () async {
                  if (_running || _actionBusy) {
                    throw const BackupFailure('busy', '已有操作进行中，请先完成或取消');
                  }
                  await _coordinator.prepareRestore(source);
                },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    final secondary = backupSecondaryColor(context);
    final recoveryOnly = _coordinator.storage.isRecoveryOnly;
    final job = _job;
    final showJob =
        job != null &&
        job.operationId != _dismissedJobId &&
        job.phase != BackupPhase.completed &&
        job.phase != BackupPhase.cancelled;
    final cleanupPending =
        (job?.cleanupPending ?? false) ||
        _coordinator.storage.cleanupPending ||
        (_history?.retiredCount ?? 0) > 0;
    return PopScope(
      canPop: !_switching && !recoveryOnly,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            '备份与恢复',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          centerTitle: true,
          automaticallyImplyLeading: !_switching && !recoveryOnly,
          actions: [
            IconButton(
              tooltip: '刷新云端备份',
              onPressed: _loading || _running || _actionBusy ? null : _reload,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: BackupBody(
          controller: _scrollController,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Icon(
                Icons.cloud_upload_outlined,
                size: 38,
                color: tokens.accent,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '备份到 iCloud',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            if (_coordinator.recoveryNotice != null)
              BackupDisclosure(
                title: '查看上次操作说明',
                children: [BackupNotice(_coordinator.recoveryNotice!.message)],
              ),
            if (recoveryOnly) ...[
              const BackupNotice(
                '本机资料暂时无法打开，可以选择一份云端备份恢复。',
                icon: Icons.shield_outlined,
              ),
              StorageErrorDetails(error: _coordinator.storage.recoveryError),
            ],
            if (showJob)
              BackupJobPanel(
                key: ValueKey(job.operationId),
                job: job,
                onCancel: _actionBusy ? null : () => _cancelJob(job),
                onRetry: _actionBusy
                    ? null
                    : () => _perform(() => _coordinator.retry(job.operationId)),
                onReview: _actionBusy ? null : () => _reviewRestore(job),
              ),
            if (_actionError != null)
              BackupNotice(_actionError!, icon: Icons.error_outline),
            if (!showJob && !recoveryOnly) ...[
              if (_localError != null)
                BackupNotice(_localError!, icon: Icons.error_outline),
              if (_cloudError != null)
                BackupNotice(_cloudError!, icon: Icons.cloud_off_outlined),
              if (_localError != null || _cloudError != null)
                OutlinedButton(
                  onPressed: _loading ? null : _reload,
                  child: const Text('重新检查'),
                )
              else
                FilledButton(
                  key: const Key('backup-start'),
                  style: backupPrimaryStyle(context),
                  onPressed:
                      _actionBusy ||
                          _current == null ||
                          _history == null ||
                          !(_availability?.available ?? false)
                      ? null
                      : _startBackup,
                  child: Text(
                    _loading && _current == null ? '正在准备资料…' : '立即备份',
                  ),
                ),
            ],
            if (showJob && !job.canRetry && job.isTerminal && !recoveryOnly)
              TextButton(
                onPressed: _actionBusy
                    ? null
                    : () {
                        setState(() => _dismissedJobId = job.operationId);
                        unawaited(_reload());
                      },
                child: const Text('返回备份'),
              ),
            const SizedBox(height: 48),
            const Text(
              '云端备份',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (_cloudError != null && _history != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '暂显示上次读取的备份',
                  style: TextStyle(fontSize: 13, color: secondary),
                ),
              ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: LinearProgressIndicator(),
              ),
            if (!_loading && _history == null) ...[
              const Divider(height: 1),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('暂时无法读取备份列表'),
              ),
              if (recoveryOnly || showJob)
                TextButton(
                  onPressed: _running || _actionBusy ? null : _reload,
                  child: const Text('重新读取备份列表'),
                ),
            ],
            if (!_loading &&
                _history != null &&
                _history!.snapshots.isEmpty) ...[
              const Divider(height: 1),
              const SizedBox(height: 24),
              const Text('还没有云端备份', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 24),
              const Divider(height: 1),
            ],
            for (final backup
                in _history?.snapshots ?? const <BackupDescriptor>[]) ...[
              const Divider(height: 1),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                title: Text(
                  backupDateLabel(
                    backup.createdAtUtc,
                    includeYear:
                        backup.createdAtUtc.toLocal().year !=
                        DateTime.now().year,
                  ),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${backup.deviceName} · ${backupBytes(backup.totalBytes)}',
                    style: TextStyle(fontSize: 13, color: secondary),
                  ),
                ),
                trailing: Icon(Icons.chevron_right, color: secondary, size: 20),
                onTap: _switching
                    ? null
                    : () =>
                          _openContents(source: BackupSource.snapshot(backup)),
              ),
            ],
            if (_history?.snapshots.isNotEmpty ?? false)
              const Divider(height: 1),
            const SizedBox(height: 16),
            if (cleanupPending)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const Key('backup-retry-cleanup'),
                  onPressed: _running || _actionBusy
                      ? null
                      : () => _perform(_coordinator.retryCleanup),
                  child: const Text('重试空间清理'),
                ),
              ),
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
