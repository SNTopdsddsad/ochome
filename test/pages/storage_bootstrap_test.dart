import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/bootstrap.dart';
import 'package:ochome/data/providers/backup_coordinator_provider.dart';
import 'package:ochome/data/providers/role_repository_provider.dart';
import 'package:ochome/data/services/data_storage.dart';
import 'package:ochome/features/backup/backup_models.dart';

import '../fakes/backup_test_support.dart';
import '../fakes/fake_role_repository.dart';

void main() {
  late Directory root;
  DataStorage? storage;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('bootstrap-routing');
  });
  tearDown(() async {
    await storage?.close();
    storage = null;
    await root.delete(recursive: true);
  });

  Future<void> pumpStartup(
    WidgetTester tester, {
    bool failReplace = false,
  }) async {
    await tester.runAsync(() async {
      final ready = failReplace
          ? DataStorage.open(
              root,
              allowRecovery: true,
              atomicReplace: (_, _) async => throw PlatformException(
                code: 'unsafe_path',
                message: '测试：本机指针替换失败',
              ),
            )
          : initializeDataStorage(supportDirectory: () async => root);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            roleRepositoryProvider.overrideWithValue(FakeRoleRepository()),
            backupCoordinatorProvider.overrideWith((ref) async {
              throw const BackupFailure('cloud_configuration', '测试云端不可用');
            }),
          ],
          child: AppStorageBootstrap(initialize: () => ready),
        ),
      );
      try {
        storage = await ready;
      } catch (_) {
        // The bootstrap must present this failure instead of a backup route.
      }
    });
    await tester.pumpAndSettle();
  }

  testWidgets('fresh real storage bootstrap opens the archive without iCloud', (
    tester,
  ) async {
    await pumpStartup(tester);
    expect(find.widgetWithText(Tab, 'OC'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('备份与恢复'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'healthy existing SQLite opens home through real bootstrap and router',
    (tester) async {
      createFixture(root);
      await pumpStartup(tester);
      expect(storage!.isRecoveryOnly, isFalse);
      expect(find.widgetWithText(Tab, 'OC'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(readName(root), '白鸦');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'native pointer failure shows retry and actual local error, not backup',
    (tester) async {
      createFixture(root);
      await pumpStartup(tester, failReplace: true);
      expect(find.text('暂时无法打开本机资料'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
      expect(find.text('备份与恢复'), findsNothing);
      await tester.tap(find.text('查看本机错误详情'));
      await tester.pumpAndSettle();
      expect(find.textContaining('测试：本机指针替换失败'), findsOneWidget);
      expect(readName(root), '白鸦');
      await tester.pumpWidget(const SizedBox.shrink());
      storage = await tester.runAsync(() => DataStorage.open(root));
    },
  );

  testWidgets('actual corrupt SQLite remains protected by recovery route', (
    tester,
  ) async {
    final file = File('${root.path}/ochome.sqlite');
    file.writeAsStringSync('damaged original');
    await pumpStartup(tester);
    expect(storage!.isRecoveryOnly, isTrue);
    expect(find.text('备份与恢复'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(file.readAsStringSync(), 'damaged original');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
