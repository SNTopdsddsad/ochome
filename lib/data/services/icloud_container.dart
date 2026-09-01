import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'backup_exceptions.dart';

/// iCloud Documents 容器里一份备份文件的清单项。
class ICloudEntry {
  const ICloudEntry({required this.relativePath, required this.bytes});

  /// 相对备份根目录（`Documents/ochome-backup/`）的路径，如 `covers/ada.png`。
  final String relativePath;
  final int bytes;
}

/// iCloud Documents 薄封装。Android 走 [UnavailableICloudContainer]。
abstract class ICloudContainer {
  static const channelName = 'com.xuwudi.ochome/icloud';
  static const containerId = 'iCloud.com.xuwudi.ochome';
  static const backupFolder = 'ochome-backup';

  static bool get platformSupported =>
      !kIsWeb && (Platform.isIOS || Platform.isMacOS);

  Future<bool> isAvailable();

  Future<String?> backupRoot();

  Future<void> upload({
    required String localPath,
    required String relativePath,
  });

  Future<void> download({
    required String relativePath,
    required String localPath,
  });

  Future<List<ICloudEntry>> list(String relativeDir);

  Future<void> delete(String relativePath);

  /// 打开系统文件界面，便于把备份存进用户看得到的 iCloud 云盘。
  Future<void> exportToDrive();
}

ICloudContainer createICloudContainer({bool? applePlatform}) {
  final apple = applePlatform ?? ICloudContainer.platformSupported;
  if (apple) {
    return MethodChannelICloudContainer();
  }
  return const UnavailableICloudContainer();
}

/// 非 Apple 平台桩：不调 iCloud API，所有写操作抛 [ICloudUnavailableException]。
class UnavailableICloudContainer implements ICloudContainer {
  const UnavailableICloudContainer();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<String?> backupRoot() async => null;

  @override
  Future<void> upload({
    required String localPath,
    required String relativePath,
  }) {
    throw const ICloudUnavailableException();
  }

  @override
  Future<void> download({
    required String relativePath,
    required String localPath,
  }) {
    throw const ICloudUnavailableException();
  }

  @override
  Future<List<ICloudEntry>> list(String relativeDir) {
    throw const ICloudUnavailableException();
  }

  @override
  Future<void> delete(String relativePath) {
    throw const ICloudUnavailableException();
  }

  @override
  Future<void> exportToDrive() {
    throw const ICloudUnavailableException();
  }
}

class MethodChannelICloudContainer implements ICloudContainer {
  MethodChannelICloudContainer({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(ICloudContainer.channelName);

  final MethodChannel _channel;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<String?> backupRoot() async {
    try {
      return await _channel.invokeMethod<String>('backupRoot');
    } on MissingPluginException {
      throw const ICloudUnavailableException();
    } on PlatformException catch (error) {
      throw ICloudUnavailableException(error.message ?? 'iCloud 云盘不可用');
    }
  }

  @override
  Future<void> upload({
    required String localPath,
    required String relativePath,
  }) {
    return _invoke('upload', {
      'localPath': localPath,
      'relativePath': relativePath,
    });
  }

  @override
  Future<void> download({
    required String relativePath,
    required String localPath,
  }) {
    return _invoke('download', {
      'relativePath': relativePath,
      'localPath': localPath,
    });
  }

  @override
  Future<List<ICloudEntry>> list(String relativeDir) async {
    final raw = await _invoke<List<dynamic>>('list', {
      'relativeDir': relativeDir,
    });
    return [
      for (final item in raw)
        ICloudEntry(
          relativePath: '${(item as Map)['relativePath']}',
          bytes: (item['bytes'] as num?)?.toInt() ?? 0,
        ),
    ];
  }

  @override
  Future<void> delete(String relativePath) {
    return _invoke('delete', {'relativePath': relativePath});
  }

  @override
  Future<void> exportToDrive() {
    return _invoke('exportToDrive');
  }

  Future<T> _invoke<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args) as T;
    } on MissingPluginException {
      throw const ICloudUnavailableException();
    } on PlatformException catch (error) {
      throw ICloudUnavailableException(error.message ?? 'iCloud 操作失败');
    }
  }
}
