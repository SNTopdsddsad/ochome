import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:ochome/data/models/role_asset.dart';
import 'package:ochome/data/models/role_asset_name.dart';
import 'package:ochome/data/models/role_asset_tags.dart';
import 'package:ochome/data/repositories/role_asset_repository.dart';

class FakeRoleAssetRepository implements RoleAssetRepository {
  FakeRoleAssetRepository([List<RoleAsset> assets = const []])
    : items = [...assets];

  final List<RoleAsset> items;
  final changes = StreamController<void>.broadcast(sync: true);
  final Map<int, File> files = {};
  Completer<void>? pendingImport;
  Completer<void>? pendingRename;
  Completer<void>? pendingUpdateTags;
  bool failRename = false;
  bool failUpdateTags = false;
  bool failImport = false;
  bool failOpen = false;
  int importCalls = 0;
  int renameCalls = 0;
  int updateTagsCalls = 0;

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

  Map<int, int> _counts() {
    final counts = <int, int>{};
    for (final item in items) {
      counts.update(item.roleId, (count) => count + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  @override
  Stream<Map<int, int>> watchAssetCounts() async* {
    yield _counts();
    await for (final _ in changes.stream) {
      yield _counts();
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
  Future<void> rename({
    required int roleId,
    required int assetId,
    required String baseName,
  }) async {
    renameCalls++;
    if (pendingRename != null) await pendingRename!.future;
    if (failRename) throw StateError('模拟重命名失败');
    final index = items.indexWhere(
      (item) => item.id == assetId && item.roleId == roleId,
    );
    if (index == -1) throw StateError('资产不存在或不属于此角色');
    final asset = items[index];
    final name = RoleAssetName(
      name: asset.name,
      relativePath: asset.relativePath,
    ).renamed(baseName);
    if (name == asset.name) return;
    items[index] = RoleAsset(
      id: asset.id,
      roleId: asset.roleId,
      name: name,
      kind: asset.kind,
      relativePath: asset.relativePath,
      bytes: asset.bytes,
      createdAt: asset.createdAt,
      tags: asset.tags,
    );
    changes.add(null);
  }

  @override
  Future<void> updateTags({
    required int roleId,
    required int assetId,
    required List<String> tags,
  }) async {
    updateTagsCalls++;
    final normalized = normalizeRoleAssetTags(tags);
    if (pendingUpdateTags != null) await pendingUpdateTags!.future;
    if (failUpdateTags) throw StateError('模拟标签保存失败');
    final index = items.indexWhere(
      (item) => item.id == assetId && item.roleId == roleId,
    );
    if (index == -1) throw StateError('资产不存在或不属于此角色');
    final asset = items[index];
    if (_sameTags(asset.tags, normalized)) return;
    items[index] = RoleAsset(
      id: asset.id,
      roleId: asset.roleId,
      name: asset.name,
      kind: asset.kind,
      relativePath: asset.relativePath,
      bytes: asset.bytes,
      createdAt: asset.createdAt,
      tags: normalized,
    );
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

bool _sameTags(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
