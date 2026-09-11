import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ochome/data/models/world.dart';
import 'package:ochome/data/models/world_entry.dart';
import 'package:ochome/data/providers/world_repository_provider.dart';
import 'package:ochome/pages/world_view_page.dart';
import 'package:ochome/theme/zaidang_theme.dart';
import 'package:ochome/theme/zaidang_tokens.dart';
import 'package:ochome/widgets/archive_list_card.dart';

import '../fakes/fake_world_repository.dart';

void main() {
  testWidgets('empty list shows placeholder and an add action', (tester) async {
    await _pump(tester, FakeWorldRepository());

    expect(find.text('还没有世界观'), findsOneWidget);
    expect(find.byTooltip('添加世界观'), findsOneWidget);
    final placeholder = tester.widget<Text>(find.text('还没有世界观'));
    expect(placeholder.style!.color, ZaidangTokens.light.inkSecondary);
  });

  testWidgets('cards show name, first summary line and route with extra', (
    tester,
  ) async {
    final worlds = [
      _world(id: 1, name: '艾尔登', summary: '被火漆封印的大陆\n第二行不显示'),
      _world(id: 2, name: '雾都', summary: ''),
    ];
    final pushed = <(String, Object?)>[];
    final router = await _pump(
      tester,
      FakeWorldRepository(worlds),
      onPush: pushed.add,
    );

    expect(find.byType(ArchiveListCard), findsNWidgets(2));
    expect(find.text('艾尔登'), findsOneWidget);
    expect(find.text('「被火漆封印的大陆」'), findsOneWidget);
    expect(find.textContaining('第二行'), findsNothing);
    expect(find.text('雾都'), findsOneWidget);
    expect(find.text('1 个词条'), findsNWidgets(2));
    expect(find.byIcon(Icons.public_outlined), findsNWidgets(2));

    await tester.tap(find.text('雾都'));
    await tester.pumpAndSettle();
    expect(pushed.single.$1, '/worlds/2');
    expect(pushed.single.$2, worlds[1]);
    expect(find.text('edit-world-route'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('添加世界观'));
    await tester.pumpAndSettle();
    expect(pushed.last.$1, '/worlds/new');
    expect(pushed.last.$2, isNull);
  });

  testWidgets('list follows repository stream updates', (tester) async {
    final repository = FakeWorldRepository();
    await _pump(tester, repository);
    expect(find.text('还没有世界观'), findsOneWidget);

    await repository.create(name: '新世界', summary: '', coverImg: '');
    await tester.pumpAndSettle();
    expect(find.text('新世界'), findsOneWidget);
    expect(find.text('还没有世界观'), findsNothing);
  });

  testWidgets('query matches name, summary and entries', (tester) async {
    final worlds = [
      _world(id: 1, name: '艾尔登', summary: '被火漆封印的大陆'),
      _world(id: 2, name: '雾都', summary: ''),
    ];

    await _pump(tester, FakeWorldRepository(worlds), query: '封印');
    expect(find.byKey(const Key('world-card-1')), findsOneWidget);
    expect(find.byKey(const Key('world-card-2')), findsNothing);

    await _pump(tester, FakeWorldRepository(worlds), query: '地理');
    expect(find.byType(ArchiveListCard), findsNWidgets(2));

    await _pump(tester, FakeWorldRepository(worlds), query: '不存在');
    expect(find.byType(ArchiveListCard), findsNothing);
    expect(find.text('没有匹配的世界观'), findsOneWidget);
    expect(find.text('还没有世界观'), findsNothing);
  });
}

Future<GoRouter> _pump(
  WidgetTester tester,
  FakeWorldRepository repository, {
  void Function((String, Object?) push)? onPush,
  String query = '',
}) async {
  final router = GoRouter(
    initialLocation: '/archive',
    routes: [
      GoRoute(
        path: '/archive',
        builder: (context, state) => WorldViewPage(query: query),
      ),
      GoRoute(
        path: '/worlds/new',
        builder: (context, state) {
          onPush?.call(('/worlds/new', state.extra));
          return const Scaffold(body: Text('new-world-route'));
        },
      ),
      GoRoute(
        path: '/worlds/:id',
        builder: (context, state) {
          onPush?.call(('/worlds/${state.pathParameters['id']}', state.extra));
          return const Scaffold(body: Text('edit-world-route'));
        },
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [worldRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp.router(
        theme: zaidangLightTheme(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

World _world({required int id, required String name, String summary = ''}) {
  return World(
    id: id,
    name: name,
    summary: summary,
    coverImg: '',
    entries: const [WorldEntry(title: '地理', content: '')],
  );
}
