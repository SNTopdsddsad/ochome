import 'dart:io';

import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';

class RoleAssetOpener {
  RoleAssetOpener({
    MethodChannel? channel,
    bool Function()? isIOS,
    Future<OpenResult> Function(String path)? fallbackOpen,
  }) : _channel = channel ?? const MethodChannel(channelName),
       _isIOS = isIOS ?? (() => Platform.isIOS),
       _fallbackOpen = fallbackOpen ?? ((path) => OpenFile.open(path));

  static const channelName = 'com.xuwudi.ochome/role_asset_preview';

  final MethodChannel _channel;
  final bool Function() _isIOS;
  final Future<OpenResult> Function(String path) _fallbackOpen;

  Future<void> open(File file, {required String displayName}) async {
    if (_isIOS()) {
      try {
        // iOS completes this request on dismissal, keeping parent actions busy.
        final previewed = await _channel.invokeMethod<bool>('openPreview', {
          'path': file.absolute.path,
          'displayName': displayName,
        });
        if (previewed == true) return;
        if (previewed != false) {
          throw const AssetOpenException('暂时无法预览此文件，请重试');
        }
      } on PlatformException catch (error) {
        final message = error.message?.trim();
        throw AssetOpenException(
          message != null && message.isNotEmpty
              ? message
              : switch (error.code) {
                  'fileNotFound' => '文件不存在，请重新添加或恢复备份',
                  'invalidArguments' => '资产信息无效，暂时无法预览',
                  'busy' => '已有预览正在打开，请关闭后重试',
                  'noPresenter' => '暂时无法显示预览，请重试',
                  _ => '暂时无法预览此文件，请重试',
                },
        );
      } on MissingPluginException {
        throw const AssetOpenException('预览服务不可用，请重新打开应用后重试');
      }
    }
    final result = await _fallbackOpen(file.path);
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
