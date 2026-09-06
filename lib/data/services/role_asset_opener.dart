import 'dart:io';

import 'package:open_file/open_file.dart';

class RoleAssetOpener {
  Future<void> open(File file) async {
    final result = await OpenFile.open(file.path);
    if (result.type != ResultType.done) {
      throw AssetOpenException(switch (result.type) {
        ResultType.noAppToOpen => '没有可打开此文件的应用',
        ResultType.fileNotFound => '文件不存在，请重新添加或恢复备份',
        ResultType.permissionDenied => '无法访问此文件',
        _ => '暂时无法打开此文件',
      });
    }
  }
}

class AssetOpenException implements Exception {
  const AssetOpenException(this.message);
  final String message;

  @override
  String toString() => message;
}
