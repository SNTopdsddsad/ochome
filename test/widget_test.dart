import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/app.dart';
import 'package:ochome/data/models/role.dart';
import 'package:ochome/data/providers/role_assets_provider.dart';
import 'package:ochome/data/providers/role_repository_provider.dart';
import 'package:ochome/data/providers/world_repository_provider.dart';
import 'package:ochome/pages/archive_page.dart';
import 'package:ochome/pages/role_list_page.dart';
import 'package:ochome/theme/zaidang_tokens.dart';
import 'package:ochome/widgets/archive_list_card.dart';

import 'fakes/fake_role_asset_repository.dart';
import 'fakes/fake_role_repository.dart';
import 'fakes/fake_world_repository.dart';

void main() {
  testWidgets('empty role list shows placeholder', (tester) async {
    await _pumpApp(tester);

    expect(find.text('我的 OC'), findsOneWidget);
    expect(find.text('记录、设定与灵感'), findsOneWidget);
    expect(find.byKey(const Key('archive-search')), findsOneWidget);
    expect(find.widgetWithText(Tab, 'OC'), findsOneWidget);
    expect(find.widgetWithText(Tab, '世界观'), findsOneWidget);
    expect(find.byTooltip('备份与恢复'), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    expect(find.text('我的'), findsOneWidget);
    expect(find.text('还没有角色'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    final theme = Theme.of(tester.element(find.byType(RoleListPage)));
    expect(theme.scaffoldBackgroundColor, ZaidangTokens.light.bg);
    expect(theme.appBarTheme.backgroundColor, ZaidangTokens.light.bg);
    expect(theme.colorScheme.primary, ZaidangTokens.light.accent);

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).image?.image ==
                const AssetImage(ArchivePage.backgroundAsset),
      ),
      findsOneWidget,
    );

    // 没有 AppBar 接管状态栏，首页要自己把图标压成深色。
    final overlay = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.descendant(
        of: find.byType(ArchivePage),
        matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      ),
    );
    expect(overlay.value.statusBarIconBrightness, Brightness.dark);
    expect(overlay.value.systemNavigationBarColor, ZaidangTokens.light.bg);
  });

  testWidgets('header survives landscape with the keyboard open', (
    tester,
  ) async {
    _useView(tester, const Size(844, 390));
    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    addTearDown(tester.view.resetViewInsets);

    await _pumpApp(tester, roles: [_sampleRole()]);

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('archive-search')), findsOneWidget);

    // 视口只剩约 134pt，头部占满；把头部拖走后列表才露出来。
    await tester.drag(find.text('记录、设定与灵感'), const Offset(0, -250));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('role-card-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'dragging the list scrolls the header away and hides the keyboard',
    (tester) async {
      _usePhoneView(tester);
      await _pumpApp(tester, roles: [_sampleRole()]);

      final search = find.byKey(const Key('archive-search'));
      await tester.enterText(search, 'a');
      await tester.pumpAndSettle();
      final editable = tester.widget<EditableText>(
        find.descendant(of: search, matching: find.byType(EditableText)),
      );
      expect(editable.focusNode.hasFocus, isTrue);
      final before = tester.getTopLeft(search).dy;

      await tester.drag(find.byType(ArchiveListCard), const Offset(0, -100));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(search).dy, lessThan(before));
      expect(editable.focusNode.hasFocus, isFalse);
    },
  );

  testWidgets('scrolling collapses the hero title into a pinned frosted bar', (
    tester,
  ) async {
    _usePhoneView(tester);
    // 状态栏归标题区吃掉，收起后的毛玻璃要铺到屏幕顶边。
    tester.view.padding = const FakeViewPadding(top: 47);
    tester.view.viewPadding = const FakeViewPadding(top: 47);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    await _pumpApp(tester, roles: [_sampleRole()]);

    final header = find.byType(SliverPersistentHeader);
    final headerBox = find
        .descendant(of: header, matching: find.byType(ClipRect))
        .first;
    final frost = find.descendant(
      of: header,
      matching: find.byType(BackdropFilter),
    );
    final title = find.text('我的 OC');
    final subtitleOpacity = find
        .ancestor(of: find.text('记录、设定与灵感'), matching: find.byType(Opacity))
        .first;
    double titleScale() => tester
        .widget<Transform>(
          find.ancestor(of: title, matching: find.byType(Transform)).first,
        )
        .transform
        .entry(0, 0);

    expect(
      find.descendant(
        of: find.byType(ArchivePage),
        matching: find.byType(SafeArea),
      ),
      findsNothing,
    );
    expect(frost, findsNothing);
    expect(titleScale(), 1.0);
    expect(tester.getTopLeft(title).dy, 47 + 16);
    expect(tester.widget<Opacity>(subtitleOpacity).opacity, 1.0);
    final restHeight = tester.getSize(headerBox).height;
    expect(restHeight, greaterThan(47 + 48));

    await tester.drag(find.byType(ArchiveListCard), const Offset(0, -500));
    await tester.pumpAndSettle();

    // 页签滚走了，标题还钉在状态栏下面，缩到 heading 字号并居中在 48 高的顶栏里。
    expect(find.widgetWithText(Tab, '世界观'), findsNothing);
    expect(title, findsOneWidget);
    expect(tester.getSize(headerBox).height, 47 + 48);
    expect(titleScale(), closeTo(20 / 26, 0.001));
    final titleRect = tester.getRect(title);
    expect(titleRect.top, closeTo(47 + (48 - titleRect.height) / 2, 0.01));
    expect(titleRect.bottom, lessThan(47 + 48));
    expect(tester.widget<Opacity>(subtitleOpacity).opacity, 0.0);
    expect(frost, findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(ArchiveListCard), const Offset(0, 500));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(Tab, '世界观'), findsOneWidget);
    expect(titleScale(), 1.0);
    expect(tester.getTopLeft(title).dy, 47 + 16);
    expect(tester.getSize(headerBox).height, restHeight);
    expect(frost, findsNothing);
  });

  testWidgets('header follows the selected archive tab', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.widgetWithText(Tab, '世界观'));
    await tester.pumpAndSettle();

    expect(find.text('我的世界观'), findsOneWidget);
    expect(find.text('我的 OC'), findsNothing);
    expect(find.text('还没有世界观'), findsOneWidget);

    await tester.tap(find.widgetWithText(Tab, 'OC'));
    await tester.pumpAndSettle();

    expect(find.text('我的 OC'), findsOneWidget);
  });

  testWidgets('add button opens create page', (tester) async {
    _usePhoneView(tester);
    await _pumpApp(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('新建角色'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '保存'), findsOneWidget);
    expect(find.byTooltip('返回'), findsOneWidget);
    expect(find.byType(CircleAvatar), findsNothing);
    expect(find.text('添加立绘'), findsOneWidget);
    expect(find.byKey(const Key('role-create-cover-portrait')), findsOneWidget);
    expect(find.text('基本信息'), findsOneWidget);
    expect(find.text('设定'), findsOneWidget);
    expect(find.text('名字'), findsWidgets);

    final hero = tester.getRect(
      find.byKey(const Key('role-create-cover-hero')),
    );
    final basicCard = tester.getRect(
      find.byKey(const Key('role-create-basic-card')),
    );
    final descCard = tester.getRect(
      find.byKey(const Key('role-create-desc-card')),
    );
    expect(hero.width, 390);
    expect(hero.height, 352);
    expect(hero.width, isNot(140));
    expect(hero.left, 0);
    expect(hero.top, 0);
    expect(basicCard.left, greaterThan(hero.left));
    expect(basicCard.right, lessThan(hero.right));
    expect(basicCard.width, lessThan(hero.width));
    expect(descCard.left, basicCard.left);
    expect(descCard.width, basicCard.width);
    expect(descCard.top, greaterThan(basicCard.bottom));

    final cardBox = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byKey(const Key('role-create-basic-card')),
        matching: find.byType(DecoratedBox),
      ),
    );
    final decoration = cardBox.decoration as BoxDecoration;
    expect(decoration.color, ZaidangTokens.light.surface);
    expect(decoration.border, isA<Border>());
  });

  testWidgets('create page requires a name then saves a new role', (
    tester,
  ) async {
    _usePhoneView(tester);
    await _pumpApp(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.text('请填写名字'), findsOneWidget);
    expect(find.text('新建角色'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, '名字'), 'Nana');
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.text('新建角色'), findsNothing);
    expect(find.text('Nana'), findsOneWidget);
  });

  testWidgets('create page caps hero width on a wide window', (tester) async {
    _useView(tester, const Size(800, 1200));
    await _pumpApp(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final hero = tester.getRect(
      find.byKey(const Key('role-create-cover-hero')),
    );
    expect(hero.width, 800);
    expect(hero.height, 352);
    expect(hero.left, 0);
    expect(hero.top, 0);
  });

  testWidgets('role list shows cards from repository', (tester) async {
    await _pumpApp(tester, roles: [_sampleRole()]);

    final card = find.byKey(const Key('role-card-1'));
    expect(card, findsOneWidget);
    expect(find.byType(ArchiveListCard), findsOneWidget);
    for (final text in ['Ada', 'human', 'engineer', 'female', '「sample」']) {
      expect(
        find.descendant(of: card, matching: find.text(text)),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(of: card, matching: find.text('0 份资产')),
      findsOneWidget,
    );
    expect(find.text('还没有角色'), findsNothing);
  });

  testWidgets('search filters roles and can be cleared', (tester) async {
    await _pumpApp(
      tester,
      roles: [
        _sampleRole(),
        const Role(
          id: 2,
          name: '白鸦',
          sex: '女',
          age: '',
          birthday: '',
          race: '鸟人',
          occupation: '信使',
          desc: '第一行\n第二行',
          coverImg: '',
        ),
      ],
    );

    expect(find.byType(ArchiveListCard), findsNWidgets(2));
    expect(find.byKey(const Key('archive-search-clear')), findsNothing);

    await tester.enterText(find.byKey(const Key('archive-search')), ' 信使 ');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('role-card-2')), findsOneWidget);
    expect(find.byKey(const Key('role-card-1')), findsNothing);
    expect(find.text('「第一行」'), findsOneWidget);
    expect(find.textContaining('第二行'), findsNothing);

    await tester.enterText(find.byKey(const Key('archive-search')), 'ENGINEER');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('role-card-1')), findsOneWidget);
    expect(find.byKey(const Key('role-card-2')), findsNothing);

    await tester.enterText(find.byKey(const Key('archive-search')), '不存在');
    await tester.pumpAndSettle();

    expect(find.byType(ArchiveListCard), findsNothing);
    expect(find.text('没有匹配的角色'), findsOneWidget);
    expect(find.text('还没有角色'), findsNothing);

    await tester.tap(find.byKey(const Key('archive-search-clear')));
    await tester.pumpAndSettle();

    expect(find.byType(ArchiveListCard), findsNWidgets(2));
    expect(find.byKey(const Key('archive-search-clear')), findsNothing);

    // 只输入空格：不过滤，但框里有字所以清除按钮要在。
    await tester.enterText(find.byKey(const Key('archive-search')), '   ');
    await tester.pumpAndSettle();

    expect(find.byType(ArchiveListCard), findsNWidgets(2));
    expect(find.byKey(const Key('archive-search-clear')), findsOneWidget);
  });

  testWidgets('tapping a role opens the edit page and saves changes', (
    tester,
  ) async {
    _usePhoneView(tester);
    await _pumpApp(tester, roles: [_sampleRole()]);

    await tester.tap(find.text('Ada'));
    await tester.pumpAndSettle();

    expect(find.text('编辑角色'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Ada'), findsOneWidget);
    expect(find.text('修改历史'), findsOneWidget);

    final nameField = find.widgetWithText(TextFormField, 'Ada');
    await tester.ensureVisible(nameField);
    await tester.enterText(nameField, 'Ada L');
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.text('编辑角色'), findsNothing);
    expect(find.text('Ada L'), findsOneWidget);
    expect(find.text('human'), findsOneWidget);
    expect(find.text('engineer'), findsOneWidget);
    expect(find.text('female'), findsOneWidget);
  });

  testWidgets('edit page can open 设定 history', (tester) async {
    _usePhoneView(tester);
    await _pumpApp(tester, roles: [_sampleRole()]);

    await tester.tap(find.text('Ada'));
    await tester.pumpAndSettle();

    expect(find.text('修改历史'), findsOneWidget);

    await tester.ensureVisible(find.text('修改历史'));
    await tester.tap(find.text('修改历史'));
    await tester.pumpAndSettle();

    expect(find.text('设定修改历史'), findsOneWidget);
    expect(find.text('当前'), findsOneWidget);
    expect(find.text('sample'), findsOneWidget);
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  List<Role> roles = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        roleRepositoryProvider.overrideWithValue(FakeRoleRepository(roles)),
        roleAssetRepositoryProvider.overrideWithValue(
          FakeRoleAssetRepository(),
        ),
        worldRepositoryProvider.overrideWithValue(FakeWorldRepository()),
      ],
      child: const MyApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void _usePhoneView(WidgetTester tester) {
  _useView(tester, const Size(390, 1200));
}

void _useView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Role _sampleRole() {
  return const Role(
    id: 1,
    name: 'Ada',
    sex: 'female',
    age: '17',
    birthday: '三月三日',
    race: 'human',
    occupation: 'engineer',
    desc: 'sample',
    coverImg: '',
  );
}
