import 'package:drift/drift.dart';

import '../database/app_database.dart' as db;
import '../models/role.dart';
import '../models/role_desc_revision.dart';
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
    return _db.transaction(() async {
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
      await _appendDescRevision(
        roleId: row.id,
        previous: null,
        next: desc,
      );
      return _toDomain(row);
    });
  }

  @override
  Future<Role> update(Role role) async {
    return _db.transaction(() async {
      final existing = await getById(role.id);
      if (existing == null) {
        throw StateError('Role ${role.id} not found');
      }
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
      await _appendDescRevision(
        roleId: role.id,
        previous: existing.desc,
        next: role.desc,
      );
      return _toDomain(updated.first);
    });
  }

  @override
  Future<void> delete(int id) {
    return _db.transaction(() async {
      await (_db.delete(
        _db.roleDescRevisions,
      )..where((t) => t.roleId.equals(id))).go();
      await (_db.delete(_db.roles)..where((t) => t.id.equals(id))).go();
    });
  }

  @override
  Stream<List<Role>> watchAll() {
    return _db
        .select(_db.roles)
        .watch()
        .map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Stream<List<RoleDescRevision>> watchDescRevisions(int roleId) {
    return _descRevisionQuery(
      roleId,
    ).watch().map((rows) => rows.map(_toDescRevision).toList());
  }

  @override
  Future<List<RoleDescRevision>> listDescRevisions(int roleId) async {
    final rows = await _descRevisionQuery(roleId).get();
    return rows.map(_toDescRevision).toList();
  }

  @override
  Future<Role> restoreDescRevision({
    required int roleId,
    required int revisionId,
  }) async {
    return _db.transaction(() async {
      final role = await getById(roleId);
      if (role == null) {
        throw StateError('Role $roleId not found');
      }
      final row =
          await (_db.select(_db.roleDescRevisions)
                ..where((t) => t.id.equals(revisionId)))
              .getSingleOrNull();
      if (row == null || row.roleId != roleId) {
        throw StateError('Desc revision $revisionId not found');
      }
      if (row.content == role.desc) {
        return role;
      }
      return update(
        Role(
          id: role.id,
          name: role.name,
          sex: role.sex,
          age: role.age,
          birthday: role.birthday,
          race: role.race,
          occupation: role.occupation,
          desc: row.content,
          coverImg: role.coverImg,
        ),
      );
    });
  }

  Selectable<db.RoleDescRevision> _descRevisionQuery(int roleId) {
    return _db.select(_db.roleDescRevisions)
      ..where((t) => t.roleId.equals(roleId))
      ..orderBy([
        (t) => OrderingTerm.desc(t.createdAt),
        (t) => OrderingTerm.desc(t.id),
      ]);
  }

  Future<void> _appendDescRevision({
    required int roleId,
    required String? previous,
    required String next,
  }) async {
    if (previous == next) {
      return;
    }
    if (previous == null && next.isEmpty) {
      return;
    }
    await _db
        .into(_db.roleDescRevisions)
        .insert(
          db.RoleDescRevisionsCompanion.insert(
            roleId: roleId,
            content: next,
            createdAt: DateTime.now(),
          ),
        );
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

  RoleDescRevision _toDescRevision(db.RoleDescRevision row) {
    return RoleDescRevision(
      id: row.id,
      roleId: row.roleId,
      content: row.content,
      createdAt: row.createdAt,
    );
  }
}
