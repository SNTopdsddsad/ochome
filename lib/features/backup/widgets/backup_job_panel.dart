import 'package:flutter/material.dart';

import '../../../theme/zaidang_tokens.dart';
import '../backup_models.dart';
import 'backup_shared.dart';

class BackupJobPanel extends StatelessWidget {
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

  bool get _backup => job.kind == BackupJobKind.backup;

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    final completed = job.phase == BackupPhase.completed;
    final label = completed
        ? (_backup
              ? '这份备份已完成'
              : job.kind == BackupJobKind.cleanup
              ? '清理已完成'
              : '已恢复这份资料')
        : backupPhaseLabel(job.phase);
    final measured = const {
      BackupPhase.hashing,
      BackupPhase.staging,
      BackupPhase.uploading,
      BackupPhase.downloading,
    }.contains(job.phase);
    final total = job.totalBytes;
    final done = job.completedBytes;
    final fraction = measured && total != null && total > 0 && done != null
        ? (done / total).clamp(0.0, 1.0)
        : null;
    return BackupPaperCard(
      key: const Key('backup-job-panel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              label,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_backup ? '备份' : '操作'}开始：${backupTime(job.startedAtUtc)}',
            style: TextStyle(color: tokens.inkSecondary, fontSize: 12),
          ),
          if (job.contentCreatedAtUtc != null)
            Text(
              '备份内容时间：${backupTime(job.contentCreatedAtUtc)}',
              style: TextStyle(color: tokens.inkSecondary, fontSize: 12),
            ),
          if (job.completedAtUtc != null)
            BackupKeyValue('本次完成时间', backupTime(job.completedAtUtc)),
          if (job.descriptor != null)
            BackupKeyValue('来源设备', job.descriptor!.deviceName),
          if (!job.isTerminal && !job.requiresConfirmation) ...[
            const SizedBox(height: 18),
            LinearProgressIndicator(
              key: const Key('backup-stage-progress'),
              value: fraction,
              semanticsLabel: job.currentItem == null ? '本阶段进度' : '当前文件进度',
              semanticsValue: fraction == null
                  ? '进度暂不可测量'
                  : '${(fraction * 100).floor()}%',
            ),
            const SizedBox(height: 8),
            if (fraction != null)
              Text(
                '${job.currentItem == null ? '本阶段' : '当前文件'} ${backupBytes(done)} / ${backupBytes(total)}',
                style: TextStyle(color: tokens.inkSecondary, fontSize: 12),
              )
            else
              Text(
                job.phase == BackupPhase.waitingForCloud
                    ? '正在等待 iCloud 确认文件上传，暂时无法计算进度。'
                    : job.phase == BackupPhase.publishing
                    ? '文件上传已确认，正在完成这份备份。'
                    : '正在处理，请稍候。',
                style: TextStyle(color: tokens.inkSecondary, fontSize: 12),
              ),
          ],
          if (job.completedFiles != null && job.totalFiles != null)
            BackupKeyValue(
              job.phase == BackupPhase.waitingForCloud ? '已确认上传项目' : '本阶段已处理项目',
              '${job.completedFiles} / ${job.totalFiles} 份',
            ),
          if (job.failedAtPhase != null && job.error != null)
            BackupKeyValue('停止阶段', backupPhaseLabel(job.failedAtPhase!)),
          const SizedBox(height: 16),
          _BackupStages(job: job),
          if (job.currentItem != null && job.currentItem!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              job.error == null ? '当前文件' : '相关文件',
              style: TextStyle(color: tokens.inkSecondary, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(job.currentItem!),
          ],
          if (job.contents case final contents?) ...[
            const Divider(height: 26),
            BackupKeyValue(
              '完整范围',
              '${contents.summary.roleCount} 位角色 · ${contents.summary.originalFileCount} 份原文件',
            ),
            BackupKeyValue(
              '完整资料量',
              contents.summary.knownLogicalDataBytes == null
                  ? '总量待检查'
                  : backupBytes(contents.summary.knownLogicalDataBytes),
            ),
          ],
          if (_backup && job.uploadBytes != null)
            BackupKeyValue('本次需传输', backupBytes(job.uploadBytes)),
          if (_backup && (job.reusedFiles > 0 || job.uploadBytes != null))
            BackupKeyValue(
              '本次复用',
              '${job.reusedFiles} 份 · ${backupBytes(job.reusedBytes)}',
            ),
          if (job.error != null)
            BackupNotice(job.error!.message, icon: Icons.error_outline),
          if (job.cleanupPending)
            const BackupNotice('旧文件清理尚未完成，可能暂时多占空间。新的完整备份已保留。'),
          if (!job.isTerminal && job.phase != BackupPhase.activating)
            BackupNotice(
              _backup ? '可以离开页面，回来继续查看同一个任务。' : '现在只准备和检查资料，确认后才会替换本机内容。',
              icon: Icons.shield_outlined,
            ),
          if (job.phase == BackupPhase.activating)
            const BackupNotice('正在切换整套资料，暂时不能取消。', icon: Icons.shield_outlined),
          if (job.requiresConfirmation)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('backup-review-restore'),
                onPressed: onReview,
                style: OutlinedButton.styleFrom(
                  foregroundColor: tokens.ink,
                  side: BorderSide(color: tokens.border),
                ),
                child: const Text('查看并确认恢复'),
              ),
            ),
          if (job.canRetry)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('backup-retry-job'),
                onPressed: onRetry,
                child: const Text('重新检查并重试'),
              ),
            ),
          if (completed && job.descriptor != null && onViewBackup != null)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onViewBackup,
                child: const Text('查看这份备份'),
              ),
            ),
          if (onContents != null && job.contents != null)
            TextButton.icon(
              onPressed: onContents,
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('查看本次资料目录'),
            ),
          if (job.canCancel)
            TextButton(
              key: const Key('backup-cancel-job'),
              onPressed: onCancel,
              style: TextButton.styleFrom(foregroundColor: tokens.ink),
              child: const Text('取消本次操作'),
            ),
        ],
      ),
    );
  }
}

class _BackupStages extends StatelessWidget {
  const _BackupStages({required this.job});
  final BackupJobState job;
  @override
  Widget build(BuildContext context) {
    final backup = job.kind == BackupJobKind.backup;
    final local =
        job.kind == BackupJobKind.restorePrevious ||
        job.kind == BackupJobKind.cleanup;
    final labels = local
        ? ['检查本机副本', '处理本机资料', '完成']
        : backup
        ? ['整理资料', '准备原文件', '上传变化内容', '确认备份完成']
        : ['读取目录', '下载原文件', '检查与升级', '确认并恢复'];
    final phase = job.failedAtPhase ?? job.phase;
    final step = local
        ? switch (phase) {
            BackupPhase.completed => 3,
            BackupPhase.activating => 1,
            _ => 0,
          }
        : backup
        ? switch (phase) {
            BackupPhase.preparing || BackupPhase.readingContents => 0,
            BackupPhase.hashing || BackupPhase.staging => 1,
            BackupPhase.uploading || BackupPhase.waitingForCloud => 2,
            BackupPhase.publishing => 3,
            BackupPhase.completed => 4,
            _ => -1,
          }
        : switch (phase) {
            BackupPhase.preparing || BackupPhase.readingContents => 0,
            BackupPhase.downloading => 1,
            BackupPhase.validating => 2,
            BackupPhase.readyForReview || BackupPhase.activating => 3,
            BackupPhase.completed => 4,
            _ => -1,
          };
    if (step < 0) return const SizedBox.shrink();
    final tokens = ZaidangTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < labels.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(
                  index < step
                      ? Icons.check_circle_outline
                      : index == step
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: index == step ? tokens.accent : tokens.inkSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    labels[index],
                    style: TextStyle(
                      fontSize: 13,
                      color: index > step ? tokens.inkSecondary : tokens.ink,
                    ),
                  ),
                ),
                if (index < step)
                  Text(
                    '已完成',
                    style: TextStyle(fontSize: 11, color: tokens.inkSecondary),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
