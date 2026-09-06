import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/app.dart';
import 'package:ochome/data/models/role.dart';
import 'package:ochome/data/providers/role_repository_provider.dart';
import 'package:ochome/pages/role_list_page.dart';
import 'package:ochome/theme/zaidang_tokens.dart';

import 'fakes/fake_role_repository.dart';

void main() {
  testWidgets('empty role list shows placeholder', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          roleRepositoryProvider.overrideWithValue(FakeRoleRepository()),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('角色'), findsOneWidget);
    expect(find.text('档案'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
    expect(find.text('还没有角色'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    final theme = Theme.of(tester.element(find.byType(RoleListPage)));
    expect(theme.scaffoldBackgroundColor, ZaidangTokens.light.bg);
    expect(theme.appBarTheme.backgroundColor, ZaidangTokens.light.bg);
    expect(theme.colorScheme.primary, ZaidangTokens.light.accent);

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, isNull);
  });

  testWidgets('add button opens create page', (tester) async {
    _usePhoneView(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          roleRepositoryProvider.overrideWithValue(FakeRoleRepository()),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

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
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          roleRepositoryProvider.overrideWithValue(FakeRoleRepository()),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

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
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          roleRepositoryProvider.overrideWithValue(FakeRoleRepository()),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

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

  testWidgets('role list shows names from repository', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          roleRepositoryProvider.overrideWithValue(
            FakeRoleRepository([_sampleRole()]),
          ),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('human · engineer · female'), findsOneWidget);
    expect(find.text('还没有角色'), findsNothing);
  });

  testWidgets('tapping a role opens the edit page and saves changes', (
    tester,
  ) async {
    _usePhoneView(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          roleRepositoryProvider.overrideWithValue(
            FakeRoleRepository([_sampleRole()]),
          ),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

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
    expect(find.text('human · engineer · female'), findsOneWidget);
  });

  testWidgets('edit page can open 设定 history', (tester) async {
    _usePhoneView(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          roleRepositoryProvider.overrideWithValue(
            FakeRoleRepository([_sampleRole()]),
          ),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

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
