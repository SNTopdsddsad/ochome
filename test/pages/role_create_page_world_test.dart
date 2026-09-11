import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/data/models/role.dart';
import 'package:ochome/data/models/world.dart';
import 'package:ochome/data/providers/role_repository_provider.dart';
import 'package:ochome/data/providers/world_repository_provider.dart';
import 'package:ochome/pages/role_create_page.dart';
import 'package:ochome/theme/zaidang_theme.dart';
import 'package:ochome/theme/zaidang_tokens.dart';

import '../fakes/fake_cover_image_picker.dart';
import '../fakes/fake_role_repository.dart';
import '../fakes/fake_world_repository.dart';

void main() {
  final worldA = const World(id: 1, name: '艾尔登', summary: '', coverImg: '');
  final worldB = const World(id: 2, name: '雾都', summary: '', coverImg: '');

  testWidgets('new role defaults to 未归属 and saves the picked world', (
    tester,
  ) async {
    _usePhoneView(tester);
    final roles = FakeRoleRepository();
    await tester.pumpWidget(
      _wrap(roles, FakeWorldRepository([worldA, worldB])),
    );
    await tester.pumpAndSettle();

    final row = find.byKey(const Key('role-world-row'));
    await tester.ensureVisible(row);
    expect(
      find.descendant(of: row, matching: find.text('未归属')),
      findsOneWidget,
    );
    final placeholder = tester.widget<Text>(
      find.descendant(of: row, matching: find.text('未归属')),
    );
    expect(placeholder.style!.color, ZaidangTokens.light.inkSecondary);

    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('role-world-picker')), findsOneWidget);
    expect(find.text('不归属'), findsOneWidget);
    expect(find.text('艾尔登'), findsOneWidget);
    expect(find.text('雾都'), findsOneWidget);

    await tester.tap(find.byKey(const Key('role-world-option-2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('role-world-picker')), findsNothing);
    expect(find.descendant(of: row, matching: find.text('雾都')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('role-field-name')), 'Nana');
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();

    final saved = (await roles.list()).single;
    expect(saved.name, 'Nana');
    expect(saved.worldId, 2);
  });

  testWidgets('editing preselects the role world and 不归属 clears it', (
    tester,
  ) async {
    _usePhoneView(tester);
    final role = _role(worldId: 1);
    final roles = FakeRoleRepository([role]);
    await tester.pumpWidget(
      _wrap(roles, FakeWorldRepository([worldA, worldB]), role: role),
    );
    await tester.pumpAndSettle();

    final row = find.byKey(const Key('role-world-row'));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: row, matching: find.text('艾尔登')),
      findsOneWidget,
    );

    await tester.tap(row);
    await tester.pumpAndSettle();
    final checked = find.descendant(
      of: find.byKey(const Key('role-world-option-1')),
      matching: find.byIcon(Icons.check),
    );
    expect(checked, findsOneWidget);
    expect(tester.widget<Icon>(checked).color, ZaidangTokens.light.accent);

    await tester.tap(find.byKey(const Key('role-world-option-none')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: row, matching: find.text('未归属')),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();
    expect((await roles.getById(role.id))!.worldId, isNull);
  });

  testWidgets('dismissing the picker keeps the current choice', (tester) async {
    _usePhoneView(tester);
    final role = _role(worldId: 1);
    final roles = FakeRoleRepository([role]);
    await tester.pumpWidget(
      _wrap(roles, FakeWorldRepository([worldA]), role: role),
    );
    await tester.pumpAndSettle();

    final row = find.byKey(const Key('role-world-row'));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    // 点弹层外的空白关闭。
    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('role-world-picker')), findsNothing);
    expect(
      find.descendant(of: row, matching: find.text('艾尔登')),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();
    expect((await roles.getById(role.id))!.worldId, 1);
  });

  testWidgets('a world deleted while editing is saved as 未归属', (tester) async {
    _usePhoneView(tester);
    final role = _role(worldId: 1);
    final roles = FakeRoleRepository([role]);
    final worlds = FakeWorldRepository([worldA]);
    await tester.pumpWidget(_wrap(roles, worlds, role: role));
    await tester.pumpAndSettle();

    final row = find.byKey(const Key('role-world-row'));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: row, matching: find.text('艾尔登')),
      findsOneWidget,
    );

    await worlds.delete(1);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: row, matching: find.text('未归属')),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();
    final saved = (await roles.getById(role.id))!;
    expect(saved.worldId, isNull);
    expect(saved.name, role.name);
    expect(find.textContaining('保存失败'), findsNothing);
  });

  testWidgets('picker lists an empty hint when no world exists', (
    tester,
  ) async {
    _usePhoneView(tester);
    await tester.pumpWidget(_wrap(FakeRoleRepository(), FakeWorldRepository()));
    await tester.pumpAndSettle();

    final row = find.byKey(const Key('role-world-row'));
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.text('不归属'), findsOneWidget);
    expect(find.text('还没有世界观'), findsOneWidget);
  });
}

Widget _wrap(
  FakeRoleRepository roles,
  FakeWorldRepository worlds, {
  Role? role,
}) {
  return ProviderScope(
    overrides: [
      roleRepositoryProvider.overrideWithValue(roles),
      worldRepositoryProvider.overrideWithValue(worlds),
    ],
    child: MaterialApp(
      theme: zaidangLightTheme(),
      home: RoleCreatePage(role: role, picker: FakeCoverImagePicker()),
    ),
  );
}

void _usePhoneView(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Role _role({int? worldId}) {
  return Role(
    id: 9,
    name: 'Ada',
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
