import 'package:flutter/material.dart';

import '../../theme/zaidang_radius.dart';
import '../../theme/zaidang_spacing.dart';
import '../../theme/zaidang_tokens.dart';
import '../../theme/zaidang_type.dart';

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

/// 分区卡头：火漆红淡底小方块内的图标 + 标题，右侧可放一句说明或按钮。
class ArchiveCardHeader extends StatelessWidget {
  const ArchiveCardHeader({
    super.key,
    required this.icon,
    required this.title,
    this.caption,
    this.trailing,
  });

  final IconData icon;
  final String title;

  /// 标题右侧的一句说明；与 [trailing] 同时给时说明排在按钮前。
  final String? caption;
  final Widget? trailing;

  /// 图标底块边长与图标尺寸。
  static const double _iconBoxSize = 32;
  static const double _iconSize = 18;

  /// 淡底用主色 10% 透明度，与成功反馈的勾选底一致。
  static const double _iconTintAlpha = 0.1;

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    final type = ZaidangType.of(context);
    final caption = this.caption;
    final hasCaption = caption != null && caption.isNotEmpty;
    final titleText = Text(
      title,
      style: type.subheading,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: ZaidangSpacing.md),
      child: Row(
        children: [
          ExcludeSemantics(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tokens.accent.withValues(alpha: _iconTintAlpha),
                borderRadius: ZaidangRadius.smAll,
              ),
              child: SizedBox.square(
                dimension: _iconBoxSize,
                child: Icon(icon, size: _iconSize, color: tokens.accent),
              ),
            ),
          ),
          const SizedBox(width: ZaidangSpacing.sm),
          // 标题是定长短词，不参与伸缩；说明独占剩余宽度才能真正贴右。
          // 两者都 flex 的话，Flexible 用不完的份额会堆在行尾，说明就悬在中间。
          if (hasCaption) ...[
            titleText,
            const SizedBox(width: ZaidangSpacing.sm),
            Expanded(
              child: Text(
                caption,
                style: type.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
              ),
            ),
          ] else
            Expanded(child: titleText),
          if (trailing != null) ...[
            const SizedBox(width: ZaidangSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// 字段格：纸色底、顶行小图标 + 标签、下方放输入框或可点的值。
///
/// 子输入框聚焦时描边变主色；描边宽度恒为 1，只换颜色，布局不抖。
class ArchiveFieldCell extends StatefulWidget {
  const ArchiveFieldCell({
    super.key,
    required this.icon,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final String label;
  final Widget child;

  static const double _iconSize = 16;

  @override
  State<ArchiveFieldCell> createState() => _ArchiveFieldCellState();
}

class _ArchiveFieldCellState extends State<ArchiveFieldCell> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) {
        if (focused != _focused) {
          setState(() => _focused = focused);
        }
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.bg,
          borderRadius: ZaidangRadius.smAll,
          border: Border.all(color: _focused ? tokens.accent : tokens.bg),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            ZaidangSpacing.md,
            ZaidangSpacing.sm,
            ZaidangSpacing.md,
            ZaidangSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      widget.icon,
                      size: ArchiveFieldCell._iconSize,
                      color: tokens.accent,
                    ),
                  ),
                  const SizedBox(width: ZaidangSpacing.xs),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: ZaidangType.of(context).micro,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              widget.child,
            ],
          ),
        ),
      ),
    );
  }
}

/// [ArchiveFieldCell] 内嵌输入框的装饰：无边框、无填充，格子本身负责底色与聚焦描边；
/// 校验失败时只在值下方画一条墨色线并显示错误文案。
InputDecoration archiveCellInputDecoration(
  BuildContext context, {
  required String hint,
}) {
  final tokens = ZaidangTokens.of(context);
  const quiet = UnderlineInputBorder(borderSide: BorderSide.none);
  final error = UnderlineInputBorder(borderSide: BorderSide(color: tokens.ink));
  return InputDecoration(
    hintText: hint,
    filled: false,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(vertical: ZaidangSpacing.xs),
    border: quiet,
    enabledBorder: quiet,
    focusedBorder: quiet,
    disabledBorder: quiet,
    errorBorder: error,
    focusedErrorBorder: error,
  );
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
