import 'role_custom_attribute.dart';

/// 业务层 OC 人设。
///
/// 与 Drift 生成的 `Role` 行类型同名，因此仓库实现里通过
/// `import '.../app_database.dart' as db` 区分两者，避免接口泄漏数据库类型。
class Role {
  const Role({
    required this.id,
    required this.name,
    required this.sex,
    required this.age,
    required this.birthday,
    required this.race,
    required this.occupation,
    required this.desc,
    required this.coverImg,
    this.customAttributes = const [],
    this.worldId,
  });

  /// 数据库主键，插入后由 Drift 回填。
  final int id;

  /// 名字 / 称呼。
  final String name;

  /// 性别，自由填写。
  final String sex;

  /// 年龄，自由填写。
  final String age;

  /// 生日，自由填写，不做日期解析。
  final String birthday;

  /// 种族。
  final String race;

  /// 身份 / 职业 / 所属。
  final String occupation;

  /// 设定（性格、外貌、背景等）。
  final String desc;

  /// 立绘路径。
  final String coverImg;

  /// 当前角色自定义的属性，按展示顺序排列；仓库和表单提供不可变快照。
  final List<RoleCustomAttribute> customAttributes;

  /// 所属世界观 id；`null` 表示未归属。重建 [Role] 时必须显式保留。
  final int? worldId;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Role &&
            other.id == id &&
            other.name == name &&
            other.sex == sex &&
            other.age == age &&
            other.birthday == birthday &&
            other.race == race &&
            other.occupation == occupation &&
            other.desc == desc &&
            other.coverImg == coverImg &&
            other.worldId == worldId &&
            _sameAttributes(other.customAttributes);
  }

  bool _sameAttributes(List<RoleCustomAttribute> other) {
    if (other.length != customAttributes.length) {
      return false;
    }
    for (var index = 0; index < customAttributes.length; index++) {
      if (other[index] != customAttributes[index]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    sex,
    age,
    birthday,
    race,
    occupation,
    desc,
    coverImg,
    worldId,
    Object.hashAll(customAttributes),
  );
}
