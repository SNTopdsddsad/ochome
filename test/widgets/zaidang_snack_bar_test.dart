import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/theme/zaidang_theme.dart';
import 'package:ochome/theme/zaidang_tokens.dart';
import 'package:ochome/widgets/zaidang_snack_bar.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      '${dark ? 'dark' : 'light'} notice uses a readable floating paper surface',
      (tester) async {
        await _pump(tester, dark: dark);
        showZaidangSnackBar(
          tester.element(find.text('页面内容')),
          '已保存 3 张角色卡到相册',
          tone: ZaidangSnackBarTone.success,
        );
        await tester.pumpAndSettle();
        final tokens = dark ? ZaidangTokens.dark : ZaidangTokens.light;
        final snack = tester.widget<SnackBar>(find.byType(SnackBar));
        final context = tester.element(find.byType(SnackBar));
        expect(
          snack.behavior ?? SnackBarTheme.of(context).behavior,
          SnackBarBehavior.floating,
        );
        final material = tester.widget<Material>(
          find
              .descendant(
                of: find.byType(SnackBar),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(material.color, tokens.surface);
        final message = find.byKey(const Key('zaidang-snack-message'));
        final text = tester.widget<Text>(message);
        final color =
            text.style?.color ??
            DefaultTextStyle.of(tester.element(message)).style.color;
        expect(color, tokens.ink);
        expect(find.byKey(const Key('zaidang-snack-icon')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('close control dismisses feedback without navigating away', (
    tester,
  ) async {
    await _pump(tester, accessibleNavigation: true);
    final controller = showZaidangSnackBar(
      tester.element(find.text('页面内容')),
      '无法保存，请重试。',
      tone: ZaidangSnackBarTone.error,
    );
    await tester.pumpAndSettle();
    final close = find.descendant(
      of: find.byType(SnackBar),
      matching: find.byIcon(Icons.close),
    );
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(await controller.closed, SnackBarClosedReason.dismiss);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('页面内容'), findsOneWidget);
  });

  testWidgets('latest feedback replaces queued messages', (tester) async {
    await _pump(tester);
    final context = tester.element(find.text('页面内容'));
    showZaidangSnackBar(context, '第一条');
    await tester.pumpAndSettle();
    showZaidangSnackBar(context, '第二条');
    showZaidangSnackBar(context, '最新一条', duration: const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('最新一条'), findsOneWidget);
    expect(find.text('第一条'), findsNothing);
    expect(find.text('第二条'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets(
    'long large text remains complete and scrollable on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pump(tester, scale: 2);
      final message = '${'恢复失败，请检查网络或稍后重试。' * 18}完整结尾';
      showZaidangSnackBar(
        tester.element(find.text('页面内容')),
        message,
        tone: ZaidangSnackBarTone.error,
      );
      await tester.pumpAndSettle();
      expect(find.text(message), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(tester.widget<SnackBar>(find.byType(SnackBar)).persist, isTrue);
      final scroller = find.descendant(
        of: find.byType(SnackBar),
        matching: find.byType(SingleChildScrollView),
      );
      expect(scroller, findsOneWidget);
      await tester.drag(scroller, const Offset(0, -120));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(SnackBar), findsOneWidget);
    },
  );

  for (final testCase in [
    (
      label: 'default info',
      tone: ZaidangSnackBarTone.info,
      duration: null,
      expected: const Duration(seconds: 4),
    ),
    (
      label: 'default error',
      tone: ZaidangSnackBarTone.error,
      duration: null,
      expected: const Duration(seconds: 5),
    ),
    (
      label: 'custom duration',
      tone: ZaidangSnackBarTone.success,
      duration: const Duration(seconds: 2),
      expected: const Duration(seconds: 2),
    ),
  ]) {
    testWidgets(
      '${testCase.label} auto-dismisses with accessible navigation enabled',
      (tester) async {
        await _pump(tester, accessibleNavigation: true);
        final controller = showZaidangSnackBar(
          tester.element(find.text('页面内容')),
          '已保存角色卡',
          tone: testCase.tone,
          duration: testCase.duration,
        );
        await tester.pumpAndSettle();
        final snack = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snack.persist, isFalse);
        expect(snack.duration, testCase.expected);
        await tester.pump(testCase.expected - const Duration(seconds: 1));
        expect(find.byType(SnackBar), findsOneWidget);
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(find.byType(SnackBar), findsNothing);
        expect(await controller.closed, SnackBarClosedReason.timeout);
      },
    );
  }

  testWidgets(
    'desktop feedback is capped instead of spanning the whole window',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pump(tester);
      showZaidangSnackBar(
        tester.element(find.text('页面内容')),
        '已备份到 iCloud',
        tone: ZaidangSnackBarTone.success,
      );
      await tester.pumpAndSettle();
      final snack = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snack.width, 480);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pump(
  WidgetTester tester, {
  bool dark = false,
  double scale = 1,
  bool accessibleNavigation = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? zaidangDarkTheme() : zaidangLightTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          accessibleNavigation: accessibleNavigation,
        ),
        child: child!,
      ),
      home: const Scaffold(body: Center(child: Text('页面内容'))),
    ),
  );
}
