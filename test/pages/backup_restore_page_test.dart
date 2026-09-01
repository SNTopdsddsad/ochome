import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/data/providers/icloud_backup_provider.dart';
import 'package:ochome/pages/backup_restore_page.dart';
import 'package:ochome/theme/zaidang_theme.dart';
import 'package:ochome/theme/zaidang_tokens.dart';

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
}
