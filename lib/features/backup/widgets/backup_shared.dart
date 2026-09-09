import 'package:flutter/material.dart';

import '../../../theme/zaidang_tokens.dart';
import '../backup_models.dart';
import '../backup_protocol.dart';

/// Page-local readable secondary ink; the global app palette stays unchanged.
Color backupSecondaryColor(BuildContext context) {
  final tokens = ZaidangTokens.of(context);
  return Theme.of(context).brightness == Brightness.dark
      ? tokens.inkSecondary
      : Color.lerp(tokens.inkSecondary, tokens.ink, .28)!;
}

String backupDateLabel(DateTime time, {bool includeYear = false}) {
  final local = time.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${includeYear ? '${local.year} 年 ' : ''}'
      '${local.month} 月 ${local.day} 日 ${two(local.hour)}:${two(local.minute)}';
}

ButtonStyle backupPrimaryStyle(BuildContext context) => FilledButton.styleFrom(
  minimumSize: const Size(double.infinity, 52),
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
);

class BackupDisclosure extends StatefulWidget {
  const BackupDisclosure({
    super.key,
    required this.title,
    required this.children,
  });
  final String title;
  final List<Widget> children;
  @override
  State<BackupDisclosure> createState() => _BackupDisclosureState();
}

class _BackupDisclosureState extends State<BackupDisclosure> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          expanded: _expanded,
          child: TextButton.icon(
            onPressed: () => setState(() => _expanded = !_expanded),
            style: TextButton.styleFrom(
              foregroundColor: backupSecondaryColor(context),
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            icon: Icon(_expanded ? Icons.remove : Icons.add, size: 18),
            label: Text(widget.title, style: const TextStyle(fontSize: 13)),
          ),
        ),
      ),
      if (_expanded) ...widget.children,
    ],
  );
}

String backupBytes(int? bytes) {
  if (bytes == null) return '正在计算';
  if (bytes < 1000) return '$bytes B';
  if (bytes < 1000000) return '${(bytes / 1000).toStringAsFixed(1)} KB';
  if (bytes < 1000000000) {
    return '${(bytes / 1000000).toStringAsFixed(bytes < 10000000 ? 1 : 0)} MB';
  }
  return '${(bytes / 1000000000).toStringAsFixed(2)} GB';
}

String backupTime(DateTime? time) {
  if (time == null) return '未提供';
  final local = time.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}/${two(local.month)}/${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

String backupPhaseLabel(BackupPhase phase) => switch (phase) {
  BackupPhase.preparing => '正在整理已保存资料',
  BackupPhase.hashing => '正在检查文件摘要',
  BackupPhase.staging => '正在准备原始文件',
  BackupPhase.uploading => '正在上传变化内容',
  BackupPhase.waitingForCloud => '等待 iCloud 上传确认',
  BackupPhase.publishing => '正在确认备份完成',
  BackupPhase.readingContents => '正在读取备份目录',
  BackupPhase.downloading => '正在下载原始文件',
  BackupPhase.validating => '正在检查与升级资料',
  BackupPhase.readyForReview => '备份已检查完整，等待你确认',
  BackupPhase.activating => '正在替换本机资料',
  BackupPhase.completed => '已完成',
  BackupPhase.failed => '操作未完成',
  BackupPhase.cancelled => '已取消',
  BackupPhase.interrupted => '上次操作需要继续处理',
};

String backupErrorMessage(Object error) =>
    error is BackupFailure ? error.message : '暂时无法完成操作，请稍后重试。';

String backupKindLabel(String kind) => switch (kind) {
  'cover' => '立绘',
  'image' => '图片',
  'video' => '视频',
  'audio' => '音频',
  _ => '文档',
};

IconData backupKindIcon(String kind) => switch (kind) {
  'cover' => Icons.portrait_outlined,
  'image' => Icons.image_outlined,
  'video' => Icons.movie_outlined,
  'audio' => Icons.graphic_eq,
  _ => Icons.description_outlined,
};

class BackupPaperCard extends StatelessWidget {
  const BackupPaperCard({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tokens.border),
      ),
      child: child,
    );
  }
}

class BackupKeyValue extends StatelessWidget {
  const BackupKeyValue(this.label, this.value, {super.key});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: TextStyle(color: backupSecondaryColor(context)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(flex: 6, child: Text(value, textAlign: TextAlign.end)),
      ],
    ),
  );
}

class BackupNotice extends StatelessWidget {
  const BackupNotice(this.message, {super.key, this.icon = Icons.info_outline});
  final String message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: backupSecondaryColor(context)),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            message,
            style: TextStyle(color: backupSecondaryColor(context), height: 1.5),
          ),
        ),
      ],
    ),
  );
}

class BackupSummaryView extends StatelessWidget {
  const BackupSummaryView({
    super.key,
    required this.summary,
    this.title = '完整资料',
  });
  final SnapshotSummary summary;
  final String title;
  @override
  Widget build(BuildContext context) => BackupPaperCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Text(
          summary.knownLogicalDataBytes == null
              ? '总量待检查'
              : backupBytes(summary.knownLogicalDataBytes),
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w500),
        ),
        const Divider(height: 28),
        LayoutBuilder(
          builder: (context, constraints) {
            final labels = [
              ('${summary.roleCount}', '位角色'),
              ('${summary.revisionCount}', '版设定历史'),
              ('${summary.originalFileCount}', '份原文件'),
            ];
            return Wrap(
              spacing: 8,
              runSpacing: 12,
              children: [
                for (final pair in labels)
                  SizedBox(
                    width: MediaQuery.textScalerOf(context).scale(14) > 24
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 16) / 3,
                    child: Column(
                      children: [
                        Text(
                          pair.$1,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          pair.$2,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: backupSecondaryColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        Text(
          '含 ${summary.customAttributeCount} 项自定义属性、${summary.coverCount} 张立绘原图',
          style: TextStyle(fontSize: 12, color: backupSecondaryColor(context)),
        ),
      ],
    ),
  );
}

class BackupBody extends StatelessWidget {
  const BackupBody({super.key, required this.children, this.controller});
  final List<Widget> children;
  final ScrollController? controller;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final horizontal = constraints.maxWidth > 640
          ? (constraints.maxWidth - 600) / 2
          : 24.0;
      return ListView(
        controller: controller,
        padding: EdgeInsets.fromLTRB(
          horizontal,
          32,
          horizontal,
          MediaQuery.paddingOf(context).bottom + 24,
        ),
        children: children,
      );
    },
  );
}
