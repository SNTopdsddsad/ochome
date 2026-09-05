import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class RoleCardExportCancelled implements Exception {
  const RoleCardExportCancelled();
}

/// Owns a complete set of PNGs until its external consumer has finished.
class RoleCardExportJob {
  RoleCardExportJob._(this.directory, List<String> paths)
    : paths = List.unmodifiable(paths);

  final Directory directory;
  final List<String> paths;
  bool _released = false;

  static final _activeDirectories = <String>{};

  /// Share consumers can outlive a sheet; retained jobs expire on a later run.
  Future<void> release({bool retainForShare = false}) async {
    if (_released) return;
    _released = true;
    if (retainForShare) {
      try {
        await File(p.join(directory.path, '.retained')).writeAsString('shared');
      } on FileSystemException {
        // Cleanup bookkeeping must not turn an otherwise completed share into
        // an error. The job directory itself still has a recent creation time.
      }
    } else {
      await _remove(directory);
    }
    _activeDirectories.remove(directory.path);
  }

  static Future<void> _remove(Directory directory) async {
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
    } on FileSystemException {
      // Only this app-owned job is touched; a later cleanup can retry it.
    }
  }
}

/// Encodes/writes one page at a time and exposes only a completed image set.
class RoleCardExportService {
  RoleCardExportService({
    Future<Directory> Function()? temporaryDirectory,
    DateTime Function()? clock,
  }) : _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _clock = clock ?? DateTime.now;

  static const directoryName = 'role-card-exports';
  static const retention = Duration(days: 1);
  final Future<Directory> Function() _temporaryDirectory;
  final DateTime Function() _clock;

  Future<RoleCardExportJob> render({
    required int pageCount,
    required Future<Uint8List> Function(int page) renderPage,
    bool Function()? isCancelled,
    void Function(int completed, int total)? onProgress,
  }) async {
    if (pageCount < 1) throw ArgumentError.value(pageCount, 'pageCount');
    void checkCancelled() {
      if (isCancelled?.call() ?? false) throw const RoleCardExportCancelled();
    }

    checkCancelled();
    final temporary = await _temporaryDirectory();
    final root = Directory(p.join(temporary.path, directoryName));
    await root.create(recursive: true);
    await _cleanupExpired(root);
    checkCancelled();
    final directory = await root.createTemp('job-');
    RoleCardExportJob._activeDirectories.add(directory.path);
    final paths = <String>[];
    try {
      onProgress?.call(0, pageCount);
      for (var page = 0; page < pageCount; page++) {
        checkCancelled();
        final bytes = await renderPage(page);
        checkCancelled();
        const pngHeader = [137, 80, 78, 71, 13, 10, 26, 10];
        if (bytes.length < pngHeader.length ||
            !Iterable<int>.generate(pngHeader.length)
                .every((i) => bytes[i] == pngHeader[i])) {
          throw const FormatException('生成的角色卡图片无效');
        }
        final number = (page + 1).toString().padLeft(3, '0');
        final file = File(p.join(directory.path, 'zaidang-card-$number.png'));
        final partial = File('${file.path}.part');
        await partial.writeAsBytes(bytes, flush: true);
        checkCancelled();
        await partial.rename(file.path);
        paths.add(file.path);
        onProgress?.call(page + 1, pageCount);
        await Future<void>.delayed(Duration.zero);
      }
      checkCancelled();
      return RoleCardExportJob._(directory, paths);
    } catch (_) {
      await RoleCardExportJob._remove(directory);
      RoleCardExportJob._activeDirectories.remove(directory.path);
      rethrow;
    }
  }

  Future<void> _cleanupExpired(Directory root) async {
    final cutoff = _clock().subtract(retention);
    try {
      await for (final entry in root.list(followLinks: false)) {
        if (entry is! Directory ||
            !p.basename(entry.path).startsWith('job-') ||
            RoleCardExportJob._activeDirectories.contains(entry.path)) {
          continue;
        }
        try {
          final stat = await entry.stat();
          if (stat.modified.isBefore(cutoff)) {
            await RoleCardExportJob._remove(entry);
          }
        } on FileSystemException {
          // A disappearing old job does not block a new export.
        }
      }
    } on FileSystemException {
      // The new job still gets its own directory and normal error handling.
    }
  }
}
