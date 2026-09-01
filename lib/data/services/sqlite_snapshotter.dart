import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../database/app_database.dart';
import 'restore_version_gate.dart';

/// 对活库做 WAL checkpoint 后拷贝 sqlite 快照。不上传 `-wal` / `-shm`。
class SqliteSnapshotter {
  const SqliteSnapshotter();

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
