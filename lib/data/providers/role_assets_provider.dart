import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/role_asset.dart';
import '../repositories/drift_role_asset_repository.dart';
import '../repositories/role_asset_repository.dart';
import '../services/role_asset_picker.dart';
import '../services/role_asset_opener.dart';
import '../services/video_thumbnail_service.dart';
import 'app_database_provider.dart';
import 'database_switch_provider.dart';

final roleAssetRepositoryProvider = Provider<RoleAssetRepository>((ref) {
  return DriftRoleAssetRepository(ref.watch(appDatabaseProvider));
});

final roleAssetsProvider = StreamProvider.autoDispose
    .family<List<RoleAsset>, int>((ref, roleId) {
      if (ref.watch(databaseSwitchProvider)) return const Stream.empty();
      return ref.watch(roleAssetRepositoryProvider).watchForRole(roleId);
    });

/// 角色 id → 资产数；供首页列表一次订阅，没有资产的角色不在表里。
final roleAssetCountsProvider = StreamProvider.autoDispose<Map<int, int>>((
  ref,
) {
  if (ref.watch(databaseSwitchProvider)) return const Stream.empty();
  return ref.watch(roleAssetRepositoryProvider).watchAssetCounts();
});

final roleAssetPickerProvider = Provider<RoleAssetPicker>(
  (ref) => RoleAssetPicker(),
);
final roleAssetOpenerProvider = Provider<RoleAssetOpener>(
  (ref) => RoleAssetOpener(),
);

final videoThumbnailServiceProvider = Provider<VideoThumbnailService>(
  (ref) => VideoThumbnailService(),
);
