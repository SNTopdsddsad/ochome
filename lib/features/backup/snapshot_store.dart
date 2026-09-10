import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../../data/database/app_database.dart';
import '../../data/services/data_storage.dart';
import '../../data/services/file_fingerprint_store.dart';
import '../../data/services/sqlite_snapshotter.dart';
import 'backup_models.dart';
import 'backup_protocol.dart';

Future<SnapshotFileDigest> hashBackupFile(File file, String name) async {
  final path = file.path;
  return Isolate.run(() async {
    final source = File(path);
    final before = await source.stat();
    final digest = await sha256.bind(source.openRead()).first;
    final after = await source.stat();
    if (before.size != after.size || before.modified != after.modified) {
      throw const BackupFailure('source_changed', '文件在检查过程中发生变化，请重试');
    }
    return SnapshotFileDigest(
      file: name,
      bytes: after.size,
      sha256: digest.toString(),
    );
  });
}

Future<void> verifyBackupFile(
  File file, {
  required int bytes,
  required String sha256,
}) async {
  if (!await file.exists() || await file.length() != bytes) {
    throw BackupFailure('integrity', '文件缺失或大小不完整：${p.basename(file.path)}');
  }
  final actual = await hashBackupFile(file, p.basename(file.path));
  if (actual.sha256 != sha256) {
    throw BackupFailure('integrity', '文件内容检查失败：${p.basename(file.path)}');
  }
}

Future<File> writeBackupJson(
  Directory directory,
  String name,
  Map<String, Object?> json,
) async {
  final bytes = await Isolate.run(() => utf8.encode(jsonEncode(json)));
  if (bytes.length > BackupJson.maxMetadataBytes) {
    throw const BackupFailure(
      'metadata_limit',
      '资料目录超过当前支持范围',
      retryable: false,
    );
  }
  final result = File(p.join(directory.path, name));
  await result.writeAsBytes(bytes, flush: true);
  return result;
}

Future<Map<String, Object?>> readBackupJson(File file) async {
  final bytes = await file.length();
  if (bytes <= 0 || bytes > BackupJson.maxMetadataBytes) {
    throw const FormatException('备份目录大小不正确');
  }
  return BackupJson.decode(await file.readAsBytes());
}

class DatabaseInventory {
  const DatabaseInventory({
    required this.schemaVersion,
    required this.roles,
    required this.assets,
    required this.revisionCount,
  });
  final int schemaVersion, revisionCount;
  final List<SnapshotRole> roles;
  final List<SnapshotContentFile> assets;
  Set<String> get paths => {
    for (final role in roles)
      if (role.coverRelativePath != null) role.coverRelativePath!,
    for (final asset in assets) asset.relativePath,
  };
}

/// Reads real SQLite and business values in an isolate. Validation occurs both
/// before and after ordinary Drift migration; no version-number rewriting.
Future<DatabaseInventory> inspectBackupDatabase(File file) {
  final path = file.path;
  return Isolate.run(() {
    final db = sqlite3.open(path, mode: OpenMode.readOnly);
    try {
      if (db.userVersion < 3 ||
          db.userVersion > AppDatabase.currentSchemaVersion) {
        throw const BackupFailure(
          'schema_unsupported',
          '这份备份的资料版本不受支持，请使用兼容的 App',
          retryable: false,
        );
      }
      if (db
              .select('PRAGMA integrity_check')
              .any((row) => row.values.first != 'ok') ||
          db.select('PRAGMA foreign_key_check').isNotEmpty) {
        throw const BackupFailure('database_integrity', '备份数据库检查失败');
      }
      final roles = <SnapshotRole>[];
      final assets = <SnapshotContentFile>[];
      final assetIdsByRole = <int, List<int>>{};
      final roleRows = db.select('SELECT * FROM role ORDER BY id');
      if (roleRows.length > BackupJson.maxEntries) {
        throw const FormatException('角色数量超出支持范围');
      }
      final roleIds = roleRows
          .map((r) => BackupJson.integer(r['id'], min: 1))
          .toSet();
      final revisions = <int, int>{};
      if (db.userVersion >= 5) {
        for (final row in db.select(
          'SELECT * FROM role_desc_revision ORDER BY id',
        )) {
          final owner = BackupJson.integer(row['role_id'], min: 1);
          if (!roleIds.contains(owner)) {
            throw const FormatException('设定历史的角色已缺失');
          }
          BackupJson.integer(row['id'], min: 1);
          BackupJson.string(row['content'], empty: true);
          BackupJson.integer(row['created_at']);
          revisions[owner] = (revisions[owner] ?? 0) + 1;
        }
      }
      if (db.userVersion >= 8) {
        final rows = db.select('SELECT * FROM role_asset ORDER BY id');
        if (rows.length > BackupJson.maxEntries) {
          throw const FormatException('资产数量超出支持范围');
        }
        for (final row in rows) {
          final owner = BackupJson.integer(row['role_id'], min: 1);
          final kind = BackupJson.string(row['kind']);
          final relativePath = BackupJson.logicalPath(row['relative_path']);
          if (!roleIds.contains(owner) ||
              !{'image', 'video', 'audio', 'document'}.contains(kind) ||
              !relativePath.startsWith('role_assets/')) {
            throw const FormatException('资产记录不完整');
          }
          BackupJson.integer(row['created_at']);
          assets.add(
            SnapshotContentFile(
              relativePath: relativePath,
              objectId: newBackupId(),
              roleIds: [owner],
              displayName: BackupJson.string(row['name']),
              kind: kind,
              bytes: BackupJson.integer(row['bytes']),
              assetId: BackupJson.integer(row['id'], min: 1),
            ),
          );
        }
      }
      if (db.userVersion >= 9) {
        final rows = db.select('SELECT * FROM role_relationship ORDER BY id');
        if (rows.length > BackupJson.maxEntries) {
          throw const FormatException('关系数量超出支持范围');
        }
        for (final row in rows) {
          final from = BackupJson.integer(row['from_role_id'], min: 1);
          final to = BackupJson.integer(row['to_role_id'], min: 1);
          if (from == to || !roleIds.contains(from) || !roleIds.contains(to)) {
            throw const FormatException('关系记录不完整');
          }
          BackupJson.integer(row['id'], min: 1);
          BackupJson.string(row['from_label']);
          BackupJson.string(row['to_label']);
          BackupJson.integer(row['created_at']);
        }
      }
      for (final asset in assets) {
        assetIdsByRole
            .putIfAbsent(asset.roleIds.single, () => [])
            .add(asset.assetId!);
      }
      for (final row in roleRows) {
        final id = BackupJson.integer(row['id'], min: 1);
        for (final key in [
          'sex',
          'birthday',
          'occupation',
          'desc',
          if (db.userVersion >= 4) ...['age', 'race'],
        ]) {
          BackupJson.string(row[key], empty: true);
        }
        final attributes = <String>[];
        if (db.userVersion >= 7) {
          for (final raw in BackupJson.list(
            jsonDecode(BackupJson.string(row['custom_attributes'])),
          )) {
            final attr = BackupJson.object(raw);
            final name = BackupJson.string(attr['name']);
            BackupJson.string(attr['content'], empty: true);
            if (name.trim().isEmpty) throw const FormatException('自定义属性名称不正确');
            attributes.add(name);
          }
        }
        final cover = BackupJson.string(row['coverimg'], empty: true);
        if (cover.isNotEmpty) BackupJson.logicalPath(cover);
        roles.add(
          SnapshotRole(
            roleId: id,
            name: BackupJson.string(row['name']),
            customAttributeNamesInOrder: List.unmodifiable(attributes),
            revisionCount: revisions[id] ?? 0,
            coverRelativePath: cover.isEmpty ? null : cover,
            assetIds: List.unmodifiable(assetIdsByRole[id] ?? const <int>[]),
          ),
        );
      }
      if (assets.map((a) => a.relativePath).toSet().length != assets.length) {
        throw const FormatException('资产路径重复');
      }
      return DatabaseInventory(
        schemaVersion: db.userVersion,
        roles: List.unmodifiable(roles),
        assets: List.unmodifiable(assets),
        revisionCount: revisions.values.fold(0, (a, b) => a + b),
      );
    } finally {
      db.close();
    }
  });
}

/// Normalize only a detached DB. A legacy absolute cover is mapped to a safe
/// logical name; the caller supplies its actual source or cloud covers mapping.
Future<Map<String, String>> normalizeSnapshotCovers(
  File file,
  Directory source, {
  bool legacy = false,
}) {
  final databasePath = file.path;
  final rootPath = source.path;
  return Isolate.run(() {
    final db = sqlite3.open(databasePath);
    try {
      final version = db.userVersion;
      if (version < 3 || version > AppDatabase.currentSchemaVersion) {
        throw const BackupFailure(
          'schema_unsupported',
          '这份资料版本不受支持',
          retryable: false,
        );
      }
      final sources = <String, String>{};
      final rows = db.select('SELECT id, coverimg FROM role ORDER BY id');
      for (final row in rows) {
        final cover = BackupJson.string(row['coverimg'], empty: true);
        if (cover.isNotEmpty && !p.isAbsolute(cover)) {
          sources[BackupJson.logicalPath(cover)] = p.join(rootPath, cover);
        }
      }
      final absoluteMappings = <String, String>{};
      for (final row in rows) {
        final cover = BackupJson.string(row['coverimg'], empty: true);
        if (cover.isEmpty) continue;
        var logical = cover;
        var local = p.join(rootPath, cover);
        if (p.isAbsolute(cover)) {
          local = legacy
              ? p.join(rootPath, 'covers', p.basename(cover))
              : cover;
          logical = 'covers/${p.basename(cover)}';
          if (absoluteMappings.containsKey(local)) {
            logical = absoluteMappings[local]!;
          } else if (sources.containsKey(logical) &&
              sources[logical] != local) {
            logical = 'covers/${newBackupId()}${p.extension(cover)}';
          }
          absoluteMappings[local] = logical;
          BackupJson.logicalPath(logical);
          db.execute('UPDATE role SET coverimg = ? WHERE id = ?', [
            logical,
            row['id'],
          ]);
        }
        BackupJson.logicalPath(logical);
        if (!logical.startsWith('covers/')) {
          throw const FormatException('立绘路径不正确');
        }
        sources[logical] = local;
      }
      db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
      return sources;
    } finally {
      db.close();
    }
  });
}

SnapshotContents buildContents({
  required String snapshotId,
  required DatabaseInventory inventory,
  required List<SnapshotFile> files,
  required int databaseBytes,
  Set<String> unknownSizePaths = const {},
}) {
  final byPath = {for (final file in files) file.relativePath: file};
  if (byPath.keys.toSet().difference(inventory.paths).isNotEmpty ||
      inventory.paths.difference(byPath.keys.toSet()).isNotEmpty) {
    throw const BackupFailure('references', '备份文件清单与角色资料不一致');
  }
  final contentFiles = <SnapshotContentFile>[];
  final assetsByPath = {
    for (final asset in inventory.assets) asset.relativePath: asset,
  };
  final coversByPath = <String, List<SnapshotRole>>{};
  for (final role in inventory.roles) {
    if (role.coverRelativePath != null) {
      coversByPath.putIfAbsent(role.coverRelativePath!, () => []).add(role);
    }
  }
  for (final path in inventory.paths.toList()..sort()) {
    final file = byPath[path]!;
    final owners = coversByPath[path] ?? const <SnapshotRole>[];
    if (owners.isNotEmpty) {
      if (file.kind != 'cover' ||
          (file.bytes <= 0 && !unknownSizePaths.contains(path))) {
        throw const FormatException('立绘文件不完整');
      }
      contentFiles.add(
        SnapshotContentFile(
          relativePath: path,
          objectId: file.objectId,
          roleIds: List.unmodifiable(owners.map((r) => r.roleId)),
          displayName: '${owners.first.name}的立绘',
          sizeKnown: !unknownSizePaths.contains(path),
          kind: 'cover',
          bytes: file.bytes,
        ),
      );
    } else {
      final asset = assetsByPath[path]!;
      if (file.kind != 'asset' || file.bytes != asset.bytes) {
        throw const FormatException('资产大小与数据库不一致');
      }
      contentFiles.add(
        SnapshotContentFile(
          relativePath: path,
          objectId: file.objectId,
          roleIds: asset.roleIds,
          displayName: asset.displayName,
          kind: asset.kind,
          bytes: file.bytes,
          assetId: asset.assetId,
        ),
      );
    }
  }
  return SnapshotContents(
    snapshotId: snapshotId,
    schemaVersion: inventory.schemaVersion,
    summary: SnapshotSummary(
      roleCount: inventory.roles.length,
      revisionCount: inventory.revisionCount,
      customAttributeCount: inventory.roles.fold(
        0,
        (n, r) => n + r.customAttributeNamesInOrder.length,
      ),
      coverCount: contentFiles.where((f) => f.kind == 'cover').length,
      assetCount: inventory.assets.length,
      originalFileCount: files.length,
      logicalDataBytes:
          databaseBytes + files.fold<int>(0, (n, f) => n + f.bytes),
      fileSizesComplete: unknownSizePaths.isEmpty,
      assetCountsByKind: Map.unmodifiable({
        for (final kind in ['image', 'video', 'audio', 'document'])
          kind: inventory.assets.where((a) => a.kind == kind).length,
      }),
    ),
    roles: inventory.roles,
    files: List.unmodifiable(contentFiles),
  );
}

class BuiltSnapshot {
  BuiltSnapshot({
    required this.directory,
    required this.database,
    required this.inventory,
    required this.files,
    required this.sources,
    required this.pin,
    required this.createdAtUtc,
  });
  final Directory directory;
  final File database;
  final DatabaseInventory inventory;
  final List<SnapshotFile> files;
  final Map<String, String> sources;
  final StoragePin pin;
  final DateTime createdAtUtc;
}

class SnapshotBuilder {
  SnapshotBuilder(this.storage, this.fingerprints);
  final DataStorage storage;
  final FileFingerprintStore fingerprints;
  final SqliteSnapshotter snapshotter = const SqliteSnapshotter();
  Future<BuiltSnapshot> build(
    Directory directory, {
    required void Function() checkCancelled,
    void Function(int done, int total, String? item)? onProgress,
  }) async {
    final prepared = await storage.exclusively(() async {
      checkCancelled();
      final source = storage.activeDirectory;
      final snapshot = await snapshotter.createSnapshot(
        liveSqlite: File(p.join(source.path, AppDatabase.sqliteFileName)),
        destDir: directory,
      );
      final sources = await normalizeSnapshotCovers(snapshot, source);
      final inventory = await inspectBackupDatabase(snapshot);
      for (final asset in inventory.assets) {
        sources[asset.relativePath] = p.join(source.path, asset.relativePath);
      }
      final pin = storage.pinFiles(sources.values);
      return (snapshot, inventory, sources, pin, DateTime.now().toUtc());
    });
    try {
      final files = <SnapshotFile>[];
      final paths = prepared.$2.paths.toList()..sort();
      final assetBytes = {
        for (final asset in prepared.$2.assets) asset.relativePath: asset.bytes,
      };
      for (final path in paths) {
        checkCancelled();
        final source = File(prepared.$3[path]!);
        final type = await FileSystemEntity.type(
          source.path,
          followLinks: false,
        );
        if (type != FileSystemEntityType.file) {
          throw BackupFailure('missing_file', '找不到原始文件：${p.basename(path)}');
        }
        final fingerprint = await fingerprints.fingerprint(source);
        if (!p.isWithin(storage.supportDirectory.path, source.absolute.path)) {
          final local = File(
            p.join(directory.path, 'external-covers', p.basename(path)),
          );
          await local.parent.create(recursive: true);
          await source.openRead().pipe(local.openWrite());
          await verifyBackupFile(
            local,
            bytes: fingerprint.bytes,
            sha256: fingerprint.sha256,
          );
          prepared.$3[path] = local.path;
        }
        final cover = path.startsWith('covers/');
        if ((cover && fingerprint.bytes == 0) ||
            (!cover && fingerprint.bytes != assetBytes[path])) {
          throw BackupFailure('integrity', '原始文件大小不完整：${p.basename(path)}');
        }
        files.add(
          SnapshotFile(
            kind: cover ? 'cover' : 'asset',
            relativePath: path,
            objectId: newBackupId(),
            bytes: fingerprint.bytes,
            sha256: fingerprint.sha256,
          ),
        );
        onProgress?.call(files.length, paths.length, path);
      }
      return BuiltSnapshot(
        directory: directory,
        database: prepared.$1,
        inventory: prepared.$2,
        sources: prepared.$3,
        pin: prepared.$4,
        files: List.unmodifiable(files),
        createdAtUtc: prepared.$5,
      );
    } catch (_) {
      await prepared.$4.release();
      rethrow;
    }
  }
}

class SnapshotValidator {
  Future<void> validateAndMigrate({
    required Directory dataset,
    required SnapshotManifest manifest,
    required SnapshotContents contents,
    bool verifyMedia = true,
  }) async {
    final database = File(p.join(dataset.path, AppDatabase.sqliteFileName));
    final inventory = await inspectBackupDatabase(database);
    if (inventory.schemaVersion != manifest.schemaVersion) {
      throw const BackupFailure('schema_mismatch', '备份清单与数据库版本不一致');
    }
    final derived = buildContents(
      snapshotId: manifest.snapshotId,
      inventory: inventory,
      files: manifest.files,
      databaseBytes: manifest.database.bytes,
    );
    if (jsonEncode(derived.toJson()) != jsonEncode(contents.toJson())) {
      throw const BackupFailure('contents_mismatch', '备份目录与实际资料不一致');
    }
    if (verifyMedia) {
      for (final entry in manifest.files) {
        await verifyBackupFile(
          File(p.join(dataset.path, entry.relativePath)),
          bytes: entry.bytes,
          sha256: entry.sha256,
        );
      }
    }
    await migrateDatabase(database);
    final migrated = await inspectBackupDatabase(database);
    if (migrated.roles.length != inventory.roles.length ||
        migrated.assets.length != inventory.assets.length ||
        migrated.paths.difference(inventory.paths).isNotEmpty ||
        inventory.paths.difference(migrated.paths).isNotEmpty) {
      throw const BackupFailure('migration_mismatch', '资料升级后的文件引用不一致');
    }
  }

  Future<void> migrateDatabase(File database) async {
    final executor = NativeDatabase.createInBackground(database);
    final db = AppDatabase(executor);
    try {
      await db.customSelect('SELECT count(*) FROM role').get();
    } finally {
      await db.close();
    }
  }
}
