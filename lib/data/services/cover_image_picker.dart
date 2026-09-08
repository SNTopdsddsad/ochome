import 'dart:io';
import 'dart:math';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import 'cover_path.dart';
import 'data_storage.dart';
import 'file_fingerprint_store.dart';
import 'managed_file_importer.dart';

/// 选封面图并落到应用沙盒的工具类。
///
/// 相册返回的路径是临时或 `content://`，不能直接写入 `Role.coverImg`。
/// 本类会把文件复制到 `support/covers/`，只把相对路径 `covers/<file>` 交给 `create`。
///
/// 相册走系统选择器，一般不必再申请存储权限。
/// 拍照走 [pickFromCamera]；iOS/macOS 已配置用途说明，Android 已声明 CAMERA。
class CoverImagePicker {
  CoverImagePicker({
    ImagePicker? picker,
    Future<Directory> Function()? supportDirectory,
  }) : _picker = picker ?? ImagePicker(),
       _supportDirectory =
           supportDirectory ??
           (() async =>
               DataStorage.current?.activeDirectory ??
               await getActiveDataDirectory()),
       _storage = supportDirectory == null ? DataStorage.current : null,
       _epoch = supportDirectory == null ? DataStorage.current?.epoch : null;

  final DataStorage? _storage;
  final int? _epoch;
  final ImagePicker _picker;
  final Future<Directory> Function() _supportDirectory;

  static const String directoryName = CoverPath.directoryName;

  /// 从相册选图，复制到本地后返回相对路径；用户取消时返回 `null`。
  Future<String?> pickFromGallery() {
    return pick(source: ImageSource.gallery);
  }

  /// 拍照并落到沙盒。平台用途说明与相机权限已在工程里配置。
  Future<String?> pickFromCamera() {
    return pick(source: ImageSource.camera);
  }

  /// 选图并保存。取消选择返回 `null`。
  Future<String?> pick({ImageSource source = ImageSource.gallery}) async {
    final picked = await _picker.pickImage(source: source);
    if (picked == null) {
      return null;
    }
    return savePickedFile(picked);
  }

  /// 把已选出的 [XFile] 写入沙盒 `covers/`，返回相对路径 `covers/<file>`。
  Future<String> savePickedFile(XFile picked) => _storage == null
      ? _save(picked)
      : _storage.mutate(() => _save(picked), expectedEpoch: _epoch);

  Future<String> _save(XFile picked) async {
    final root = await _supportDirectory();
    final dir = Directory(p.join(root.path, directoryName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final rawExt = p.extension(picked.name).isEmpty
        ? (p.extension(picked.path).isEmpty ? '.jpg' : p.extension(picked.path))
        : p.extension(picked.name);
    final ext = RegExp(r'^\.[a-zA-Z0-9]{1,12}$').hasMatch(rawExt)
        ? rawExt
        : '.jpg';
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final dest = File(p.join(dir.path, '$id$ext'));
    final fingerprints = FileFingerprintStore(
      _storage?.controlDirectory ??
          Directory(p.join(root.path, 'storage-control')),
    );
    try {
      await ManagedFileImporter.copy(picked, dest, fingerprints: fingerprints);
    } finally {
      await fingerprints.close();
    }
    return CoverPath.relative(dest.path);
  }
}
