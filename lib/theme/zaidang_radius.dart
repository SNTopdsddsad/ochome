import 'package:flutter/painting.dart';

/// 崽档圆角刻度。三档加一个胶囊形，覆盖 App 内所有圆角。
abstract final class ZaidangRadius {
  /// 卡片、输入框、缩略图、小按钮。
  static const double sm = 8;

  /// SnackBar、便笺按钮、候选卡、纸卡。
  static const double md = 16;

  /// 弹窗、Sheet 顶部、hero 纸边。
  static const double lg = 26;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius lgTop = BorderRadius.vertical(
    top: Radius.circular(lg),
  );

  /// 胶囊形，高度决定圆角，用于玻璃保存按钮之类的 pill。
  static const ShapeBorder pill = StadiumBorder();
}
