import 'dart:async';
import 'dart:io';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/data/models/role.dart';
import 'package:ochome/data/providers/role_repository_provider.dart';
import 'package:ochome/pages/cover_preview_page.dart';
import 'package:ochome/pages/role_create_page.dart';
import 'package:path/path.dart' as p;

import '../fakes/fake_cover_image_picker.dart';
import '../fakes/fake_role_repository.dart';

/// 1×1 透明 PNG，供 [CoverFileView] 真正解码，避免非法图片数据报错。
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

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('role_cover');
    await _writeCover(tempDir, 'ada.png');
    await _writeCover(tempDir, 'new.png');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets(
    'tapping portrait with a readable cover opens full-screen preview',
    (tester) async {
      _usePhoneView(tester);
      final role = _role(coverImg: 'covers/ada.png');
      final picker = FakeCoverImagePicker();
      await tester.pumpWidget(_wrap(role, picker, tempDir));
      await _pump(tester);

      // 可读 → 出现「更换」，不再显示「添加立绘」。
      expect(find.byTooltip('更换立绘'), findsOneWidget);
      expect(find.text('更换'), findsOneWidget);
      expect(find.text('添加立绘'), findsNothing);

      // 点立绘槽 → 打开预览，而不是选图。
      await tester.tap(find.byKey(const Key('role-create-cover-portrait')));
      await _pump(tester);
      expect(picker.pickCalls, 0);
      expect(find.byType(CoverPreviewPage), findsOneWidget);
      expect(find.byTooltip('关闭'), findsOneWidget);

      // 关闭预览只退出预览层，不 pop 编辑页、不丢立绘。
      await tester.tap(find.byTooltip('关闭'));
      await _pump(tester);
      expect(find.byType(CoverPreviewPage), findsNothing);
      expect(find.byType(RoleCreatePage), findsOneWidget);
    },
  );

  testWidgets('tapping 更换 opens the gallery; cancel keeps cover unchanged', (
    tester,
  ) async {
    _usePhoneView(tester);
    final role = _role(coverImg: 'covers/ada.png');
    final picker = FakeCoverImagePicker(); // 返回 null → 模拟取消
    await tester.pumpWidget(_wrap(role, picker, tempDir));
    await _pump(tester);

    // 只有点「更换」才调相册。
    await tester.tap(find.text('更换'));
    await _pump(tester);
    expect(picker.pickCalls, 1);

    // 取消后画面不变：仍显示「更换」、没进预览。
    expect(find.byTooltip('更换立绘'), findsOneWidget);
    expect(find.byType(CoverPreviewPage), findsNothing);
  });

  testWidgets('empty state shows 添加立绘 and becomes previewable after picking', (
    tester,
  ) async {
    _usePhoneView(tester);
    final role = _role(coverImg: '');
    final picker = FakeCoverImagePicker('covers/new.png');
    await tester.pumpWidget(_wrap(role, picker, tempDir));
    await _pump(tester);

    // 空态：显示「添加立绘」、无「更换」。
    expect(find.text('添加立绘'), findsOneWidget);
    expect(find.byTooltip('更换立绘'), findsNothing);

    // 点立绘槽 → 打开相册。
    await tester.tap(find.byKey(const Key('role-create-cover-portrait')));
    await _pump(tester);
    expect(picker.pickCalls, 1);

    // 选图成功后出现「更换」，再点立绘是预览而非立刻再开相册。
    expect(find.text('添加立绘'), findsNothing);
    expect(find.byTooltip('更换立绘'), findsOneWidget);
    await tester.tap(find.byKey(const Key('role-create-cover-portrait')));
    await _pump(tester);
    expect(picker.pickCalls, 1);
    expect(find.byType(CoverPreviewPage), findsOneWidget);
  });

  testWidgets('tapping background or name does not open gallery or preview', (
    tester,
  ) async {
    _usePhoneView(tester);
    final role = _role(coverImg: 'covers/ada.png');
    final picker = FakeCoverImagePicker();
    await tester.pumpWidget(_wrap(role, picker, tempDir));
    await _pump(tester);

    // 点模糊背景（hero 上部空白处）→ 不选图、不进预览。
    await tester.tapAt(const Offset(195, 100));
    await _pump(tester);
    expect(picker.pickCalls, 0);
    expect(find.byType(CoverPreviewPage), findsNothing);

    // 点名字 → 不选图、不进预览。只找名片里的 Text，避开表单里的 EditableText。
    await tester.tap(
      find.byWidgetPredicate((w) => w is Text && w.data == 'Ada'),
    );
    await _pump(tester);
    expect(picker.pickCalls, 0);
    expect(find.byType(CoverPreviewPage), findsNothing);
  });

  testWidgets('replacement has an accessible name and remains a button', (
    tester,
  ) async {
    _usePhoneView(tester);
    final semantics = tester.ensureSemantics();
    try {
      final picker = FakeCoverImagePicker();
      await tester.pumpWidget(
        _wrap(_role(coverImg: 'covers/ada.png'), picker, tempDir),
      );
      await _pump(tester);

      final data = tester
          .getSemantics(find.widgetWithText(TextButton, '更换'))
          .getSemanticsData();
      expect(data.label, '更换立绘');
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isEnabled.toBoolOrNull(), isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(find.bySemanticsLabel('更换立绘'), findsOneWidget);

      await tester.tap(find.text('更换'));
      await _pump(tester);
      expect(picker.pickCalls, 1);
    } finally {
      semantics.dispose();
    }
  });

  for (final editing in [false, true]) {
    testWidgets(
      '${editing ? 'edit' : 'create'} save blocks preview and returns to the previous page',
      (tester) async {
        _usePhoneView(tester);
        final role = editing ? _role(coverImg: 'covers/ada.png') : null;
        final repository = _DelayedSaveRoleRepository(
          role == null ? [] : [role],
        );
        final picker = FakeCoverImagePicker('covers/new.png');
        await tester.pumpWidget(
          ProviderScope(
            overrides: [roleRepositoryProvider.overrideWithValue(repository)],
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => RoleCreatePage(
                          role: role,
                          picker: picker,
                          supportDirectory: () async => tempDir,
                        ),
                      ),
                    ),
                    child: const Text('打开角色表单'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('打开角色表单'));
        await _pump(tester);

        final portrait = find.byKey(const Key('role-create-cover-portrait'));
        if (!editing) {
          await tester.tap(portrait);
          await _pump(tester);
        }
        await tester.enterText(
          find.widgetWithText(TextFormField, '名字'),
          'Saved once',
        );
        await _pump(tester);

        await tester.tap(find.widgetWithText(TextButton, '保存'));
        // 先验证重建前的旧回调，再验证保存中已经重建的禁用控件。
        await tester.tap(portrait);
        await _pump(tester);
        expect(find.byType(CoverPreviewPage), findsNothing);
        await tester.tap(portrait);
        await _pump(tester);
        expect(find.byType(CoverPreviewPage), findsNothing);

        repository.saveCompleted.complete();
        await _pump(tester);
        expect(find.byType(RoleCreatePage), findsNothing);
        expect(find.text('打开角色表单'), findsOneWidget);
        final saved = await repository.list();
        expect(saved, hasLength(1));
        expect(saved.single.name, 'Saved once');
        expect(
          saved.single.coverImg,
          editing ? 'covers/ada.png' : 'covers/new.png',
        );
      },
    );
  }
}

class _DelayedSaveRoleRepository extends FakeRoleRepository {
  _DelayedSaveRoleRepository(super.roles);

  final saveCompleted = Completer<void>();

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
  }) async {
    await saveCompleted.future;
    return super.create(
      name: name,
      sex: sex,
      age: age,
      birthday: birthday,
      race: race,
      occupation: occupation,
      desc: desc,
      coverImg: coverImg,
    );
  }

  @override
  Future<Role> update(Role role) async {
    await saveCompleted.future;
    return super.update(role);
  }
}

/// 用有界帧推进替代 [WidgetTester.pumpAndSettle]：实时图片解码在假异步下永不完成，
/// `pumpAndSettle` 会等不到静止。这里推进几帧 + 一段过渡时长即可覆盖路由动画。
Future<void> _pump(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
}

Widget _wrap(Role role, FakeCoverImagePicker picker, Directory tempDir) {
  return ProviderScope(
    overrides: [
      roleRepositoryProvider.overrideWithValue(FakeRoleRepository([role])),
    ],
    child: MaterialApp(
      home: RoleCreatePage(
        role: role,
        picker: picker,
        supportDirectory: () async => tempDir,
      ),
    ),
  );
}

Future<void> _writeCover(Directory tempDir, String name) async {
  final coverDir = Directory(p.join(tempDir.path, 'covers'));
  await coverDir.create(recursive: true);
  await File(p.join(coverDir.path, name))
      .writeAsBytes(_transparentPng, flush: true);
}

void _usePhoneView(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Role _role({String coverImg = ''}) {
  return Role(
    id: 1,
    name: 'Ada',
    sex: 'female',
    age: '17',
    birthday: '三月三日',
    race: 'human',
    occupation: 'engineer',
    desc: 'sample',
    coverImg: coverImg,
  );
}
