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
    expect(find.text('还没有角色'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);

    final theme = Theme.of(tester.element(find.byType(RoleListPage)));
    expect(theme.scaffoldBackgroundColor, ZaidangTokens.light.bg);
    expect(theme.appBarTheme.backgroundColor, ZaidangTokens.light.bg);
    expect(theme.colorScheme.primary, ZaidangTokens.light.accent);

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, isNull);
  });

  testWidgets('add button opens create page', (tester) async {
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

    await tester.enterText(find.widgetWithText(TextFormField, 'Ada'), 'Ada L');
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.text('编辑角色'), findsNothing);
    expect(find.text('Ada L'), findsOneWidget);
    expect(find.text('human · engineer · female'), findsOneWidget);
  });
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
