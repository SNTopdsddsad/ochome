import 'package:drift/drift.dart';

import '../database/app_database.dart' as db;
import '../models/role.dart';
import 'role_repository.dart';

/// [RoleRepository] 的 Drift 实现。
///
/// [db] 前缀用来避开生成行类型 `db.Role` 与领域模型 [Role] 的命名冲突。
class DriftRoleRepository implements RoleRepository {
  DriftRoleRepository(this._db);

  final db.AppDatabase _db;

  @override
  Future<List<Role>> list() async {
    final rows = await _db.select(_db.roles).get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<Role?> getById(int id) async {
    final row = await (_db.select(
      _db.roles,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<Role> create({
    required String name,
    required String sex,
    required String age,
    required String birthday,
    required String race,
    required String occupation,
    required String desc,
    required String coverImg,
  }) async {
    // insertReturning 可拿到自增 id 及写入后的完整行。
    final row = await _db
        .into(_db.roles)
        .insertReturning(
          db.RolesCompanion.insert(
            name: name,
            sex: sex,
            age: age,
            birthday: birthday,
            race: race,
            occupation: occupation,
            desc: desc,
            coverImg: coverImg,
          ),
        );
    return _toDomain(row);
  }

  @override
  Future<Role> update(Role role) async {
    final updated =
        await (_db.update(
          _db.roles,
        )..where((t) => t.id.equals(role.id))).writeReturning(
          db.RolesCompanion(
            name: Value(role.name),
            sex: Value(role.sex),
            age: Value(role.age),
            birthday: Value(role.birthday),
            race: Value(role.race),
            occupation: Value(role.occupation),
            desc: Value(role.desc),
            coverImg: Value(role.coverImg),
          ),
        );
    if (updated.isEmpty) {
      throw StateError('Role ${role.id} not found');
    }
    return _toDomain(updated.first);
  }

  @override
  Future<void> delete(int id) {
    return (_db.delete(_db.roles)..where((t) => t.id.equals(id))).go();
  }

  @override
  Stream<List<Role>> watchAll() {
    return _db
        .select(_db.roles)
        .watch()
        .map((rows) => rows.map(_toDomain).toList());
  }

  /// 把 Drift 行映射成领域 [Role]，避免上层依赖生成代码。
  Role _toDomain(db.Role row) {
    return Role(
      id: row.id,
      name: row.name,
      sex: row.sex,
      age: row.age,
      birthday: row.birthday,
      race: row.race,
      occupation: row.occupation,
      desc: row.desc,
      coverImg: row.coverImg,
    );
  }
}
