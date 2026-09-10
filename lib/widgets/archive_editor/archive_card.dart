import 'package:flutter/material.dart';

import '../../theme/zaidang_tokens.dart';

/// 档案编辑页的表单栏上限。hero 全宽铺顶，不跟这个宽度走。
const double archiveEditorContentMaxWidth = 440;

/// 卡片相对表单栏的左右留白。
const double archiveEditorCardInset = 20;

/// 档案分组：纸面填充 + 描边，圆角与输入框一致。
class ArchiveCard extends StatelessWidget {
  const ArchiveCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    return DecoratedBox(
      decoration: archiveCardDecoration(tokens),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: child,
      ),
    );
  }
}

BoxDecoration archiveCardDecoration(ZaidangTokens tokens) => BoxDecoration(
  color: tokens.surface,
  borderRadius: BorderRadius.circular(8),
  border: Border.all(color: tokens.border),
);

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          color: tokens.inkSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class FieldRow extends StatelessWidget {
  const FieldRow({super.key, required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }
}

/// 表单栏左右内边距：卡片留白 + 宽屏时把内容居中到 [archiveEditorContentMaxWidth]。
double archiveEditorHorizontalPadding(BuildContext context) {
  final overflow =
      (MediaQuery.sizeOf(context).width - archiveEditorContentMaxWidth).clamp(
        0,
        double.infinity,
      );
  return archiveEditorCardInset + overflow / 2;
}
