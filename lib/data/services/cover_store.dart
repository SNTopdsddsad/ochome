import 'dart:io';

import 'package:path/path.dart' as p;

import 'cover_path.dart';

class LocalCoverFile {
  const LocalCoverFile({required this.file, required this.relativePath});

  final File file;
  final String relativePath;

  Future<int> get bytes async => file.length();
}

/// 沙盒 `covers/`：列举原图、整目录替换（旁路 rename，失败可回滚）。
class CoverStore {
  CoverStore(this.supportDir);

  final Directory supportDir;

  Directory get directory =>
      Directory(p.join(supportDir.path, CoverPath.directoryName));

  Future<List<LocalCoverFile>> listLocal() async {
    final dir = directory;
    if (!await dir.exists()) {
      return [];
    }
    final files = <LocalCoverFile>[];
    await for (final entity in dir.list()) {
      if (entity is! File) {
        continue;
      }
      final name = p.basename(entity.path);
      if (name.startsWith('.')) {
        continue;
      }
      files.add(
        LocalCoverFile(
          file: entity,
          relativePath: CoverPath.relative(entity.path),
        ),
      );
    }
    files.sort((a, b) => a.relativePath.compareTo(b.relativePath));
    return files;
  }

  Future<void> copyInto(Directory dest) async {
    if (!await dest.exists()) {
      await dest.create(recursive: true);
    }
    for (final cover in await listLocal()) {
      await cover.file.copy(p.join(dest.path, p.basename(cover.file.path)));
    }
  }

  /// 把 [incoming] 换成活 `covers/`。返回旧目录备份（若有），调用方在 sqlite 替换成功后再删。
  Future<Directory?> replaceKeepingBackup(Directory incoming) async {
    final live = directory;
    final next = Directory(
      p.join(supportDir.path, '${CoverPath.directoryName}.next'),
    );
    final bak = Directory(
      p.join(supportDir.path, '${CoverPath.directoryName}.bak'),
    );
    if (await next.exists()) {
      await next.delete(recursive: true);
    }
    if (await bak.exists()) {
      await bak.delete(recursive: true);
    }
    await _copyDirectory(incoming, next);
    Directory? saved;
    try {
      if (await live.exists()) {
        await live.rename(bak.path);
        saved = bak;
      }
      await next.rename(live.path);
      return saved;
    } catch (_) {
      if (saved != null && !await live.exists() && await saved.exists()) {
        await saved.rename(live.path);
      }
      if (await next.exists()) {
        await next.delete(recursive: true);
      }
      rethrow;
    }
  }

  Future<void> rollback(Directory? backup) async {
    final live = directory;
    if (await live.exists()) {
      await live.delete(recursive: true);
    }
    if (backup != null && await backup.exists()) {
      await backup.rename(live.path);
    }
  }

  Future<void> discardBackup(Directory? backup) async {
    if (backup != null && await backup.exists()) {
      await backup.delete(recursive: true);
    }
  }

  Future<void> _copyDirectory(Directory source, Directory dest) async {
    await dest.create(recursive: true);
    if (!await source.exists()) {
      return;
    }
    await for (final entity in source.list()) {
      if (entity is File) {
        await entity.copy(p.join(dest.path, p.basename(entity.path)));
      }
    }
  }
}
