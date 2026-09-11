import 'package:flutter/material.dart';

import 'zaidang_radius.dart';
import 'zaidang_spacing.dart';
import 'zaidang_tokens.dart';
import 'zaidang_type.dart';

/// 用手写语义色搭 [ThemeData]，避免 seed 把火漆红算成粉紫。
/// 字号、间距、圆角同样来自 Token，原生组件不再落回 M3 默认值。
ThemeData zaidangTheme(ZaidangTokens tokens, {required Brightness brightness}) {
  final type = ZaidangType.from(tokens);
  final onSecondary = brightness == Brightness.light ? tokens.ink : tokens.bg;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: tokens.accent,
    onPrimary: tokens.onAccent,
    secondary: tokens.accentGold,
    onSecondary: onSecondary,
    error: tokens.ink,
    onError: tokens.bg,
    surface: tokens.bg,
    onSurface: tokens.ink,
    onSurfaceVariant: tokens.inkSecondary,
    surfaceContainerLow: tokens.surface,
    outline: tokens.border,
    outlineVariant: tokens.border,
    surfaceTint: Colors.transparent,
    shadow: const Color(0xFF000000),
  );

  final inputBorder = OutlineInputBorder(
    borderRadius: ZaidangRadius.smAll,
    borderSide: BorderSide(color: tokens.border),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: tokens.bg,
    extensions: <ThemeExtension<dynamic>>[tokens, type],
    textTheme: type.toTextTheme(),
    appBarTheme: AppBarThemeData(
      backgroundColor: tokens.bg,
      foregroundColor: tokens.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: type.pageTitle,
      toolbarTextStyle: type.body,
    ),
    dividerTheme: DividerThemeData(
      color: tokens.border,
      space: 1,
      thickness: 1,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: tokens.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 4,
      shadowColor: scheme.shadow.withValues(alpha: 0.12),
      titleTextStyle: type.heading,
      contentTextStyle: type.body,
      shape: RoundedRectangleBorder(
        borderRadius: ZaidangRadius.lgAll,
        side: BorderSide(color: tokens.border),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: tokens.surface,
      contentTextStyle: type.body,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: ZaidangRadius.mdAll,
        side: BorderSide(color: tokens.border),
      ),
      insetPadding: const EdgeInsets.fromLTRB(
        ZaidangSpacing.lg,
        ZaidangSpacing.sm,
        ZaidangSpacing.lg,
        ZaidangSpacing.lg,
      ),
      showCloseIcon: true,
      closeIconColor: tokens.ink,
      actionTextColor: tokens.ink,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: tokens.accent,
      foregroundColor: tokens.onAccent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      // 主体高度不含手机底部安全区，由 NavigationBar 内部统一处理。
      height: 56,
      backgroundColor: tokens.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: Colors.transparent,
      labelPadding: const EdgeInsets.only(top: ZaidangSpacing.xxs),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(size: 24, color: _navigationColor(tokens, states));
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return type.micro.copyWith(color: _navigationColor(tokens, states));
      }),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: tokens.inkSecondary,
      titleTextStyle: type.subheading,
      subtitleTextStyle: type.caption,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: ZaidangSpacing.lg,
        vertical: ZaidangSpacing.sm,
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelStyle: type.label,
      unselectedLabelStyle: type.label,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: tokens.accent),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: tokens.accent,
        disabledForegroundColor: tokens.inkSecondary,
        textStyle: type.label,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        textStyle: type.label,
        shape: const RoundedRectangleBorder(borderRadius: ZaidangRadius.smAll),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        textStyle: type.label,
        shape: const RoundedRectangleBorder(borderRadius: ZaidangRadius.smAll),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: tokens.accent,
      selectionColor: tokens.accent.withValues(alpha: 0.18),
      selectionHandleColor: tokens.accent,
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: tokens.surface,
      alignLabelWithHint: true,
      labelStyle: type.bodyLarge.copyWith(color: tokens.inkSecondary),
      floatingLabelStyle: type.caption.copyWith(color: tokens.ink),
      hintStyle: type.bodyLarge.copyWith(color: tokens.inkSecondary),
      errorStyle: type.micro.copyWith(color: tokens.ink),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: ZaidangSpacing.lg,
        vertical: ZaidangSpacing.lg,
      ),
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: tokens.accent, width: 1.5),
      ),
      errorBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: tokens.ink),
      ),
      focusedErrorBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: tokens.ink, width: 1.5),
      ),
    ),
  );
}

Color _navigationColor(ZaidangTokens tokens, Set<WidgetState> states) {
  return states.contains(WidgetState.selected)
      ? tokens.accent
      : tokens.inkSecondary;
}

ThemeData zaidangLightTheme() =>
    zaidangTheme(ZaidangTokens.light, brightness: Brightness.light);

ThemeData zaidangDarkTheme() =>
    zaidangTheme(ZaidangTokens.dark, brightness: Brightness.dark);
