import 'dart:ui' as ui show ImageFilter;

import 'package:flutter/material.dart';

import '../../theme/zaidang_spacing.dart';
import '../../theme/zaidang_tokens.dart';

/// 头图上玻璃按钮的边长，也是编辑页顶部工具栏的高度。
const double glassButtonSize = 44;

/// 压在头图上的圆形玻璃按钮：有立绘时更透，露出图；纸面时更实，保住对比。
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.iconSize,
    required this.tooltip,
    required this.onPhoto,
    required this.onTap,
  });

  final IconData icon;
  final double iconSize;
  final String tooltip;
  final bool onPhoto;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    final fillAlpha = onPhoto ? 0.34 : 0.72;
    return Tooltip(
      message: tooltip,
      child: ClipOval(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Material(
            color: tokens.ink.withValues(alpha: fillAlpha),
            shape: CircleBorder(
              side: BorderSide(
                color: ZaidangTokens.light.surface.withValues(alpha: 0.18),
              ),
            ),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox.square(
                dimension: glassButtonSize,
                child: Icon(
                  icon,
                  size: iconSize,
                  color: onTap == null
                      ? ZaidangTokens.light.surface.withValues(alpha: 0.5)
                      : ZaidangTokens.light.surface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 头图右上的火漆红实心药丸「保存」：主操作用 accent + onAccent，不可用时降透明度。
/// 实心底在立绘与纸面上都够对比，所以不像 [GlassIconButton] 那样区分 onPhoto。
class GlassSaveButton extends StatelessWidget {
  const GlassSaveButton({
    super.key,
    required this.saving,
    required this.onPressed,
  });

  final bool saving;
  final VoidCallback? onPressed;

  /// 不可用 / 保存中时的填充透明度。
  static const double _disabledFillAlpha = 0.55;

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    final enabled = !saving && onPressed != null;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: enabled
            ? tokens.accent
            : tokens.accent.withValues(alpha: _disabledFillAlpha),
        shape: StadiumBorder(
          side: BorderSide(
            color: ZaidangTokens.light.surface.withValues(alpha: 0.18),
          ),
        ),
      ),
      child: TextButton(
        onPressed: saving ? null : onPressed,
        style: TextButton.styleFrom(
          foregroundColor: tokens.onAccent,
          disabledForegroundColor: tokens.onAccent,
          overlayColor: tokens.onAccent,
          shape: const StadiumBorder(),
          minimumSize: const Size(44, glassButtonSize),
          padding: const EdgeInsets.symmetric(horizontal: ZaidangSpacing.lg),
        ),
        child: saving
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: tokens.onAccent,
                    ),
                  ),
                  const SizedBox(width: ZaidangSpacing.sm),
                  const Text('保存中…'),
                ],
              )
            : const Text('保存'),
      ),
    );
  }
}
