import 'package:drift/drift.dart';

import 'role.dart';

@TableIndex(name: 'role_asset_role_id', columns: {#roleId})
class RoleAssets extends Table {
  @override
  String get tableName => 'role_asset';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get roleId =>
      integer().references(Roles, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get kind => text()();
  TextColumn get relativePath => text().unique()();
  IntColumn get bytes => integer()();
  DateTimeColumn get createdAt => dateTime()();
}
