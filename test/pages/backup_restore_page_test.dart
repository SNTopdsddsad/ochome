import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/data/providers/backup_coordinator_provider.dart';
import 'package:ochome/data/services/data_storage.dart';
import 'package:ochome/features/backup/backup_coordinator.dart';
import 'package:ochome/features/backup/backup_models.dart';
import 'package:ochome/features/backup/backup_protocol.dart';
import 'package:ochome/features/backup/widgets/backup_job_panel.dart';
import 'package:ochome/pages/backup_contents_page.dart';
import 'package:ochome/pages/backup_restore_page.dart';
import 'package:ochome/theme/zaidang_theme.dart';
import 'package:ochome/theme/zaidang_tokens.dart';

const _snapshotId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _writerId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const _jobId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const _summary = SnapshotSummary(
  roleCount: 1,
  revisionCount: 2,
  customAttributeCount: 1,
  coverCount: 1,
  assetCount: 1,
  originalFileCount: 2,
  logicalDataBytes: 1000003,
  assetCountsByKind: {'image': 1, 'video': 0, 'audio': 0, 'document': 0},
);
const _contents = SnapshotContents(
  snapshotId: _snapshotId,
  schemaVersion: 8,
  summary: _summary,
  roles: [
    SnapshotRole(
      roleId: 1,
      name: '备份时的白鸦',
      customAttributeNamesInOrder: ['能力'],
      revisionCount: 2,
      assetIds: [1],
      coverRelativePath: 'covers/a.png',
    ),
  ],
  files: [
    SnapshotContentFile(
      relativePath: 'covers/a.png',
      objectId: _snapshotId,
      roleIds: [1],
      displayName: '白鸦的立绘.png',
      kind: 'cover',
      bytes: 3,
    ),
    SnapshotContentFile(
      relativePath: 'role_assets/a.png',
      objectId: _writerId,
      roleIds: [1],
      assetId: 1,
      displayName: '最初的衣服参考.png',
      kind: 'image',
      bytes: 1000000,
    ),
  ],
);
final _descriptor = BackupDescriptor(
  snapshotId: _snapshotId,
  writerId: _writerId,
  basePath: 'writers/$_writerId/snapshots/$_snapshotId',
  createdAtUtc: DateTime.utc(2026, 9, 8, 1, 36),
  appVersion: '1.0.0+100',
  schemaVersion: 8,
  roleCount: 1,
  revisionCount: 2,
  assetCount: 1,
  fileCount: 2,
  totalBytes: 1000003,
  manifestSha256: '0' * 64,
  commitSha256: '1' * 64,
  deviceName: '测试 iPhone',
  accountSequence: 1,
);

void main() {
  late Directory root;
  late DataStorage storage;
  late _FakeCoordinator coordinator;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('backup-page-test');
    storage = await DataStorage.open(root);
    coordinator = _FakeCoordinator(storage);
  });
  tearDown(() async {
    await coordinator.dispose();
    await storage.close();
    await root.delete(recursive: true);
  });

  Future<void> open(
    WidgetTester tester, {
    bool supported = true,
    bool dark = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backupCoordinatorProvider.overrideWith((ref) async => coordinator),
        ],
        child: MaterialApp(
          theme: dark ? zaidangDarkTheme() : zaidangLightTheme(),
          home: BackupRestorePage(icloudSupported: supported),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'unsupported platform explains availability and never starts a job',
    (tester) async {
      await open(tester, supported: false);
      expect(find.text('iCloud 备份仅在 iPhone 和 Mac 上可用'), findsOneWidget);
      expect(find.byKey(const Key('backup-start')), findsNothing);
      expect(coordinator.availabilityCalls, 0);
    },
  );

  testWidgets(
    'overview shows account-wide retention and no file backup export',
    (tester) async {
      await open(tester);
      expect(find.text('同一 iCloud 账户合计保留最近 3 份'), findsOneWidget);
      expect(find.text('本机已保存资料'), findsOneWidget);
      expect(find.text('保存到文件'), findsNothing);
      expect(find.text('从文件恢复'), findsNothing);
      expect(find.textContaining('测试 iPhone'), findsOneWidget);
      await tester.tap(find.byKey(const Key('backup-start')));
      await tester.pumpAndSettle();
      expect(find.text('这次会备份什么'), findsOneWidget);
      expect(coordinator.backupCalls, 0);
      await tester.tap(find.byKey(const Key('backup-start-confirm')));
      await tester.pumpAndSettle();
      expect(coordinator.backupCalls, 1);
    },
  );

  testWidgets(
    'history contents use frozen names and metadata file information',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: zaidangLightTheme(),
          home: BackupContentsPage(
            loadContents: () async => _contents,
            descriptor: _descriptor,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('备份时的白鸦'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, '文件清单'));
      await tester.pumpAndSettle();
      expect(find.text('最初的衣服参考.png'), findsOneWidget);
      await tester.tap(find.text('最初的衣服参考.png'));
      await tester.pumpAndSettle();
      expect(find.text('所属角色'), findsOneWidget);
      expect(find.text('原始文件大小'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('100 percent of bytes still waiting for cloud is not completed', (
    tester,
  ) async {
    final job = BackupJobState(
      operationId: _jobId,
      kind: BackupJobKind.backup,
      phase: BackupPhase.waitingForCloud,
      startedAtUtc: DateTime.utc(2026, 9, 8),
      completedBytes: 100,
      totalBytes: 100,
      contents: _contents,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: zaidangLightTheme(),
        home: Scaffold(
          body: SingleChildScrollView(child: BackupJobPanel(job: job)),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('等待 iCloud 上传确认'), findsOneWidget);
    expect(find.text('这份备份已完成'), findsNothing);
    final indicator = tester.widget<LinearProgressIndicator>(
      find.byKey(const Key('backup-stage-progress')),
    );
    expect(indicator.value, isNull);
    expect(find.textContaining('正在等待 iCloud 确认文件上传'), findsOneWidget);
    final uploadStep = find
        .ancestor(of: find.text('上传变化内容'), matching: find.byType(Row))
        .first;
    expect(
      find.descendant(
        of: uploadStep,
        matching: find.byIcon(Icons.radio_button_checked),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: uploadStep,
        matching: find.byIcon(Icons.check_circle_outline),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'download ready never activates without explicit review confirmation',
    (tester) async {
      coordinator.job = BackupJobState(
        operationId: _jobId,
        kind: BackupJobKind.restore,
        phase: BackupPhase.readyForReview,
        startedAtUtc: DateTime.utc(2026, 9, 8),
        contentCreatedAtUtc: _descriptor.createdAtUtc,
        contents: _contents,
        descriptor: _descriptor,
        restorePreview: RestorePreview(
          incoming: _contents,
          current: _contents,
          datasetEpoch: 0,
          mutationRevision: 0,
          additionalBytes: 2000000,
        ),
      );
      await open(tester);
      expect(coordinator.confirmCalls, 0);
      final review = find.byKey(const Key('backup-review-restore'));
      await tester.ensureVisible(review);
      await tester.tap(review);
      await tester.pumpAndSettle();
      expect(find.text('用这份备份替换本机资料？'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('测试 iPhone'),
        ),
        findsOneWidget,
      );
      expect(coordinator.confirmCalls, 0);
      await tester.tap(find.text('先不恢复'));
      await tester.pumpAndSettle();
      expect(coordinator.confirmCalls, 0);
      await tester.ensureVisible(review);
      await tester.tap(review);
      await tester.pumpAndSettle();
      final confirm = find.byKey(const Key('backup-activate-confirm'));
      await tester.ensureVisible(confirm);
      final button = tester.widget<OutlinedButton>(confirm);
      expect(
        button.style!.foregroundColor!.resolve({}),
        ZaidangTokens.light.ink,
      );
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(coordinator.confirmCalls, 1);
    },
  );

  testWidgets('reopening the page shows the same app-owned job', (
    tester,
  ) async {
    coordinator.job = BackupJobState(
      operationId: _jobId,
      kind: BackupJobKind.backup,
      phase: BackupPhase.failed,
      startedAtUtc: DateTime.utc(2026, 9, 8),
      failedAtPhase: BackupPhase.uploading,
      error: const BackupFailure('network', '网络暂不可用，请重试'),
      currentItem: '白鸦动作.mp4',
    );
    await open(tester);
    expect(find.text('白鸦动作.mp4'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await open(tester);
    expect(find.text('白鸦动作.mp4'), findsOneWidget);
    expect(coordinator.currentJob!.operationId, _jobId);
    expect(coordinator.backupCalls, 0);
    expect(find.byKey(const Key('backup-retry-job')), findsOneWidget);
  });

  testWidgets('previous-copy cleanup waits for a destructive confirmation', (
    tester,
  ) async {
    coordinator.previous = true;
    await open(tester);
    final cleanup = find.byKey(const Key('backup-discard-previous'));
    await tester.scrollUntilVisible(cleanup, 250);
    await tester.tap(cleanup);
    await tester.pumpAndSettle();
    expect(coordinator.discardCalls, 0);
    await tester.tap(find.byKey(const Key('zaidang-confirm-cancel')));
    await tester.pumpAndSettle();
    expect(coordinator.discardCalls, 0);
    await tester.scrollUntilVisible(cleanup, 250);
    await tester.tap(cleanup);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('zaidang-confirm-action')));
    await tester.pumpAndSettle();
    expect(coordinator.discardCalls, 1);
  });

  for (final dark in [false, true]) {
    testWidgets(
      '${dark ? 'dark' : 'light'} 320px large-text overview and scope fit',
      (tester) async {
        tester.view.physicalSize = const Size(320, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              backupCoordinatorProvider.overrideWith(
                (ref) async => coordinator,
              ),
            ],
            child: MaterialApp(
              theme: dark ? zaidangDarkTheme() : zaidangLightTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.8)),
                child: child!,
              ),
              home: const BackupRestorePage(icloudSupported: true),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final start = find.byKey(const Key('backup-start'));
        await tester.ensureVisible(start);
        await tester.tap(start);
        await tester.pumpAndSettle();
        expect(find.text('这次会备份什么'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _FakeCoordinator implements BackupCoordinator {
  _FakeCoordinator(this.storage);
  @override
  final DataStorage storage;
  final _events = StreamController<BackupJobState>.broadcast();
  BackupJobState? job;
  bool previous = false;
  int availabilityCalls = 0,
      backupCalls = 0,
      confirmCalls = 0,
      discardCalls = 0;
  @override
  BackupJobState? get currentJob => job;
  @override
  BackupFailure? get recoveryNotice => null;
  @override
  bool get previousExists => previous;
  @override
  Stream<BackupJobState> watchJob() => _events.stream;
  @override
  Future<BackupAvailability> availability() async {
    availabilityCalls++;
    return const BackupAvailability(
      supported: true,
      available: true,
      deviceName: '测试 iPhone',
      appVersion: '1.0.0+100',
      accountId: 'test-account',
    );
  }

  @override
  Future<SnapshotContents> currentContents() async => _contents;
  @override
  Future<BackupHistory> listBackups() async => BackupHistory(
    snapshots: [_descriptor],
    legacyExists: false,
    legacyDiscoveryComplete: true,
  );
  @override
  Future<SnapshotContents> contentsFor(BackupSource source) async => _contents;
  @override
  Future<bool> hasPrevious() async => previous;
  @override
  Future<String> startBackup() async {
    backupCalls++;
    return _jobId;
  }

  @override
  Future<void> confirmRestore(String operationId) async {
    confirmCalls++;
  }

  @override
  Future<void> discardPrevious() async {
    discardCalls++;
    previous = false;
  }

  @override
  Future<void> dispose() async {
    if (!_events.isClosed) {
      await _events.close();
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
