/// 业务层角色模型。
///
/// 与 Drift 生成的 `Role` 行类型同名，因此仓库实现里通过
/// `import '.../app_database.dart' as db` 区分两者，避免接口泄漏数据库类型。
class Role {
  const Role({
    required this.id,
    required this.name,
    required this.sex,
    required this.birthday,
    required this.occupation,
    required this.desc,
  });

  /// 数据库主键，插入后由 Drift 回填。
  final int id;

  /// 角色姓名。
  final String name;

  /// 性别，当前以文本存储。
  final String sex;

  /// 出生日期。
  final DateTime birthday;

  /// 职业。
  final String occupation;

  /// 角色描述。
  final String desc;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Role &&
            other.id == id &&
            other.name == name &&
            other.sex == sex &&
            other.birthday == birthday &&
            other.occupation == occupation &&
            other.desc == desc;
  }

  @override
  int get hashCode => Object.hash(id, name, sex, birthday, occupation, desc);
}
