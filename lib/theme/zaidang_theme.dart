import 'package:flutter/material.dart';

import 'zaidang_tokens.dart';

/// 用手写语义色搭 [ThemeData]，避免 seed 把火漆红算成粉紫。
ThemeData zaidangTheme(ZaidangTokens tokens, {required Brightness brightness}) {
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

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: tokens.bg,
    extensions: <ThemeExtension<dynamic>>[tokens],
    appBarTheme: AppBarThemeData(
      backgroundColor: tokens.bg,
      foregroundColor: tokens.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: BorderSide(color: tokens.border),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: tokens.surface,
      contentTextStyle: TextStyle(
        color: tokens.ink,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.4,
      ),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: tokens.border),
      ),
      insetPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      showCloseIcon: true,
      closeIconColor: tokens.ink,
      actionTextColor: tokens.ink,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: tokens.accent,
      foregroundColor: tokens.onAccent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: tokens.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(color: _navigationColor(tokens, states));
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return TextStyle(color: _navigationColor(tokens, states));
      }),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: tokens.inkSecondary,
      titleTextStyle: TextStyle(
        color: tokens.ink,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      subtitleTextStyle: TextStyle(color: tokens.inkSecondary, fontSize: 13),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: tokens.accent),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: tokens.accent,
        disabledForegroundColor: tokens.inkSecondary,
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
      labelStyle: TextStyle(color: tokens.inkSecondary, fontSize: 14),
      floatingLabelStyle: TextStyle(color: tokens.ink, fontSize: 14),
      hintStyle: TextStyle(color: tokens.inkSecondary, fontSize: 14),
      errorStyle: TextStyle(color: tokens.ink, fontSize: 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: tokens.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: tokens.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: tokens.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: tokens.ink),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
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
