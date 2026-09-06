import 'package:file_selector/file_selector.dart' as selector;
import 'package:image_picker/image_picker.dart';

/// 系统选择器的薄封装，页面测试可以注入取消、成功或异常结果。
class RoleAssetPicker {
  Future<List<XFile>> pickMedia() =>
      ImagePicker().pickMultipleMedia(requestFullMetadata: false);

  Future<List<XFile>> pickFiles() =>
      selector.openFiles(confirmButtonText: '添加资产');
}
