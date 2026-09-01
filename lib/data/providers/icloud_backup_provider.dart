import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../app_version.dart';
import '../services/icloud_backup_service.dart';
import '../services/icloud_container.dart';

final iCloudContainerProvider = Provider<ICloudContainer>((ref) {
  return createICloudContainer();
});

final iCloudBackupServiceProvider = Provider<ICloudBackupService>((ref) {
  return ICloudBackupService(
    container: ref.watch(iCloudContainerProvider),
    supportDirectory: getApplicationSupportDirectory,
    appVersion: kAppVersion,
  );
});
