import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/theme/zaidang_theme.dart';
import 'package:ochome/theme/zaidang_tokens.dart';
import 'package:ochome/widgets/archive_editor/role_identity_header.dart';
import 'package:ochome/widgets/archive_tag.dart';

void main() {
  test('heightFor grows with the text scale but never below the portrait', () {
    final base = RoleIdentityHeader.heightFor(TextScaler.noScaling);
    final large = RoleIdentityHeader.heightFor(const TextScaler.linear(1.5));
    expect(base, greaterThan(RoleIdentityHeader.portraitSize));
    expect(large, greaterThan(base));
  });

  testWidgets('shows name, sparkle, tags, quoted line and export entry', (
    tester,
  ) async {
    var exports = 0;
    await _pump(
      tester,
      _header(
        name: '度渊',
        tags: const ['人类', '队长', '男'],
        quote: '来自古人类的歌者',
        onExport: () => exports++,
      ),
    );

    expect(find.text('度渊'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    expect(find.byType(ArchiveTag), findsNWidgets(3));
    expect(find.text('「来自古人类的歌者」'), findsOneWidget);
    final quote = tester.widget<Text>(find.text('「来自古人类的歌者」'));
    expect(quote.style!.color, ZaidangTokens.light.ink);

    final header = tester.getRect(find.byType(RoleIdentityHeader));
    final portrait = tester.getRect(
      find.byKey(const Key('role-create-cover-portrait')),
    );
    expect(header.height, RoleIdentityHeader.heightFor(TextScaler.noScaling));
    expect(
      portrait.top,
      lessThan(header.top + RoleIdentityHeader.portraitOverlap),
    );

    await tester.tap(find.byKey(const Key('role-card-export')));
    await tester.pumpAndSettle();
    expect(exports, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('falls back to emptyName and omits tags and quote when blank', (
    tester,
  ) async {
    await _pump(tester, _header(name: '  ', tags: const [], quote: ''));

    expect(find.text('新建角色'), findsOneWidget);
    expect(find.byType(ArchiveTag), findsNothing);
    expect(find.textContaining('「'), findsNothing);
    expect(find.text('添加立绘'), findsOneWidget);
    expect(find.byKey(const Key('role-cover-change')), findsNothing);
  });

  testWidgets('portrait without cover picks; with cover previews and changes', (
    tester,
  ) async {
    var portraitTaps = 0;
    var changes = 0;
    await _pump(
      tester,
      _header(
        name: '白鸦',
        onPortraitTap: () => portraitTaps++,
        onChangeCover: () => changes++,
      ),
    );
    await tester.tap(find.byKey(const Key('role-create-cover-portrait')));
    expect(portraitTaps, 1);
    expect(find.byKey(const Key('role-cover-change')), findsNothing);

    await _pump(
      tester,
      _header(
        name: '白鸦',
        hasCover: true,
        coverImg: '/no/such/file.png',
        onPortraitTap: () => portraitTaps++,
        onChangeCover: () => changes++,
      ),
    );
    expect(find.byTooltip('更换立绘'), findsOneWidget);
    await tester.tap(find.byKey(const Key('role-create-cover-portrait')));
    await tester.tap(find.byKey(const Key('role-cover-change')));
    expect(portraitTaps, 2);
    expect(changes, 1);
  });

  testWidgets('badge and export button meet the minimum tap target', (
    tester,
  ) async {
    await _pump(
      tester,
      _header(name: '白鸦', hasCover: true, coverImg: '/no/such/file.png'),
    );
    final badge = tester.getSize(find.byKey(const Key('role-cover-change')));
    expect(badge.width, greaterThanOrEqualTo(kMinInteractiveDimension));
    expect(badge.height, greaterThanOrEqualTo(kMinInteractiveDimension));
    final export = tester.getSize(find.byKey(const Key('role-card-export')));
    expect(export.height, greaterThanOrEqualTo(kMinInteractiveDimension));
    expect(export.width, RoleIdentityHeader.portraitSize);
    // 角标命中区不能伸出头像盒子，否则伸出去的那部分收不到点击。
    final badgeRect = tester.getRect(
      find.byKey(const Key('role-cover-change')),
    );
    final portraitBox = tester.getRect(
      find
          .ancestor(
            of: find.byKey(const Key('role-create-cover-portrait')),
            matching: find.byType(Stack),
          )
          .first,
    );
    expect(portraitBox.contains(badgeRect.topLeft), isTrue);
    expect(
      portraitBox.contains(badgeRect.bottomRight - const Offset(0.1, 0.1)),
      isTrue,
    );
  });

  testWidgets('change badge exposes a button with label and enabled state', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pump(
        tester,
        _header(
          name: '白鸦',
          hasCover: true,
          coverImg: '/no/such/file.png',
          onChangeCover: () {},
        ),
      );
      final data = tester
          .getSemantics(find.byKey(const Key('role-cover-change')))
          .getSemanticsData();
      expect(data.label, '更换立绘');
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isEnabled.toBoolOrNull(), isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);

      await _pump(
        tester,
        _header(
          name: '白鸦',
          hasCover: true,
          coverImg: '/no/such/file.png',
          onChangeCover: null,
          onPortraitTap: null,
          onExport: null,
        ),
      );
      final disabled = tester
          .getSemantics(find.byKey(const Key('role-cover-change')))
          .getSemanticsData();
      expect(disabled.flagsCollection.isEnabled.toBoolOrNull(), isFalse);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('role-card-export')))
            .onPressed,
        isNull,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('a 1.6x text scale clips instead of overflowing', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pump(
      tester,
      _header(
        name: '一个特别特别长的角色名字用来撑爆一行',
        tags: const ['人类', '队长', '男', '歌者', '推广者'],
        quote: '来自古人类的歌者，人类文明推广者，一句很长很长的设定用来测试两行省略。',
        height: RoleIdentityHeader.heightFor(const TextScaler.linear(1.6)),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a 2x text scale keeps both quote lines inside the header', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pump(
      tester,
      _header(
        name: '度渊',
        tags: const ['人类', '队长', '男'],
        quote: '来自古人类的歌者，人类文明推广者，一句足够长的设定用来撑满两行。',
        height: RoleIdentityHeader.heightFor(const TextScaler.linear(2)),
      ),
    );
    final header = tester.getRect(find.byType(RoleIdentityHeader));
    final quote = find.textContaining('「');
    expect(tester.getRect(quote).bottom, lessThanOrEqualTo(header.bottom));
    // 两行都在：引文没有被裁成一行。
    final quoteText = tester.widget<Text>(quote);
    final painter = TextPainter(
      text: TextSpan(text: quoteText.data, style: quoteText.style),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      textScaler: const TextScaler.linear(2),
    )..layout(maxWidth: tester.getSize(quote).width);
    expect(painter.computeLineMetrics().length, 2);
    expect(tester.getSize(quote).height, closeTo(painter.height, 0.5));
    painter.dispose();
  });
}

RoleIdentityHeader _header({
  required String name,
  List<String> tags = const ['人类'],
  String quote = '设定',
  bool hasCover = false,
  String coverImg = '',
  VoidCallback? onPortraitTap = _noop,
  VoidCallback? onChangeCover = _noop,
  VoidCallback? onExport = _noop,
  double? height,
}) {
  return RoleIdentityHeader(
    name: name,
    emptyName: '新建角色',
    tags: tags,
    quote: quote,
    coverImg: coverImg,
    hasCover: hasCover,
    onPortraitTap: onPortraitTap,
    onChangeCover: onChangeCover,
    onExport: onExport,
    height: height ?? RoleIdentityHeader.heightFor(TextScaler.noScaling),
  );
}

void _noop() {}

/// 身份头按屏宽算左右留白，所以要像真机一样占满一个手机宽度。
Future<void> _pump(WidgetTester tester, RoleIdentityHeader header) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: zaidangLightTheme(),
      home: Scaffold(
        body: Align(alignment: Alignment.topCenter, child: header),
      ),
    ),
  );
  await tester.pump();
}
