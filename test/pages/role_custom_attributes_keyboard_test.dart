import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/data/models/role_custom_attribute.dart';
import 'package:ochome/data/providers/role_repository_provider.dart';
import 'package:ochome/pages/role_create_page.dart';
import 'package:ochome/theme/zaidang_theme.dart';

import '../fakes/fake_role_repository.dart';

void main() {
  testWidgets(
    'keyboard entry appends focused rows and saves a new role from a long list',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final repository = FakeRoleRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [roleRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(
            theme: zaidangLightTheme(),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(builder: (_) => const RoleCreatePage()),
                  ),
                  child: const Text('新建角色'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('新建角色'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, '名字'), '白鸦');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();

      final add = find.byKey(const Key('role-custom-attribute-add'));
      final expected = <RoleCustomAttribute>[];
      for (var index = 0; index < 10; index++) {
        if (add.evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            add,
            250,
            scrollable: find.byType(Scrollable).first,
            maxScrolls: 30,
          );
        } else {
          await tester.ensureVisible(add);
        }
        await tester.pumpAndSettle();
        await tester.tap(add);
        await tester.pumpAndSettle();

        final names = find.widgetWithText(TextFormField, '属性名称');
        final nameField = tester.widget<TextFormField>(names.last);
        final nameInput = tester.widget<TextField>(
          find.descendant(of: names.last, matching: find.byType(TextField)),
        );
        expect(nameInput.focusNode!.hasFocus, isTrue, reason: 'row $index');
        expect(nameField.controller!.text, isEmpty);
        final name = '属性名称 $index';
        final content = '内容 $index\n第二行 $index';
        await tester.enterText(names.last, name);
        final contents = find.widgetWithText(TextFormField, '属性内容');
        await tester.ensureVisible(contents.last);
        await tester.enterText(contents.last, content);
        expected.add(RoleCustomAttribute(name: name, content: content));
        expect(tester.takeException(), isNull);
      }

      // The first lazy row has left the viewport; controllers remain page-owned.
      expect(find.text('属性名称 0'), findsNothing);
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.byType(RoleCreatePage), findsNothing);
      final saved = (await repository.list()).single;
      expect(saved.name, '白鸦');
      expect(saved.customAttributes, expected);
      expect(tester.takeException(), isNull);
    },
  );
}
