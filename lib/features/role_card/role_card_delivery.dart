import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

enum RoleCardDeliveryStatus {
  saved,

  /// Positive platform callback; not a guarantee of downstream delivery.
  shared,
  cancelled,
  unknown,
}

class RoleCardDeliveryResult {
  const RoleCardDeliveryResult(this.status, {this.count = 0, this.directory});

  final RoleCardDeliveryStatus status;
  final int count;
  final String? directory;
}

abstract interface class RoleCardDelivery {
  bool get canSave;
  bool get canShare;
  String get saveLabel;
  Future<RoleCardDeliveryResult> save(List<String> paths);
  Future<RoleCardDeliveryResult> share(List<String> paths, Rect origin);
}

class PlatformRoleCardDelivery implements RoleCardDelivery {
  PlatformRoleCardDelivery({
    MethodChannel? channel,
    TargetPlatform? platform,
    Future<ShareResult> Function(ShareParams)? shareFiles,
  }) : _channel = channel ?? const MethodChannel(channelName),
       _platform = platform ?? defaultTargetPlatform,
       _shareFiles = shareFiles ?? SharePlus.instance.share;

  static const channelName = 'com.xuwudi.ochome/role_card_export';
  final MethodChannel _channel;
  final TargetPlatform _platform;
  final Future<ShareResult> Function(ShareParams) _shareFiles;

  @override
  bool get canSave =>
      !kIsWeb &&
      (_platform == TargetPlatform.iOS || _platform == TargetPlatform.macOS);

  @override
  bool get canShare =>
      !kIsWeb &&
      const {
        TargetPlatform.iOS,
        TargetPlatform.macOS,
        TargetPlatform.android,
        TargetPlatform.windows,
      }.contains(_platform);

  @override
  String get saveLabel => _platform == TargetPlatform.macOS ? '保存到文件夹' : '保存图片';

  Future<void> _validate(List<String> paths) async {
    if (paths.isEmpty) throw ArgumentError('没有可以导出的图片');
    for (final path in paths) {
      final file = File(path);
      if (!await file.exists() || await file.length() == 0) {
        throw const FileSystemException('角色卡图片已失效，请重新生成');
      }
    }
  }

  @override
  Future<RoleCardDeliveryResult> save(List<String> paths) async {
    if (!canSave) throw UnsupportedError('当前平台不支持直接保存，请使用分享');
    final files = List<String>.unmodifiable(paths);
    await _validate(files);
    final result = await _channel.invokeMapMethod<String, Object?>(
      'saveImages',
      {'paths': files},
    );
    if (result?['status'] == 'cancelled') {
      return const RoleCardDeliveryResult(RoleCardDeliveryStatus.cancelled);
    }
    if (result?['status'] != 'saved' || result?['count'] != files.length) {
      throw const FormatException('未能确认全部角色卡均已保存');
    }
    return RoleCardDeliveryResult(
      RoleCardDeliveryStatus.saved,
      count: files.length,
      directory: result?['directory'] as String?,
    );
  }

  @override
  Future<RoleCardDeliveryResult> share(List<String> paths, Rect origin) async {
    if (!canShare) throw UnsupportedError('当前平台不支持图片分享');
    final files = List<String>.unmodifiable(paths);
    await _validate(files);
    final result = await _shareFiles(
      ShareParams(
        files: [for (final path in files) XFile(path, mimeType: 'image/png')],
        fileNameOverrides: [
          for (var i = 0; i < files.length; i++)
            'zaidang-card-${(i + 1).toString().padLeft(3, '0')}.png',
        ],
        title: '角色卡',
        sharePositionOrigin: origin,
      ),
    );
    return RoleCardDeliveryResult(switch (result.status) {
      ShareResultStatus.success => RoleCardDeliveryStatus.shared,
      ShareResultStatus.dismissed => RoleCardDeliveryStatus.cancelled,
      ShareResultStatus.unavailable => RoleCardDeliveryStatus.unknown,
    }, count: files.length);
  }
}
