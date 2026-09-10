import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/data/models/role.dart';
import 'package:ochome/data/models/role_custom_attribute.dart';
import 'package:ochome/data/providers/role_repository_provider.dart';
import 'package:ochome/pages/role_create_page.dart';
import 'package:ochome/theme/zaidang_theme.dart';
import 'package:ochome/theme/zaidang_tokens.dart';
import 'package:ochome/widgets/zaidang_confirm_dialog.dart';

import '../fakes/fake_role_repository.dart';

const _magic = RoleCustomAttribute(name: '魔法属性', content: '冰');
const _cost = RoleCustomAttribute(name: '能力代价', content: '失去记忆\n醒来后恢复');

void main() {
  testWidgets(
    'empty state adds inline, validates names and saves optional content',
    (tester) async {
      _phone(tester, height: 1200);
      final repository = FakeRoleRepository();
      await _open(tester, repository);
      expect(
        find.byKey(const Key('role-create-custom-attributes-card')),
        findsNothing,
      );
      await tester.enterText(find.widgetWithText(TextFormField, '名字'), '白鸦');
      await _reveal(tester, find.byKey(const Key('role-custom-attribute-add')));
      final basicBottom = tester
          .getBottomLeft(find.byKey(const Key('role-create-basic-card')))
          .dy;
      final addTop = tester
          .getTopLeft(find.byKey(const Key('role-custom-attribute-add')))
          .dy;
      final descTop = tester
          .getTopLeft(find.byKey(const Key('role-create-desc-card')))
          .dy;
      expect(basicBottom, lessThan(addTop));
      expect(addTop, lessThan(descTop));
      await tester.tap(find.byKey(const Key('role-custom-attribute-add')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('role-create-custom-attributes-card')),
        findsOneWidget,
      );
      final name = find.widgetWithText(TextFormField, '属性名称');
      expect(
        tester
            .widget<TextField>(
              find.descendant(of: name, matching: find.byType(TextField)),
            )
            .focusNode!
            .hasFocus,
        isTrue,
      );
      await tester.enterText(name, '   ');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.text('请填写属性名称'), findsOneWidget);
      expect(await repository.list(), isEmpty);
      await tester.enterText(name, '  魔法属性  ');
      await _reveal(tester, find.byKey(const Key('role-custom-attribute-add')));
      await tester.tap(find.byKey(const Key('role-custom-attribute-add')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, '属性名称').last,
        '能力代价',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '属性内容').last,
        '失去记忆\n醒来后恢复',
      );
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect((await repository.list()).single.customAttributes, [
        const RoleCustomAttribute(name: '魔法属性', content: ''),
        _cost,
      ]);
      await tester.tap(find.text('打开角色'));
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('魔法属性'));
      expect(_input(tester, '魔法属性').controller!.text, '魔法属性');
    },
  );

  testWidgets(
    'editing then moving keeps controller identity and name/content pairing after reopen',
    (tester) async {
      _phone(tester, height: 1200);
      final repository = FakeRoleRepository([
        _role(attributes: [_magic, _cost]),
      ]);
      await _open(tester, repository);
      await _reveal(tester, find.text('魔法属性'));
      final nameController = _input(tester, '魔法属性').controller;
      final contentController = _input(tester, '冰').controller;
      await tester.enterText(_inputFinder('魔法属性'), '霜冻');
      await tester.enterText(_inputFinder('冰'), '新的冰\n新的代价');
      await _reveal(tester, find.byTooltip('下移第 1 条属性'));
      await tester.tap(find.byTooltip('下移第 1 条属性'));
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('霜冻'));
      expect(_input(tester, '霜冻').controller, same(nameController));
      expect(_input(tester, '新的冰\n新的代价').controller, same(contentController));
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect((await repository.list()).single.customAttributes, [
        _cost,
        const RoleCustomAttribute(name: '霜冻', content: '新的冰\n新的代价'),
      ]);
      await tester.tap(find.text('打开角色'));
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('能力代价'));
      expect(_input(tester, '能力代价').controller!.text, '能力代价');
      await _reveal(tester, find.text('霜冻'));
      expect(_input(tester, '新的冰\n新的代价').controller!.text, '新的冰\n新的代价');
    },
  );

  testWidgets(
    'failed save preserves draft and deleting all returns to add-only state',
    (tester) async {
      _phone(tester, height: 1200);
      final repository = _FailOnceRepository([
        _role(attributes: [_magic]),
      ]);
      await _open(tester, repository);
      await _reveal(tester, find.text('魔法属性'));
      await tester.enterText(_inputFinder('魔法属性'), '契约对象');
      await tester.enterText(_inputFinder('冰'), '契约白鸦');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.textContaining('保存失败'), findsOneWidget);
      expect(_input(tester, '契约对象').controller!.text, '契约对象');
      expect(_input(tester, '契约白鸦').controller!.text, '契约白鸦');
      expect((await repository.list()).single.customAttributes, [_magic]);
      await _reveal(tester, find.byTooltip('删除第 1 条属性'));
      await tester.tap(find.byTooltip('删除第 1 条属性'));
      await tester.pumpAndSettle();
      expect(find.text('保存角色后生效。'), findsOneWidget);
      await tester.tap(find.byKey(const Key('zaidang-confirm-cancel')));
      await tester.pumpAndSettle();
      expect(find.text('契约对象'), findsOneWidget);
      await tester.tap(find.byTooltip('删除第 1 条属性'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('zaidang-confirm-action')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('role-create-custom-attributes-card')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('role-custom-attribute-add')),
        findsOneWidget,
      );
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect((await repository.list()).single.customAttributes, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'leaving without saving preserves stored attributes and another role',
    (tester) async {
      _phone(tester, height: 1200);
      final repository = FakeRoleRepository([
        _role(attributes: [_magic]),
        _role(id: 2, attributes: [_cost]),
      ]);
      await _open(tester, repository);
      await _reveal(tester, find.text('魔法属性'));
      await tester.enterText(_inputFinder('魔法属性'), '草稿');
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect((await repository.getById(1))!.customAttributes, [_magic]);
      expect((await repository.getById(2))!.customAttributes, [_cost]);
    },
  );

  testWidgets('offscreen blank names still block saving a long list', (
    tester,
  ) async {
    _phone(tester);
    final attributes = List.generate(
      12,
      (index) => RoleCustomAttribute(
        name: index == 10 ? ' ' : '属性 $index',
        content: '内容 $index',
      ),
    );
    final repository = FakeRoleRepository([_role(attributes: attributes)]);
    await _open(tester, repository);
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.byType(RoleCreatePage), findsOneWidget);
    await _reveal(tester, find.text('请填写属性名称'));
    expect(find.text('请填写属性名称'), findsOneWidget);
  });

  for (final editing in [false, true]) {
    testWidgets(
      '${editing ? 'update' : 'create'} pending save disables mutations and ignores stale callbacks',
      (tester) async {
        _phone(tester, height: 1200);
        final repository = _DelayedRepository(
          editing
              ? [
                  _role(attributes: [_magic, _cost]),
                ]
              : [],
        );
        await _open(tester, repository);
        if (!editing) {
          await tester.enterText(
            find.widgetWithText(TextFormField, '名字'),
            '白鸦',
          );
          await _reveal(
            tester,
            find.byKey(const Key('role-custom-attribute-add')),
          );
          await tester.tap(find.byKey(const Key('role-custom-attribute-add')));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.widgetWithText(TextFormField, '属性名称'),
            '魔法属性',
          );
          await tester.enterText(
            find.widgetWithText(TextFormField, '属性内容'),
            '冰',
          );
        }
        await _reveal(tester, find.byTooltip('删除第 1 条属性'));
        final staleDelete = tester
            .widget<IconButton>(_iconButton('删除第 1 条属性'))
            .onPressed!;
        final staleReorder = tester
            .widget<SliverReorderableList>(find.byType(SliverReorderableList))
            .onReorderItem!;
        final staleAdd = tester
            .widget<TextButton>(
              find.byKey(const Key('role-custom-attribute-add')),
            )
            .onPressed!;
        await tester.tap(find.text('保存'));
        staleAdd();
        staleDelete();
        if (editing) staleReorder(0, 1);
        await tester.pump();
        expect(find.byType(ZaidangConfirmDialog), findsNothing);
        expect(
          tester.widget<IconButton>(_iconButton('删除第 1 条属性')).onPressed,
          isNull,
        );
        expect(
          tester
              .widget<TextButton>(
                find.byKey(const Key('role-custom-attribute-add')),
              )
              .onPressed,
          isNull,
        );
        expect(_input(tester, '魔法属性').enabled, isFalse);
        expect(repository.submitted, editing ? [_magic, _cost] : [_magic]);
        expect(() => repository.submitted!.add(_cost), throwsUnsupportedError);
        repository.complete.complete();
        await tester.pumpAndSettle();
        expect(find.byType(RoleCreatePage), findsNothing);
        expect(
          (await repository.list()).single.customAttributes,
          editing ? [_magic, _cost] : [_magic],
        );
      },
    );
  }

  testWidgets(
    'history warns before replacing unsaved description and keeps attribute drafts',
    (tester) async {
      _phone(tester, height: 1200);
      final repository = FakeRoleRepository([
        _role(attributes: [_magic], desc: '旧设定'),
      ]);
      await repository.update(_role(attributes: [_magic], desc: '新设定'));
      await _open(tester, repository);
      await _reveal(tester, find.text('魔法属性'));
      await tester.enterText(_inputFinder('魔法属性'), '草稿名称');
      await tester.enterText(_inputFinder('冰'), '草稿内容');
      await _reveal(tester, find.text('新设定'));
      await tester.enterText(_inputFinder('新设定'), '还没有保存的设定草稿');
      await _reveal(tester, find.text('修改历史'));
      await tester.tap(find.text('修改历史'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('旧设定'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('恢复此版'));
      await tester.pumpAndSettle();
      expect(find.textContaining('还没保存的设定修改会丢失。'), findsOneWidget);
      await tester.tap(find.byKey(const Key('zaidang-confirm-action')));
      await tester.pumpAndSettle();
      expect((await repository.getById(1))!.customAttributes, [_magic]);
      expect((await repository.getById(1))!.desc, '旧设定');
      expect(
        (await repository.listDescRevisions(1))
            .map((revision) => revision.content),
        isNot(contains('还没有保存的设定草稿')),
      );
      await _reveal(tester, find.text('草稿名称'));
      expect(_input(tester, '草稿内容').controller!.text, '草稿内容');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      final saved = (await repository.getById(1))!;
      expect(saved.desc, '旧设定');
      expect(saved.customAttributes, [
        const RoleCustomAttribute(name: '草稿名称', content: '草稿内容'),
      ]);
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      '${dark ? 'dark' : 'light'} phone supports drag reordering and accessible controls',
      (tester) async {
        _phone(tester);
        final semantics = tester.ensureSemantics();
        try {
          final repository = FakeRoleRepository([
            _role(attributes: [_magic, _cost]),
          ]);
          await _open(tester, repository, dark: dark);
          await _reveal(tester, find.byTooltip('下移第 1 条属性'));
          final moveData = tester
              .getSemantics(_iconButton('下移第 1 条属性'))
              .getSemanticsData();
          expect(moveData.label, '下移第 1 条属性');
          expect(moveData.flagsCollection.isButton, isTrue);
          expect(moveData.hasAction(SemanticsAction.tap), isTrue);
          final delete = tester.widget<IconButton>(_iconButton('删除第 1 条属性'));
          expect(
            delete.color,
            dark ? ZaidangTokens.dark.ink : ZaidangTokens.light.ink,
          );
          final handles = find.byType(ReorderableDragStartListener);
          final first = tester.getCenter(handles.first);
          await tester.timedDragFrom(
            first,
            const Offset(0, 320),
            const Duration(milliseconds: 800),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('保存'));
          await tester.pumpAndSettle();
          expect((await repository.list()).single.customAttributes, [
            _cost,
            _magic,
          ]);
        } finally {
          semantics.dispose();
        }
      },
    );
  }
}

Future<void> _open(
  WidgetTester tester,
  FakeRoleRepository repository, {
  bool dark = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [roleRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        theme: dark ? zaidangDarkTheme() : zaidangLightTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                final role = await repository.getById(1);
                if (!context.mounted) return;
                await Navigator.of(context).push<void>(
                  MaterialPageRoute(builder: (_) => RoleCreatePage(role: role)),
                );
              },
              child: const Text('打开角色'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开角色'));
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; finder.evaluate().isEmpty && attempt < 30; attempt++) {
    // Swipe inside the visible content rather than the overlapping header or a text field.
    final height =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    await tester.dragFrom(Offset(20, height - 120), const Offset(0, -250));
    await tester.pumpAndSettle();
  }
  await Scrollable.ensureVisible(tester.element(finder.first), alignment: 0.2);
  await tester.pumpAndSettle();
}

Finder _inputFinder(String text) => find.byWidgetPredicate(
  (widget) => widget is TextFormField && widget.controller?.text == text,
);
TextFormField _input(WidgetTester tester, String text) =>
    tester.widget<TextFormField>(_inputFinder(text));

void _phone(WidgetTester tester, {double height = 844}) {
  tester.view.physicalSize = Size(390, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Role _role({
  int id = 1,
  List<RoleCustomAttribute> attributes = const [],
  String desc = '角色设定',
}) => Role(
  id: id,
  name: '白鸦',
  sex: '',
  age: '',
  birthday: '',
  race: '',
  occupation: '',
  desc: desc,
  coverImg: '',
  customAttributes: attributes,
);

class _FailOnceRepository extends FakeRoleRepository {
  _FailOnceRepository(super.roles);
  bool fail = true;
  @override
  Future<Role> update(Role role) async {
    if (fail) {
      fail = false;
      throw StateError('测试保存失败');
    }
    return super.update(role);
  }
}

class _DelayedRepository extends FakeRoleRepository {
  _DelayedRepository(super.roles);
  final complete = Completer<void>();
  List<RoleCustomAttribute>? submitted;
  @override
  Future<Role> create({
    required String name,
    required String sex,
    required String age,
    required String birthday,
    required String race,
    required String occupation,
    required String desc,
    required String coverImg,
    List<RoleCustomAttribute> customAttributes = const [],
    int? worldId,
  }) async {
    submitted = customAttributes;
    await complete.future;
    return super.create(
      name: name,
      sex: sex,
      age: age,
      birthday: birthday,
      race: race,
      occupation: occupation,
      desc: desc,
      coverImg: coverImg,
      customAttributes: customAttributes,
      worldId: worldId,
    );
  }

  @override
  Future<Role> update(Role role) async {
    submitted = role.customAttributes;
    await complete.future;
    return super.update(role);
  }
}

Finder _iconButton(String label) => find.byWidgetPredicate(
  (widget) => widget is IconButton && widget.tooltip == label,
);
