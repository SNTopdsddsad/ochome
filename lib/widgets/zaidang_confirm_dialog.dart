import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/zaidang_tokens.dart';

/// 显示创作便笺确认框。只有明确点击主操作才返回 true。
Future<bool> showZaidangConfirmDialog({
  required BuildContext context,
  required String title,
  required String body,
  required String consequence,
  required String confirmLabel,
  String cancelLabel = '取消',
  String? cancelSemanticLabel,
  bool showSparkle = true,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    requestFocus: true,
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
    animationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : const AnimationStyle(duration: Duration(milliseconds: 180)),
    builder: (context) => ZaidangConfirmDialog(
      title: title,
      body: body,
      consequence: consequence,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      cancelSemanticLabel: cancelSemanticLabel,
      showSparkle: showSparkle,
    ),
  );
  return confirmed ?? false;
}

/// 可独立用于 [showDialog] 的创作便笺；业务操作由调用方在确认后执行。
class ZaidangConfirmDialog extends StatefulWidget {
  const ZaidangConfirmDialog({
    super.key,
    required this.title,
    required this.body,
    required this.consequence,
    required this.confirmLabel,
    this.cancelLabel = '取消',
    this.cancelSemanticLabel,
    this.showSparkle = true,
  });

  final String title;
  final String body;
  final String consequence;
  final String confirmLabel;
  final String cancelLabel;
  final String? cancelSemanticLabel;
  final bool showSparkle;

  @override
  State<ZaidangConfirmDialog> createState() => _ZaidangConfirmDialogState();
}

class _ZaidangConfirmDialogState extends State<ZaidangConfirmDialog> {
  bool _resolved = false;

  void _resolve(bool confirmed) {
    // A second tap during the exit transition must not pop the caller's page.
    if (_resolved || ModalRoute.of(context)?.isCurrent == false) return;
    _resolved = true;
    Navigator.of(context).pop<bool>(confirmed);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    final theme = Theme.of(context);
    final bodyStyle = theme.textTheme.bodyMedium!.copyWith(
      color: tokens.ink,
      fontSize: 15,
      fontWeight: FontWeight.w400,
      height: 1.8,
      letterSpacing: 0,
    );
    final actionStyle = theme.textTheme.labelLarge!.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      height: 1.5,
      letterSpacing: 0,
    );
    final inset = MediaQuery.sizeOf(context).width < 320 ? 16.0 : 24.0;

    return Dialog(
      key: const Key('zaidang-confirm-dialog'),
      backgroundColor: tokens.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 4,
      shadowColor: theme.colorScheme.shadow.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: BorderSide(color: tokens.border),
      ),
      constraints: const BoxConstraints(maxWidth: 380),
      insetPadding: EdgeInsets.all(inset),
      insetAnimationDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 100),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 380,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final padding = constraints.maxWidth < 300 ? 20.0 : 24.0;
            final contentWidth = math.max(
              1.0,
              constraints.maxWidth - padding * 2,
            );
            final textScaler = MediaQuery.textScalerOf(context);
            final direction = Directionality.of(context);

            Size labelSize(String label, double width) {
              final painter = TextPainter(
                text: TextSpan(text: label, style: actionStyle),
                textDirection: direction,
                textScaler: textScaler,
              )..layout(maxWidth: math.max(1.0, width));
              final size = painter.size;
              painter.dispose();
              return size;
            }

            final halfLabelWidth = (contentWidth - 12) / 2 - 24;
            final stackActions =
                labelSize(widget.cancelLabel, double.infinity).width >
                    halfLabelWidth ||
                labelSize(widget.confirmLabel, double.infinity).width >
                    halfLabelWidth;
            final buttonWidth = stackActions
                ? contentWidth
                : (contentWidth - 12) / 2;
            double buttonHeight(String label) =>
                math.max(48, labelSize(label, buttonWidth - 24).height + 24);
            final cancelHeight = buttonHeight(widget.cancelLabel);
            final confirmHeight = buttonHeight(widget.confirmLabel);
            final actionsHeight = stackActions
                ? cancelHeight + confirmHeight + 12
                : math.max(cancelHeight, confirmHeight);
            final actions = _buildActions(
              tokens,
              actionStyle,
              stackActions: stackActions,
            );
            final content = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NotebookMark(showSparkle: widget.showSparkle),
                const SizedBox(height: 22),
                Semantics(
                  namesRoute: true,
                  header: true,
                  child: Text(
                    widget.title,
                    style: theme.textTheme.titleLarge!.copyWith(
                      color: tokens.ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(widget.body, style: bodyStyle),
                const SizedBox(height: 8),
                Text(widget.consequence, style: bodyStyle),
              ],
            );

            // Keep actions visible with long copy. On exceptionally short
            // windows or huge button labels, let the whole sheet scroll so
            // neither the text nor the actions are clipped or unreachable.
            final scrollWholeSheet =
                constraints.maxHeight < actionsHeight + padding * 2 + 126;
            if (scrollWholeSheet) {
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(padding, 28, padding, padding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [content, const SizedBox(height: 26), actions],
                ),
              );
            }
            return Padding(
              // The rotated notebook extends above and to the left of its
              // layout box. Put those gutters inside the scroll viewport.
              padding: EdgeInsets.fromLTRB(
                padding - 4,
                18,
                padding - 4,
                padding,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                      child: content,
                    ),
                  ),
                  const SizedBox(height: 26),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: actions,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildActions(
    ZaidangTokens tokens,
    TextStyle textStyle, {
    required bool stackActions,
  }) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(15),
    );
    final cancel = TextButton(
      key: const Key('zaidang-confirm-cancel'),
      autofocus: true,
      onPressed: () => _resolve(false),
      style: TextButton.styleFrom(
        foregroundColor: tokens.ink,
        backgroundColor: tokens.bg,
        side: BorderSide(color: tokens.border),
        shape: shape,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.all(12),
        visualDensity: VisualDensity.standard,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: textStyle,
      ),
      child: Text(
        widget.cancelLabel,
        semanticsLabel: widget.cancelSemanticLabel,
        textAlign: TextAlign.center,
      ),
    );
    final confirm = FilledButton(
      key: const Key('zaidang-confirm-action'),
      onPressed: () => _resolve(true),
      style: FilledButton.styleFrom(
        foregroundColor: tokens.surface,
        backgroundColor: tokens.ink,
        shape: shape,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.all(12),
        visualDensity: VisualDensity.standard,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: textStyle,
      ),
      child: Text(widget.confirmLabel, textAlign: TextAlign.center),
    );
    if (stackActions) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [cancel, const SizedBox(height: 12), confirm],
      );
    }
    return Row(
      children: [
        Expanded(child: cancel),
        const SizedBox(width: 12),
        Expanded(child: confirm),
      ],
    );
  }
}

class _NotebookMark extends StatelessWidget {
  const _NotebookMark({required this.showSparkle});

  final bool showSparkle;

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    return ExcludeSemantics(
      child: Transform.rotate(
        angle: -math.pi / 30,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              key: const Key('zaidang-confirm-notebook'),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: tokens.bg,
                border: Border.all(color: tokens.border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.edit_note_rounded, color: tokens.ink, size: 26),
            ),
            if (showSparkle)
              Positioned(
                top: -7,
                right: -7,
                child: Container(
                  key: const Key('zaidang-confirm-sparkle'),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: tokens.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_awesome_outlined,
                    color: tokens.accent,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
