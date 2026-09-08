import 'dart:io';
import 'dart:math';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;

import 'local_file_store.dart';
import 'file_fingerprint_store.dart';
import 'managed_file_importer.dart';
import 'data_storage.dart';

class RoleAssetStore extends LocalFileStore {
  RoleAssetStore(super.supportDir) : super(directoryName: folderName);

  FileFingerprintStore _fingerprints() {
    final current = DataStorage.current;
    return FileFingerprintStore(
      current != null &&
              (p.equals(current.supportDirectory.path, supportDir.path) ||
                  p.isWithin(current.supportDirectory.path, supportDir.path))
          ? current.controlDirectory
          : Directory(p.join(supportDir.path, 'storage-control')),
    );
  }

  static const folderName = 'role_assets';
  static final _random = Random.secure();

  static bool isValidPath(String path) =>
      path.startsWith('$folderName/') &&
      RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._-]*$')
          .hasMatch(path.substring(folderName.length + 1));

  File resolve(String relativePath) {
    if (!isValidPath(relativePath)) {
      throw const FormatException('资产文件路径无效');
    }
    return File(p.join(supportDir.path, relativePath));
  }

  /// 流式复制，较大的视频不整体读进内存；完成后才公开最终文件名。
  Future<LocalStoredFile> importFile(XFile source) async {
    await directory.create(recursive: true);
    final suffix = p.extension(source.name).toLowerCase();
    final extension = RegExp(r'^\.[a-z0-9]{1,12}$').hasMatch(suffix)
        ? suffix
        : '';
    final id = List.generate(
      16,
      (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final relativePath = '$folderName/$id$extension';
    final target = resolve(relativePath);
    final fingerprints = _fingerprints();
    try {
      await ManagedFileImporter.copy(
        source,
        target,
        fingerprints: fingerprints,
      );
      return LocalStoredFile(file: target, relativePath: relativePath);
    } finally {
      await fingerprints.close();
    }
  }
}
