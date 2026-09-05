import 'package:ochome/data/services/cover_image_picker.dart';

/// 测试用假选图器：跳过系统相册，直接返回预设路径或 null（模拟取消）。
class FakeCoverImagePicker extends CoverImagePicker {
  FakeCoverImagePicker([this.result]) : super();

  final String? result;

  /// 记录被调用的次数，用于断言「点背景不选图 / 只有点更换才选图」。
  int pickCalls = 0;

  @override
  Future<String?> pickFromGallery() async {
    pickCalls++;
    return result;
  }
}
