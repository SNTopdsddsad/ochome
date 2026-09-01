import 'package:flutter/material.dart';

/// 崽档语义色。数值来自笔记《主题色与设计 Token》v1，禁止再用 [ColorScheme.fromSeed]。
@immutable
class ZaidangTokens extends ThemeExtension<ZaidangTokens> {
  const ZaidangTokens({
    required this.bg,
    required this.surface,
    required this.ink,
    required this.inkSecondary,
    required this.border,
    required this.accent,
    required this.onAccent,
    required this.accentGold,
  });

  /// 页面背景（纸白 / 暖黑）。
  final Color bg;

  /// 卡片 / 弹窗。
  final Color surface;

  /// 正文、标题（永远墨色，不用红）。
  final Color ink;

  /// 次要文字。
  final Color inkSecondary;

  /// 分隔线 / 描边。
  final Color border;

  /// 主按钮、选中态、火漆印、水印。
  final Color accent;

  /// 主色上的文字。
  final Color onAccent;

  /// 买断 / 会员标识。
  final Color accentGold;

  static const light = ZaidangTokens(
    bg: Color(0xFFFAF6F0),
    surface: Color(0xFFFFFFFF),
    ink: Color(0xFF2B2622),
    inkSecondary: Color(0xFF8C8177),
    border: Color(0xFFEAE3D9),
    accent: Color(0xFFC2402A),
    onAccent: Color(0xFFFFFFFF),
    accentGold: Color(0xFFB97D2A),
  );

  static const dark = ZaidangTokens(
    bg: Color(0xFF171412),
    surface: Color(0xFF201C19),
    ink: Color(0xFFEDE7DF),
    inkSecondary: Color(0xFFA79C90),
    border: Color(0xFF35302B),
    accent: Color(0xFFD96C5A),
    onAccent: Color(0xFF2B1310),
    accentGold: Color(0xFFD9A254),
  );

  static ZaidangTokens of(BuildContext context) {
    return Theme.of(context).extension<ZaidangTokens>() ?? ZaidangTokens.light;
  }

  @override
  ZaidangTokens copyWith({
    Color? bg,
    Color? surface,
    Color? ink,
    Color? inkSecondary,
    Color? border,
    Color? accent,
    Color? onAccent,
    Color? accentGold,
  }) {
    return ZaidangTokens(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      ink: ink ?? this.ink,
      inkSecondary: inkSecondary ?? this.inkSecondary,
      border: border ?? this.border,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      accentGold: accentGold ?? this.accentGold,
    );
  }

  @override
  ZaidangTokens lerp(ThemeExtension<ZaidangTokens>? other, double t) {
    if (other is! ZaidangTokens) {
      return this;
    }
    return ZaidangTokens(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSecondary: Color.lerp(inkSecondary, other.inkSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      accentGold: Color.lerp(accentGold, other.accentGold, t)!,
    );
  }
}
