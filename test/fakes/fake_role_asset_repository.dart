import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:ochome/data/models/role_asset.dart';
import 'package:ochome/data/repositories/role_asset_repository.dart';

class FakeRoleAssetRepository implements RoleAssetRepository {
  FakeRoleAssetRepository([List<RoleAsset> assets = const []])
    : items = [...assets];

  final List<RoleAsset> items;
  final changes = StreamController<void>.broadcast(sync: true);
  final Map<int, File> files = {};
  Completer<void>? pendingImport;
  bool failImport = false;
  bool failOpen = false;
  int importCalls = 0;

  @override
  Future<List<RoleAsset>> listForRole(int roleId) async =>
      items.where((item) => item.roleId == roleId).toList();

  @override
  Stream<List<RoleAsset>> watchForRole(int roleId) async* {
    yield await listForRole(roleId);
    await for (final _ in changes.stream) {
      yield await listForRole(roleId);
    }
  }

  @override
  Future<void> importFiles(int roleId, List<XFile> files) async {
    importCalls++;
    if (pendingImport != null) await pendingImport!.future;
    if (failImport) throw StateError('模拟磁盘写入失败');
    for (final file in files) {
      final id =
          items.fold(0, (max, item) => item.id > max ? item.id : max) + 1;
      items.insert(
        0,
        RoleAsset(
          id: id,
          roleId: roleId,
          name: file.name,
          kind: RoleAssetKind.fromFile(file.name),
          relativePath: 'role_assets/$id-${file.name}',
          bytes: await file.length(),
          createdAt: DateTime(2026, 9, 6),
        ),
      );
    }
    changes.add(null);
  }

  @override
  Future<void> delete({required int roleId, required int assetId}) async {
    items.removeWhere((item) => item.id == assetId && item.roleId == roleId);
    changes.add(null);
  }

  @override
  Future<File> fileFor(RoleAsset asset) async {
    if (failOpen) throw const FileSystemException('文件不存在');
    return files[asset.id] ?? File('/private/tmp/${asset.relativePath}');
  }

  Future<void> dispose() => changes.close();
}
