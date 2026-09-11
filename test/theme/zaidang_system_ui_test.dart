import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/theme/zaidang_system_ui.dart';
import 'package:ochome/theme/zaidang_theme.dart';
import 'package:ochome/theme/zaidang_tokens.dart';

void main() {
  testWidgets('light paper uses dark status icons and paper nav bar', (
    tester,
  ) async {
    final style = await _resolve(tester, dark: false);

    expect(style.statusBarIconBrightness, Brightness.dark);
    expect(style.statusBarColor, Colors.transparent);
    expect(style.systemNavigationBarColor, ZaidangTokens.light.bg);
    expect(style.systemNavigationBarIconBrightness, Brightness.dark);
  });

  testWidgets('a cover under the status bar flips icons to light', (
    tester,
  ) async {
    final style = await _resolve(tester, dark: false, onDarkBackdrop: true);

    expect(style.statusBarIconBrightness, Brightness.light);
    expect(style.systemNavigationBarColor, ZaidangTokens.light.bg);
    expect(style.systemNavigationBarIconBrightness, Brightness.dark);
  });

  testWidgets('dark theme always uses light icons', (tester) async {
    for (final onDarkBackdrop in [false, true]) {
      final style = await _resolve(
        tester,
        dark: true,
        onDarkBackdrop: onDarkBackdrop,
      );

      expect(style.statusBarIconBrightness, Brightness.light);
      expect(style.systemNavigationBarColor, ZaidangTokens.dark.bg);
      expect(style.systemNavigationBarIconBrightness, Brightness.light);
    }
  });
}

Future<SystemUiOverlayStyle> _resolve(
  WidgetTester tester, {
  required bool dark,
  bool onDarkBackdrop = false,
}) async {
  late SystemUiOverlayStyle style;
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? zaidangDarkTheme() : zaidangLightTheme(),
      home: Builder(
        builder: (context) {
          style = zaidangSystemUiOverlayStyle(
            context,
            onDarkBackdrop: onDarkBackdrop,
          );
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return style;
}
