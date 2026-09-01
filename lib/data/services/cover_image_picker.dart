import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'cover_path.dart';

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
       _supportDirectory = supportDirectory ?? getApplicationSupportDirectory;

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
  Future<String> savePickedFile(XFile picked) async {
    final root = await _supportDirectory();
    final dir = Directory(p.join(root.path, directoryName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final ext = p.extension(picked.name).isEmpty
        ? (p.extension(picked.path).isEmpty ? '.jpg' : p.extension(picked.path))
        : p.extension(picked.name);
    final dest = File(
      p.join(dir.path, '${DateTime.now().microsecondsSinceEpoch}$ext'),
    );
    // 用字节写入，避免 Android content:// 无法 File.copy。
    await dest.writeAsBytes(await picked.readAsBytes(), flush: true);
    return CoverPath.relative(dest.path);
  }
}
