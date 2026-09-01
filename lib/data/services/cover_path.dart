import 'package:path/path.dart' as p;

/// `Role.coverImg` 的路径合同：库里存相对路径 `covers/<file>`，展示时再拼沙盒。
///
/// 旧数据可能仍是绝对路径；解析层两种都认，避免升级或换机后封面全丢。
class CoverPath {
  CoverPath._();

  static const directoryName = 'covers';

  /// 沙盒内相对路径，始终用 `/`，方便跨设备恢复。
  static String relative(String fileName) =>
      '$directoryName/${p.basename(fileName)}';

  /// 把库里的 [coverImg] 变成可 `File` 打开的绝对路径。
  ///
  /// 空字符串表示无封面。已经是绝对路径的原样返回。
  static String resolve(String supportDir, String coverImg) {
    if (coverImg.isEmpty) {
      return '';
    }
    if (p.isAbsolute(coverImg)) {
      return coverImg;
    }
    return p.join(supportDir, coverImg);
  }

  /// 仅当绝对路径的父目录就是 `covers/` 时改写成相对路径，否则原样返回。
  static String toRelativeIfUnderCovers(String coverImg) {
    if (coverImg.isEmpty || !p.isAbsolute(coverImg)) {
      return coverImg;
    }
    if (p.basename(p.dirname(coverImg)) != directoryName) {
      return coverImg;
    }
    return relative(coverImg);
  }
}
