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
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: tokens.accent,
      foregroundColor: tokens.onAccent,
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

ThemeData zaidangLightTheme() =>
    zaidangTheme(ZaidangTokens.light, brightness: Brightness.light);

ThemeData zaidangDarkTheme() =>
    zaidangTheme(ZaidangTokens.dark, brightness: Brightness.dark);
