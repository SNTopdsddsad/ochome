import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/data/models/role.dart';
import 'package:ochome/data/models/role_relationship.dart';
import 'package:ochome/data/providers/role_assets_provider.dart';
import 'package:ochome/data/providers/role_relationships_provider.dart';
import 'package:ochome/data/providers/role_repository_provider.dart';
import 'package:ochome/pages/role_create_page.dart';
import 'package:ochome/theme/zaidang_theme.dart';
import 'package:ochome/theme/zaidang_tokens.dart';

import '../fakes/fake_role_asset_repository.dart';
import '../fakes/fake_role_relationship_repository.dart';
import '../fakes/fake_role_repository.dart';

void main() {
  testWidgets('新建流程没有关系 Tab，编辑流程有', (tester) async {
    final relationships = FakeRoleRelationshipRepository();
    addTearDown(relationships.dispose);
    await _open(tester, relationships, role: null);
    expect(find.widgetWithText(Tab, '关系'), findsNothing);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('打开角色'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(Tab, '关系'), findsOneWidget);
  });

  testWidgets('空态、添加关系并按视角显示文案', (tester) async {
    final relationships = FakeRoleRelationshipRepository();
    addTearDown(relationships.dispose);
    await _open(tester, relationships);
    await _relationships(tester);
    expect(find.text('还没有关系'), findsOneWidget);
    expect(find.text('0 条关系'), findsOneWidget);

    await tester.tap(find.byKey(const Key('role-relationship-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('role-relationship-editor')), findsOneWidget);
    // 点面板外的空白处可以关闭，不写库。
    await tester.tapAt(const Offset(20, 40));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('role-relationship-editor')), findsNothing);
    expect(relationships.createCalls, 0);
    expect(find.text('关系已添加'), findsNothing);

    await tester.tap(find.byKey(const Key('role-relationship-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('role-relationship-editor')), findsOneWidget);
    // 自己不会出现在对方候选里；唯一候选自动选中，两句话直接成形。
    expect(find.byKey(const Key('role-relationship-candidate-1')), findsNothing);
    expect(
      find.byKey(const Key('role-relationship-candidate-2')),
      findsOneWidget,
    );
    expect(_sentence(tester, 'self'), ['白鸦', '是', '墨鲤', '的']);
    expect(_sentence(tester, 'other'), ['墨鲤', '是', '白鸦', '的']);

    // 空文案不能保存。
    await tester.tap(find.byKey(const Key('role-relationship-save')));
    await tester.pumpAndSettle();
    expect(find.text('两句话都要补完，才能记下这段关系'), findsOneWidget);
    expect(relationships.createCalls, 0);

    // 触顶字数时提示，而不是静默截断。
    await tester.enterText(
      find.byKey(const Key('role-relationship-self-label')),
      '师' * relationshipLabelMaxLength,
    );
    await tester.pumpAndSettle();
    expect(find.text('称呼最多 $relationshipLabelMaxLength 个字'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('role-relationship-self-label')),
      '徒弟',
    );
    await tester.enterText(
      find.byKey(const Key('role-relationship-other-label')),
      ' 师父 ',
    );
    await tester.tap(find.byKey(const Key('role-relationship-swap')));
    await tester.pumpAndSettle();
    expect(_labelText(tester, 'self'), ' 师父 ');
    expect(_labelText(tester, 'other'), '徒弟');
    await tester.tap(find.byKey(const Key('role-relationship-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('role-relationship-editor')), findsNothing);
    expect(find.text('关系已添加'), findsOneWidget);
    expect(relationships.createCalls, 1);
    final saved = relationships.items.single;
    expect(saved.fromRoleId, 1);
    expect(saved.toRoleId, 2);
    expect(saved.fromLabel, '师父');
    expect(saved.toLabel, '徒弟');
    expect(find.text('1 条关系'), findsOneWidget);
    expect(find.text('墨鲤'), findsOneWidget);
    expect(find.text('我是 TA 的师父 · TA 是我的徒弟'), findsOneWidget);
  });

  testWidgets('从对方页面看同一条关系文案反向，可修改和删除', (tester) async {
    final relationships = FakeRoleRelationshipRepository([
      RoleRelationship(
        id: 5,
        fromRoleId: 1,
        toRoleId: 2,
        fromLabel: '师父',
        toLabel: '徒弟',
        createdAt: DateTime(2026, 9, 10),
      ),
    ]);
    addTearDown(relationships.dispose);
    await _open(tester, relationships, role: _other);
    await _relationships(tester);
    expect(find.text('白鸦'), findsWidgets);
    expect(find.text('我是 TA 的徒弟 · TA 是我的师父'), findsOneWidget);

    await tester.tap(find.byTooltip('更多操作：白鸦'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('修改'));
    await tester.pumpAndSettle();
    expect(find.text('修改关系'), findsOneWidget);
    expect(_labelText(tester, 'self'), '徒弟');
    expect(_labelText(tester, 'other'), '师父');
    // 未改动直接保存不会写库。
    await tester.tap(find.byKey(const Key('role-relationship-save')));
    await tester.pumpAndSettle();
    expect(relationships.updateCalls, 0);
    expect(find.byKey(const Key('role-relationship-editor')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('role-relationship-5')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('role-relationship-self-label')),
      '关门弟子',
    );
    await tester.tap(find.byKey(const Key('role-relationship-save')));
    await tester.pumpAndSettle();
    expect(relationships.updateCalls, 1);
    final updated = relationships.items.single;
    expect(updated.id, 5);
    expect(updated.selfLabel(2), '关门弟子');
    expect(updated.otherLabel(2), '师父');
    expect(updated.selfLabel(1), '师父');
    expect(find.text('我是 TA 的关门弟子 · TA 是我的师父'), findsOneWidget);

    await tester.tap(find.byTooltip('更多操作：白鸦'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(find.text('删除这条关系？'), findsOneWidget);
    await tester.tap(find.byKey(const Key('zaidang-confirm-action')));
    await tester.pumpAndSettle();
    expect(relationships.items, isEmpty);
    expect(find.text('关系已删除'), findsOneWidget);
    expect(find.text('还没有关系'), findsOneWidget);
  });

  testWidgets('保存中禁用页面保存与返回，失败留在编辑器内提示', (tester) async {
    final relationships = FakeRoleRelationshipRepository()
      ..pendingSave = Completer<void>();
    addTearDown(relationships.dispose);
    await _open(tester, relationships);
    await _relationships(tester);
    await tester.tap(find.byKey(const Key('role-relationship-add')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextButton>(
            find.descendant(
              of: find.byType(RoleCreatePage),
              matching: find.widgetWithText(TextButton, '保存'),
            ),
          )
          .onPressed,
      isNull,
      reason: '弹窗期间页面保存按钮禁用',
    );
    await tester.enterText(
      find.byKey(const Key('role-relationship-self-label')),
      '师父',
    );
    await tester.enterText(
      find.byKey(const Key('role-relationship-other-label')),
      '徒弟',
    );
    await tester.tap(find.byKey(const Key('role-relationship-save')));
    await tester.pump();
    expect(find.text('保存中…'), findsOneWidget);
    final saving = tester.widget<FilledButton>(
      find.byKey(const Key('role-relationship-save')),
    );
    expect(saving.onPressed, isNull);
    expect(
      saving.style!.backgroundColor!.resolve({WidgetState.disabled}),
      ZaidangTokens.light.accent,
      reason: '保存中按钮保持满色，文字对比度不掉',
    );
    // 保存中点空白处不会关掉面板。
    await tester.tapAt(const Offset(20, 40));
    await tester.pump();
    expect(find.byKey(const Key('role-relationship-editor')), findsOneWidget);
    relationships.failSave = true;
    relationships.pendingSave!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('role-relationship-editor')), findsOneWidget);
    expect(find.text('模拟写入失败'), findsOneWidget);
    await tester.tap(find.byKey(const Key('role-relationship-cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('role-relationship-editor')), findsNothing);
    expect(relationships.items, isEmpty);
  });

  testWidgets('删除已被移除的关系时如实提示', (tester) async {
    final relationships = FakeRoleRelationshipRepository([
      RoleRelationship(
        id: 5,
        fromRoleId: 1,
        toRoleId: 2,
        fromLabel: '师父',
        toLabel: '徒弟',
        createdAt: DateTime(2026, 9, 10),
      ),
    ]);
    addTearDown(relationships.dispose);
    await _open(tester, relationships);
    await _relationships(tester);
    await tester.tap(find.byTooltip('更多操作：墨鲤'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    // 确认框还开着时，这条关系已在别处被删掉。
    relationships.items.clear();
    await tester.tap(find.byKey(const Key('zaidang-confirm-action')));
    await tester.pumpAndSettle();
    expect(find.text('这条关系已经不存在了'), findsOneWidget);
    expect(find.text('关系已删除'), findsNothing);
    expect(find.text('还没有关系'), findsOneWidget);
  });

  testWidgets('多位候选时先选对方，句子随选择变化', (tester) async {
    final relationships = FakeRoleRelationshipRepository();
    addTearDown(relationships.dispose);
    await _open(
      tester,
      relationships,
      roles: FakeRoleRepository([_role, _other, _third]),
    );
    await _relationships(tester);
    await tester.tap(find.byKey(const Key('role-relationship-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('role-relationship-candidate-1')), findsNothing);
    expect(
      find.byKey(const Key('role-relationship-candidate-2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('role-relationship-candidate-3')),
      findsOneWidget,
    );
    expect(_sentence(tester, 'self'), ['白鸦', '是', '对方', '的']);

    await tester.tap(find.byKey(const Key('role-relationship-save')));
    await tester.pumpAndSettle();
    expect(find.text('先选一位对方 OC'), findsOneWidget);
    expect(relationships.createCalls, 0);

    await tester.tap(find.byKey(const Key('role-relationship-candidate-3')));
    await tester.pumpAndSettle();
    expect(_sentence(tester, 'self'), ['白鸦', '是', '青鸾', '的']);
    expect(_sentence(tester, 'other'), ['青鸾', '是', '白鸦', '的']);
    expect(find.text('先选一位对方 OC'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('role-relationship-self-label')),
      '宿敌',
    );
    await tester.enterText(
      find.byKey(const Key('role-relationship-other-label')),
      '宿敌',
    );
    await tester.tap(find.byKey(const Key('role-relationship-save')));
    await tester.pumpAndSettle();
    expect(relationships.items.single.toRoleId, 3);
    expect(find.text('青鸾'), findsOneWidget);
  });

  testWidgets('库里没有其他 OC 时提示先新建', (tester) async {
    final relationships = FakeRoleRelationshipRepository();
    addTearDown(relationships.dispose);
    await _open(tester, relationships, roles: FakeRoleRepository([_role]));
    await _relationships(tester);
    await tester.tap(find.byKey(const Key('role-relationship-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('role-relationship-editor')), findsNothing);
    expect(find.textContaining('还没有其他 OC'), findsOneWidget);
  });
}

Future<void> _open(
  WidgetTester tester,
  FakeRoleRelationshipRepository relationships, {
  FakeRoleRepository? roles,
  Role? role = _role,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final assets = FakeRoleAssetRepository();
  addTearDown(assets.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        roleRepositoryProvider.overrideWithValue(
          roles ?? FakeRoleRepository([_role, _other]),
        ),
        roleAssetRepositoryProvider.overrideWithValue(assets),
        roleRelationshipRepositoryProvider.overrideWithValue(relationships),
      ],
      child: MaterialApp(
        theme: zaidangLightTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => RoleCreatePage(role: role),
                    ),
                  ),
                  child: Text(role == null ? '新建角色' : '打开角色'),
                ),
                if (role == null)
                  TextButton(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => const RoleCreatePage(role: _role),
                      ),
                    ),
                    child: const Text('打开角色'),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text(role == null ? '新建角色' : '打开角色'));
  await tester.pumpAndSettle();
}

Future<void> _relationships(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(Tab, '关系'));
  await tester.pumpAndSettle();
}

/// 句子行里除填空外的文字，按阅读顺序。
List<String> _sentence(WidgetTester tester, String which) {
  final row = find.byKey(Key('role-relationship-sentence-$which'));
  final field = find.descendant(of: row, matching: find.byType(TextField));
  final inField = tester
      .widgetList<Text>(find.descendant(of: field, matching: find.byType(Text)))
      .toSet();
  return tester
      .widgetList<Text>(find.descendant(of: row, matching: find.byType(Text)))
      .where((text) => !inField.contains(text))
      .map((text) => text.data!)
      .toList();
}

String _labelText(WidgetTester tester, String which) => tester
    .widget<TextField>(find.byKey(Key('role-relationship-$which-label')))
    .controller!
    .text;

const _role = Role(
  id: 1,
  name: '白鸦',
  sex: '',
  age: '',
  birthday: '',
  race: '',
  occupation: '',
  desc: '角色设定',
  coverImg: '',
);

const _other = Role(
  id: 2,
  name: '墨鲤',
  sex: '',
  age: '',
  birthday: '',
  race: '',
  occupation: '',
  desc: '',
  coverImg: '',
);

const _third = Role(
  id: 3,
  name: '青鸾',
  sex: '',
  age: '',
  birthday: '',
  race: '',
  occupation: '',
  desc: '',
  coverImg: '',
);
