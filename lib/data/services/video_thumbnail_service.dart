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
  final _pending = <String, Future<File?>>{};
  final _failed = <String>{};
  Future<void> _queue = Future.value();

  Future<File?> thumbnailFor(File video) async {
    try {
      final stat = await video.stat();
      if (stat.type != FileSystemEntityType.file || stat.size == 0) return null;
      final name =
          '${p.basename(video.path)}-${stat.size}-${stat.modified.microsecondsSinceEpoch}.jpg';
      final key = '${video.absolute.path}:$name';
      if (_failed.contains(key)) return null;
      final existing = _pending[key];
      if (existing != null) return await existing;
      final request = _queue.then((_) => _loadOrGenerate(video, name));
      _pending[key] = request;
      _queue = request.then<void>((_) {});
      try {
        final result = await request;
        if (result == null) {
          if (_failed.length >= 64) _failed.remove(_failed.first);
          _failed.add(key);
        }
        return result;
      } finally {
        _pending.remove(key);
      }
    } catch (_) {
      return null;
    }
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
}
