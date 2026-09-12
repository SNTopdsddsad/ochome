import 'package:file_selector/file_selector.dart' as selector;
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

/// 系统选择器的薄封装，页面测试可以注入取消、成功或异常结果。
class RoleAssetPicker {
  Future<List<XFile>> pickMedia() {
    final platform = ImagePickerPlatform.instance;
    if (platform is ImagePickerAndroid) {
      platform.useAndroidPhotoPicker = true;
    }
    return ImagePicker().pickMultipleMedia(requestFullMetadata: false);
  }

  Future<List<XFile>> pickFiles() =>
      selector.openFiles(confirmButtonText: '添加资产');
}
