import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/role_asset.dart';
import '../repositories/drift_role_asset_repository.dart';
import '../repositories/role_asset_repository.dart';
import '../services/role_asset_picker.dart';
import '../services/role_asset_opener.dart';
import '../services/video_thumbnail_service.dart';
import 'app_database_provider.dart';

final roleAssetRepositoryProvider = Provider<RoleAssetRepository>((ref) {
  return DriftRoleAssetRepository(ref.watch(appDatabaseProvider));
});

final roleAssetsProvider = StreamProvider.autoDispose
    .family<List<RoleAsset>, int>((ref, roleId) {
      return ref.watch(roleAssetRepositoryProvider).watchForRole(roleId);
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
