import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/app.dart';
import 'package:ochome/data/models/role.dart';
import 'package:ochome/data/providers/role_assets_provider.dart';
import 'package:ochome/data/providers/role_repository_provider.dart';
import 'package:ochome/data/providers/backup_coordinator_provider.dart';
import 'package:ochome/data/providers/world_repository_provider.dart';
import 'package:ochome/features/backup/backup_models.dart';
import 'package:ochome/pages/archive_page.dart';
import 'package:ochome/pages/role_list_page.dart';
import 'package:ochome/theme/zaidang_tokens.dart';

import '../fakes/fake_role_asset_repository.dart';
import '../fakes/fake_role_repository.dart';
import '../fakes/fake_world_repository.dart';

void main() {
  testWidgets('cold start shows 档案 with both tabs', (tester) async {
    await _pumpApp(tester);

    expect(find.text('我的 OC'), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(RoleListPage), findsOneWidget);
    expect(find.widgetWithText(Tab, 'OC'), findsOneWidget);
    expect(find.widgetWithText(Tab, '世界观'), findsOneWidget);
    expect(find.byTooltip('备份与恢复'), findsOneWidget);
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
    expect(find.text('我的 OC'), findsNothing);
    expect(find.text('Ada'), findsNothing);
    expect(find.text('还没有角色'), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byTooltip('备份与恢复'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(_tab('档案'));
    await tester.pumpAndSettle();

    expect(find.text('我的 OC'), findsOneWidget);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.element(find.byType(RoleListPage)), same(listElement));
  });

  testWidgets('archive tabs preserve the OC list and selected inner tab', (
    tester,
  ) async {
    _useView(tester, const Size(390, 844));
    await _pumpApp(
      tester,
      roles: List.generate(
        30,
        (index) => _sampleRole(id: index + 1, name: 'OC $index'),
      ),
    );

    final listElement = tester.element(find.byType(RoleListPage));
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    // 头部随列表滚走后页签不可点；往回拖一段，浮动头部先回来，列表位置只小幅回退。
    expect(find.widgetWithText(Tab, '世界观'), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(Tab, '世界观'), findsOneWidget);
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    final offset = scrollable.position.pixels;
    expect(offset, greaterThan(0));

    await tester.tap(find.widgetWithText(Tab, '世界观'));
    await tester.pumpAndSettle();
    expect(find.text('还没有世界观'), findsOneWidget);
    expect(find.byTooltip('添加世界观'), findsOneWidget);
    expect(find.byTooltip('添加角色'), findsNothing);
    expect(find.byTooltip('备份与恢复'), findsOneWidget);

    await tester.tap(_tab('我的'));
    await tester.pumpAndSettle();
    await tester.tap(_tab('档案'));
    await tester.pumpAndSettle();
    expect(find.text('还没有世界观'), findsOneWidget);

    await tester.drag(find.byType(TabBarView), const Offset(350, 0));
    await tester.pumpAndSettle();
    expect(find.byTooltip('添加角色'), findsOneWidget);
    expect(tester.element(find.byType(RoleListPage)), same(listElement));
    expect(scrollable.position.pixels, offset);
    expect(tester.takeException(), isNull);
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
    expect(find.text('我的 OC'), findsOneWidget);
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
    expect(find.text('我的 OC'), findsOneWidget);
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

    expect(find.text('我的 OC'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets(
    'compact tab bar preserves the phone safe area and FAB clearance',
    (tester) async {
      _useView(tester, const Size(390, 844));
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      await _pumpApp(tester);

      for (final bottomInset in [0.0, 34.0]) {
        tester.view.padding = FakeViewPadding(bottom: bottomInset);
        tester.view.viewPadding = FakeViewPadding(bottom: bottomInset);
        await tester.pumpAndSettle();

        final fab = tester.getRect(find.byType(FloatingActionButton));
        final tabBar = tester.getRect(find.byType(NavigationBar));
        expect(tabBar.height, 56 + bottomInset);
        expect(tabBar.bottom, 844);
        expect(fab.bottom, lessThan(tabBar.top));
        for (final label in ['档案', '我的']) {
          expect(
            tester.getRect(_tab(label)).bottom,
            lessThanOrEqualTo(844 - bottomInset),
          );
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'keyboard shrinks the archive body but not its paper background',
    (tester) async {
      _useView(tester, const Size(390, 844));
      addTearDown(tester.view.resetViewInsets);
      await _pumpApp(tester, roles: [_sampleRole()]);

      final paper = find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).image?.image ==
                const AssetImage(ArchivePage.backgroundAsset),
      );
      final shellBody = tester.getRect(find.byType(ArchivePage));
      final paperBefore = tester.getRect(paper);
      final listBefore = tester.getRect(find.byType(RoleListPage));
      expect(paperBefore, shellBody);

      const keyboardTop = 844.0 - 300;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();

      expect(tester.getRect(paper), paperBefore);
      expect(tester.getRect(find.byType(ArchivePage)), shellBody);
      final listAfter = tester.getRect(find.byType(RoleListPage));
      expect(listAfter.top, listBefore.top);
      // The tab bar is already under the keyboard, so the branch must not
      // subtract it again: the list ends on the keyboard edge, not above a gap.
      expect(listAfter.bottom, keyboardTop);
      final fab = tester.getRect(find.byType(FloatingActionButton));
      expect(fab.bottom, keyboardTop - kFloatingActionButtonMargin);
      expect(tester.takeException(), isNull);

      tester.view.viewInsets = const FakeViewPadding(bottom: 20);
      await tester.pumpAndSettle();

      // An inset shorter than the tab bar never reaches the branch page.
      expect(tester.getRect(find.byType(RoleListPage)), listBefore);
      expect(tester.getRect(paper), paperBefore);
    },
  );

  testWidgets('system back from 我的 returns to 档案', (tester) async {
    await _pumpApp(tester);

    await tester.tap(_tab('我的'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '我的'), findsOneWidget);

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(handled, isTrue);
    expect(find.byType(MyApp), findsOneWidget);
    expect(find.text('我的 OC'), findsOneWidget);
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
        roleAssetRepositoryProvider.overrideWithValue(
          FakeRoleAssetRepository(),
        ),
        worldRepositoryProvider.overrideWithValue(FakeWorldRepository()),
        // This suite tests routing, not disk bootstrap or iCloud availability.
        backupCoordinatorProvider.overrideWith((ref) async {
          throw const BackupFailure('test_unavailable', '测试环境未连接备份服务');
        }),
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

Role _sampleRole({int id = 1, String name = 'Ada'}) {
  return Role(
    id: id,
    name: name,
    sex: 'female',
    age: '17',
    birthday: '三月三日',
    race: 'human',
    occupation: 'engineer',
    desc: 'sample',
    coverImg: '',
  );
}
