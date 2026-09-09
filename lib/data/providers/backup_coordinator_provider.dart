import 'dart:async';

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/backup/backup_coordinator.dart';
import '../../features/backup/backup_transport.dart';
import '../services/data_storage.dart';
import 'app_database_provider.dart';
import 'database_switch_provider.dart';
import 'role_assets_provider.dart';
import 'role_desc_revisions_provider.dart';
import 'role_repository_provider.dart';
import 'roles_provider.dart';

final backupTransportProvider = Provider<BackupTransport>((ref) {
  return MethodChannelBackupTransport();
});

/// App-scoped, not auto-disposed when the backup page leaves the navigation stack.
final backupCoordinatorProvider = FutureProvider<BackupCoordinator>((
  ref,
) async {
  final storage = DataStorage.current ?? await initializeDataStorage();
  if (!storage.isRecoveryOnly) {
    // On a pristine installation this materializes the ordinary local schema
    // before the snapshot reader runs; recovery-only must never create an empty DB.
    await ref.read(appDatabaseProvider).customSelect('SELECT 1').get();
  }
  final coordinator = BackupCoordinator(
    storage: storage,
    transport: ref.watch(backupTransportProvider),
    closeDatabase: () async {
      ref.read(databaseSwitchProvider.notifier).begin();
      // Hidden routes pause their streams. Drift.close waits for their done
      // events, which cannot arrive until those subscriptions are cancelled.
      ref.invalidate(rolesProvider);
      ref.invalidate(roleAssetsProvider);
      ref.invalidate(roleDescRevisionsProvider);
      if (!storage.isRecoveryOnly) await ref.read(appDatabaseProvider).close();
    },
    reopenDatabase: () async {
      ref.invalidate(appDatabaseProvider);
      ref.invalidate(roleRepositoryProvider);
      ref.invalidate(roleAssetRepositoryProvider);
      ref.invalidate(rolesProvider);
      await ref
          .read(appDatabaseProvider)
          .customSelect('SELECT id FROM role LIMIT 1')
          .get();
      imageCache.clear();
      imageCache.clearLiveImages();
      ref.read(databaseSwitchProvider.notifier).complete();
    },
  );
  ref.onDispose(() => unawaited(coordinator.dispose()));
  await coordinator.recoverOnStartup();
  return coordinator;
});
