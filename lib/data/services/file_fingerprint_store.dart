import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

class FileFingerprint {
  const FileFingerprint({required this.sha256, required this.bytes});
  final String sha256;
  final int bytes;
}

/// Shared bounded file-work queue: at most one import/hash worker reads media.
/// The queue does not hold business write leases and does not swallow failures.
class ManagedFileWork {
  static Future<void> _tail = Future.value();
  static Future<T> run<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}

/// Rebuildable local-only SQLite index. Absolute dataset path plus size, mtime
/// and ctime isolate immutable file identities. A hit is NOT a fresh integrity
/// check: upload and restoration must validate the bytes they actually copy.
class FileFingerprintStore {
  FileFingerprintStore(this.controlRoot);
  final Directory controlRoot;
  Database? _database;
  bool _closed = false;
  Future<void> _tail = Future.value();

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) {
      if (_closed) throw StateError('文件摘要索引已关闭');
      return action();
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<Database> _open() async {
    if (_database != null) return _database!;
    await controlRoot.create(recursive: true);
    final path = p.join(controlRoot.path, 'file-fingerprints.sqlite');
    Database? database;
    try {
      database = sqlite3.open(path);
      database.execute('PRAGMA busy_timeout = 5000');
      database.execute(
        'CREATE TABLE IF NOT EXISTS file_fingerprints ('
        'path TEXT PRIMARY KEY, digest TEXT NOT NULL, bytes INTEGER NOT NULL, '
        'mtime INTEGER NOT NULL, ctime INTEGER NOT NULL)',
      );
      database.select(
        'SELECT path, digest, bytes, mtime, ctime FROM file_fingerprints LIMIT 0',
      );
      _database = database;
      return database;
    } catch (_) {
      database?.close();
      // The index alone may be rebuilt. Never rename/delete the role database.
      final suffix = '.corrupt-${DateTime.now().microsecondsSinceEpoch}';
      for (final companion in ['', '-journal', '-wal', '-shm']) {
        final broken = File('$path$companion');
        if (await broken.exists()) await broken.rename('${broken.path}$suffix');
      }
      rethrow;
    }
  }

  Future<FileFingerprint> fingerprint(File file, {bool force = false}) =>
      _serial(() async {
        final path = await file.resolveSymbolicLinks();
        final before = await _stat(file);
        Database? database;
        try {
          database = await _open();
        } catch (_) {
          /* Derived cache unavailable: still hash actual bytes. */
        }
        if (!force && database != null) {
          final cached = _cachedValue(database, path, before);
          if (cached != null) return cached;
        }
        final result = await ManagedFileWork.run(
          () => _hashFile(path, before.size),
        );
        final after = await _stat(file);
        if (!_same(before, after)) {
          throw FileSystemException('计算摘要时文件发生变化', file.path);
        }
        await _remember(file, result, after);
        return result;
      });

  /// Reads only an existing recorded expectation, without hashing the source or
  /// creating/updating a cache. [requireCurrentStat] false is exclusively for
  /// verifying preserved immutable originals against their historical digest:
  /// changed stat signals must not erase evidence of a content mismatch.
  Future<FileFingerprint?> cachedFingerprint(
    File file, {
    bool requireCurrentStat = true,
  }) => _serial(() async {
    Database? opened;
    try {
      final path = await file.resolveSymbolicLinks();
      final stat = await _stat(file);
      var database = _database;
      if (database == null) {
        final cache = File(
          p.join(controlRoot.path, 'file-fingerprints.sqlite'),
        );
        if (!await cache.exists()) return null;
        opened = sqlite3.open(cache.path, mode: OpenMode.readOnly);
        database = opened;
      }
      return _cachedValue(database, path, requireCurrentStat ? stat : null);
    } catch (_) {
      return null;
    } finally {
      opened?.close();
    }
  });

  static FileFingerprint? _cachedValue(
    Database database,
    String path,
    FileStat? stat,
  ) {
    final rows = database.select(
      'SELECT digest, bytes, mtime, ctime FROM file_fingerprints WHERE path = ?',
      [path],
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    if (row['digest'] is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(row['digest'] as String) ||
        row['bytes'] is! int ||
        (row['bytes'] as int) < 0) {
      return null;
    }
    if (stat != null &&
        (row['bytes'] != stat.size ||
            row['mtime'] != stat.modified.microsecondsSinceEpoch ||
            row['ctime'] != stat.changed.microsecondsSinceEpoch)) {
      return null;
    }
    return FileFingerprint(
      sha256: row['digest'] as String,
      bytes: row['bytes'] as int,
    );
  }

  /// Call only after the exact imported/restored bytes were verified and the
  /// immutable final name was published. Cache failure is safe to ignore.
  Future<void> remember(File file, FileFingerprint fingerprint) =>
      _serial(() async {
        final stat = await _stat(file);
        if (stat.size != fingerprint.bytes ||
            !RegExp(r'^[a-f0-9]{64}$').hasMatch(fingerprint.sha256)) {
          throw const FormatException('文件摘要或大小无效');
        }
        await _remember(file, fingerprint, stat);
      });

  Future<void> _remember(
    File file,
    FileFingerprint fingerprint,
    FileStat stat,
  ) async {
    try {
      final database = await _open();
      database.execute(
        'INSERT OR REPLACE INTO file_fingerprints(path,digest,bytes,mtime,ctime) VALUES (?,?,?,?,?)',
        [
          await file.resolveSymbolicLinks(),
          fingerprint.sha256,
          fingerprint.bytes,
          stat.modified.microsecondsSinceEpoch,
          stat.changed.microsecondsSinceEpoch,
        ],
      );
    } catch (_) {
      /* Derived cache does not invalidate a successful import. */
    }
  }

  static Future<FileStat> _stat(File file) async {
    final stat = await file.stat();
    if (stat.type != FileSystemEntityType.file) {
      throw FileSystemException('文件不存在或不是普通文件', file.path);
    }
    return stat;
  }

  static bool _same(FileStat a, FileStat b) =>
      a.size == b.size && a.modified == b.modified && a.changed == b.changed;
  Future<void> close() async {
    await _tail;
    if (_closed) return;
    _closed = true;
    _database?.close();
    _database = null;
  }
}

Future<FileFingerprint> _hashFile(String path, int bytes) =>
    Isolate.run(() async {
      final digest = await crypto.sha256.bind(File(path).openRead()).first;
      return FileFingerprint(sha256: digest.toString(), bytes: bytes);
    });
