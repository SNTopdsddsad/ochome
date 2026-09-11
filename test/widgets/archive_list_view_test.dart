import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/theme/zaidang_spacing.dart';
import 'package:ochome/theme/zaidang_theme.dart';
import 'package:ochome/theme/zaidang_tokens.dart';
import 'package:ochome/widgets/archive_list_view.dart';

void main() {
  testWidgets('empty items show the empty hint in inkSecondary', (
    tester,
  ) async {
    await _pump(tester, items: const []);

    expect(find.text('还没有条目'), findsOneWidget);
    expect(find.text('没有匹配的条目'), findsNothing);
    expect(find.byType(ListView), findsNothing);
    final hint = tester.widget<Text>(find.text('还没有条目'));
    expect(hint.style!.color, ZaidangTokens.light.inkSecondary);
  });

  testWidgets('renders every item with card spacing and FAB inset', (
    tester,
  ) async {
    await _pump(tester, items: const ['Ada', '白鸦']);

    expect(find.text('item:Ada'), findsOneWidget);
    expect(find.text('item:白鸦'), findsOneWidget);
    final list = tester.widget<ListView>(find.byType(ListView));
    expect(
      list.keyboardDismissBehavior,
      ScrollViewKeyboardDismissBehavior.onDrag,
    );
    expect(
      list.padding,
      const EdgeInsets.fromLTRB(
        ZaidangSpacing.page,
        ZaidangSpacing.sm,
        ZaidangSpacing.page,
        ArchiveListView.bottomInset,
      ),
    );
    final first = tester.getBottomLeft(find.text('item:Ada')).dy;
    final second = tester.getTopLeft(find.text('item:白鸦')).dy;
    expect(second - first, ZaidangSpacing.md);
  });

  testWidgets('query is trimmed, case-insensitive and matches any field', (
    tester,
  ) async {
    await _pump(tester, items: const ['Ada', '白鸦'], query: '  ADA ');
    expect(find.text('item:Ada'), findsOneWidget);
    expect(find.text('item:白鸦'), findsNothing);

    await _pump(tester, items: const ['Ada', '白鸦'], query: 'extra-白鸦');
    expect(find.text('item:Ada'), findsNothing);
    expect(find.text('item:白鸦'), findsOneWidget);

    await _pump(tester, items: const ['Ada', '白鸦'], query: '   ');
    expect(find.text('item:Ada'), findsOneWidget);
    expect(find.text('item:白鸦'), findsOneWidget);
  });

  testWidgets('no match shows the no-match hint, not the empty hint', (
    tester,
  ) async {
    await _pump(tester, items: const ['Ada'], query: '不存在');

    expect(find.text('没有匹配的条目'), findsOneWidget);
    expect(find.text('还没有条目'), findsNothing);
    expect(find.textContaining('item:'), findsNothing);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required List<String> items,
  String query = '',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: zaidangLightTheme(),
      home: Scaffold(
        body: ArchiveListView<String>(
          items: items,
          query: query,
          searchFields: (item) => [item, 'extra-$item'],
          emptyHint: '还没有条目',
          noMatchHint: '没有匹配的条目',
          itemBuilder: (context, item) => Text('item:$item'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
