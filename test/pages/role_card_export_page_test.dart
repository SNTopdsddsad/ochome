import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/data/models/role.dart';
import 'package:ochome/data/models/role_custom_attribute.dart';
import 'package:ochome/data/providers/role_repository_provider.dart';
import 'package:ochome/features/role_card/role_card_content.dart';
import 'package:ochome/features/role_card/role_card_delivery.dart';
import 'package:ochome/features/role_card/role_card_export_service.dart';
import 'package:ochome/features/role_card/role_card_field_picker.dart';
import 'package:ochome/features/role_card/role_card_fonts.dart';
import 'package:ochome/features/role_card/role_card_renderer.dart';
import 'package:ochome/pages/role_card_export_page.dart';
import 'package:ochome/pages/role_create_page.dart';
import 'package:ochome/theme/zaidang_theme.dart';

import '../fakes/fake_role_repository.dart';

const _entry = Key('role-card-export');
const _fields = Key('role-card-fields');
const _apply = Key('role-card-fields-apply');
const _save = Key('role-card-save');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(RoleCardFonts.ensureLoaded);

  testWidgets(
    'export snapshots unsaved reordered drafts and preserves editor identity',
    (tester) async {
      _view(tester, const Size(390, 1200));
      final role = _role();
      final repository = _RecordingRepository([role]);
      await _openEditor(tester, repository, role);
      final nameController = tester
          .widget<TextFormField>(find.byKey(const Key('role-field-name')))
          .controller;
      await tester.enterText(
        find.byKey(const Key('role-field-name')),
        ' 未保存名字 ',
      );
      await _reveal(tester, _input('第一份内容'));
      final attributeController = tester
          .widget<TextFormField>(_input('第一份内容'))
          .controller;
      await tester.enterText(_input('第一份内容'), '改过的第一份内容');
      await _reveal(tester, find.byTooltip('下移第 1 条属性'));
      await tester.tap(find.byTooltip('下移第 1 条属性'));
      await _settle(tester);
      await _reveal(tester, _input('原始设定'));
      final descController = tester
          .widget<TextFormField>(_input('原始设定'))
          .controller;
      await tester.enterText(_input('原始设定'), '尚未保存的设定\n保留换行');
      await _reveal(tester, find.byKey(_entry));
      final open = tester.widget<OutlinedButton>(find.byKey(_entry)).onPressed!;
      // Keep a callback from the enabled frame to exercise the synchronous guard.
      open();
      open();
      await _settle(tester);

      expect(find.byType(RoleCardExportPage), findsOneWidget);
      final snapshot = tester
          .widget<RoleCardExportPage>(find.byType(RoleCardExportPage))
          .snapshot;
      expect(snapshot.name, ' 未保存名字 ');
      expect(snapshot.desc, '尚未保存的设定\n保留换行');
      expect(snapshot.customAttributes, const [
        RoleCustomAttribute(name: '同名属性', content: '第二份内容'),
        RoleCustomAttribute(name: '同名属性', content: '改过的第一份内容'),
      ]);
      expect(repository.writes, 0);
      await tester.pageBack();
      await _settle(tester);
      expect(find.byType(RoleCreatePage), findsOneWidget);
      expect(find.byType(RoleCardExportPage), findsNothing);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('role-field-name')))
            .controller,
        same(nameController),
      );
      await _reveal(tester, _input('改过的第一份内容'));
      expect(
        tester.widget<TextFormField>(_input('改过的第一份内容')).controller,
        same(attributeController),
      );
      expect(
        tester.getTopLeft(_input('第二份内容')).dy,
        lessThan(tester.getTopLeft(_input('改过的第一份内容')).dy),
      );
      await _reveal(tester, _input('尚未保存的设定\n保留换行'));
      expect(
        tester.widget<TextFormField>(_input('尚未保存的设定\n保留换行')).controller,
        same(descController),
      );
      expect(repository.writes, 0);
      expect((await repository.list()).single, role);
      expect(tester.takeException(), isNull);
    },
  );

  for (final editing in [false, true]) {
    testWidgets(
      '${editing ? 'update' : 'create'} pending save guards the export entry and stale callback',
      (tester) async {
        _view(tester, const Size(390, 1200));
        final role = editing ? _role() : null;
        final completed = Completer<void>();
        final repository = _RecordingRepository(role == null ? [] : [role])
          ..saveGate = completed.future;
        await _openEditor(tester, repository, role);
        await tester.enterText(
          find.byKey(const Key('role-field-name')),
          '只保存一次',
        );
        final oldCallback = tester
            .widget<OutlinedButton>(find.byKey(_entry))
            .onPressed!;
        await tester.tap(find.widgetWithText(TextButton, '保存'));
        oldCallback();
        await tester.pump();
        expect(
          tester.widget<OutlinedButton>(find.byKey(_entry)).onPressed,
          isNull,
        );
        oldCallback();
        await tester.pump();
        expect(find.byType(RoleCardExportPage), findsNothing);
        expect(repository.writes, 1);
        completed.complete();
        await _settle(tester);
        expect(find.byType(RoleCreatePage), findsNothing);
        expect(find.text('打开角色'), findsOneWidget);
        expect((await repository.list()).single.name, '只保存一次');
        expect(repository.writes, 1);
      },
    );
  }

  testWidgets(
    'selection excludes private defaults and treats duplicate attributes independently',
    (tester) async {
      _view(tester, const Size(390, 844));
      final renderer = _RecordingRenderer();
      final description = List.generate(
        65,
        (index) => '设定行 $index，完整接续显示。',
      ).join('\n');
      final snapshot = RoleCardSnapshot(
        name: '隐藏后不能再出现的名字',
        desc: description,
        customAttributes: const [
          RoleCustomAttribute(name: '同名属性', content: '公开的属性值'),
          RoleCustomAttribute(name: '同名属性', content: '私密的属性值'),
        ],
      );
      await _openPreview(tester, snapshot, renderer: renderer);
      expect(find.byTooltip('开源许可'), findsNothing);
      expect(find.byIcon(Icons.info_outline), findsNothing);
      expect(renderer.inputs.single.sections, isEmpty);
      expect(find.text('1 / 1'), findsOneWidget);
      expect(_canSave(tester), isTrue);
      await tester.tap(find.byKey(_fields));
      await _settle(tester);
      await _toggle(tester, 'role-card-field-name');
      await _toggle(tester, 'role-card-field-desc');
      await _toggle(tester, 'role-card-attribute-0');
      final first = tester.widget<CheckboxListTile>(
        find.byKey(const Key('role-card-attribute-0')),
      );
      final second = tester.widget<CheckboxListTile>(
        find.byKey(const Key('role-card-attribute-1')),
      );
      expect(first.value, isTrue);
      expect(second.value, isFalse);
      await tester.tap(find.byKey(_apply));
      await _settle(tester);

      final selected = renderer.inputs.last;
      expect(selected.name, isEmpty);
      expect(selected.sections.map((item) => item.value), [
        description,
        '公开的属性值',
      ]);
      final document = renderer.documents.last;
      expect(document.pageCount, greaterThan(1));
      final pageText = List.generate(
        document.pageCount,
        document.semanticsForPage,
      ).join('\n');
      expect(pageText, isNot(contains(snapshot.name)));
      expect(pageText, isNot(contains('私密的属性值')));
      expect(pageText, contains('公开的属性值'));
      expect(find.text('1 / ${document.pageCount}'), findsOneWidget);
      await tester.tap(find.byTooltip('下一张'));
      await _settle(tester);
      expect(find.text('2 / ${document.pageCount}'), findsOneWidget);
      expect(_canSave(tester), isTrue);
      expect(_shareButton(tester).onPressed, isNotNull);

      // Remove all selected content: both destinations disable, but selection remains reachable.
      await tester.tap(find.byKey(_fields));
      await _settle(tester);
      await _toggle(tester, 'role-card-field-desc');
      await _toggle(tester, 'role-card-attribute-0');
      await tester.tap(find.byKey(_apply));
      await _settle(tester);
      expect(find.text('请至少选择一项有内容的资料或立绘。'), findsOneWidget);
      expect(_canSave(tester), isFalse);
      expect(_shareButton(tester).onPressed, isNull);
      await tester.tap(find.byKey(_fields));
      await _settle(tester);
      expect(find.byType(RoleCardFieldPicker), findsOneWidget);
      await _toggle(tester, 'role-card-field-name');
      await tester.tap(find.byKey(_apply));
      await _settle(tester);
      expect(find.text('1 / 1'), findsOneWidget);
      expect(_canSave(tester), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a failed selected image blocks output until the user hides it', (
    tester,
  ) async {
    _view(tester, const Size(390, 844));
    final renderer = _RecordingRenderer();
    // Starting in a real asynchronous scope lets the filesystem failure complete.
    await tester.runAsync(() async {
      await _openPreview(
        tester,
        RoleCardSnapshot(
          name: '可导出的名字',
          coverImg: '/missing-role-card-art.png',
        ),
        renderer: renderer,
        settle: false,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await _settle(tester);
    expect(find.text('立绘无法加载，请更换图片或在显示内容中隐藏立绘。'), findsOneWidget);
    expect(_canSave(tester), isFalse);
    expect(_shareButton(tester).onPressed, isNull);
    await tester.tap(find.byKey(_fields));
    await _settle(tester);
    await _toggle(tester, 'role-card-field-cover');
    await tester.tap(find.byKey(_apply));
    await _settle(tester);
    expect(renderer.inputs.last.coverImg, isEmpty);
    expect(_canSave(tester), isTrue);
    expect(find.text('1 / 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cancelled sharing reports no success and retains the image job',
    (tester) async {
      _view(tester, const Size(390, 844));
      final job = await _makeJob(tester);
      final service = _PreparedExports([job]);
      final delivery = _Delivery();
      await _openPreview(
        tester,
        RoleCardSnapshot(name: '度漪'),
        delivery: delivery,
        exportService: service,
      );
      await tester.tap(find.byKey(const Key('role-card-share-label')));
      await _finishIo(
        tester,
        () => File('${job.directory.path}/.retained').existsSync(),
      );
      await _settle(tester);
      expect(delivery.shareCalls, 1);
      expect(delivery.deliveredPaths.single, job.paths);
      expect(service.requestedPageCounts, [1]);
      expect(service.cancellationChecks, [false]);
      expect(delivery.lastOrigin!.width, greaterThan(0));
      expect(delivery.lastOrigin!.height, greaterThan(0));
      expect(find.byType(SnackBar), findsNothing);
      expect(_shareButton(tester).onPressed, isNotNull);
      expect(
        await tester.runAsync(() => File(job.paths.single).exists()),
        isTrue,
      );
    },
  );

  testWidgets(
    'an older preparation cannot restore content hidden by a newer selection',
    (tester) async {
      _view(tester, const Size(390, 844));
      final firstPrepared = Completer<void>();
      final renderer = _RecordingRenderer()
        ..firstPreparationGate = firstPrepared.future;
      await _openPreview(
        tester,
        RoleCardSnapshot(name: '将被隐藏的名字', age: '二十岁'),
        renderer: renderer,
        settle: false,
      );
      await _finishIo(tester, () => renderer.documents.length == 1);
      final staleDocument = renderer.documents.single;
      await tester.tap(find.byKey(_fields));
      // The older preparation intentionally keeps its loading animation alive.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const Key('role-card-field-name')));
      await tester.pump();
      await tester.tap(find.byKey(_apply));
      await _settle(tester);
      expect(renderer.documents, hasLength(2));
      expect(renderer.inputs.last.name, isEmpty);
      expect(renderer.documents.last.semanticsForPage(0), contains('二十岁'));
      firstPrepared.complete();
      await _settle(tester);
      expect(() => staleDocument.semanticsForPage(0), throwsStateError);
      expect(
        renderer.documents.last.semanticsForPage(0),
        isNot(contains('将被隐藏的名字')),
      );
      expect(find.text('1 / 1'), findsOneWidget);
      expect(_canSave(tester), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'save failure is retryable and stale repeated taps cannot deliver twice',
    (tester) async {
      _view(tester, const Size(390, 844));
      final firstJob = await _makeJob(tester);
      final secondJob = await _makeJob(tester);
      final service = _PreparedExports([firstJob, secondJob]);
      final firstResult = Completer<void>();
      final delivery = _Delivery()
        ..saveAction = (call) async {
          if (call == 1) {
            await firstResult.future;
            throw PlatformException(code: 'saveFailed', message: '保存失败，请重试');
          }
          return const RoleCardDeliveryResult(
            RoleCardDeliveryStatus.saved,
            count: 1,
            directory: '/chosen',
          );
        };
      await _openPreview(
        tester,
        RoleCardSnapshot(name: '度漪'),
        delivery: delivery,
        exportService: service,
      );
      final oldCallback = tester
          .widget<FilledButton>(find.byKey(_save))
          .onPressed!;
      oldCallback();
      oldCallback();
      await tester.pump();
      expect(_canSave(tester), isFalse);
      expect(_shareButton(tester).onPressed, isNull);
      expect(tester.widget<TextButton>(find.byKey(_fields)).onPressed, isNull);
      oldCallback();
      await tester.pump();
      expect(service.calls, 1);
      expect(delivery.saveCalls, 1);
      firstResult.complete();
      await _finishIo(tester, () => !firstJob.directory.existsSync());
      await _settle(tester);
      expect(find.text('保存失败，请重试'), findsOneWidget);
      expect(_canSave(tester), isTrue);
      ScaffoldMessenger.of(tester.element(find.byKey(_save)))
          .removeCurrentSnackBar();
      await _settle(tester);
      await tester.tap(find.byKey(_save));
      await _finishIo(tester, () => !secondJob.directory.existsSync());
      await _settle(tester);
      expect(service.calls, 2);
      expect(delivery.saveCalls, 2);
      expect(delivery.deliveredPaths, [firstJob.paths, secondJob.paths]);
      expect(service.requestedPageCounts, [1, 1]);
      expect(find.text('已保存 1 张角色卡到所选文件夹'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'leaving during delivery keeps the document and files alive until completion',
    (tester) async {
      _view(tester, const Size(390, 844));
      final job = await _makeJob(tester);
      final renderer = _RecordingRenderer();
      final result = Completer<RoleCardDeliveryResult>();
      final delivery = _Delivery()..saveAction = (_) => result.future;
      await _openPreview(
        tester,
        RoleCardSnapshot(name: '度漪'),
        renderer: renderer,
        delivery: delivery,
        exportService: _PreparedExports([job]),
      );
      await tester.tap(find.byKey(_save));
      await tester.pump();
      expect(delivery.saveCalls, 1);
      final document = renderer.documents.single;
      await tester.pumpWidget(const SizedBox.shrink());
      expect(document.semanticsForPage(0), contains('度漪'));
      expect(
        await tester.runAsync(() => File(job.paths.single).exists()),
        isTrue,
      );
      result.complete(
        const RoleCardDeliveryResult(RoleCardDeliveryStatus.saved, count: 1),
      );
      await _finishIo(tester, () => !job.directory.existsSync());
      await tester.pump();
      expect(() => document.semanticsForPage(0), throwsStateError);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'leaving during generation cancels delivery and releases the completed job',
    (tester) async {
      _view(tester, const Size(390, 844));
      final job = await _makeJob(tester);
      final generated = Completer<void>();
      final service = _PreparedExports([job])
        ..generationGate = generated.future;
      final renderer = _RecordingRenderer();
      final delivery = _Delivery();
      await _openPreview(
        tester,
        RoleCardSnapshot(name: '度漪'),
        renderer: renderer,
        delivery: delivery,
        exportService: service,
      );
      await tester.tap(find.byKey(_save));
      await tester.pump();
      expect(service.calls, 1);
      final document = renderer.documents.single;
      await tester.pumpWidget(const SizedBox.shrink());
      expect(service.lastCancellationCheck!(), isTrue);
      expect(document.semanticsForPage(0), contains('度漪'));
      generated.complete();
      await _finishIo(tester, () => !job.directory.existsSync());
      expect(delivery.saveCalls, 0);
      expect(delivery.shareCalls, 0);
      expect(() => document.semanticsForPage(0), throwsStateError);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'narrow large-text controls and the end of a long field sheet remain reachable',
    (tester) async {
      _view(tester, const Size(320, 568));
      final renderer = _RecordingRenderer();
      final longSetting = List.filled(60, '长设定完整保留在续页中。').join('\n');
      final snapshot = RoleCardSnapshot(
        name: '度漪',
        customAttributes: List.generate(
          18,
          (index) => RoleCustomAttribute(
            name: '属性 $index',
            content: index == 17 ? longSetting : '内容 $index',
          ),
        ),
      );
      await _openPreview(tester, snapshot, renderer: renderer, textScale: 2.5);
      await tester.ensureVisible(find.byKey(_save));
      await _settle(tester);
      expect(find.byKey(_save).hitTestable(), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const Key('role-card-share-label')),
      );
      await _settle(tester);
      expect(
        find.byKey(const Key('role-card-share-label')).hitTestable(),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byKey(_fields));
      await _settle(tester);
      await tester.tap(find.byKey(_fields));
      await _settle(tester);
      await _toggle(tester, 'role-card-attribute-17');
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const Key('role-card-attribute-17')),
            )
            .value,
        isTrue,
      );
      expect(find.byKey(_apply).hitTestable(), findsOneWidget);
      await tester.tap(find.byKey(_apply));
      await _settle(tester);
      expect(renderer.inputs.last.sections.single.value, longSetting);
      final pageCount = renderer.documents.last.pageCount;
      expect(pageCount, greaterThan(1));
      await tester.ensureVisible(find.byTooltip('下一张'));
      await _settle(tester);
      await tester.tap(find.byTooltip('下一张'));
      await _settle(tester);
      expect(find.text('2 / $pageCount'), findsOneWidget);
      await tester.ensureVisible(find.byKey(_save));
      await _settle(tester);
      expect(find.byKey(_save).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

void _view(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _openPreview(
  WidgetTester tester,
  RoleCardSnapshot snapshot, {
  RoleCardRenderer renderer = const RoleCardRenderer(),
  RoleCardDelivery? delivery,
  RoleCardExportService? exportService,
  double textScale = 1,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: zaidangLightTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: RoleCardExportPage(
        snapshot: snapshot,
        renderer: renderer,
        delivery: delivery ?? _Delivery(),
        exportService: exportService,
      ),
    ),
  );
  if (settle) await _settle(tester);
}

Future<void> _openEditor(
  WidgetTester tester,
  FakeRoleRepository repository,
  Role? role,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [roleRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        theme: zaidangLightTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => RoleCreatePage(role: role)),
              ),
              child: const Text('打开角色'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开角色'));
  await _settle(tester);
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      240,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 30,
    );
  } else {
    await tester.ensureVisible(finder.first);
  }
  await _settle(tester);
}

Future<void> _toggle(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  final sheetScroll = find.descendant(
    of: find.byType(RoleCardFieldPicker),
    matching: find.byType(Scrollable),
  );
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      280,
      scrollable: sheetScroll,
      maxScrolls: 35,
    );
  } else {
    await tester.ensureVisible(finder);
  }
  await _settle(tester);
  await tester.tap(finder);
  await _settle(tester);
}

Finder _input(String text) => find.byWidgetPredicate(
  (widget) => widget is TextFormField && widget.controller?.text == text,
);
bool _canSave(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byKey(_save)).onPressed != null;
OutlinedButton _shareButton(WidgetTester tester) =>
    tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.byKey(const Key('role-card-share-label')),
        matching: find.byType(OutlinedButton),
      ),
    );

Future<RoleCardExportJob> _makeJob(WidgetTester tester) async {
  final job = await tester.runAsync(() async {
    final root = await Directory.systemTemp.createTemp('role-card-page-test-');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    return RoleCardExportService(temporaryDirectory: () async => root).render(
      pageCount: 1,
      renderPage: (_) async => base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==',
      ),
    );
  });
  return job!;
}

Future<void> _finishIo(WidgetTester tester, bool Function() complete) async {
  var completionFrames = 0;
  for (var i = 0; i < 100; i++) {
    // File futures use the real event loop; their awaiting UI continuations
    // use the fake clock. Advance both, including cleanup's final callback.
    await tester.pump();
    final done = await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return complete();
    });
    completionFrames = done == true ? completionFrames + 1 : 0;
    if (completionFrames == 3) return;
  }
  fail('the asynchronous export should finish');
}

Role _role() => const Role(
  id: 1,
  name: '原始名字',
  sex: '',
  age: '',
  birthday: '',
  race: '',
  occupation: '',
  desc: '原始设定',
  coverImg: '',
  customAttributes: [
    RoleCustomAttribute(name: '同名属性', content: '第一份内容'),
    RoleCustomAttribute(name: '同名属性', content: '第二份内容'),
  ],
);

class _RecordingRenderer extends RoleCardRenderer {
  final inputs = <RoleCardContent>[];
  final documents = <RoleCardDocument>[];
  Future<void>? firstPreparationGate;

  @override
  Future<RoleCardDocument> prepare(
    RoleCardContent content, {
    Future<Directory> Function()? supportDirectory,
  }) async {
    final first = inputs.isEmpty;
    inputs.add(content);
    final document = await super.prepare(
      content,
      supportDirectory: supportDirectory,
    );
    documents.add(document);
    if (first) await firstPreparationGate;
    return document;
  }
}

class _PreparedExports extends RoleCardExportService {
  _PreparedExports(this.jobs);
  final List<RoleCardExportJob> jobs;
  int calls = 0;
  final requestedPageCounts = <int>[];
  final cancellationChecks = <bool?>[];
  Future<void>? generationGate;
  bool Function()? lastCancellationCheck;

  @override
  Future<RoleCardExportJob> render({
    required int pageCount,
    required Future<Uint8List> Function(int page) renderPage,
    bool Function()? isCancelled,
    void Function(int completed, int total)? onProgress,
  }) async {
    calls++;
    requestedPageCounts.add(pageCount);
    cancellationChecks.add(isCancelled?.call());
    lastCancellationCheck = isCancelled;
    await generationGate;
    return jobs.removeAt(0);
  }
}

class _Delivery implements RoleCardDelivery {
  int saveCalls = 0;
  int shareCalls = 0;
  Rect? lastOrigin;
  final deliveredPaths = <List<String>>[];
  Future<RoleCardDeliveryResult> Function(int call)? saveAction;
  @override
  bool get canSave => true;
  @override
  bool get canShare => true;
  @override
  String get saveLabel => '保存图片';
  @override
  Future<RoleCardDeliveryResult> save(List<String> paths) {
    saveCalls++;
    deliveredPaths.add(List.of(paths));
    final action = saveAction;
    if (action != null) return action(saveCalls);
    return Future.value(
      const RoleCardDeliveryResult(RoleCardDeliveryStatus.cancelled),
    );
  }

  @override
  Future<RoleCardDeliveryResult> share(List<String> paths, Rect origin) async {
    shareCalls++;
    lastOrigin = origin;
    deliveredPaths.add(List.of(paths));
    return const RoleCardDeliveryResult(RoleCardDeliveryStatus.cancelled);
  }
}

class _RecordingRepository extends FakeRoleRepository {
  _RecordingRepository(super.roles);
  int writes = 0;
  Future<void>? saveGate;

  @override
  Future<Role> update(Role role) async {
    writes++;
    await saveGate;
    return super.update(role);
  }

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
    writes++;
    await saveGate;
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
}

// FontLoader retains a real-zone Future. Drain it after mounting each new
// document before advancing animations in the widget test's fake clock.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 20)),
  );
  await tester.pumpAndSettle();
}
