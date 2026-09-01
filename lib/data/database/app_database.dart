import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'tables/role.dart';

part 'app_database.g.dart';

/// 应用本地数据库入口，只负责打开连接和挂表，不写业务 CRUD。
///
/// 可选 [executor] 供测试注入内存库；正式运行走 [_openConnection]。
@DriftDatabase(tables: [Roles])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  /// 表结构版本。增删列后必须递增并补 migration。
  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      // v3 起 birthday 改为文本；更早的库直接按新表重建。
      if (from < 3) {
        await migrator.deleteTable('role');
        await migrator.createTable(roles);
      } else if (from < 4) {
        await migrator.addColumn(roles, roles.age);
        await migrator.addColumn(roles, roles.race);
      }
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'ochome',
      native: const DriftNativeOptions(
        // 默认是文档目录；改到 support 目录，避免出现在用户可见文件里。
        databaseDirectory: getApplicationSupportDirectory,
      ),
    );
  }
}
