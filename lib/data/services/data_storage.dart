import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../database/app_database.dart' show AppDatabase;

/// Bootstrap before constructing business providers. Explicit support roots stay
/// isolated; only this production entry point installs [DataStorage.current].
Future<DataStorage> initializeDataStorage({
  Future<Directory> Function()? supportDirectory,
}) async {
  final root = await (supportDirectory ?? getApplicationSupportDirectory)();
  final storage = await DataStorage.open(
    root,
    allowRecovery: true,
    atomicReplace:
        supportDirectory == null && (Platform.isIOS || Platform.isMacOS)
        ? _nativeAtomicReplace
        : null,
  );
  DataStorage.current = storage;
  return storage;
}

Future<Directory> getActiveDataDirectory() async {
  final storage = DataStorage.current;
  if (storage?.isRecoveryOnly ?? false) {
    throw StateError('本地资料不可用，请先完成恢复');
  }
  return storage?.activeDirectory ?? await getApplicationSupportDirectory();
}

typedef StorageAtomicReplace = Future<void> Function(
  File temporary,
  File target,
);

Future<void> _nativeAtomicReplace(File temporary, File target) async {
  await const MethodChannel('com.xuwudi.ochome/backup_v3').invokeMethod<void>(
    'storageAtomicReplace',
    {'temporaryPath': temporary.path, 'destinationPath': target.path},
  );
}

/// The only authority for a writable dataset. A pointer selects the complete
/// database + media root; no live database/file directory is copied piecemeal.
class DataStorage {
  DataStorage._(this.supportDirectory, this._replace, this._inputRoot);

  static DataStorage? current;
  static final _openedRoots = <String>{};
  static final _zoneKey = Object();
  static final _random = Random.secure();
  static const _sqliteName = 'ochome.sqlite';

  final Directory supportDirectory;
  final StorageAtomicReplace _replace;
  final String _inputRoot;
  bool _recoveryOnly = false;
  Object? _recoveryError;
  _Pointer? _knownPointer;
  bool get isRecoveryOnly => _recoveryOnly;
  Object? get recoveryError => _recoveryError;
  late _Pointer _pointer;
  RandomAccessFile? _processLock;
  final _changes = StreamController<int>.broadcast();
  Future<void> _tail = Future.value();
  final _pins = <String, int>{};
  final _deletions = <String>{};
  bool _closed = false;
  int _mutationRevision = 0;

  Directory get controlDirectory =>
      Directory(p.join(supportDirectory.path, 'storage-control'));
  Directory get activeDirectory => _directory(_pointer.current);
  int get epoch => _pointer.epoch;
  int get mutationRevision => _mutationRevision;
  Stream<int> get changes => _changes.stream;
  bool get cleanupPending =>
      _pointer.garbage.isNotEmpty || _deletions.isNotEmpty;
  Directory? get previousDirectory =>
      _pointer.previous == null ? null : _directory(_pointer.previous!);

  /// An isolated instance for tests/tools. The Dart fallback flushes the file
  /// before same-directory rename; production Apple bootstrap uses native fsync
  /// of both file and parent directory. Never silently replace corrupt controls.
  static Future<DataStorage> open(
    Directory supportDirectory, {
    StorageAtomicReplace? atomicReplace,
    bool allowRecovery = false,
  }) async {
    await supportDirectory.create(recursive: true);
    final root = Directory(await supportDirectory.resolveSymbolicLinks());
    if (!_openedRoots.add(root.path)) throw StateError('资料已由另一个应用实例使用');
    final storage = DataStorage._(
      root,
      atomicReplace ?? _rename,
      p.normalize(supportDirectory.absolute.path),
    );
    try {
      await storage.controlDirectory.create(recursive: true);
      storage._processLock = await File(
        p.join(storage.controlDirectory.path, 'process.lock'),
      ).open(mode: FileMode.append);
      await storage._processLock!.lock(FileLock.exclusive);
      try {
        await storage._recover();
      } catch (error) {
        // Recovery-only is reserved for data/control evidence that is known to
        // be invalid. Platform-channel, filesystem and transient SQLite I/O
        // failures belong to the bootstrap error flow: treating those as data
        // corruption would unnecessarily lock a healthy user into restore UI.
        if (!allowRecovery || error is! FormatException) rethrow;
        // Keep process ownership, controls and every dataset intact. No business
        // connection may be opened until a verified cloud dataset is activated.
        storage._pointer =
            storage._knownPointer ??
            const _Pointer(_DatasetRef.legacy(), null, 0, []);
        storage._recoveryOnly = true;
        storage._recoveryError = error;
      }
      return storage;
    } catch (error, stack) {
      try {
        await storage._processLock?.close();
      } catch (_) {
        // Preserve the startup failure that explains why initialization failed.
        // The in-process ownership marker still has to be released for retry.
      } finally {
        _openedRoots.remove(root.path);
      }
      Error.throwWithStackTrace(error, stack);
    }
  }

  static Future<void> _rename(File temporary, File target) async {
    await temporary.rename(target.path);
  }

  Future<T> exclusively<T>(Future<T> Function() action) {
    if (_closed) return Future.error(StateError('资料会话已关闭'));
    final inherited = Zone.current[_zoneKey];
    if (inherited is _Lease &&
        identical(inherited.owner, this) &&
        inherited.active) {
      return action();
    }
    final result = _tail.then((_) async {
      if (_closed) throw StateError('资料会话已关闭');
      final lease = _Lease(this);
      try {
        return await runZoned(action, zoneValues: {_zoneKey: lease});
      } finally {
        lease.active = false;
      }
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<T> mutate<T>(Future<T> Function() action, {int? expectedEpoch}) =>
      exclusively(() async {
        if (_recoveryOnly) throw StateError('本地资料不可用，请先完成恢复');
        if (expectedEpoch != null && epoch != expectedEpoch) {
          throw StateError('资料已经切换，请重新打开页面后操作');
        }
        final result = await action();
        _mutationRevision++;
        return result;
      });

  StoragePin pinFiles(Iterable<String> absolutePaths) {
    if (_closed) throw StateError('资料会话已关闭');
    final paths = absolutePaths.map((path) {
      if (!p.isAbsolute(path)) throw ArgumentError.value(path, 'absolutePaths');
      return _physicalPath(path);
    }).toSet();
    for (final path in paths) {
      _pins[path] = (_pins[path] ?? 0) + 1;
    }
    return StoragePin._(this, paths);
  }

  Future<void> deleteWhenUnpinned(File file) => exclusively(() async {
    final path = _physicalPath(file.absolute.path);
    if (!p.isWithin(supportDirectory.path, path)) {
      throw ArgumentError('只能清理应用资料目录内的文件');
    }
    if ((_pins[path] ?? 0) > 0) {
      _deletions.add(path);
      return;
    }
    if (await File(path).exists()) await File(path).delete();
  });

  Future<void> _release(Set<String> paths) => exclusively(() async {
    for (final path in paths) {
      final count = (_pins[path] ?? 0) - 1;
      if (count > 0) {
        _pins[path] = count;
      } else {
        _pins.remove(path);
      }
    }
    for (final path in _deletions.toList()) {
      if (_pins.containsKey(path)) continue;
      try {
        await deleteWhenUnpinned(File(path));
        _deletions.remove(path);
      } on FileSystemException {
        /* Unreferenced file can be cleaned on a later pass. */
      }
    }
    try {
      await _cleanup();
    } catch (_) {
      /* Retry retired dataset cleanup later. */
    }
  });

  Future<Directory> createStagingDataset() => exclusively(() async {
    final id = List.generate(
      16,
      (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return Directory(p.join(supportDirectory.path, 'datasets', id))
        .create(recursive: true);
  });

  Future<void> activate(
    Directory staging, {
    required Future<void> Function() closeDatabase,
    required Future<void> Function() reopenDatabase,
  }) => exclusively(
    () => _activate(_refForStaging(staging), closeDatabase, reopenDatabase),
  );

  Future<bool> hasPrevious() async {
    final previous = _pointer.previous;
    if (previous == null) return false;
    try {
      await _health(previous);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> restorePrevious({
    required Future<void> Function() closeDatabase,
    required Future<void> Function() reopenDatabase,
  }) => exclusively(() async {
    final previous = _pointer.previous;
    if (previous == null) throw StateError('没有可恢复的本地副本');
    await _activate(previous, closeDatabase, reopenDatabase);
  });

  Future<void> discardPrevious() => exclusively(() async {
    if (_recoveryOnly) throw StateError('本地资料需要恢复，暂不能清理副本');
    final previous = _pointer.previous;
    if (previous == null) return;
    final next = _Pointer(_pointer.current, null, epoch, [
      ..._pointer.garbage,
      previous,
    ]);
    await _writePointer(next);
    _pointer = next;
    try {
      await _cleanup();
    } catch (_) {
      /* Deferred cleanup cannot undo removal. */
    }
  });

  Future<void> _activate(
    _DatasetRef nextRef,
    Future<void> Function() closeDatabase,
    Future<void> Function() reopenDatabase,
  ) async {
    if (nextRef == _pointer.current || _pointer.garbage.contains(nextRef)) {
      throw StateError('不能恢复正在使用或已退休的资料目录');
    }
    final incoming = _directory(nextRef);
    if (await incoming.resolveSymbolicLinks() != incoming.path) {
      throw const FormatException('恢复资料目录不能是符号链接');
    }
    await _health(nextRef);
    final old = _pointer;
    final wasRecoveryOnly = _recoveryOnly;
    if (wasRecoveryOnly) await _preserveRecoveryControls();
    try {
      await closeDatabase();
    } catch (error) {
      _enterRecoveryMode(error);
      rethrow;
    }
    final next = _Pointer(nextRef, old.current, old.epoch + 1, [
      if (!wasRecoveryOnly) ...old.garbage,
      if (!wasRecoveryOnly && old.previous != null && old.previous != nextRef)
        old.previous!,
    ]);
    var switched = false;
    try {
      await _write('restore-intent.json', {
        'format': 1,
        'phase': 'prepared',
        'old': old.json,
        'next': next.json,
      });
      await _writePointer(next);
      _pointer = next;
      switched = true;
      await _health(nextRef);
      _recoveryOnly = false;
      await reopenDatabase();
      await _write('restore-intent.json', {
        'format': 1,
        'phase': 'healthy',
        'old': old.json,
        'next': next.json,
      });
    } catch (error, stack) {
      try {
        if (switched) await closeDatabase();
        final rollback = _Pointer(
          old.current,
          old.previous,
          switched ? next.epoch + 1 : old.epoch,
          old.garbage,
        );
        await _writePointer(rollback);
        _pointer = rollback;
        _recoveryOnly = wasRecoveryOnly;
        if (!wasRecoveryOnly) await reopenDatabase();
        await _removeIntent();
        if (switched) _changes.add(epoch);
      } catch (rollbackError) {
        // An uncertain connection/pointer must never release writable business
        // providers. Restart recovery or another verified restore can repair it.
        _enterRecoveryMode(rollbackError);
        rethrow;
      }
      Error.throwWithStackTrace(error, stack);
    }
    _recoveryError = null;
    _knownPointer = _pointer;
    _changes.add(epoch);
    // Once healthy, cleanup failure cannot undo data or change restore success.
    try {
      await _removeIntent();
      await _cleanup();
    } catch (_) {
      /* Retry at startup; platform cleanup errors do not undo healthy data. */
    }
  }

  void _enterRecoveryMode(Object error) {
    _recoveryOnly = true;
    _recoveryError = error;
    _knownPointer = _pointer;
    _changes.add(epoch);
  }

  Future<void> _recover() async {
    final activeFile = File(p.join(controlDirectory.path, 'active.json'));
    final intentFile = File(
      p.join(controlDirectory.path, 'restore-intent.json'),
    );
    _Pointer? active;
    Object? activeError;
    if (await activeFile.exists()) {
      try {
        active = _Pointer.parse(await _read(activeFile));
        _knownPointer = active;
      } on FormatException catch (error) {
        activeError = error;
      }
    }
    if (await intentFile.exists()) {
      final intent = await _read(intentFile);
      if (intent['format'] != 1 ||
          !['prepared', 'healthy'].contains(intent['phase'])) {
        throw const FormatException('恢复日志无效，原资料已保留');
      }
      final old = _Pointer.parse(intent['old']);
      final next = _Pointer.parse(intent['next']);
      if (next.previous != old.current || next.epoch != old.epoch + 1) {
        throw const FormatException('恢复日志不一致');
      }
      if (active != null &&
          active.current != old.current &&
          active.current != next.current) {
        throw const FormatException('资料指针与恢复日志不一致');
      }
      // A newer pointer can record an explicit rollback or later cleanup.
      // Never let a stale journal resurrect retired data or undo newer writes.
      if (active != null && active.epoch > next.epoch) {
        await _health(active.current);
      } else {
        final useNew =
            intent['phase'] == 'healthy' || active?.current == next.current;
        if (useNew) {
          final chosen = active?.current == next.current ? active! : next;
          try {
            await _health(chosen.current);
            active = chosen;
          } catch (_) {
            // Only a prepared switch has never released business writes.
            // Once healthy, surface corruption instead of silently discarding
            // edits made after the restore completed.
            if (intent['phase'] == 'healthy') rethrow;
            await _health(old.current);
            active = _Pointer(
              old.current,
              old.previous,
              next.epoch + 1,
              old.garbage,
            );
          }
        } else {
          await _health(old.current);
          active = old;
        }
      }
      _knownPointer = active;
      await _writePointer(active);
      await _removeIntent();
    } else if (activeError != null) {
      throw const FormatException('资料指针损坏，原文件已保留，请修复后重试');
    }
    if (active == null) {
      final existingDatasets = Directory(
        p.join(supportDirectory.path, 'datasets'),
      );
      if (await existingDatasets.exists() &&
          !await existingDatasets.list().isEmpty) {
        throw const FormatException('资料指针缺失，现有数据集已保留');
      }
      active = _Pointer(const _DatasetRef.legacy(), null, 0, []);
      await _health(active.current, allowEmptyLegacy: true);
      await _writePointer(active);
    } else {
      _knownPointer = active;
      await _health(active.current, allowEmptyLegacy: active.epoch == 0);
    }
    _pointer = active;
    try {
      await _cleanup();
    } catch (_) {
      /* Keep retired data for retry. */
    }
  }

  Future<void> _health(_DatasetRef ref, {bool allowEmptyLegacy = false}) async {
    final root = _directory(ref);
    final file = File(p.join(root.path, _sqliteName));
    if (!await file.exists()) {
      if (allowEmptyLegacy && ref.id == null) {
        for (final suffix in ['-wal', '-shm', '.bak', '.next']) {
          if (await File(p.join(root.path, '$_sqliteName$suffix')).exists()) {
            throw const FormatException('发现未完成的数据库文件，原资料已保留');
          }
        }
        for (final name in [
          'covers',
          'role_assets',
          'covers.bak',
          'role_assets.bak',
        ]) {
          final dir = Directory(p.join(root.path, name));
          if (await dir.exists() && !await dir.list().isEmpty) {
            throw const FormatException('数据库缺失，媒体文件已保留');
          }
        }
        return;
      }
      throw const FormatException('数据库缺失，原资料已保留');
    }
    final path = file.path;
    await _checkHealth(path);
  }

  String _physicalPath(String absolutePath) {
    final normalized = p.normalize(absolutePath);
    try {
      return File(normalized).resolveSymbolicLinksSync();
    } on FileSystemException {
      try {
        return p.join(
          Directory(p.dirname(normalized)).resolveSymbolicLinksSync(),
          p.basename(normalized),
        );
      } on FileSystemException {
        if (p.isWithin(_inputRoot, normalized)) {
          return p.join(
            supportDirectory.path,
            p.relative(normalized, from: _inputRoot),
          );
        }
        return normalized;
      }
    }
  }

  Future<void> _preserveRecoveryControls() async {
    final archive = await Directory(
      p.join(
        controlDirectory.path,
        'recovery-controls',
        DateTime.now().microsecondsSinceEpoch.toString(),
      ),
    ).create(recursive: true);
    for (final name in [
      'active.json',
      'restore-intent.json',
      'active.json.pending',
      'restore-intent.json.pending',
    ]) {
      final source = File(p.join(controlDirectory.path, name));
      if (!await source.exists()) continue;
      final copy = await source.copy(p.join(archive.path, name));
      final handle = await copy.open(mode: FileMode.append);
      try {
        await handle.flush();
      } finally {
        await handle.close();
      }
    }
  }

  _DatasetRef _refForStaging(Directory dir) {
    final path = p.normalize(dir.absolute.path);
    final datasets = p.join(supportDirectory.path, 'datasets');
    if (p.dirname(path) != datasets) {
      throw ArgumentError('恢复目录必须位于应用 datasets 目录');
    }
    final ref = _DatasetRef(p.basename(path));
    ref.validate();
    return ref;
  }

  Directory _directory(_DatasetRef ref) => ref.id == null
      ? supportDirectory
      : Directory(p.join(supportDirectory.path, 'datasets', ref.id));
  Future<void> _writePointer(_Pointer value) =>
      _write('active.json', value.json);
  Future<void> _write(String name, Map<String, Object?> value) async {
    final target = File(p.join(controlDirectory.path, name));
    final temporary = File('${target.path}.pending');
    await temporary.writeAsString(jsonEncode(value), flush: true);
    await _replace(temporary, target);
  }

  Future<Map<String, dynamic>> _read(File file) async {
    if (await file.length() > 64 * 1024) {
      throw const FormatException('资料控制文件过大');
    }
    final value = jsonDecode(await file.readAsString());
    if (value is! Map<String, dynamic>) throw const FormatException('资料控制文件无效');
    return value;
  }

  Future<void> _removeIntent() async {
    final file = File(p.join(controlDirectory.path, 'restore-intent.json'));
    if (await file.exists()) await file.delete();
  }

  Future<void> _cleanup() async {
    if (_recoveryOnly) return;
    final remaining = <_DatasetRef>[];
    for (final ref in _pointer.garbage) {
      if (ref == _pointer.current || ref == _pointer.previous) {
        throw const FormatException('清理记录引用使用中的资料');
      }
      final dir = _directory(ref);
      if (_pins.keys.any((path) => p.isWithin(dir.path, path))) {
        remaining.add(ref);
        continue;
      }
      try {
        if (ref.id != null) {
          if (await dir.exists()) await dir.delete(recursive: true);
        } else {
          for (final name in [
            _sqliteName,
            '$_sqliteName-wal',
            '$_sqliteName-shm',
          ]) {
            final file = File(p.join(dir.path, name));
            if (await file.exists()) await file.delete();
          }
          for (final name in ['covers', 'role_assets']) {
            final folder = Directory(p.join(dir.path, name));
            if (await folder.exists()) await folder.delete(recursive: true);
          }
        }
      } on FileSystemException {
        remaining.add(ref);
      }
    }
    if (remaining.length != _pointer.garbage.length) {
      final updated = _Pointer(
        _pointer.current,
        _pointer.previous,
        epoch,
        remaining,
      );
      await _writePointer(updated);
      _pointer = updated;
    }
  }

  Future<void> close() async {
    await _tail;
    if (_closed) return;
    _closed = true;
    if (identical(current, this)) current = null;
    await _processLock?.close();
    _openedRoots.remove(supportDirectory.path);
    await _changes.close();
  }
}

class StoragePin {
  StoragePin._(this._storage, this._paths);
  final DataStorage _storage;
  final Set<String> _paths;
  bool _released = false;
  Future<void> release() async {
    if (_released) return;
    _released = true;
    await _storage._release(_paths);
  }
}

class _Lease {
  _Lease(this.owner);
  final DataStorage owner;
  bool active = true;
}

class _DatasetRef {
  const _DatasetRef(this.id);
  const _DatasetRef.legacy() : id = null;
  final String? id;
  void validate() {
    if (id != null &&
        !RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_-]{0,127}$').hasMatch(id!)) {
      throw const FormatException('数据集编号无效');
    }
  }

  Map<String, Object?> get json =>
      id == null ? {'kind': 'legacy'} : {'kind': 'dataset', 'id': id};
  static _DatasetRef parse(dynamic value) {
    if (value is! Map ||
        (value['kind'] != 'legacy' && value['kind'] != 'dataset')) {
      throw const FormatException('数据集指针无效');
    }
    if (value['kind'] == 'legacy') {
      if (value.length != 1) throw const FormatException('旧数据集指针无效');
      return const _DatasetRef.legacy();
    }
    if (value['id'] is! String || value.length != 2) {
      throw const FormatException('数据集编号无效');
    }
    final ref = _DatasetRef(value['id'] as String);
    ref.validate();
    return ref;
  }

  @override
  bool operator ==(Object other) => other is _DatasetRef && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

class _Pointer {
  const _Pointer(this.current, this.previous, this.epoch, this.garbage);
  final _DatasetRef current;
  final _DatasetRef? previous;
  final int epoch;
  final List<_DatasetRef> garbage;
  Map<String, Object?> get json => {
    'format': 1,
    'current': current.json,
    'previous': previous?.json,
    'epoch': epoch,
    'garbage': garbage.map((e) => e.json).toList(),
  };
  static _Pointer parse(dynamic value) {
    if (value is! Map ||
        value['format'] != 1 ||
        value['epoch'] is! int ||
        (value['epoch'] as int) < 0 ||
        (value['garbage'] != null && value['garbage'] is! List)) {
      throw const FormatException('资料指针格式无效');
    }
    final pointer = _Pointer(
      _DatasetRef.parse(value['current']),
      value['previous'] == null ? null : _DatasetRef.parse(value['previous']),
      value['epoch'] as int,
      (value['garbage'] as List? ?? []).map(_DatasetRef.parse).toList(),
    );
    if (pointer.current == pointer.previous ||
        pointer.garbage.contains(pointer.current) ||
        (pointer.previous != null &&
            pointer.garbage.contains(pointer.previous))) {
      throw const FormatException('资料指针包含冲突引用');
    }
    return pointer;
  }
}

/// SQLite validation is read-only and cannot initialize an empty replacement.
Future<void> _checkHealth(String path) => Isolate.run(() {
  Database? database;
  try {
    database = sqlite3.open(path, mode: OpenMode.readOnly);
    if (database.userVersion < 3 ||
        database.userVersion > AppDatabase.currentSchemaVersion ||
        database
            .select('PRAGMA quick_check')
            .any((row) => row.columnAt(0) != 'ok')) {
      throw const FormatException('数据库健康检查未通过');
    }
    try {
      // Drift's table is named `role`. Reaching this constant query with an
      // SQLITE_ERROR means the supported database lacks its required root
      // table/column, so this is structural damage rather than an I/O failure.
      database.select('SELECT id FROM role LIMIT 0');
    } on SqliteException catch (error) {
      if (error.resultCode == SqlError.SQLITE_ERROR) {
        throw const FormatException('数据库结构不完整');
      }
      rethrow;
    }
  } on SqliteException catch (error) {
    if (_isDefiniteDatabaseCorruption(error)) {
      throw const FormatException('数据库健康检查未通过');
    }
    rethrow;
  } finally {
    database?.close();
  }
});

bool _isDefiniteDatabaseCorruption(SqliteException error) =>
    switch (error.resultCode) {
      SqlError.SQLITE_CORRUPT ||
      SqlError.SQLITE_FORMAT ||
      SqlError.SQLITE_NOTADB => true,
      _ => false,
    };
