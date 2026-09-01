import 'package:drift/drift.dart';

import 'role.dart';

/// 角色设定的修订记录。一行一版全文，[Roles.desc] 仍是当前正文。
class RoleDescRevisions extends Table {
  @override
  String get tableName => 'role_desc_revision';

  IntColumn get id => integer().autoIncrement()();

  IntColumn get roleId =>
      integer().references(Roles, #id, onDelete: KeyAction.cascade)();

  TextColumn get content => text()();

  DateTimeColumn get createdAt => dateTime()();
}
