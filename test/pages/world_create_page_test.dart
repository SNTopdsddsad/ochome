import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ochome/data/models/role.dart';
import 'package:ochome/data/models/world.dart';
import 'package:ochome/data/models/world_entry.dart';
import 'package:ochome/data/providers/role_repository_provider.dart';
import 'package:ochome/data/providers/world_repository_provider.dart';
import 'package:ochome/pages/world_create_page.dart';
import 'package:ochome/theme/zaidang_theme.dart';
import 'package:ochome/theme/zaidang_tokens.dart';

import '../fakes/fake_cover_image_picker.dart';
import '../fakes/fake_role_repository.dart';
import '../fakes/fake_world_repository.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('world_create');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('create saves name, summary and ordered entries then pops', (
    tester,
  ) async {
    _usePhoneView(tester);
    final worlds = FakeWorldRepository();
    await tester.pumpWidget(_wrap(worlds, FakeRoleRepository(), tempDir));
    await tester.pumpAndSettle();

    expect(find.text('新建世界观'), findsOneWidget);
    expect(find.text('添加封面'), findsOneWidget);
    expect(find.byKey(const Key('world-detail-tabs')), findsNothing);
    expect(find.byKey(const Key('world-more-action')), findsNothing);

    await tester.enterText(find.widgetWithText(TextFormField, '名称'), ' 艾尔登 ');
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('world-create-summary-card')),
        matching: find.byType(TextFormField),
      ),
      '被封印的大陆',
    );

    await tester.tap(find.byKey(const Key('world-entry-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, '词条标题'), '地理');
    await tester.enterText(
      find.widgetWithText(TextFormField, '词条内容'),
      '北方雪原\n南方海',
    );
    await tester.tap(find.byKey(const Key('world-entry-add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, '词条标题').last,
      '势力',
    );

    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();

    final saved = (await worlds.list()).single;
    expect(saved.name, '艾尔登');
    expect(saved.summary, '被封印的大陆');
    expect(saved.entries, const [
      WorldEntry(title: '地理', content: '北方雪原\n南方海'),
      WorldEntry(title: '势力', content: ''),
    ]);
    expect(find.text('新建世界观'), findsNothing);
    expect(find.text('previous-route'), findsOneWidget);
  });

  testWidgets('empty name and blank entry titles block saving', (tester) async {
    _usePhoneView(tester);
    final worlds = FakeWorldRepository();
    await tester.pumpWidget(_wrap(worlds, FakeRoleRepository(), tempDir));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();
    expect(find.text('请填写名称'), findsOneWidget);
    expect(await worlds.list(), isEmpty);

    await tester.enterText(find.widgetWithText(TextFormField, '名称'), '雾都');
    await tester.tap(find.byKey(const Key('world-entry-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.text('请填写每条词条的标题'), findsOneWidget);
    expect(find.text('请填写词条标题'), findsOneWidget);
    expect(await worlds.list(), isEmpty);
    expect(find.text('新建世界观'), findsOneWidget);
  });

  testWidgets('failed save keeps the draft and reports the error', (
    tester,
  ) async {
    _usePhoneView(tester);
    final worlds = FakeWorldRepository()
      ..nextWriteError = StateError('disk full');
    await tester.pumpWidget(_wrap(worlds, FakeRoleRepository(), tempDir));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, '名称'), '雾都');
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.textContaining('保存失败'), findsOneWidget);
    expect(find.text('新建世界观'), findsOneWidget);
    expect(find.text('雾都'), findsWidgets);
    expect(await worlds.list(), isEmpty);
  });

  testWidgets('editing shows 详情 / 角色 tabs, keeps drafts and lists members', (
    tester,
  ) async {
    _usePhoneView(tester);
    final world = _world();
    final worlds = FakeWorldRepository([world]);
    final roles = FakeRoleRepository([
      _role(id: 1, name: '成员甲', worldId: world.id),
      _role(id: 2, name: '路人', worldId: null),
      _role(id: 3, name: '成员乙', worldId: world.id),
    ]);
    final pushedRoles = <Object?>[];
    await tester.pumpWidget(
      _wrap(worlds, roles, tempDir, world: world, onRolePush: pushedRoles.add),
    );
    await tester.pumpAndSettle();

    expect(find.text('编辑世界观'), findsOneWidget);
    expect(find.byKey(const Key('world-detail-tabs')), findsOneWidget);
    expect(find.widgetWithText(Tab, '详情'), findsOneWidget);
    expect(find.widgetWithText(Tab, '角色'), findsOneWidget);
    expect(find.text('地理'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, '名称'), '艾尔登·改');

    await tester.tap(find.widgetWithText(Tab, '角色'));
    await tester.pumpAndSettle();
    expect(find.text('成员甲'), findsOneWidget);
    expect(find.text('成员乙'), findsOneWidget);
    expect(find.text('路人'), findsNothing);

    await tester.tap(find.text('成员乙'));
    await tester.pumpAndSettle();
    expect(pushedRoles.single, isA<Role>().having((r) => r.id, 'id', 3));
    expect(find.text('role-route'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(Tab, '详情'));
    await tester.pumpAndSettle();
    expect(find.text('艾尔登·改'), findsWidgets);

    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();
    final saved = (await worlds.list()).single;
    expect(saved.name, '艾尔登·改');
    expect(saved.entries, world.entries);
  });

  testWidgets('roles tab shows an empty state when nothing belongs', (
    tester,
  ) async {
    _usePhoneView(tester);
    final world = _world();
    await tester.pumpWidget(
      _wrap(
        FakeWorldRepository([world]),
        FakeRoleRepository([_role(id: 1, name: '路人')]),
        tempDir,
        world: world,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(Tab, '角色'));
    await tester.pumpAndSettle();
    expect(find.text('还没有角色归属这个世界观'), findsOneWidget);
    expect(find.text('路人'), findsNothing);
  });

  for (final dark in [false, true]) {
    testWidgets(
      '${dark ? 'dark' : 'light'} delete asks for confirmation, keeps roles and pops',
      (tester) async {
        _usePhoneView(tester);
        final world = _world();
        final worlds = FakeWorldRepository([world]);
        final roles = FakeRoleRepository([
          _role(id: 1, name: '成员甲', worldId: world.id),
        ]);
        worlds.onDelete = roles.detachWorld;
        await tester.pumpWidget(
          _wrap(
            worlds,
            roles,
            tempDir,
            world: world,
            theme: dark ? zaidangDarkTheme() : zaidangLightTheme(),
          ),
        );
        await tester.pumpAndSettle();
        final tokens = dark ? ZaidangTokens.dark : ZaidangTokens.light;

        await tester.tap(find.byKey(const Key('world-more-action')));
        await tester.pumpAndSettle();
        final deleteTile = find.byKey(const Key('world-delete-action'));
        expect(deleteTile, findsOneWidget);
        final deleteIcon = tester.widget<Icon>(
          find.descendant(of: deleteTile, matching: find.byType(Icon)),
        );
        expect(deleteIcon.color, tokens.ink);
        expect(deleteIcon.color, isNot(tokens.accent));

        // 取消：什么都不发生。
        await tester.tap(deleteTile);
        await tester.pumpAndSettle();
        expect(find.text('要删掉这个世界观吗？'), findsOneWidget);
        expect(find.textContaining('不会被删除'), findsOneWidget);
        await tester.tap(find.byKey(const Key('zaidang-confirm-cancel')));
        await tester.pumpAndSettle();
        expect(worlds.deletedIds, isEmpty);
        expect(find.text('编辑世界观'), findsOneWidget);

        // 确认：删除、角色保留并解除归属、返回上一页。
        await tester.tap(find.byKey(const Key('world-more-action')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('world-delete-action')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('zaidang-confirm-action')));
        await tester.pumpAndSettle();

        expect(worlds.deletedIds, [world.id]);
        expect(await worlds.list(), isEmpty);
        final member = (await roles.list()).single;
        expect(member.name, '成员甲');
        expect(member.worldId, isNull);
        expect(find.text('编辑世界观'), findsNothing);
        expect(find.text('previous-route'), findsOneWidget);
      },
    );
  }

  testWidgets('picking a cover shows 更换封面 and persists the path', (
    tester,
  ) async {
    _usePhoneView(tester);
    // 真实文件 IO 不能在假异步的测试体里直接 await。
    await tester.runAsync(() => _writeCover(tempDir, 'picked.png'));
    final picker = FakeCoverImagePicker('covers/picked.png');
    final worlds = FakeWorldRepository();
    await tester.pumpWidget(
      _wrap(worlds, FakeRoleRepository(), tempDir, picker: picker),
    );
    await _pump(tester);
    expect(find.text('添加封面'), findsOneWidget);
    expect(find.byTooltip('更换封面'), findsNothing);

    await tester.tap(find.byKey(const Key('world-create-cover-portrait')));
    await _pump(tester);
    expect(picker.pickCalls, 1);
    expect(find.byTooltip('更换封面'), findsOneWidget);
    expect(find.text('添加封面'), findsNothing);

    await tester.enterText(find.widgetWithText(TextFormField, '名称'), '雾都');
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await _pump(tester);
    expect((await worlds.list()).single.coverImg, 'covers/picked.png');
  });
}

/// 1×1 透明 PNG，供 [CoverFileView] 真正解码。
const List<int> _transparentPng = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, //
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, //
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, //
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, //
  0x42, 0x60, 0x82,
];

Future<void> _writeCover(Directory tempDir, String name) async {
  final coverDir = Directory('${tempDir.path}/covers');
  await coverDir.create(recursive: true);
  await File('${coverDir.path}/$name')
      .writeAsBytes(_transparentPng, flush: true);
}

/// 真实图片解码在假异步下不会静止，用有界帧推进替代 pumpAndSettle。
Future<void> _pump(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
}

Widget _wrap(
  FakeWorldRepository worlds,
  FakeRoleRepository roles,
  Directory tempDir, {
  World? world,
  FakeCoverImagePicker? picker,
  ThemeData? theme,
  void Function(Object? extra)? onRolePush,
}) {
  final router = GoRouter(
    initialLocation: '/edit',
    routes: [
      GoRoute(
        path: '/home',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('previous-route'))),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (context, state) => WorldCreatePage(
              world: world,
              picker: picker ?? FakeCoverImagePicker(),
              supportDirectory: () async => tempDir,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/roles/:id',
        builder: (context, state) {
          onRolePush?.call(state.extra);
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('role-route')),
          );
        },
      ),
    ],
    redirect: (context, state) =>
        state.uri.path == '/edit' ? '/home/edit' : null,
  );
  return ProviderScope(
    overrides: [
      worldRepositoryProvider.overrideWithValue(worlds),
      roleRepositoryProvider.overrideWithValue(roles),
    ],
    child: MaterialApp.router(
      theme: theme ?? zaidangLightTheme(),
      routerConfig: router,
    ),
  );
}

void _usePhoneView(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

World _world() {
  return const World(
    id: 7,
    name: '艾尔登',
    summary: '被封印的大陆',
    coverImg: '',
    entries: [WorldEntry(title: '地理', content: '北方雪原')],
  );
}

Role _role({required int id, required String name, int? worldId}) {
  return Role(
    id: id,
    name: name,
    sex: '',
    age: '',
    birthday: '',
    race: '',
    occupation: '',
    desc: '',
    coverImg: '',
    worldId: worldId,
  );
}
