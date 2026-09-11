import 'package:flutter/material.dart';

import '../../theme/zaidang_radius.dart';
import '../../theme/zaidang_spacing.dart';
import '../../theme/zaidang_tokens.dart';

/// 档案编辑页的表单栏上限。hero 全宽铺顶，不跟这个宽度走。
const double archiveEditorContentMaxWidth = 440;

/// 卡片相对表单栏的左右留白。
const double archiveEditorCardInset = ZaidangSpacing.page;

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
        padding: const EdgeInsets.all(ZaidangSpacing.card),
        child: child,
      ),
    );
  }
}

BoxDecoration archiveCardDecoration(ZaidangTokens tokens) => BoxDecoration(
  color: tokens.surface,
  borderRadius: ZaidangRadius.smAll,
  border: Border.all(color: tokens.border),
);

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
        const SizedBox(width: ZaidangSpacing.md),
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
