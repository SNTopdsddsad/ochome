import 'world_entry.dart';

/// 业务层世界观（设定集）。
///
/// 与 Drift 生成的 `World` 行类型同名，仓库实现里通过
/// `import '.../app_database.dart' as db` 区分两者。
class World {
  const World({
    required this.id,
    required this.name,
    required this.summary,
    required this.coverImg,
    this.entries = const [],
  });

  /// 数据库主键，插入后由 Drift 回填。
  final int id;

  /// 名称，必填。
  final String name;

  /// 简介，可为空。
  final String summary;

  /// 封面相对路径 `covers/<file>`，空字符串表示没有封面。
  final String coverImg;

  /// 有序词条，仓库和表单提供不可变快照。
  final List<WorldEntry> entries;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is World &&
            other.id == id &&
            other.name == name &&
            other.summary == summary &&
            other.coverImg == coverImg &&
            _sameEntries(other.entries);
  }

  bool _sameEntries(List<WorldEntry> other) {
    if (other.length != entries.length) {
      return false;
    }
    for (var index = 0; index < entries.length; index++) {
      if (other[index] != entries[index]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(id, name, summary, coverImg, Object.hashAll(entries));
}
