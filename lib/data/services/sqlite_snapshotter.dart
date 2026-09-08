import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../database/app_database.dart';
import 'restore_version_gate.dart';

/// Consistent SQLite Online Backup snapshots, including committed WAL pages.
/// Legacy checkpoint/copy APIs remain available for older backup callers.
class SqliteSnapshotter {
  const SqliteSnapshotter();

  /// Uses SQLite's Online Backup API, not checkpoint + file copy. Caller holds
  /// the storage mutation gate until media references are read and pinned.
  Future<File> createSnapshot({
    required File liveSqlite,
    required Directory destDir,
  }) async {
    if (!await liveSqlite.exists()) {
      throw FileSystemException('数据库不存在', liveSqlite.path);
    }
    await destDir.create(recursive: true);
    final target = File(p.join(destDir.path, AppDatabase.sqliteFileName));
    if (p.equals(liveSqlite.absolute.path, target.absolute.path)) {
      throw ArgumentError('快照不能覆盖正在使用的数据库');
    }
    if (await target.exists()) {
      throw FileSystemException('快照目标已存在', target.path);
    }
    final sourcePath = liveSqlite.path;
    final targetPath = target.path;
    await _createOnlineSnapshot(sourcePath, targetPath);
    return target;
  }

  Future<void> checkpoint(AppDatabase database) {
    return database.customStatement('PRAGMA wal_checkpoint(FULL)');
  }

  /// 把已经 checkpoint 的活库拷到 [destDir]/ochome.sqlite。
  Future<File> copySnapshot({
    required File liveSqlite,
    required Directory destDir,
  }) async {
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }
    final dest = File(p.join(destDir.path, AppDatabase.sqliteFileName));
    await liveSqlite.copy(dest.path);
    return dest;
  }

  int readUserVersion(File sqliteFile) {
    final db = sqlite3.open(sqliteFile.path, mode: OpenMode.readOnly);
    try {
      return db.userVersion;
    } finally {
      db.close();
    }
  }

  /// 以快照中的引用为准，避免云端目录枚举遗漏时静默丢失资产文件。
  Map<String, int> readAssetFiles(File sqliteFile) {
    final database = sqlite3.open(sqliteFile.path, mode: OpenMode.readOnly);
    try {
      if (database.userVersion < 8) return {};
      return {
        for (final row in database.select(
          'SELECT relative_path, bytes FROM role_asset',
        ))
          row['relative_path'] as String: row['bytes'] as int,
      };
    } finally {
      database.close();
    }
  }

  void writeUserVersion(File sqliteFile, int version) {
    final db = sqlite3.open(sqliteFile.path);
    try {
      db.userVersion = version;
    } finally {
      db.close();
    }
  }

  RestoreVersionDecision compareVersion({
    required int sqliteUserVersion,
    required int appSchemaVersion,
    int? manifestSchemaVersion,
  }) {
    return RestoreVersionGate.compare(
      appSchemaVersion: appSchemaVersion,
      sqliteUserVersion: sqliteUserVersion,
      manifestSchemaVersion: manifestSchemaVersion,
    );
  }

  /// 用快照替换活库。调用前必须已经关闭 Drift 连接。
  ///
  /// 先把旧 `-wal`/`-shm` 和活库挪走，再让快照占用活库路径，避免新库接到旧 WAL。
  /// 快照就位后的清理失败不当成替换失败。
  Future<void> replaceLive({
    required File snapshot,
    required File liveSqlite,
  }) async {
    final next = File('${liveSqlite.path}.next');
    final bak = File('${liveSqlite.path}.bak');
    final wal = File('${liveSqlite.path}-wal');
    final shm = File('${liveSqlite.path}-shm');
    final walBak = File('${liveSqlite.path}-wal.bak');
    final shmBak = File('${liveSqlite.path}-shm.bak');
    await snapshot.copy(next.path);
    await _deleteIfExists(bak);
    await _deleteIfExists(walBak);
    await _deleteIfExists(shmBak);
    if (await wal.exists()) {
      await wal.rename(walBak.path);
    }
    if (await shm.exists()) {
      await shm.rename(shmBak.path);
    }
    final hadLive = await liveSqlite.exists();
    if (hadLive) {
      await liveSqlite.rename(bak.path);
    }
    try {
      await next.rename(liveSqlite.path);
    } catch (_) {
      if (hadLive && await bak.exists() && !await liveSqlite.exists()) {
        await bak.rename(liveSqlite.path);
      }
      if (await walBak.exists() && !await wal.exists()) {
        await walBak.rename(wal.path);
      }
      if (await shmBak.exists() && !await shm.exists()) {
        await shmBak.rename(shm.path);
      }
      await _deleteIfExists(next);
      rethrow;
    }
    await _deleteIfExists(bak);
    await _deleteIfExists(walBak);
    await _deleteIfExists(shmBak);
  }

  Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}

Future<void> _createOnlineSnapshot(String sourcePath, String targetPath) =>
    Isolate.run(() async {
      final pendingPath = '$targetPath.pending';
      if (await File(pendingPath).exists()) {
        throw FileSystemException('快照准备文件已存在', pendingPath);
      }
      Database? source;
      Database? target;
      try {
        source = sqlite3.open(sourcePath, mode: OpenMode.readOnly);
        target = sqlite3.open(pendingPath);
        source.execute('PRAGMA busy_timeout = 5000');
        target.execute('PRAGMA synchronous = FULL');
        await source.backup(target, nPage: 128).drain<void>();
        target.execute('PRAGMA journal_mode = DELETE');
        if (target
            .select('PRAGMA quick_check')
            .any((row) => row.columnAt(0) != 'ok')) {
          throw const FormatException('数据库快照校验失败');
        }
        target.close();
        target = null;
        source.close();
        source = null;
        final file = await File(pendingPath).open(mode: FileMode.append);
        await file.flush();
        await file.close();
        await File(pendingPath).rename(targetPath);
      } finally {
        target?.close();
        source?.close();
        for (final suffix in ['', '-wal', '-shm', '-journal']) {
          final file = File('$pendingPath$suffix');
          if (await file.exists()) await file.delete();
        }
      }
    });
