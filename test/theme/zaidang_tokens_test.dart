import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/theme/zaidang_theme.dart';
import 'package:ochome/theme/zaidang_tokens.dart';

void main() {
  test('light tokens match the 崽档 note', () {
    expect(ZaidangTokens.light.bg, const Color(0xFFFAF6F0));
    expect(ZaidangTokens.light.accent, const Color(0xFFC2402A));
    expect(ZaidangTokens.light.ink, const Color(0xFF2B2622));
    expect(ZaidangTokens.light.onAccent, const Color(0xFFFFFFFF));
  });

  test('dark tokens use lifted accent, not inverted light red', () {
    expect(ZaidangTokens.dark.bg, const Color(0xFF171412));
    expect(ZaidangTokens.dark.accent, const Color(0xFFD96C5A));
    expect(ZaidangTokens.dark.onAccent, const Color(0xFF2B1310));
    expect(ZaidangTokens.dark.accent, isNot(ZaidangTokens.light.accent));
  });

  test('theme maps paper canvas and ink without a seed palette', () {
    final light = zaidangLightTheme();
    final dark = zaidangDarkTheme();

    expect(light.colorScheme.primary, const Color(0xFFC2402A));
    expect(light.colorScheme.surface, const Color(0xFFFAF6F0));
    expect(light.scaffoldBackgroundColor, const Color(0xFFFAF6F0));
    expect(light.appBarTheme.backgroundColor, const Color(0xFFFAF6F0));
    expect(light.colorScheme.error, isNot(const Color(0xFFC2402A)));

    expect(dark.colorScheme.primary, const Color(0xFFD96C5A));
    expect(dark.scaffoldBackgroundColor, const Color(0xFF171412));
    expect(dark.appBarTheme.backgroundColor, const Color(0xFF171412));
    expect(dark.colorScheme.error, isNot(const Color(0xFFD96C5A)));
  });
}
