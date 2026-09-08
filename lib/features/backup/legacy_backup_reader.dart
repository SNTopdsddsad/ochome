import 'dart:io';

import 'package:path/path.dart' as p;

import '../../data/database/app_database.dart';
import 'backup_models.dart';
import 'backup_protocol.dart';
import 'backup_transport.dart';
import 'snapshot_store.dart';

class LegacyPrepared {
  const LegacyPrepared({
    required this.contents,
    required this.files,
    required this.inventory,
    this.createdAtUtc,
    this.appVersion,
  });
  final SnapshotContents contents;
  final List<SnapshotFile> files;
  final DatabaseInventory inventory;
  final DateTime? createdAtUtc;
  final String? appVersion;
}

/// A metadata-only transfer plan. Unknown historical cover sizes remain
/// explicitly unknown; logicalDataBytes is only the known lower bound then.
class LegacyTransferPlan {
  const LegacyTransferPlan({
    required this.contents,
    required this.databaseBytes,
    this.createdAtUtc,
  });
  final SnapshotContents contents;
  final int databaseBytes;
  final DateTime? createdAtUtc;
}

/// Reads only the native-selected known legacy slot. A missing manifest is
/// accepted solely on a definite file_not_found response, never on network or
/// discovery failure. Old hashes were not recorded: report limited integrity.
class LegacyBackupReader {
  LegacyBackupReader(this.transport);
  final BackupTransport transport;
  Future<LegacyPrepared> read({
    required String operationId,
    required String accountId,
    required Directory directory,
    required bool downloadMedia,
    required void Function() checkCancelled,
    Future<void> Function(LegacyTransferPlan plan)? beforeMedia,
    Future<void> Function(
      SnapshotContentFile file,
      int remainingKnownBytes,
      int databaseBytes,
    )?
    beforeMediaFile,
    void Function(int done, int total, String path)? onProgress,
  }) async {
    final discovery = await transport.legacyInfo(accountId);
    if (!discovery.discoveryComplete || !discovery.exists) {
      throw const BackupFailure('legacy_pending', '旧版备份尚未发现或尚未同步，请稍后重试');
    }
    Map<String, Object?>? manifest;
    try {
      final file = File(p.join(directory.path, 'legacy-manifest.json'));
      await transport.download(
        operationId: operationId,
        accountId: accountId,
        relativePath: 'manifest.json',
        localPath: file.path,
        legacy: true,
      );
      manifest = await readBackupJson(file);
    } on BackupFailure catch (error) {
      if (!{
        'file_not_found',
        'not_found',
        'legacy_manifest_missing',
      }.contains(error.code)) {
        rethrow;
      }
    }
    int? manifestSchema;
    DateTime? created;
    String? appVersion;
    final sizes = <String, int>{};
    if (manifest != null) {
      final format = BackupJson.integer(manifest['format'], min: 1);
      if (format != 1 && format != 2) throw const FormatException('不支持的旧备份格式');
      manifestSchema = BackupJson.integer(manifest['schemaVersion'], min: 1);
      created = BackupJson.time(manifest['createdAt']);
      appVersion = BackupJson.string(manifest['appVersion']);
      for (final group in ['covers', if (format >= 2) 'assets']) {
        for (final entry in BackupJson.list(manifest[group])) {
          final j = BackupJson.object(entry);
          final name = BackupJson.string(j['file']);
          final prefix = group == 'covers' ? 'covers' : 'role_assets';
          final path = BackupJson.logicalPath(
            name.startsWith('$prefix/') ? name : '$prefix/$name',
          );
          if (sizes.containsKey(path)) {
            throw const FormatException('旧版备份文件路径重复');
          }
          sizes[path] = BackupJson.integer(
            j['bytes'],
            min: group == 'covers' ? 1 : 0,
          );
        }
      }
    }
    checkCancelled();
    final database = File(p.join(directory.path, AppDatabase.sqliteFileName));
    await transport.download(
      operationId: operationId,
      accountId: accountId,
      relativePath: AppDatabase.sqliteFileName,
      localPath: database.path,
      legacy: true,
    );
    await normalizeSnapshotCovers(database, directory, legacy: true);
    final inventory = await inspectBackupDatabase(database);
    if (manifestSchema != null && manifestSchema != inventory.schemaVersion) {
      throw const BackupFailure('schema_mismatch', '旧备份清单与数据库版本不一致');
    }
    final unknownSizes = <String>{};
    final paths = inventory.paths.toList()..sort();
    final assetBytes = {
      for (final asset in inventory.assets) asset.relativePath: asset.bytes,
    };
    final plannedFiles = <SnapshotFile>[];
    for (final path in paths) {
      final cover = path.startsWith('covers/');
      final expected = cover ? sizes[path] : assetBytes[path];
      if (!cover && sizes.containsKey(path) && sizes[path] != expected) {
        throw const BackupFailure('integrity', '旧备份资产大小记录不一致');
      }
      if (expected == null) unknownSizes.add(path);
      plannedFiles.add(
        SnapshotFile(
          kind: cover ? 'cover' : 'asset',
          relativePath: path,
          objectId: newBackupId(),
          bytes: expected ?? 0,
          sha256: '0' * 64,
        ),
      );
    }
    final databaseBytes = await database.length();
    final snapshotId = newBackupId();
    final plannedContents = buildContents(
      snapshotId: snapshotId,
      inventory: inventory,
      files: plannedFiles,
      databaseBytes: databaseBytes,
      unknownSizePaths: unknownSizes,
    );
    final files = <SnapshotFile>[];
    if (downloadMedia) {
      // Entire known scope and version validation precede the first media read.
      await beforeMedia?.call(
        LegacyTransferPlan(
          contents: plannedContents,
          databaseBytes: databaseBytes,
          createdAtUtc: created,
        ),
      );
      var remainingKnown = plannedFiles.fold<int>(
        0,
        (sum, file) => sum + file.bytes,
      );
      final contentByPath = {
        for (final file in plannedContents.files) file.relativePath: file,
      };
      for (final file in plannedFiles) {
        checkCancelled();
        await beforeMediaFile?.call(
          contentByPath[file.relativePath]!,
          remainingKnown,
          databaseBytes,
        );
        checkCancelled();
        final target = File(p.join(directory.path, file.relativePath));
        await target.parent.create(recursive: true);
        final receipt = await transport.download(
          operationId: operationId,
          accountId: accountId,
          relativePath: file.relativePath,
          localPath: target.path,
          bytes: unknownSizes.contains(file.relativePath) ? null : file.bytes,
          legacy: true,
        );
        if (file.kind == 'cover' && receipt.bytes <= 0) {
          throw const BackupFailure('integrity', '旧备份立绘为空');
        }
        files.add(
          SnapshotFile(
            kind: file.kind,
            relativePath: file.relativePath,
            objectId: file.objectId,
            bytes: receipt.bytes,
            sha256: receipt.sha256,
          ),
        );
        remainingKnown -= file.bytes;
        onProgress?.call(files.length, paths.length, file.relativePath);
      }
    } else {
      files.addAll(plannedFiles);
    }
    return LegacyPrepared(
      contents: buildContents(
        snapshotId: snapshotId,
        inventory: inventory,
        files: files,
        databaseBytes: databaseBytes,
        unknownSizePaths: downloadMedia ? const {} : unknownSizes,
      ),
      files: List.unmodifiable(files),
      inventory: inventory,
      createdAtUtc: created,
      appVersion: appVersion,
    );
  }
}
