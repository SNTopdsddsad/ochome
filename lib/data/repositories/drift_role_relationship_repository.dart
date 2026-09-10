import 'package:drift/drift.dart';

import '../database/app_database.dart' as db;
import '../models/role_relationship.dart';
import 'role_relationship_repository.dart';

class DriftRoleRelationshipRepository implements RoleRelationshipRepository {
  DriftRoleRelationshipRepository(this._db);

  final db.AppDatabase _db;

  SimpleSelectStatement<db.$RoleRelationshipsTable, db.RoleRelationship> _query(
    int roleId,
  ) =>
      _db.select(_db.roleRelationships)
        ..where((t) => t.fromRoleId.equals(roleId) | t.toRoleId.equals(roleId))
        ..orderBy([
          (t) => OrderingTerm.desc(t.createdAt),
          (t) => OrderingTerm.desc(t.id),
        ]);

  @override
  Stream<List<RoleRelationship>> watchForRole(int roleId) =>
      _query(roleId).watch().map(_map);

  @override
  Future<List<RoleRelationship>> listForRole(int roleId) async =>
      _map(await _query(roleId).get());

  List<RoleRelationship> _map(List<db.RoleRelationship> rows) =>
      List.unmodifiable(rows.map(_toDomain));

  RoleRelationship _toDomain(db.RoleRelationship row) => RoleRelationship(
    id: row.id,
    fromRoleId: row.fromRoleId,
    toRoleId: row.toRoleId,
    fromLabel: row.fromLabel,
    toLabel: row.toLabel,
    createdAt: row.createdAt,
  );

  /// 两端必须是不同的、都存在的角色。`from` 约定为发起编辑的当前角色。
  Future<void> _ensureEndpoints(int fromRoleId, int toRoleId) async {
    if (fromRoleId == toRoleId) {
      throw const FormatException('不能和自己建立关系');
    }
    final existing = (await (_db.selectOnly(_db.roles)
              ..addColumns([_db.roles.id])
              ..where(_db.roles.id.isIn([fromRoleId, toRoleId])))
            .get())
        .map((row) => row.read(_db.roles.id))
        .toSet();
    if (!existing.contains(fromRoleId)) {
      throw StateError('当前角色已不存在，请先保存角色');
    }
    if (!existing.contains(toRoleId)) {
      throw StateError('对方 OC 已不存在，请重新选择');
    }
  }

  @override
  Future<RoleRelationship> create({
    required int fromRoleId,
    required int toRoleId,
    required String fromLabel,
    required String toLabel,
  }) async {
    // 校验放在 async 体内，让文案错误也以 Future 错误的形式返回给调用方。
    final normalizedFrom = normalizeRelationshipLabel(fromLabel);
    final normalizedTo = normalizeRelationshipLabel(toLabel);
    return _db.mutate(
      () => _db.transaction(() async {
        await _ensureEndpoints(fromRoleId, toRoleId);
        final row = await _db
            .into(_db.roleRelationships)
            .insertReturning(
              db.RoleRelationshipsCompanion.insert(
                fromRoleId: fromRoleId,
                toRoleId: toRoleId,
                fromLabel: normalizedFrom,
                toLabel: normalizedTo,
                createdAt: DateTime.now(),
              ),
            );
        return _toDomain(row);
      }),
    );
  }

  @override
  Future<RoleRelationship> update(RoleRelationship relationship) async {
    final normalizedFrom = normalizeRelationshipLabel(relationship.fromLabel);
    final normalizedTo = normalizeRelationshipLabel(relationship.toLabel);
    return _db.mutate(
      () => _db.transaction(() async {
        await _ensureEndpoints(
          relationship.fromRoleId,
          relationship.toRoleId,
        );
        final rows =
            await (_db.update(_db.roleRelationships)
                  ..where((t) => t.id.equals(relationship.id)))
                .writeReturning(
                  db.RoleRelationshipsCompanion(
                    fromRoleId: Value(relationship.fromRoleId),
                    toRoleId: Value(relationship.toRoleId),
                    fromLabel: Value(normalizedFrom),
                    toLabel: Value(normalizedTo),
                  ),
                );
        if (rows.isEmpty) throw StateError('关系不存在');
        return _toDomain(rows.single);
      }),
    );
  }

  @override
  Future<bool> delete({required int roleId, required int relationshipId}) =>
      _db.mutate(() async {
        final deleted =
            await (_db.delete(_db.roleRelationships)..where(
                  (t) =>
                      t.id.equals(relationshipId) &
                      (t.fromRoleId.equals(roleId) | t.toRoleId.equals(roleId)),
                ))
                .go();
        return deleted > 0;
      });
}
