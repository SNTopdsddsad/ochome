import 'package:drift/drift.dart';

import 'world.dart';

/// Drift 表定义。类名用复数 [Roles]，避免和生成行类型 `Role` 冲突。
///
/// SQLite 表名固定为 `role`，与领域模型字段一一对应。
class Roles extends Table {
  @override
  String get tableName => 'role';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get sex => text()();

  /// 年龄按原文存储，如「十七」「外表 20」。
  TextColumn get age => text()();

  /// 生日按用户输入的原文存储，不做日期解析。
  TextColumn get birthday => text()();

  /// 种族，如人类、兽人、吸血鬼。
  TextColumn get race => text()();
  TextColumn get occupation => text()();
  TextColumn get desc => text()();

  /// 封面图路径或 URL，列名与需求一致为 coverimg。
  TextColumn get coverImg => text().named('coverimg')();

  /// 按展示顺序存储名称和内容，由仓库负责 JSON 编解码。
  TextColumn get customAttributes => text().withDefault(const Constant('[]'))();

  /// 所属世界观；删除世界观时由数据库置空，角色本身保留。
  IntColumn get worldId => integer().nullable().references(
    Worlds,
    #id,
    onDelete: KeyAction.setNull,
  )();
}
