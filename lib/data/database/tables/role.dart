import 'package:drift/drift.dart';

/// Drift 表定义。类名用复数 [Roles]，避免和生成行类型 `Role` 冲突。
///
/// SQLite 表名固定为 `role`，与领域模型字段一一对应。
class Roles extends Table {
  @override
  String get tableName => 'role';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get sex => text()();
  DateTimeColumn get birthday => dateTime()();
  TextColumn get occupation => text()();
  TextColumn get desc => text()();
}
