import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/features/backup/backup_coordinator.dart';
import 'package:ochome/features/backup/backup_models.dart';
import 'package:ochome/features/backup/backup_protocol.dart';
import 'package:ochome/pages/backup_contents_page.dart';
import 'package:ochome/theme/zaidang_theme.dart';

const _snapshotId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _writerId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const _otherSnapshotId = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
const _contents = SnapshotContents(
  snapshotId: _snapshotId,
  schemaVersion: 8,
  summary: SnapshotSummary(
    roleCount: 1,
    revisionCount: 1,
    customAttributeCount: 0,
    coverCount: 1,
    assetCount: 0,
    originalFileCount: 1,
    logicalDataBytes: 3,
    assetCountsByKind: {'image': 0, 'video': 0, 'audio': 0, 'document': 0},
  ),
  roles: [
    SnapshotRole(
      roleId: 1,
      name: '备份里的角色',
      customAttributeNamesInOrder: [],
      revisionCount: 1,
      assetIds: [],
      coverRelativePath: 'covers/a.png',
    ),
  ],
  files: [
    SnapshotContentFile(
      relativePath: 'covers/a.png',
      objectId: _snapshotId,
      roleIds: [1],
      displayName: '角色立绘.png',
      kind: 'cover',
      bytes: 3,
    ),
  ],
);
final _descriptor = BackupDescriptor(
  snapshotId: _snapshotId,
  writerId: _writerId,
  basePath: 'writers/$_writerId/snapshots/$_snapshotId',
  createdAtUtc: DateTime.utc(2026, 9, 9, 6, 32),
  appVersion: '1.0.0+100',
  schemaVersion: 8,
  roleCount: 1,
  revisionCount: 1,
  assetCount: 0,
  fileCount: 1,
  totalBytes: 3,
  manifestSha256: '0' * 64,
  commitSha256: '1' * 64,
  deviceName: 'iPhone',
);
final _otherDescriptor = BackupDescriptor(
  snapshotId: _otherSnapshotId,
  writerId: _writerId,
  basePath: 'writers/$_writerId/snapshots/$_otherSnapshotId',
  createdAtUtc: DateTime.utc(2026, 9, 8, 6, 32),
  appVersion: '1.0.0+100',
  schemaVersion: 8,
  roleCount: 1,
  revisionCount: 1,
  assetCount: 0,
  fileCount: 1,
  totalBytes: 3,
  manifestSha256: '2' * 64,
  commitSha256: '3' * 64,
  deviceName: 'Mac',
);

void main() {
  testWidgets('large file indexes stay grouped and shared files count once', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const categories = {
      'cover': 2,
      'image': 501,
      'video': 300,
      'audio': 100,
      'document': 100,
    };
    final files = [
      for (final entry in categories.entries)
        for (var i = 0; i < entry.value; i++)
          SnapshotContentFile(
            relativePath: '${entry.key}/$i.bin',
            objectId: '${entry.key}-$i',
            roleIds: i.isEven ? [1, 2] : [2],
            displayName: '不应显示的文件-${entry.key}-$i',
            kind: entry.key,
            bytes: 1,
          ),
    ];
    final contents = SnapshotContents(
      snapshotId: _snapshotId,
      schemaVersion: 8,
      summary: const SnapshotSummary(
        roleCount: 2,
        revisionCount: 1,
        customAttributeCount: 0,
        coverCount: 2,
        assetCount: 1001,
        originalFileCount: 1003,
        logicalDataBytes: 1003,
        assetCountsByKind: {
          'image': 501,
          'video': 300,
          'audio': 100,
          'document': 100,
        },
      ),
      roles: [
        ..._contents.roles,
        const SnapshotRole(
          roleId: 2,
          name: '另一角色',
          customAttributeNamesInOrder: [],
          revisionCount: 0,
          assetIds: [],
          coverRelativePath: null,
        ),
      ],
      files: files,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: zaidangDarkTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!,
        ),
        home: BackupContentsPage(loadContents: () async => contents),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看备份内容'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '文件分类'));
    await tester.pumpAndSettle();
    for (final entry in categories.entries) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey('backup-file-category-${entry.key}')),
          matching: find.text('${entry.value} 个'),
        ),
        findsOneWidget,
      );
    }
    expect(find.textContaining('不应显示的文件'), findsNothing);
    expect(find.byType(ListTile), findsNothing);
    expect(find.byTooltip('下一页'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(ChoiceChip, '角色资料'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('备份里的角色'));
    await tester.tap(find.text('备份里的角色'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('backup-file-category-image')),
        matching: find.text('251 个'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('不应显示的文件'), findsNothing);
    expect(find.byTooltip('下一页'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty file category shows no zero-count rows', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: zaidangLightTheme(),
        home: BackupContentsPage(
          loadContents: () async => const SnapshotContents(
            snapshotId: _snapshotId,
            schemaVersion: 8,
            summary: SnapshotSummary(
              roleCount: 0,
              revisionCount: 0,
              customAttributeCount: 0,
              coverCount: 0,
              assetCount: 0,
              originalFileCount: 0,
              logicalDataBytes: 0,
              assetCountsByKind: {
                'image': 0,
                'video': 0,
                'audio': 0,
                'document': 0,
              },
            ),
            roles: [],
            files: [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看备份内容'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '文件分类'));
    await tester.pumpAndSettle();
    expect(find.text('暂无文件'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('backup-file-category-cover')),
      findsNothing,
    );
    expect(find.byTooltip('下一页'), findsNothing);
  });

  testWidgets(
    'only a newly observed ready restore opens review automatically',
    (tester) async {
      final coordinator = _DetailCoordinator();
      addTearDown(coordinator.dispose);
      coordinator.job = _restoreJob(BackupPhase.downloading);
      var reviewCalls = 0;

      Widget page() => _detailApp(
        coordinator: coordinator,
        onReviewRestore: (_) async => reviewCalls++,
      );

      await tester.pumpWidget(page());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(reviewCalls, 0);

      coordinator.emit(_restoreJob(BackupPhase.readyForReview));
      await tester.pump();
      await tester.pump();
      expect(reviewCalls, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(page());
      await tester.pump();
      await tester.pump();
      expect(reviewCalls, 1);
      expect(find.byKey(const Key('backup-review-restore')), findsOneWidget);
    },
  );

  testWidgets('restore intent stays on detail and shows its downloading job', (
    tester,
  ) async {
    final coordinator = _DetailCoordinator();
    addTearDown(coordinator.dispose);

    await tester.pumpWidget(
      _detailApp(
        coordinator: coordinator,
        onPrepareRestore: () async {
          coordinator.emit(_restoreJob(BackupPhase.downloading));
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('backup-prepare-restore')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('备份详情'), findsOneWidget);
    expect(find.text('正在下载并检查'), findsOneWidget);
    expect(find.byKey(const Key('backup-job-panel')), findsOneWidget);
    expect(find.byKey(const Key('backup-prepare-restore')), findsNothing);
    expect(find.text('根页面'), findsNothing);
  });

  testWidgets('ready restore behind a nested contents route waits for a tap', (
    tester,
  ) async {
    final coordinator = _DetailCoordinator();
    addTearDown(coordinator.dispose);
    coordinator.job = _restoreJob(BackupPhase.downloading);
    var reviewCalls = 0;

    await tester.pumpWidget(
      _detailApp(
        coordinator: coordinator,
        onReviewRestore: (_) async => reviewCalls++,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('查看备份内容'));
    await tester.pump();
    await tester.tap(find.text('备份里的角色'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('基础资料与设定'), findsOneWidget);

    coordinator.emit(_restoreJob(BackupPhase.readyForReview));
    await tester.pump();
    await tester.pump();
    expect(reviewCalls, 0);

    await tester.tap(find.byType(BackButton).hitTestable());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('backup-review-restore')), findsOneWidget);
    expect(reviewCalls, 0);
  });

  testWidgets('activation hides back affordance and blocks route pop', (
    tester,
  ) async {
    final coordinator = _DetailCoordinator();
    addTearDown(coordinator.dispose);
    coordinator.job = _restoreJob(BackupPhase.activating);

    await tester.pumpWidget(_detailApp(coordinator: coordinator));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(BackButton), findsNothing);
    expect(find.text('正在恢复资料'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('备份详情'), findsOneWidget);
    expect(find.text('根页面'), findsNothing);
  });

  testWidgets('restore job for another snapshot is not shown here', (
    tester,
  ) async {
    final coordinator = _DetailCoordinator();
    addTearDown(coordinator.dispose);
    coordinator.job = _restoreJob(
      BackupPhase.downloading,
      descriptor: _otherDescriptor,
    );

    await tester.pumpWidget(
      _detailApp(coordinator: coordinator, onPrepareRestore: () async {}),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('backup-job-panel')), findsNothing);
    expect(find.byKey(const Key('backup-prepare-restore')), findsOneWidget);
  });
}

Widget _detailApp({
  required BackupCoordinator coordinator,
  Future<void> Function()? onPrepareRestore,
  Future<void> Function(BackupJobState)? onReviewRestore,
}) => MaterialApp(
  theme: zaidangLightTheme(),
  initialRoute: '/detail',
  routes: {
    '/': (_) => const Scaffold(body: Center(child: Text('根页面'))),
    '/detail': (_) => BackupContentsPage(
      title: '备份详情',
      descriptor: _descriptor,
      loadContents: () async => _contents,
      coordinator: coordinator,
      onPrepareRestore: onPrepareRestore,
      onReviewRestore: onReviewRestore,
    ),
  },
);

BackupJobState _restoreJob(BackupPhase phase, {BackupDescriptor? descriptor}) =>
    BackupJobState(
      operationId: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      kind: BackupJobKind.restore,
      phase: phase,
      startedAtUtc: DateTime.utc(2026, 9, 9, 6, 35),
      descriptor: descriptor ?? _descriptor,
      contents: _contents,
      restorePreview: phase == BackupPhase.readyForReview
          ? const RestorePreview(
              incoming: _contents,
              current: _contents,
              datasetEpoch: 0,
              mutationRevision: 0,
              additionalBytes: 0,
            )
          : null,
    );

class _DetailCoordinator implements BackupCoordinator {
  final _events = StreamController<BackupJobState>.broadcast();
  BackupJobState? job;

  @override
  BackupJobState? get currentJob => job;

  @override
  Stream<BackupJobState> watchJob() => _events.stream;

  void emit(BackupJobState next) {
    job = next;
    _events.add(next);
  }

  @override
  Future<void> dispose() => _events.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
