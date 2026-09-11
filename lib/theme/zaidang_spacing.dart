/// 崽档间距刻度。4 的倍数，页面里不再手写 6 / 10 / 14 这类中间值。
///
/// 只覆盖「间隔」和「内边距」；触控尺寸、缩略图尺寸、maxWidth 等布局常量
/// 留在各自组件里。
abstract final class ZaidangSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// 页面横向内边距。
  static const double page = xl;

  /// 卡片 / 纸片内边距。
  static const double card = lg;
}
