import 'dart:async';

import 'package:flutter/material.dart';

import '../../../theme/zaidang_tokens.dart';
import '../backup_models.dart';
import 'backup_shared.dart';

/// Only actionable job state belongs on the page. Journals retain diagnostics.
class BackupJobPanel extends StatefulWidget {
  const BackupJobPanel({
    super.key,
    required this.job,
    this.onCancel,
    this.onRetry,
    this.onReview,
    this.onContents,
    this.onViewBackup,
  });
  final BackupJobState job;
  final VoidCallback? onCancel, onRetry, onReview, onContents, onViewBackup;

  @override
  State<BackupJobPanel> createState() => _BackupJobPanelState();
}

class _BackupJobPanelState extends State<BackupJobPanel> {
  Timer? _timer;
  DateTime _lastProgress = DateTime.now();
  bool get _slow => DateTime.now().difference(_lastProgress).inSeconds >= 60;

  @override
  void initState() {
    super.initState();
    _watchProgress();
  }

  @override
  void didUpdateWidget(BackupJobPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = oldWidget.job, after = widget.job;
    if (before.operationId != after.operationId ||
        before.phase != after.phase ||
        before.currentItem != after.currentItem ||
        before.completedBytes != after.completedBytes ||
        before.completedFiles != after.completedFiles) {
      _lastProgress = DateTime.now();
    }
    _watchProgress();
  }

  void _watchProgress() {
    if (widget.job.isTerminal || widget.job.requiresConfirmation) {
      _timer?.cancel();
      _timer = null;
    } else {
      _timer ??= Timer.periodic(const Duration(seconds: 15), (_) {
        if (mounted && _slow) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    if (job.phase == BackupPhase.completed ||
        job.phase == BackupPhase.cancelled) {
      return const SizedBox.shrink();
    }
    final tokens = ZaidangTokens.of(context);
    final backup = job.kind == BackupJobKind.backup;
    final failed =
        job.phase == BackupPhase.failed || job.phase == BackupPhase.interrupted;
    final label = failed
        ? job.kind == BackupJobKind.cleanup
              ? '空间清理未完成'
              : backup
              ? '这次备份未完成'
              : '这次恢复未完成'
        : _slow && !job.requiresConfirmation
        ? switch (job.kind) {
            BackupJobKind.backup => '备份耗时较长',
            BackupJobKind.restore => '恢复耗时较长',
            BackupJobKind.cleanup => '空间清理耗时较长',
          }
        : switch (job.phase) {
            BackupPhase.waitingForCloud || BackupPhase.publishing => '正在确认云端备份',
            BackupPhase.readyForReview => '备份已通过检查',
            BackupPhase.activating => '正在恢复资料',
            _ =>
              job.kind == BackupJobKind.cleanup
                  ? '正在清理旧文件'
                  : backup
                  ? '正在备份'
                  : '正在下载并检查',
          };
    final String? description = failed
        ? job.error?.message ?? '请重试'
        : job.phase == BackupPhase.activating
        ? '请保持 App 打开'
        : null;
    final measured = const {
      BackupPhase.hashing,
      BackupPhase.staging,
      BackupPhase.uploading,
      BackupPhase.downloading,
    }.contains(job.phase);
    final total = job.totalBytes, done = job.completedBytes;
    final fraction = measured && total != null && total > 0 && done != null
        ? (done / total).clamp(0.0, 1.0)
        : null;
    return Container(
      key: const Key('backup-job-panel'),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border.symmetric(horizontal: BorderSide(color: tokens.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              label,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                color: backupSecondaryColor(context),
              ),
            ),
          ],
          if (!job.isTerminal && !job.requiresConfirmation) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(
              key: const Key('backup-stage-progress'),
              value: fraction,
              semanticsLabel: job.currentItem == null ? '本阶段进度' : '当前文件进度',
              semanticsValue: fraction == null
                  ? '进度暂不可测量'
                  : '${(fraction * 100).floor()}%',
            ),
            if (fraction != null) ...[
              const SizedBox(height: 8),
              Text(
                '${job.currentItem == null ? '本阶段' : '当前文件'} ${backupBytes(done)} / ${backupBytes(total)}',
                style: TextStyle(
                  fontSize: 12,
                  color: backupSecondaryColor(context),
                ),
              ),
            ],
          ],
          if (failed || _slow)
            BackupDisclosure(
              key: ValueKey('${job.operationId}-details'),
              title: failed ? '查看原因' : '查看当前状态',
              children: [
                BackupKeyValue(
                  '当前步骤',
                  backupPhaseLabel(job.failedAtPhase ?? job.phase),
                ),
                if (job.currentItem?.isNotEmpty ?? false)
                  Text(job.currentItem!),
              ],
            ),
          if (job.requiresConfirmation || job.canRetry || job.canCancel)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 16,
                runSpacing: 8,
                children: [
                  if (job.canCancel)
                    TextButton(
                      key: const Key('backup-cancel-job'),
                      onPressed: widget.onCancel,
                      style: TextButton.styleFrom(foregroundColor: tokens.ink),
                      child: Text(
                        job.requiresConfirmation
                            ? '放弃恢复'
                            : backup
                            ? '取消备份'
                            : '取消',
                      ),
                    ),
                  if (job.canRetry)
                    TextButton(
                      key: const Key('backup-retry-job'),
                      onPressed: widget.onRetry,
                      style: TextButton.styleFrom(foregroundColor: tokens.ink),
                      child: Text(
                        job.kind == BackupJobKind.cleanup
                            ? '重试清理'
                            : backup
                            ? '重试备份'
                            : '重试恢复',
                      ),
                    ),
                  if (job.requiresConfirmation)
                    TextButton(
                      key: const Key('backup-review-restore'),
                      onPressed: widget.onReview,
                      style: TextButton.styleFrom(foregroundColor: tokens.ink),
                      child: const Text('继续恢复'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
