import 'package:drift/drift.dart';

import 'role.dart';

/// 两个 OC 之间的一条有向关系，单行同时记录两个视角的文案。
///
/// 同一对角色允许多行；两端角色不能相同，由仓储层校验。
@TableIndex(name: 'role_relationship_from_role_id', columns: {#fromRoleId})
@TableIndex(name: 'role_relationship_to_role_id', columns: {#toRoleId})
class RoleRelationships extends Table {
  @override
  String get tableName => 'role_relationship';

  IntColumn get id => integer().autoIncrement()();
  @ReferenceName('outgoingRelationships')
  IntColumn get fromRoleId =>
      integer().references(Roles, #id, onDelete: KeyAction.cascade)();
  @ReferenceName('incomingRelationships')
  IntColumn get toRoleId =>
      integer().references(Roles, #id, onDelete: KeyAction.cascade)();

  /// from 是 to 的 ___。
  TextColumn get fromLabel => text()();

  /// to 是 from 的 ___。
  TextColumn get toLabel => text()();
  DateTimeColumn get createdAt => dateTime()();
}
