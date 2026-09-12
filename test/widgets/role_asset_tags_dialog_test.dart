import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/theme/zaidang_theme.dart';
import 'package:ochome/widgets/role_asset_tags_dialog.dart';

void main() {
  testWidgets(
    'saving includes the pending input and cancellation keeps the original tags',
    (tester) async {
      final writes = <List<String>>[];
      await _open(tester, onSave: (tags) async => writes.add(tags));
      await tester.enterText(
        find.byKey(const Key('role-asset-tag-input')),
        '  立绘  ',
      );
      await tester.tap(find.byKey(const Key('role-asset-tags-save')));
      await tester.pumpAndSettle();
      expect(writes, [
        ['设定', '立绘'],
      ]);
      expect(find.byType(RoleAssetTagsDialog), findsNothing);

      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('role-asset-tag-input')),
        '官方图',
      );
      await tester.tap(find.byKey(const Key('role-asset-tag-add')));
      await tester.pumpAndSettle();
      expect(find.text('官方图'), findsOneWidget);
      await tester.tap(find.byKey(const Key('role-asset-tags-cancel')));
      await tester.pumpAndSettle();
      expect(writes, hasLength(1));
    },
  );

  testWidgets(
    'validation keeps the draft; failed save can retry; pending save blocks dismissal',
    (tester) async {
      final pending = Completer<void>();
      var calls = 0;
      await _open(
        tester,
        onSave: (_) async {
          calls++;
          if (calls == 1) throw StateError('资产不存在或不属于此角色');
          await pending.future;
        },
      );
      final input = find.byKey(const Key('role-asset-tag-input'));
      await tester.enterText(input, '   ');
      await tester.tap(find.byKey(const Key('role-asset-tag-add')));
      await tester.pumpAndSettle();
      expect(find.text('标签不能为空'), findsOneWidget);
      expect(calls, 0);
      await tester.enterText(input, '');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('标签不能为空'), findsOneWidget);
      await tester.enterText(input, '长' * 17);
      await tester.tap(find.byKey(const Key('role-asset-tags-save')));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.byType(RoleAssetTagsDialog), findsOneWidget);
      await tester.enterText(input, '官方图');
      await tester.tap(find.byKey(const Key('role-asset-tags-save')));
      await tester.pumpAndSettle();
      expect(find.text('资产不存在或不属于此角色'), findsOneWidget);
      expect(find.text('官方图'), findsOneWidget);
      final save = tester
          .widget<FilledButton>(find.byKey(const Key('role-asset-tags-save')))
          .onPressed!;
      save();
      save();
      await tester.pump();
      expect(calls, 2);
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('role-asset-tags-cancel')))
            .onPressed,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(RoleAssetTagsDialog), findsOneWidget);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.byType(RoleAssetTagsDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'removing the last tag saves an empty list and a stale save callback respects canSave',
    (tester) async {
      var enabled = true;
      final writes = <List<String>>[];
      await _open(
        tester,
        canSave: () => enabled,
        onSave: (tags) async => writes.add(tags),
      );
      tester
          .widget<InputChip>(find.byKey(const ValueKey('role-asset-tag-设定')))
          .onDeleted!();
      await tester.pump();
      final submit = tester
          .widget<FilledButton>(find.byKey(const Key('role-asset-tags-save')))
          .onPressed!;
      enabled = false;
      submit();
      await tester.pump();
      expect(writes, isEmpty);
      enabled = true;
      submit();
      await tester.pumpAndSettle();
      expect(writes, [<String>[]]);
    },
  );
}

Future<void> _open(
  WidgetTester tester, {
  bool Function()? canSave,
  required Future<void> Function(List<String>) onSave,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: zaidangLightTheme(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (_) => RoleAssetTagsDialog(
                name: '角色设定.pdf',
                tags: const ['设定'],
                canSave: canSave ?? () => true,
                onSave: onSave,
              ),
            ),
            child: const Text('打开'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开'));
  await tester.pumpAndSettle();
}
