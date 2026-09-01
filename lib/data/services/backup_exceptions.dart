/// 备份 / 恢复的用户可见错误。UI 直接展示 [userMessage]。
sealed class BackupException implements Exception {
  const BackupException(this.userMessage);

  final String userMessage;

  @override
  String toString() => userMessage;
}

class ICloudUnavailableException extends BackupException {
  const ICloudUnavailableException([
    super.userMessage = '未登录 iCloud，或 iCloud 云盘不可用',
  ]);
}

class ICloudNoBackupException extends BackupException {
  const ICloudNoBackupException([super.userMessage = 'iCloud 里还没有备份']);
}

class BackupNewerThanAppException extends BackupException {
  const BackupNewerThanAppException([
    super.userMessage = '这份备份来自更新版本的 App，请先升级后再恢复',
  ]);
}

class BackupTooOldException extends BackupException {
  const BackupTooOldException([super.userMessage = '这份备份过旧，无法在当前版本恢复']);
}

class BackupFailedException extends BackupException {
  const BackupFailedException([super.userMessage = '备份失败，请稍后重试']);
}

class RestoreFailedException extends BackupException {
  const RestoreFailedException([super.userMessage = '恢复失败，本机数据未改动']);
}
