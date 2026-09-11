import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/theme/zaidang_theme.dart';
import 'package:ochome/theme/zaidang_tokens.dart';
import 'package:ochome/widgets/archive_list_card.dart';
import 'package:ochome/widgets/archive_tag.dart';

void main() {
  testWidgets('shows title, tags, quoted first line and meta with icon', (
    tester,
  ) async {
    await _pump(
      tester,
      const ArchiveListCard(
        coverImg: '',
        title: '白鸦',
        tags: ['鸟人', '信使'],
        summary: '第一行\r\n第二行',
        meta: '1 份资产',
        onTap: _noop,
      ),
    );

    expect(find.text('白鸦'), findsOneWidget);
    expect(find.text('鸟人'), findsOneWidget);
    expect(find.text('信使'), findsOneWidget);
    expect(find.text('「第一行」'), findsOneWidget);
    expect(find.textContaining('第二行'), findsNothing);
    expect(find.text('1 份资产'), findsOneWidget);
    expect(find.byIcon(Icons.description_outlined), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);

    final quote = tester.widget<Text>(find.text('「第一行」'));
    expect(quote.style!.color, ZaidangTokens.light.ink);
    expect(find.byType(ArchiveTag), findsNWidgets(2));
    final tag = tester.widget<Text>(find.text('鸟人'));
    expect(tag.style!.color, ZaidangTokens.light.ink);
  });

  testWidgets('omits tags, summary and meta when they are absent', (
    tester,
  ) async {
    await _pump(
      tester,
      const ArchiveListCard(
        coverImg: '',
        title: '雾都',
        placeholderIcon: Icons.public_outlined,
        summary: '  \n  ',
        onTap: _noop,
      ),
    );

    expect(find.text('雾都'), findsOneWidget);
    expect(find.byType(Wrap), findsNothing);
    expect(find.textContaining('「'), findsNothing);
    expect(find.byIcon(Icons.description_outlined), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect(find.byIcon(Icons.public_outlined), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsNothing);
  });

  testWidgets('tap fires onTap once', (tester) async {
    var taps = 0;
    await _pump(
      tester,
      ArchiveListCard(coverImg: '', title: '白鸦', onTap: () => taps++),
    );

    await tester.tap(find.text('白鸦'));
    await tester.pumpAndSettle();

    expect(taps, 1);
  });

  testWidgets('dark theme keeps the quote in ink on surface', (tester) async {
    await _pump(
      tester,
      const ArchiveListCard(
        coverImg: '',
        title: '白鸦',
        summary: '设定',
        onTap: _noop,
      ),
      dark: true,
    );

    final quote = tester.widget<Text>(find.text('「设定」'));
    expect(quote.style!.color, ZaidangTokens.dark.ink);
    final surface = tester.widget<Material>(
      find.ancestor(of: find.text('白鸦'), matching: find.byType(Material)).first,
    );
    expect(surface.color, ZaidangTokens.dark.surface);
  });
}

void _noop() {}

Future<void> _pump(
  WidgetTester tester,
  Widget card, {
  bool dark = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? zaidangDarkTheme() : zaidangLightTheme(),
      home: Scaffold(
        body: Center(child: SizedBox(width: 350, child: card)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
