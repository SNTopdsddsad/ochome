import 'dart:io';

import 'package:drift/drift.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart' as db;
import '../models/role_asset.dart';
import '../models/role_asset_name.dart';
import '../services/local_file_store.dart';
import '../services/role_asset_store.dart';
import 'role_asset_repository.dart';

class DriftRoleAssetRepository implements RoleAssetRepository {
  DriftRoleAssetRepository(
    this._db, {
    Future<Directory> Function()? supportDirectory,
  }) : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory;

  final db.AppDatabase _db;
  final Future<Directory> Function() _supportDirectory;

  SimpleSelectStatement<db.$RoleAssetsTable, db.RoleAsset> _query(int roleId) =>
      _db.select(_db.roleAssets)
        ..where((t) => t.roleId.equals(roleId))
        ..orderBy([
          (t) => OrderingTerm.desc(t.createdAt),
          (t) => OrderingTerm.desc(t.id),
        ]);

  @override
  Stream<List<RoleAsset>> watchForRole(int roleId) =>
      _query(roleId).watch().map(_map);

  @override
  Future<List<RoleAsset>> listForRole(int roleId) async =>
      _map(await _query(roleId).get());

  List<RoleAsset> _map(List<db.RoleAsset> rows) => List.unmodifiable(
    rows.map(
      (row) => RoleAsset(
        id: row.id,
        roleId: row.roleId,
        name: row.name,
        kind: RoleAssetKind.values.byName(row.kind),
        relativePath: row.relativePath,
        bytes: row.bytes,
        createdAt: row.createdAt,
      ),
    ),
  );

  @override
  Future<void> importFiles(int roleId, List<XFile> files) async {
    if (files.isEmpty) return;
    final role = await (_db.select(
      _db.roles,
    )..where((t) => t.id.equals(roleId))).getSingleOrNull();
    if (role == null) throw StateError('请先保存角色');
    final store = RoleAssetStore(await _supportDirectory());
    final imported = <LocalStoredFile>[];
    try {
      for (final file in files) {
        imported.add(await store.importFile(file));
      }
      await _db.transaction(() async {
        final now = DateTime.now();
        for (var index = 0; index < imported.length; index++) {
          final source = files[index];
          final saved = imported[index];
          await _db
              .into(_db.roleAssets)
              .insert(
                db.RoleAssetsCompanion.insert(
                  roleId: roleId,
                  name: source.name.isEmpty ? '未命名文件' : source.name,
                  kind: RoleAssetKind.fromFile(
                    source.name,
                    mimeType: source.mimeType,
                  ).name,
                  relativePath: saved.relativePath,
                  bytes: await saved.bytes,
                  createdAt: now,
                ),
              );
        }
      });
    } catch (_) {
      for (final saved in imported) {
        if (await saved.file.exists()) await saved.file.delete();
      }
      rethrow;
    }
  }

  @override
  Future<void> rename({
    required int roleId,
    required int assetId,
    required String baseName,
  }) => _db.transaction(() async {
    final asset =
        await (_db.select(_db.roleAssets)
              ..where((t) => t.id.equals(assetId) & t.roleId.equals(roleId)))
            .getSingleOrNull();
    if (asset == null) throw StateError('资产不存在或不属于此角色');
    final name = RoleAssetName(
      name: asset.name,
      relativePath: asset.relativePath,
    ).renamed(baseName);
    if (name == asset.name) return;
    await (_db.update(_db.roleAssets)
          ..where((t) => t.id.equals(assetId) & t.roleId.equals(roleId)))
        .write(db.RoleAssetsCompanion(name: Value(name)));
  });

  @override
  Future<File> fileFor(RoleAsset asset) async {
    final file = RoleAssetStore(await _supportDirectory())
        .resolve(asset.relativePath);
    if (!await file.exists()) {
      throw const FileSystemException('文件不存在，请尝试恢复备份或重新添加');
    }
    return file;
  }

  @override
  Future<void> delete({required int roleId, required int assetId}) async {
    final query = _db.select(_db.roleAssets)
      ..where((t) => t.id.equals(assetId) & t.roleId.equals(roleId));
    final asset = await query.getSingleOrNull();
    if (asset == null) return;
    final file = RoleAssetStore(await _supportDirectory())
        .resolve(asset.relativePath);
    File? pending;
    try {
      if (await file.exists()) {
        pending = await file.rename(
          '${file.parent.path}/.${file.uri.pathSegments.last}.deleting',
        );
      }
      await (_db.delete(
        _db.roleAssets,
      )..where((t) => t.id.equals(assetId) & t.roleId.equals(roleId))).go();
    } catch (_) {
      if (pending != null && await pending.exists()) {
        await pending.rename(file.path);
      }
      rethrow;
    }
    try {
      if (pending != null) await pending.delete();
    } on FileSystemException {
      // 元数据已删除，隐藏的暂存文件不会进入备份。
    }
  }
}
