import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'tables/role.dart';
import 'tables/role_desc_revision.dart';

part 'app_database.g.dart';

/// 应用本地数据库入口，只负责打开连接和挂表，不写业务 CRUD。
///
/// 可选 [executor] 供测试注入内存库；正式运行走 [_openConnection]。
@DriftDatabase(tables: [Roles, RoleDescRevisions])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  /// 表结构版本。增删列后必须递增并补 migration。
  @override
  int get schemaVersion => 5;

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
      if (from < 5) {
        await migrator.createTable(roleDescRevisions);
        // 已有角色的当前设定记成第一版，避免历史页是空的。
        await customStatement(
          'INSERT INTO role_desc_revision (role_id, content, created_at) '
          "SELECT id, desc, CAST(strftime('%s', 'now') AS INTEGER) "
          "FROM role WHERE desc != ''",
        );
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
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
