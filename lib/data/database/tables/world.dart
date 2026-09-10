import 'package:drift/drift.dart';

/// 世界观表。类名用复数 [Worlds]，避免和生成行类型 `World` 冲突。
class Worlds extends Table {
  @override
  String get tableName => 'world';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();

  /// 简介，允许空字符串。
  TextColumn get summary => text()();

  /// 封面相对路径 `covers/<file>`，空字符串表示没有封面；列名与 role 表一致。
  TextColumn get coverImg => text().named('coverimg')();

  /// 有序词条 JSON `[{"title","content"}]`，由仓库负责编解码。
  TextColumn get entries => text().withDefault(const Constant('[]'))();
}
