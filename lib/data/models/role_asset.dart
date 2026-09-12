import 'package:path/path.dart' as p;

enum RoleAssetKind {
  image('图片'),
  video('视频'),
  audio('音频'),
  document('文档');

  const RoleAssetKind(this.label);

  final String label;

  static RoleAssetKind fromFile(String name, {String? mimeType}) {
    if (mimeType?.startsWith('image/') ?? false) return image;
    if (mimeType?.startsWith('video/') ?? false) return video;
    if (mimeType?.startsWith('audio/') ?? false) return audio;
    final extension = p.extension(name).toLowerCase();
    if (const {
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.webp',
      '.heic',
      '.heif',
      '.bmp',
      '.tif',
      '.tiff',
      '.avif',
      '.svg',
    }.contains(extension)) {
      return image;
    }
    if (const {
      '.mp4',
      '.mov',
      '.m4v',
      '.webm',
      '.mkv',
      '.avi',
      '.3gp',
      '.mpeg',
      '.mpg',
    }.contains(extension)) {
      return video;
    }
    if (const {
      '.mp3',
      '.m4a',
      '.aac',
      '.wav',
      '.flac',
      '.ogg',
      '.opus',
      '.aiff',
      '.aif',
      '.amr',
    }.contains(extension)) {
      return audio;
    }
    return document;
  }
}

/// 每份资产独立归属于一个已保存的角色。路径相对于 Application Support。
class RoleAsset {
  const RoleAsset({
    required this.id,
    required this.roleId,
    required this.name,
    required this.kind,
    required this.relativePath,
    required this.bytes,
    required this.createdAt,
    this.tags = const [],
  });

  final int id;
  final int roleId;
  final String name;
  final RoleAssetKind kind;
  final String relativePath;
  final int bytes;
  final DateTime createdAt;
  final List<String> tags;
}
