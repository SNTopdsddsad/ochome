import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../app_version.dart';
import '../database/app_database.dart';
import 'backup_exceptions.dart';
import 'backup_manifest.dart';
import 'cover_path.dart';
import 'cover_store.dart';
import 'icloud_container.dart';
import 'restore_progress.dart';
import 'role_asset_store.dart';
import 'restore_version_gate.dart';
import 'sqlite_snapshotter.dart';

class RestorePlan {
  RestorePlan({
    required this.workDir,
    required this.sqliteSnapshot,
    required this.coversDir,
    required this.schemaVersion,
    this.manifest,
  });

  final Directory workDir;
  final File sqliteSnapshot;
  final Directory coversDir;
  final int schemaVersion;
  final BackupManifest? manifest;

  Directory get assetsDir =>
      Directory(p.join(workDir.path, RoleAssetStore.folderName));

  Future<void> dispose() async {
    if (await workDir.exists()) {
      await workDir.delete(recursive: true);
    }
  }
}

class ICloudStatus {
  const ICloudStatus({
    required this.available,
    this.manifest,
    this.remoteFiles = const [],
  });

  final bool available;
  final BackupManifest? manifest;
  final List<String> remoteFiles;
}

/// 手动快照备份 / 恢复编排。不把活库路径指到 ubiquity。
class ICloudBackupService {
  ICloudBackupService({
    required this.container,
    required this.supportDirectory,
    this.appVersion = kAppVersion,
    this.schemaVersion = AppDatabase.currentSchemaVersion,
    this.snapshotter = const SqliteSnapshotter(),
    this.clock,
  });

  final ICloudContainer container;
  final Future<Directory> Function() supportDirectory;
  final String appVersion;
  final int schemaVersion;
  final SqliteSnapshotter snapshotter;
  final DateTime Function()? clock;

  Future<ICloudStatus> status() async {
    if (!await container.isAvailable()) {
      return const ICloudStatus(available: false);
    }
    var remoteFiles = const <String>[];
    try {
      remoteFiles = [
        for (final entry in await container.list('')) entry.relativePath,
      ]..sort();
    } on BackupException {
      remoteFiles = const [];
    }
    return ICloudStatus(
      available: true,
      manifest: await _tryReadManifest(),
      remoteFiles: remoteFiles,
    );
  }

  Future<BackupManifest> backup({
    required AppDatabase database,
    void Function(String message)? onProgress,
  }) async {
    onProgress?.call('正在检查 iCloud…');
    await _ensureAvailable();
    final support = await supportDirectory();
    final liveSqlite = File(p.join(support.path, AppDatabase.sqliteFileName));
    final covers = CoverStore(support);
    final workDir = await Directory.systemTemp.createTemp('ochome-backup');
    try {
      onProgress?.call('正在生成数据库快照…');
      await snapshotter.checkpoint(database);
      final snapshot = await snapshotter.copySnapshot(
        liveSqlite: liveSqlite,
        destDir: workDir,
      );
      final userVersion = snapshotter.readUserVersion(snapshot);

      onProgress?.call('正在上传立绘…');
      final localCovers = await covers.listLocal();
      final remoteCovers = await _remoteCoverSizes();
      final localNames = <String>{};
      for (final cover in localCovers) {
        localNames.add(cover.relativePath);
        final size = await cover.bytes;
        if (remoteCovers[cover.relativePath] != size) {
          await container.upload(
            localPath: cover.file.path,
            relativePath: cover.relativePath,
          );
        }
      }
      for (final remote in remoteCovers.keys) {
        if (!localNames.contains(remote)) {
          await container.delete(remote);
        }
      }

      onProgress?.call('正在上传角色资产…');
      final assetFiles = snapshotter.readAssetFiles(snapshot);
      final assetStore = RoleAssetStore(support);
      final remoteAssets = await _remoteAssetSizes();
      for (final entry in assetFiles.entries) {
        final file = assetStore.resolve(entry.key);
        if (!await file.exists() || await file.length() != entry.value) {
          throw BackupFailedException('资产文件缺失或不完整：${entry.key}');
        }
        if (remoteAssets[entry.key] != entry.value) {
          await container.upload(localPath: file.path, relativePath: entry.key);
        }
      }

      onProgress?.call('正在上传数据库…');
      await container.upload(
        localPath: snapshot.path,
        relativePath: AppDatabase.sqliteFileName,
      );

      final manifest = BackupManifest(
        format: BackupManifest.formatVersion,
        schemaVersion: userVersion,
        appVersion: appVersion,
        createdAt: (clock ?? DateTime.now)().toUtc(),
        covers: [
          for (final cover in localCovers)
            CoverManifestEntry(
              file: cover.relativePath,
              bytes: await cover.bytes,
            ),
        ],
        assets: [
          for (final entry in assetFiles.entries)
            BackupFileEntry(file: entry.key, bytes: entry.value),
        ],
      );
      final manifestFile = File(p.join(workDir.path, 'manifest.json'));
      await manifestFile.writeAsString(
        jsonEncode(manifest.toJson()),
        flush: true,
      );
      await container.upload(
        localPath: manifestFile.path,
        relativePath: 'manifest.json',
      );
      for (final path in remoteAssets.keys) {
        if (!assetFiles.containsKey(path)) await container.delete(path);
      }
      return manifest;
    } on BackupException {
      rethrow;
    } catch (error) {
      throw BackupFailedException('备份失败：$error');
    } finally {
      if (await workDir.exists()) {
        await workDir.delete(recursive: true);
      }
    }
  }

  /// 只拉 `manifest.json` 和 sqlite，做版本闸。换机时不依赖本机 `list()`。
  Future<RestorePlan> inspectBackup({
    void Function(RestoreProgress progress)? onProgress,
  }) async {
    onProgress?.call(RestoreProgress.checking());
    await _ensureAvailable();
    final workDir = await Directory.systemTemp.createTemp('ochome-restore');
    try {
      final sqliteSnapshot = File(
        p.join(workDir.path, AppDatabase.sqliteFileName),
      );
      final coversDir = Directory(
        p.join(workDir.path, CoverPath.directoryName),
      );
      await coversDir.create(recursive: true);
      await _downloadRequired(
        relativePath: 'manifest.json',
        localPath: p.join(workDir.path, 'manifest.json'),
        required: false,
      );
      await _downloadRequired(
        relativePath: AppDatabase.sqliteFileName,
        localPath: sqliteSnapshot.path,
        required: true,
      );
      await _rejectEmptyFile(sqliteSnapshot, AppDatabase.sqliteFileName);
      final manifest = await _readLocalManifest(workDir);
      final sqliteVersion = snapshotter.readUserVersion(sqliteSnapshot);
      switch (snapshotter.compareVersion(
        sqliteUserVersion: sqliteVersion,
        appSchemaVersion: schemaVersion,
        manifestSchemaVersion: manifest?.schemaVersion,
      )) {
        case RestoreVersionDecision.refuseNewer:
          throw const BackupNewerThanAppException();
        case RestoreVersionDecision.refuseTooOld:
          throw const BackupTooOldException();
        case RestoreVersionDecision.proceed:
          break;
      }
      return RestorePlan(
        workDir: workDir,
        sqliteSnapshot: sqliteSnapshot,
        coversDir: coversDir,
        schemaVersion: sqliteVersion,
        manifest: manifest,
      );
    } catch (error) {
      if (await workDir.exists()) {
        await workDir.delete(recursive: true);
      }
      if (error is BackupException) {
        rethrow;
      }
      throw RestoreFailedException('恢复失败：$error');
    }
  }

  Future<RestorePlan> prepareRestore({
    RestorePlan? inspection,
    void Function(RestoreProgress progress)? onProgress,
  }) async {
    final plan = inspection ?? await inspectBackup(onProgress: onProgress);
    try {
      final coverPaths = await _coverPathsToDownload(plan.manifest);
      final assets = snapshotter.readAssetFiles(plan.sqliteSnapshot);
      await plan.assetsDir.create(recursive: true);
      final total = coverPaths.length + assets.length;
      final expectedBytes = {
        for (final cover
            in plan.manifest?.covers ?? const <CoverManifestEntry>[])
          cover.file: cover.bytes,
      };
      final watch = Stopwatch()..start();
      for (var i = 0; i < coverPaths.length; i++) {
        final relativePath = coverPaths[i];
        onProgress?.call(
          RestoreProgress(total: total, current: i + 1, elapsed: watch.elapsed),
        );
        final localPath = p.join(plan.coversDir.path, p.basename(relativePath));
        await container.download(
          relativePath: relativePath,
          localPath: localPath,
        );
        final minBytes = expectedBytes[relativePath] ?? 1;
        await _rejectEmptyFile(
          File(localPath),
          relativePath,
          minBytes: minBytes,
        );
      }
      var current = coverPaths.length;
      for (final asset in assets.entries) {
        if (!RoleAssetStore.isValidPath(asset.key) || asset.value < 0) {
          throw const RestoreFailedException('备份中的资产信息无效');
        }
        onProgress?.call(
          RestoreProgress(
            total: total,
            current: ++current,
            elapsed: watch.elapsed,
          ),
        );
        final localPath = p.join(
          plan.assetsDir.path,
          p.posix.basename(asset.key),
        );
        await container.download(relativePath: asset.key, localPath: localPath);
        final file = File(localPath);
        if (!await file.exists() || await file.length() != asset.value) {
          throw RestoreFailedException('下载 ${asset.key} 失败：文件不完整');
        }
      }
      return plan;
    } catch (error) {
      if (inspection == null) {
        await plan.dispose();
      }
      if (error is BackupException) {
        rethrow;
      }
      throw RestoreFailedException('恢复失败：$error');
    }
  }

  /// 调用前必须已经关闭活库连接。数据库替换失败时回滚立绘和资产目录。
  Future<void> commitRestore(RestorePlan plan) async {
    final support = await supportDirectory();
    final liveSqlite = File(p.join(support.path, AppDatabase.sqliteFileName));
    final covers = CoverStore(support);
    final assets = RoleAssetStore(support);
    Directory? coversBak;
    Directory? assetsBak;
    var assetsReplaced = false;
    try {
      coversBak = await covers.replaceKeepingBackup(plan.coversDir);
      try {
        assetsBak = await assets.replaceKeepingBackup(plan.assetsDir);
        assetsReplaced = true;
        await snapshotter.replaceLive(
          snapshot: plan.sqliteSnapshot,
          liveSqlite: liveSqlite,
        );
      } catch (error) {
        try {
          if (assetsReplaced) await assets.rollback(assetsBak);
        } finally {
          await covers.rollback(coversBak);
        }
        coversBak = null;
        throw RestoreFailedException('恢复失败：$error');
      }
      try {
        await covers.discardBackup(coversBak);
        await assets.discardBackup(assetsBak);
      } catch (_) {
        // 覆盖已经成功；旧 covers 备份删不掉不影响本机数据。
      }
      coversBak = null;
    } on BackupException {
      rethrow;
    } catch (error) {
      throw RestoreFailedException('恢复失败：$error');
    } finally {
      await plan.dispose();
    }
  }

  Future<void> _ensureAvailable() async {
    if (!await container.isAvailable()) {
      throw const ICloudUnavailableException();
    }
  }

  Future<void> _downloadRequired({
    required String relativePath,
    required String localPath,
    required bool required,
  }) async {
    try {
      await container.download(
        relativePath: relativePath,
        localPath: localPath,
      );
    } on BackupException {
      if (required) {
        throw const ICloudNoBackupException();
      }
    }
  }

  Future<void> _rejectEmptyFile(
    File file,
    String relativePath, {
    int minBytes = 1,
  }) async {
    if (!await file.exists()) {
      throw RestoreFailedException('下载 $relativePath 失败');
    }
    if (minBytes > 0 && await file.length() == 0) {
      throw RestoreFailedException('下载 $relativePath 失败：文件是空的');
    }
  }

  Future<List<String>> _coverPathsToDownload(BackupManifest? manifest) async {
    final paths = <String>{
      for (final cover in manifest?.covers ?? const <CoverManifestEntry>[])
        if (cover.file.startsWith('${CoverPath.directoryName}/')) cover.file,
    };
    try {
      for (final entry in await container.list(CoverPath.directoryName)) {
        if (entry.relativePath.startsWith('${CoverPath.directoryName}/')) {
          paths.add(entry.relativePath);
        }
      }
    } on BackupException {
      // 换机时 list 可能为空；有 manifest 就按清单拉。
    }
    final ordered = paths.toList()..sort();
    return ordered;
  }

  Future<Map<String, int>> _remoteCoverSizes() async {
    try {
      final entries = await container.list(CoverPath.directoryName);
      return {
        for (final entry in entries)
          if (entry.relativePath.startsWith('${CoverPath.directoryName}/'))
            entry.relativePath: entry.bytes,
      };
    } on BackupException {
      return {};
    }
  }

  Future<Map<String, int>> _remoteAssetSizes() async {
    try {
      return {
        for (final entry in await container.list(RoleAssetStore.folderName))
          if (RoleAssetStore.isValidPath(entry.relativePath))
            entry.relativePath: entry.bytes,
      };
    } on BackupException {
      return {};
    }
  }

  Future<BackupManifest?> _readLocalManifest(Directory workDir) async {
    final file = File(p.join(workDir.path, 'manifest.json'));
    if (!await file.exists()) {
      return null;
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) {
        return null;
      }
      return BackupManifest.fromJson(Map<String, Object?>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<BackupManifest?> _tryReadManifest({Directory? workDir}) async {
    final dir =
        workDir ?? await Directory.systemTemp.createTemp('ochome-manifest');
    final owned = workDir == null;
    try {
      final file = File(p.join(dir.path, 'manifest.json'));
      await container.download(
        relativePath: 'manifest.json',
        localPath: file.path,
      );
      if (!await file.exists()) {
        return null;
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) {
        return null;
      }
      return BackupManifest.fromJson(Map<String, Object?>.from(decoded));
    } on BackupException {
      return null;
    } catch (_) {
      return null;
    } finally {
      if (owned && await dir.exists()) {
        await dir.delete(recursive: true);
      }
    }
  }
}
