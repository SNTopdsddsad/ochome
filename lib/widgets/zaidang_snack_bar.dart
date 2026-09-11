import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/zaidang_spacing.dart';
import '../theme/zaidang_tokens.dart';
import '../theme/zaidang_type.dart';

enum ZaidangSnackBarTone { info, success, error }

/// 提示图标的圆形底座边长。
const double _markSize = 32;

/// 原生关闭按钮预留宽度，略大于实际值让估算偏保守。
const double _closeButtonReserve = 56;

/// 用原生消息队列展示悬浮便笺，保留关闭、计时和无障碍播报行为。
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showZaidangSnackBar(
  BuildContext context,
  String message, {
  ZaidangSnackBarTone tone = ZaidangSnackBarTone.info,
  Duration? duration,
}) {
  final messenger = ScaffoldMessenger.of(context);
  final media = MediaQuery.of(context);
  final availableWidth = media.size.width - media.padding.horizontal;
  final snackWidth = availableWidth >= 512
      ? 480.0
      : availableWidth - ZaidangSpacing.lg * 2;
  // Reserve the content padding, leading mark/gap and native close button.
  final messageWidth = math.max(
    1.0,
    snackWidth -
        (ZaidangSpacing.lg + ZaidangSpacing.sm) -
        (_markSize + ZaidangSpacing.md) -
        _closeButtonReserve,
  );
  final painter = TextPainter(
    text: TextSpan(text: message, style: _messageStyle(context)),
    textDirection: Directionality.of(context),
    textScaler: media.textScaler,
    locale: Localizations.maybeLocaleOf(context),
  )..layout(maxWidth: messageWidth);
  final needsScrolling = painter.height > _maxMessageHeight(media);
  painter.dispose();
  messenger.clearSnackBars();
  return messenger.showSnackBar(
    SnackBar(
      content: ZaidangSnackBarContent(message: message, tone: tone),
      behavior: SnackBarBehavior.floating,
      width: availableWidth >= 512 ? 480 : null,
      padding: const EdgeInsets.fromLTRB(
        ZaidangSpacing.lg,
        ZaidangSpacing.md,
        ZaidangSpacing.sm,
        ZaidangSpacing.md,
      ),
      showCloseIcon: true,
      persist: media.accessibleNavigation || needsScrolling,
      duration:
          duration ??
          Duration(seconds: tone == ZaidangSnackBarTone.error ? 5 : 4),
    ),
  );
}

TextStyle _messageStyle(BuildContext context) => ZaidangType.of(context).body;

double _maxMessageHeight(MediaQueryData media) {
  final usableHeight =
      media.size.height - media.viewInsets.bottom - media.padding.vertical;
  return math.max(28.0, math.min(180.0, usableHeight * 0.35));
}

/// 可复用于原生 [SnackBar] 的便笺正文；完整消息会换行，过长时可滚动。
class ZaidangSnackBarContent extends StatelessWidget {
  const ZaidangSnackBarContent({
    super.key,
    required this.message,
    this.tone = ZaidangSnackBarTone.info,
  });

  final String message;
  final ZaidangSnackBarTone tone;

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    final media = MediaQuery.of(context);
    final isSuccess = tone == ZaidangSnackBarTone.success;
    final icon = switch (tone) {
      ZaidangSnackBarTone.info => Icons.notes_rounded,
      ZaidangSnackBarTone.success => Icons.check_rounded,
      ZaidangSnackBarTone.error => Icons.error_outline_rounded,
    };

    return Row(
      key: const Key('zaidang-snack-content'),
      children: [
        ExcludeSemantics(
          child: Container(
            width: _markSize,
            height: _markSize,
            decoration: BoxDecoration(
              color: isSuccess
                  ? tokens.accent.withValues(alpha: 0.10)
                  : tokens.bg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              key: const Key('zaidang-snack-icon'),
              color: isSuccess ? tokens.accent : tokens.ink,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: ZaidangSpacing.md),
        Expanded(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: _maxMessageHeight(media)),
            child: SingleChildScrollView(
              child: Text(
                message,
                key: const Key('zaidang-snack-message'),
                style: _messageStyle(context),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
