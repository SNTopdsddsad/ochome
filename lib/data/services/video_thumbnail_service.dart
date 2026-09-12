import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 视频封面是可重建缓存，不写入资产表或备份。串行解码避免同时加载多个大视频。
class VideoThumbnailService {
  VideoThumbnailService({
    MethodChannel? channel,
    Future<Directory> Function()? cacheDirectory,
  }) : _channel = channel ?? const MethodChannel(channelName),
       _cacheDirectory = cacheDirectory ?? getTemporaryDirectory;

  static const channelName = 'com.xuwudi.ochome/video_thumbnail';
  static const folderName = 'video-thumbnails-v1';
  final MethodChannel _channel;
  final Future<Directory> Function() _cacheDirectory;
  final _thumbnailPending = <String, Future<File?>>{};
  final _thumbnailFailures = <String>{};
  final _durationPending = <String, Future<Duration?>>{};
  final _durationFailures = <String>{};
  Future<void> _queue = Future.value();

  Future<File?> thumbnailFor(File video) async {
    try {
      final identity = await _identityFor(video);
      if (identity == null) return null;
      if (_thumbnailFailures.contains(identity.key)) return null;
      final existing = _thumbnailPending[identity.key];
      if (existing != null) return await existing;
      final request = _queue.then(
        (_) => _loadOrGenerate(video, '${identity.cacheStem}.jpg'),
      );
      _thumbnailPending[identity.key] = request;
      _queue = request.then<void>((_) {});
      try {
        final result = await request;
        if (result == null) {
          _rememberFailure(_thumbnailFailures, identity.key);
        }
        return result;
      } finally {
        _thumbnailPending.remove(identity.key);
      }
    } catch (_) {
      return null;
    }
  }

  /// 读取视频的真实时长。时长是按源文件状态建立的可重建缓存，不写入资产数据库。
  Future<Duration?> durationFor(File video) async {
    try {
      final identity = await _identityFor(video);
      if (identity == null) return null;
      if (_durationFailures.contains(identity.key)) return null;
      final existing = _durationPending[identity.key];
      if (existing != null) return await existing;
      final request = _loadOrReadDuration(video, identity.cacheStem);
      _durationPending[identity.key] = request;
      try {
        final result = await request;
        if (result == null) {
          _rememberFailure(_durationFailures, identity.key);
        }
        return result;
      } finally {
        _durationPending.remove(identity.key);
      }
    } catch (_) {
      return null;
    }
  }

  Future<_VideoIdentity?> _identityFor(File video) async {
    final stat = await video.stat();
    if (stat.type != FileSystemEntityType.file || stat.size == 0) return null;
    final cacheStem =
        '${p.basename(video.path)}-${stat.size}-${stat.modified.microsecondsSinceEpoch}';
    return _VideoIdentity('${video.absolute.path}:$cacheStem', cacheStem);
  }

  void _rememberFailure(Set<String> failures, String key) {
    if (failures.length >= 64) failures.remove(failures.first);
    failures.add(key);
  }

  Future<File?> _loadOrGenerate(File video, String name) async {
    File? pending;
    try {
      final directory = Directory(
        p.join((await _cacheDirectory()).path, folderName),
      );
      await directory.create(recursive: true);
      final cached = File(p.join(directory.path, name));
      if (await cached.exists() && await cached.length() > 0) return cached;
      pending = File(p.join(directory.path, '.$name.pending.jpg'));
      final success = await _channel.invokeMethod<bool>('firstFrame', {
        'videoPath': video.absolute.path,
        'thumbnailPath': pending.path,
        'maxDimension': 320,
      });
      if (success != true ||
          !await pending.exists() ||
          await pending.length() == 0) {
        return null;
      }
      await pending.rename(cached.path);
      return cached;
    } catch (_) {
      // 损坏视频、平台不支持或缓存不可写时只回退封面，不影响原视频。
      return null;
    } finally {
      try {
        if (pending != null && await pending.exists()) await pending.delete();
      } on FileSystemException {
        // 临时封面留在系统缓存中，系统可按需清理。
      }
    }
  }

  Future<Duration?> _loadOrReadDuration(File video, String cacheStem) async {
    File? pending;
    try {
      Directory? directory;
      File? cached;
      try {
        directory = Directory(
          p.join((await _cacheDirectory()).path, folderName),
        );
        await directory.create(recursive: true);
        cached = File(p.join(directory.path, '$cacheStem.duration-ms'));
        if (await cached.exists()) {
          final milliseconds = int.tryParse(
            (await cached.readAsString()).trim(),
          );
          if (milliseconds != null && milliseconds > 0) {
            return Duration(milliseconds: milliseconds);
          }
        }
      } catch (_) {
        // 缓存不可读写时仍可直接读取原视频时长。
      }
      final milliseconds = await _channel.invokeMethod<int>('duration', {
        'videoPath': video.absolute.path,
      });
      if (milliseconds == null || milliseconds <= 0) return null;
      if (directory != null && cached != null) {
        try {
          pending = File(
            p.join(directory.path, '.$cacheStem.duration-ms.pending'),
          );
          await pending.writeAsString('$milliseconds', flush: true);
          if (await cached.exists()) await cached.delete();
          await pending.rename(cached.path);
          pending = null;
        } catch (_) {
          // 时长已读取成功，缓存写入失败不应隐藏结果。
        }
      }
      return Duration(milliseconds: milliseconds);
    } catch (_) {
      // 损坏视频、平台不支持或缓存不可写时不显示时长，不影响原视频。
      return null;
    } finally {
      try {
        if (pending != null && await pending.exists()) await pending.delete();
      } on FileSystemException {
        // 临时时长缓存留在系统缓存中，系统可按需清理。
      }
    }
  }
}

class _VideoIdentity {
  const _VideoIdentity(this.key, this.cacheStem);

  final String key;
  final String cacheStem;
}
