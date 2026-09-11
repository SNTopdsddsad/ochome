import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'zaidang_tokens.dart';

/// 无 AppBar 页面的系统栏样式：状态栏透明、图标随背景明暗切换，
/// 底部系统导航栏始终跟随纸面 `bg`。
///
/// [onDarkBackdrop] 为 true 表示状态栏压在深色内容（如立绘 / 封面）上，
/// 图标用浅色；深色主题下无论背景如何都用浅色图标。
SystemUiOverlayStyle zaidangSystemUiOverlayStyle(
  BuildContext context, {
  bool onDarkBackdrop = false,
}) {
  final tokens = ZaidangTokens.of(context);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final base = (onDarkBackdrop || isDark)
      ? SystemUiOverlayStyle.light
      : SystemUiOverlayStyle.dark;
  return base.copyWith(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: tokens.bg,
    systemNavigationBarIconBrightness: isDark
        ? Brightness.light
        : Brightness.dark,
  );
}
