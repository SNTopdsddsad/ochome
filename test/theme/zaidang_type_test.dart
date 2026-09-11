import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/theme/zaidang_radius.dart';
import 'package:ochome/theme/zaidang_spacing.dart';
import 'package:ochome/theme/zaidang_theme.dart';
import 'package:ochome/theme/zaidang_tokens.dart';
import 'package:ochome/theme/zaidang_type.dart';

void main() {
  test('type scale has eleven roles on seven sizes', () {
    final type = ZaidangType.light;
    final roles = <String, (TextStyle, double, FontWeight, double)>{
      'hero': (type.hero, 26, FontWeight.w600, 1.2),
      'title': (type.title, 22, FontWeight.w600, 1.25),
      'heading': (type.heading, 20, FontWeight.w500, 1.3),
      'pageTitle': (type.pageTitle, 17, FontWeight.w600, 1.3),
      'subheading': (type.subheading, 17, FontWeight.w500, 1.4),
      'bodyLarge': (type.bodyLarge, 17, FontWeight.w400, 1.5),
      'body': (type.body, 15, FontWeight.w400, 1.5),
      'label': (type.label, 15, FontWeight.w500, 1.3),
      'sectionLabel': (type.sectionLabel, 13, FontWeight.w600, 1.4),
      'caption': (type.caption, 13, FontWeight.w400, 1.4),
      'micro': (type.micro, 12, FontWeight.w400, 1.3),
    };

    for (final MapEntry(key: name, value: (style, size, weight, height))
        in roles.entries) {
      expect(style.fontSize, size, reason: '$name size');
      expect(style.fontWeight, weight, reason: '$name weight');
      expect(style.height, height, reason: '$name height');
    }

    final sizes = roles.values.map((role) => role.$2).toSet();
    expect(sizes, {26, 22, 20, 17, 15, 13, 12});
  });

  test('secondary roles bake in inkSecondary, the rest use ink', () {
    for (final tokens in [ZaidangTokens.light, ZaidangTokens.dark]) {
      final type = ZaidangType.from(tokens);
      for (final style in [type.sectionLabel, type.caption, type.micro]) {
        expect(style.color, tokens.inkSecondary);
      }
      for (final style in [
        type.hero,
        type.title,
        type.heading,
        type.pageTitle,
        type.subheading,
        type.bodyLarge,
        type.body,
        type.label,
      ]) {
        expect(style.color, tokens.ink);
      }
    }
  });

  test('toTextTheme fills all fifteen Material slots', () {
    final type = ZaidangType.light;
    final textTheme = type.toTextTheme();

    expect(textTheme.displayLarge, type.hero);
    expect(textTheme.displayMedium, type.hero);
    expect(textTheme.displaySmall, type.hero);
    expect(textTheme.headlineLarge, type.title);
    expect(textTheme.headlineMedium, type.title);
    expect(textTheme.headlineSmall, type.title);
    expect(textTheme.titleLarge, type.heading);
    expect(textTheme.titleMedium, type.pageTitle);
    expect(textTheme.titleSmall, type.subheading);
    expect(textTheme.bodyLarge, type.bodyLarge);
    expect(textTheme.bodyMedium, type.body);
    expect(textTheme.bodySmall, type.caption);
    expect(textTheme.labelLarge, type.label);
    expect(textTheme.labelMedium, type.sectionLabel);
    expect(textTheme.labelSmall, type.micro);
  });

  test('theme exposes the type extension and wires component text', () {
    final light = zaidangLightTheme();
    final type = light.extension<ZaidangType>()!;

    expect(type.body.color, ZaidangTokens.light.ink);
    // ThemeData merges the platform font family in, so compare the fields
    // the scale owns rather than the whole style.
    final bodyMedium = light.textTheme.bodyMedium!;
    expect(bodyMedium.fontSize, type.body.fontSize);
    expect(bodyMedium.fontWeight, type.body.fontWeight);
    expect(bodyMedium.height, type.body.height);
    expect(bodyMedium.color, type.body.color);
    expect(
      light.textTheme.labelMedium!.color,
      ZaidangTokens.light.inkSecondary,
    );
    expect(light.appBarTheme.titleTextStyle, type.pageTitle);
    expect(light.dialogTheme.titleTextStyle, type.heading);
    expect(light.dialogTheme.contentTextStyle, type.body);
    expect(light.snackBarTheme.contentTextStyle, type.body);
    expect(light.listTileTheme.titleTextStyle, type.subheading);
    expect(light.listTileTheme.subtitleTextStyle, type.caption);
    expect(light.tabBarTheme.labelStyle, type.label);
    expect(light.inputDecorationTheme.hintStyle?.fontSize, 17);
    expect(light.inputDecorationTheme.errorStyle?.fontSize, 12);
    expect(
      light.navigationBarTheme.labelTextStyle!.resolve({})!.fontSize,
      type.micro.fontSize,
    );

    final dark = zaidangDarkTheme();
    expect(dark.extension<ZaidangType>()!.body.color, ZaidangTokens.dark.ink);
  });

  test('theme radii and spacing come from the token scales', () {
    final light = zaidangLightTheme();

    final dialog = light.dialogTheme.shape as RoundedRectangleBorder;
    expect(dialog.borderRadius, ZaidangRadius.lgAll);

    final snack = light.snackBarTheme.shape as RoundedRectangleBorder;
    expect(snack.borderRadius, ZaidangRadius.mdAll);

    final input =
        light.inputDecorationTheme.enabledBorder as OutlineInputBorder;
    expect(input.borderRadius, ZaidangRadius.smAll);
    expect(
      light.inputDecorationTheme.contentPadding,
      const EdgeInsets.symmetric(
        horizontal: ZaidangSpacing.lg,
        vertical: ZaidangSpacing.lg,
      ),
    );
    expect(
      light.listTileTheme.contentPadding,
      const EdgeInsets.symmetric(
        horizontal: ZaidangSpacing.lg,
        vertical: ZaidangSpacing.sm,
      ),
    );
  });

  test('of() falls back to light and lerp interpolates colours', () {
    expect(
      ZaidangType.light.lerp(ZaidangType.dark, 0).body.color,
      ZaidangTokens.light.ink,
    );
    expect(
      ZaidangType.light.lerp(ZaidangType.dark, 1).body.color,
      ZaidangTokens.dark.ink,
    );
    expect(
      ZaidangType.light.lerp(ZaidangType.dark, 0.5).body.color,
      Color.lerp(ZaidangTokens.light.ink, ZaidangTokens.dark.ink, 0.5),
    );
    expect(ZaidangType.light.lerp(null, 0.5), same(ZaidangType.light));
  });

  testWidgets('ZaidangType.of reads the active theme', (tester) async {
    late ZaidangType resolved;
    await tester.pumpWidget(
      MaterialApp(
        theme: zaidangDarkTheme(),
        home: Builder(
          builder: (context) {
            resolved = ZaidangType.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(resolved.body.color, ZaidangTokens.dark.ink);
    expect(resolved.caption.color, ZaidangTokens.dark.inkSecondary);
  });
}
