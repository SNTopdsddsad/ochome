import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../services/cover_path.dart';
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
  static const int currentSchemaVersion = 6;

  static const String sqliteFileName = 'ochome.sqlite';

  @override
  int get schemaVersion => currentSchemaVersion;

  /// Application Support 里的活库路径。备份只拷快照，不要把这个文件映射到 iCloud。
  static Future<File> sqliteFile({
    Future<Directory> Function()? supportDirectory,
  }) async {
    final dir = await (supportDirectory ?? getApplicationSupportDirectory)();
    return File(p.join(dir.path, sqliteFileName));
  }

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
      if (from < 6) {
        await _rewriteCoverImgToRelative();
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// 把仍落在 `covers/` 目录下的绝对路径改成 `covers/<basename>`。
  /// 无法改写的绝对路径保留，展示层两种都认。
  Future<void> _rewriteCoverImgToRelative() async {
    final rows = await customSelect('SELECT id, coverimg FROM role').get();
    for (final row in rows) {
      final cover = row.read<String>('coverimg');
      final rewritten = CoverPath.toRelativeIfUnderCovers(cover);
      if (rewritten == cover) {
        continue;
      }
      await customStatement('UPDATE role SET coverimg = ? WHERE id = ?', [
        rewritten,
        row.read<int>('id'),
      ]);
    }
  }

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
