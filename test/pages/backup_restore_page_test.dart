import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/data/providers/icloud_backup_provider.dart';
import 'package:ochome/data/services/backup_exceptions.dart';
import 'package:ochome/data/services/icloud_backup_service.dart';
import 'package:ochome/data/services/restore_progress.dart';
import 'package:ochome/pages/backup_restore_page.dart';
import 'package:ochome/theme/zaidang_theme.dart';
import 'package:ochome/theme/zaidang_tokens.dart';
import 'package:ochome/widgets/zaidang_confirm_dialog.dart';

import '../fakes/fake_icloud_container.dart';

void main() {
  testWidgets('Android shows unavailability copy and no backup button', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          iCloudContainerProvider.overrideWithValue(FakeICloudContainer()),
        ],
        child: MaterialApp(
          theme: zaidangLightTheme(),
          home: const BackupRestorePage(icloudSupported: false),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('iCloud 备份仅在 iPhone 和 Mac 上可用'), findsOneWidget);
    expect(find.text('备份到 iCloud'), findsNothing);
    expect(find.text('从 iCloud 恢复'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('Apple restore control is ink outline, not accent fill', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          iCloudContainerProvider.overrideWithValue(FakeICloudContainer()),
        ],
        child: MaterialApp(
          theme: zaidangLightTheme(),
          home: const BackupRestorePage(icloudSupported: true),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('备份到 iCloud'), findsOneWidget);
    expect(find.text('从 iCloud 恢复'), findsOneWidget);
    expect(find.text('保存到文件'), findsOneWidget);

    final restore = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '从 iCloud 恢复'),
    );
    expect(
      restore.style?.foregroundColor?.resolve(const {}),
      ZaidangTokens.light.ink,
    );
  });

  testWidgets(
    'cloud restore waits for explicit confirmation and cleans plans',
    (tester) async {
      final service = _DialogBackupService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [iCloudBackupServiceProvider.overrideWithValue(service)],
          child: MaterialApp(
            theme: zaidangLightTheme(),
            home: const BackupRestorePage(icloudSupported: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('从 iCloud 恢复'));
      await tester.pumpAndSettle();
      expect(find.byType(ZaidangConfirmDialog), findsOneWidget);
      expect(find.text('这次替换无法撤销。'), findsOneWidget);
      expect(find.byKey(const Key('zaidang-confirm-sparkle')), findsNothing);
      expect(service.prepareCalls, 0);
      await tester.tap(find.byKey(const Key('zaidang-confirm-cancel')));
      await tester.pumpAndSettle();
      expect(service.plans.single.disposeCalls, 1);
      expect(service.prepareCalls, 0);

      await tester.tap(find.text('从 iCloud 恢复'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('zaidang-confirm-action')));
      await tester.pumpAndSettle();
      expect(service.prepareCalls, 1);
      expect(service.preparedPlan, same(service.plans.last));
      expect(service.plans.last.disposeCalls, 1);
      expect(find.byType(ZaidangConfirmDialog), findsNothing);
      expect(find.text('测试下载失败'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, '从 iCloud 恢复'),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

/// Tests the page's confirmation boundary without touching disk or iCloud.
class _DialogBackupService extends ICloudBackupService {
  _DialogBackupService()
    : super(
        container: FakeICloudContainer(),
        supportDirectory: () async => Directory('/unused-dialog-test'),
      );

  final plans = <_TrackedPlan>[];
  int prepareCalls = 0;
  RestorePlan? preparedPlan;

  @override
  Future<ICloudStatus> status() async => const ICloudStatus(available: true);

  @override
  Future<RestorePlan> inspectBackup({
    void Function(RestoreProgress progress)? onProgress,
  }) async {
    final plan = _TrackedPlan();
    plans.add(plan);
    return plan;
  }

  @override
  Future<RestorePlan> prepareRestore({
    RestorePlan? inspection,
    void Function(RestoreProgress progress)? onProgress,
  }) async {
    prepareCalls++;
    preparedPlan = inspection;
    throw const RestoreFailedException('测试下载失败');
  }
}

class _TrackedPlan extends RestorePlan {
  _TrackedPlan()
    : super(
        workDir: Directory('/unused-dialog-test'),
        sqliteSnapshot: File('/unused-dialog-test/snapshot'),
        coversDir: Directory('/unused-dialog-test/covers'),
        schemaVersion: 1,
      );

  int disposeCalls = 0;

  @override
  Future<void> dispose() async => disposeCalls++;
}
