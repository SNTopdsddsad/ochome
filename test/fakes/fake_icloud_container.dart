import 'dart:io';

import 'package:ochome/data/services/backup_exceptions.dart';
import 'package:ochome/data/services/icloud_container.dart';

class FakeICloudContainer implements ICloudContainer {
  FakeICloudContainer({this.available = true});

  bool available;
  bool hideFromList = false;
  final Map<String, List<int>> files = {};
  int uploadCount = 0;
  bool failNextDownload = false;
  String? failDownloadOf;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<String?> backupRoot() async =>
      available ? '/fake/${ICloudContainer.backupFolder}' : null;

  @override
  Future<void> upload({
    required String localPath,
    required String relativePath,
  }) async {
    _ensureAvailable();
    files[relativePath] = await File(localPath).readAsBytes();
    uploadCount += 1;
  }

  @override
  Future<void> download({
    required String relativePath,
    required String localPath,
  }) async {
    _ensureAvailable();
    if (failNextDownload || failDownloadOf == relativePath) {
      failNextDownload = false;
      throw const RestoreFailedException('模拟下载失败');
    }
    final bytes = files[relativePath];
    if (bytes == null) {
      throw ICloudUnavailableException('iCloud 中找不到 $relativePath');
    }
    final file = File(localPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<List<ICloudEntry>> list(String relativeDir) async {
    _ensureAvailable();
    if (hideFromList) {
      return [];
    }
    final prefix = relativeDir.isEmpty ? '' : '$relativeDir/';
    return [
      for (final entry in files.entries)
        if (relativeDir.isEmpty ||
            entry.key == relativeDir ||
            entry.key.startsWith(prefix))
          ICloudEntry(relativePath: entry.key, bytes: entry.value.length),
    ];
  }

  @override
  Future<void> delete(String relativePath) async {
    _ensureAvailable();
    files.remove(relativePath);
  }

  @override
  Future<void> exportToDrive() async {
    _ensureAvailable();
  }

  void _ensureAvailable() {
    if (!available) {
      throw const ICloudUnavailableException();
    }
  }
}
