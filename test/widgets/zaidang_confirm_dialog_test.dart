import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/theme/zaidang_theme.dart';
import 'package:ochome/theme/zaidang_tokens.dart';
import 'package:ochome/widgets/zaidang_confirm_dialog.dart';

const _cancel = Key('zaidang-confirm-cancel');
const _confirm = Key('zaidang-confirm-action');
const _body = '「随身物品」和里面的内容会一起移除。';
const _effect = '保存角色后生效。';

void main() {
  for (final dismissal in ['cancel', 'barrier', 'back', 'escape']) {
    testWidgets('$dismissal returns false without confirming', (tester) async {
      final results = <bool>[];
      await _open(tester, onResult: results.add);
      switch (dismissal) {
        case 'cancel':
          await tester.tap(find.byKey(_cancel));
        case 'barrier':
          await tester.tapAt(const Offset(5, 5));
        case 'back':
          await tester.binding.handlePopRoute();
        case 'escape':
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      }
      await tester.pumpAndSettle();
      expect(results, [false]);
      expect(find.byType(ZaidangConfirmDialog), findsNothing);
      expect(find.text('打开弹窗'), findsOneWidget);
    });
  }

  testWidgets('explicit confirm returns true and restores trigger focus', (
    tester,
  ) async {
    final results = <bool>[];
    final opener = FocusNode();
    addTearDown(opener.dispose);
    await _open(tester, onResult: results.add, opener: opener);
    await tester.tap(find.byKey(_confirm));
    await tester.pumpAndSettle();
    expect(results, [true]);
    expect(opener.hasFocus, isTrue);
  });

  testWidgets('Enter on opening cannot confirm a destructive operation', (
    tester,
  ) async {
    final results = <bool>[];
    await _open(tester, onResult: results.add);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(results, isNot(contains(true)));
  });

  testWidgets('repeated exit callbacks cannot pop the caller route', (
    tester,
  ) async {
    final results = <bool>[];
    await _open(tester, onResult: results.add);
    final confirm = tester
        .widget<ButtonStyleButton>(find.byKey(_confirm))
        .onPressed!;
    final cancel = tester
        .widget<ButtonStyleButton>(find.byKey(_cancel))
        .onPressed!;

    // Retain callbacks across the route's exit transition, before rebuilding.
    confirm();
    confirm();
    cancel();
    await tester.pumpAndSettle();

    expect(results, [true]);
    expect(find.byType(ZaidangConfirmDialog), findsNothing);
    expect(find.text('打开弹窗'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keyboard traversal stays inside the modal in visual order', (
    tester,
  ) async {
    final results = <bool>[];
    final opener = FocusNode();
    addTearDown(opener.dispose);
    await _open(tester, onResult: results.add, opener: opener);

    Key? focusedButton() {
      final context = FocusManager.instance.primaryFocus?.context;
      return context?.findAncestorWidgetOfExactType<TextButton>()?.key ??
          context?.findAncestorWidgetOfExactType<FilledButton>()?.key;
    }

    expect(focusedButton(), _cancel);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(focusedButton(), _confirm);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(focusedButton(), _cancel);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(focusedButton(), _confirm);
    expect(opener.hasFocus, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(results, [false]);
    expect(opener.hasFocus, isTrue);
  });

  testWidgets('very short windows let users scroll to either action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 240);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final results = <bool>[];
    await _open(
      tester,
      onResult: results.add,
      scale: 2,
      body: '${'很长的属性内容' * 6}会一起移除。',
    );
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.byKey(_cancel));
    await tester.pumpAndSettle();
    expect(find.byKey(_cancel).hitTestable(), findsOneWidget);
    await tester.ensureVisible(find.byKey(_confirm));
    await tester.pumpAndSettle();
    expect(find.byKey(_confirm).hitTestable(), findsOneWidget);
    await tester.tap(find.byKey(_confirm));
    await tester.pumpAndSettle();
    expect(results, [true]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Widget can be reused directly with a standard dialog route', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: zaidangLightTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<bool>(
                  context: context,
                  builder: (_) => const ZaidangConfirmDialog(
                    title: '直接复用组件',
                    body: _body,
                    consequence: _effect,
                    confirmLabel: '删除属性',
                  ),
                );
              },
              child: const Text('打开弹窗'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开弹窗'));
    await tester.pumpAndSettle();
    expect(find.text('直接复用组件'), findsOneWidget);
    await tester.tap(find.byKey(_confirm));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('friendly cancellation retains its full actionable semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await _open(tester, onResult: (_) {});
      expect(
        tester.getSemantics(find.byKey(_cancel)),
        isSemantics(
          label: '先留着，保留这条属性',
          isButton: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.byKey(_confirm)),
        isSemantics(label: '删除属性', isButton: true, hasTapAction: true),
      );
    } finally {
      semantics.dispose();
    }
  });

  for (final dark in [false, true]) {
    testWidgets('${dark ? 'dark' : 'light'} actions use readable ink colors', (
      tester,
    ) async {
      await _open(tester, onResult: (_) {}, dark: dark);
      final tokens = dark ? ZaidangTokens.dark : ZaidangTokens.light;
      final action = tester.widget<ButtonStyleButton>(find.byKey(_confirm));
      final fill = tester.widget<Material>(
        find.descendant(
          of: find.byKey(_confirm),
          matching: find.byType(Material),
        ),
      );
      final foreground = action.style!.foregroundColor!.resolve({})!;
      expect(fill.color, tokens.ink);
      expect(foreground, tokens.surface);
      expect(_contrast(fill.color!, foreground), greaterThanOrEqualTo(4.5));
      expect(tester.widget<Text>(find.text(_body)).style?.color, tokens.ink);
      expect(tester.widget<Text>(find.text(_effect)).style?.color, tokens.ink);
      expect(
        tester.getSize(find.byKey(_confirm)).height,
        greaterThanOrEqualTo(48),
      );
      expect(
        tester.getSize(find.byKey(_cancel)).height,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets(
      '${dark ? 'dark' : 'light'} narrow large-text dialog keeps both actions reachable',
      (tester) async {
        tester.view.physicalSize = const Size(320, 480);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final results = <bool>[];
        final longBody = '「${'这是很长的自定义属性名称' * 12}」和里面的内容会一起移除。';
        await _open(
          tester,
          onResult: results.add,
          dark: dark,
          scale: 2,
          body: longBody,
        );
        expect(tester.takeException(), isNull);
        expect(find.text(longBody), findsOneWidget);
        expect(find.byKey(_cancel).hitTestable(), findsOneWidget);
        expect(find.byKey(_confirm).hitTestable(), findsOneWidget);
        expect(
          tester.getRect(find.byKey(_confirm)).bottom,
          lessThanOrEqualTo(480),
        );
        await tester.tap(find.byKey(_cancel));
        await tester.pumpAndSettle();
        expect(results, [false]);
      },
    );
  }

  testWidgets('whole-device overwrite can omit the decorative sparkle', (
    tester,
  ) async {
    await _open(tester, onResult: (_) {}, showSparkle: false);
    expect(find.byKey(const Key('zaidang-confirm-notebook')), findsOneWidget);
    expect(find.byKey(const Key('zaidang-confirm-sparkle')), findsNothing);
  });
}

Future<void> _open(
  WidgetTester tester, {
  required ValueChanged<bool> onResult,
  bool dark = false,
  double scale = 1,
  String body = _body,
  bool showSparkle = true,
  FocusNode? opener,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? zaidangDarkTheme() : zaidangLightTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              focusNode: opener,
              autofocus: true,
              onPressed: () async {
                onResult(
                  await showZaidangConfirmDialog(
                    context: context,
                    title: '要删掉这条属性吗？',
                    body: body,
                    consequence: _effect,
                    cancelLabel: '先留着',
                    cancelSemanticLabel: '先留着，保留这条属性',
                    confirmLabel: '删除属性',
                    showSparkle: showSparkle,
                  ),
                );
              },
              child: const Text('打开弹窗'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('打开弹窗'));
  await tester.pumpAndSettle();
}

double _contrast(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05);
}
