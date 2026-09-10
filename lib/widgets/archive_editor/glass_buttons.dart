import 'dart:ui' as ui show ImageFilter;

import 'package:flutter/material.dart';

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

class GlassSaveButton extends StatelessWidget {
  const GlassSaveButton({
    super.key,
    required this.saving,
    required this.onPhoto,
    required this.onPressed,
  });

  final bool saving;
  final bool onPhoto;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    final fillAlpha = onPhoto ? 0.34 : 0.72;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.ink.withValues(alpha: fillAlpha),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: ZaidangTokens.light.surface.withValues(alpha: 0.18),
            ),
          ),
          child: TextButton(
            onPressed: saving ? null : onPressed,
            style: TextButton.styleFrom(
              foregroundColor: tokens.accent,
              disabledForegroundColor: tokens.inkSecondary,
              minimumSize: const Size(44, glassButtonSize),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: saving
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('保存中…'),
                    ],
                  )
                : const Text('保存'),
          ),
        ),
      ),
    );
  }
}
