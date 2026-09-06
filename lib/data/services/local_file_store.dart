import 'dart:io';

import 'package:path/path.dart' as p;

class LocalStoredFile {
  const LocalStoredFile({required this.file, required this.relativePath});

  final File file;
  final String relativePath;

  Future<int> get bytes async => file.length();
}

/// 沙盒附件目录：列举文件、整目录替换（旁路 rename，失败可回滚）。
class LocalFileStore {
  LocalFileStore(this.supportDir, {required this.directoryName});

  final Directory supportDir;
  final String directoryName;

  Directory get directory => Directory(p.join(supportDir.path, directoryName));

  Future<List<LocalStoredFile>> listLocal() async {
    final dir = directory;
    if (!await dir.exists()) {
      return [];
    }
    final files = <LocalStoredFile>[];
    await for (final entity in dir.list()) {
      if (entity is! File) {
        continue;
      }
      final name = p.basename(entity.path);
      if (name.startsWith('.')) {
        continue;
      }
      files.add(
        LocalStoredFile(file: entity, relativePath: '$directoryName/$name'),
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

  /// 把 [incoming] 换成当前目录。返回旧目录备份，调用方在 sqlite 替换成功后再删。
  Future<Directory?> replaceKeepingBackup(Directory incoming) async {
    final live = directory;
    final next = Directory(p.join(supportDir.path, '$directoryName.next'));
    final bak = Directory(p.join(supportDir.path, '$directoryName.bak'));
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
