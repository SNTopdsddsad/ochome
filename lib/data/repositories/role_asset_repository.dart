import 'dart:io';

import 'package:file_selector/file_selector.dart';

import '../models/role_asset.dart';

abstract interface class RoleAssetRepository {
  Stream<List<RoleAsset>> watchForRole(int roleId);
  Future<List<RoleAsset>> listForRole(int roleId);

  /// 每个角色的资产数，键为角色 id；没有资产的角色不出现在结果里。
  /// 一条流服务整张列表，避免每张卡各查一次。
  Stream<Map<int, int>> watchAssetCounts();

  /// 一批文件全数复制和登记成功才生效；失败清理本批新增文件。
  Future<void> importFiles(int roleId, List<XFile> files);

  /// 仅修改显示名称，保留扩展名和导入文件。
  Future<void> rename({
    required int roleId,
    required int assetId,
    required String baseName,
  });
  Future<void> delete({required int roleId, required int assetId});
  Future<File> fileFor(RoleAsset asset);
}
