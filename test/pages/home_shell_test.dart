import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/app.dart';
import 'package:ochome/data/models/role.dart';
import 'package:ochome/data/providers/role_repository_provider.dart';
import 'package:ochome/pages/role_list_page.dart';
import 'package:ochome/theme/zaidang_tokens.dart';

import '../fakes/fake_role_repository.dart';

void main() {
  testWidgets('cold start shows 档案 with both tabs', (tester) async {
    await _pumpApp(tester);

    expect(find.widgetWithText(AppBar, '角色'), findsOneWidget);
    expect(find.byType(RoleListPage), findsOneWidget);
    expect(find.text('还没有角色'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(_tab('档案'), findsOneWidget);
    expect(_tab('我的'), findsOneWidget);

    final theme = Theme.of(tester.element(find.byType(NavigationBar)));
    expect(theme.scaffoldBackgroundColor, ZaidangTokens.light.bg);
    expect(theme.navigationBarTheme.backgroundColor, ZaidangTokens.light.bg);
    expect(theme.navigationBarTheme.indicatorColor, Colors.transparent);
    expect(
      theme.navigationBarTheme.iconTheme!.resolve({
        WidgetState.selected,
      })!.color,
      ZaidangTokens.light.accent,
    );

    final edge = tester.widget<Divider>(
      find.byKey(const Key('home-shell-tab-edge')),
    );
    expect(edge.height, 1);
    expect(theme.dividerTheme.color, ZaidangTokens.light.border);
  });

  testWidgets('我的 is blank and 档案 round trip keeps the list', (tester) async {
    await _pumpApp(tester, roles: [_sampleRole()]);

    final listElement = tester.element(find.byType(RoleListPage));
    expect(find.text('Ada'), findsOneWidget);

    await tester.tap(_tab('我的'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, '我的'), findsOneWidget);
    expect(find.widgetWithText(AppBar, '角色'), findsNothing);
    expect(find.text('Ada'), findsNothing);
    expect(find.text('还没有角色'), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byTooltip('备份与恢复'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(_tab('档案'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, '角色'), findsOneWidget);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.element(find.byType(RoleListPage)), same(listElement));
  });

  testWidgets('create covers the tab bar and pops back to 档案', (tester) async {
    _usePhoneView(tester);
    await _pumpApp(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('新建角色'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.enterText(find.widgetWithText(TextFormField, '名字'), 'Nana');
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.text('新建角色'), findsNothing);
    expect(find.widgetWithText(AppBar, '角色'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Nana'), findsOneWidget);
  });

  testWidgets('edit covers the tab bar and returns the updated row', (
    tester,
  ) async {
    _usePhoneView(tester);
    await _pumpApp(tester, roles: [_sampleRole()]);

    await tester.tap(find.text('Ada'));
    await tester.pumpAndSettle();

    expect(find.text('编辑角色'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    final nameField = find.widgetWithText(TextFormField, 'Ada');
    await tester.ensureVisible(nameField);
    await tester.enterText(nameField, 'Ada L');
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.text('编辑角色'), findsNothing);
    expect(find.widgetWithText(AppBar, '角色'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Ada L'), findsOneWidget);
  });

  testWidgets('cloud action covers the tab bar', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.byTooltip('备份与恢复'));
    await tester.pumpAndSettle();

    expect(find.text('备份与恢复'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, '角色'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('FAB sits above the tab bar on a phone frame', (tester) async {
    _useView(tester, const Size(390, 844));
    await _pumpApp(tester);

    final fab = tester.getRect(find.byType(FloatingActionButton));
    final tabBar = tester.getRect(find.byType(NavigationBar));
    expect(fab.bottom, lessThan(tabBar.top));
  });

  testWidgets('system back from 我的 returns to 档案', (tester) async {
    await _pumpApp(tester);

    await tester.tap(_tab('我的'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '我的'), findsOneWidget);

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(handled, isTrue);
    expect(find.byType(MyApp), findsOneWidget);
    expect(find.widgetWithText(AppBar, '角色'), findsOneWidget);
    expect(find.text('还没有角色'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}

Finder _tab(String label) {
  return find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(label),
  );
}

Future<void> _pumpApp(
  WidgetTester tester, {
  List<Role> roles = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        roleRepositoryProvider.overrideWithValue(FakeRoleRepository(roles)),
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
