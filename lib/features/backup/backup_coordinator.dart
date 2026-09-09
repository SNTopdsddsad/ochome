import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../data/database/app_database.dart';
import '../../data/services/data_storage.dart';
import '../../data/services/file_fingerprint_store.dart';
import '../../data/services/sqlite_snapshotter.dart';
import 'backup_models.dart';
import 'backup_protocol.dart';
import 'backup_transport.dart';
import 'legacy_backup_reader.dart';
import 'snapshot_store.dart';

/// App-owned coordinator. Widgets observe jobs and send intents; leaving the
/// page never releases the task lock or authorizes activation.
class BackupCoordinator {
  BackupCoordinator({
    required this.storage,
    BackupTransport? transport,
    required this.closeDatabase,
    required this.reopenDatabase,
  }) : transport = transport ?? MethodChannelBackupTransport(),
       _fingerprints = FileFingerprintStore(storage.controlDirectory) {
    _subscription = this.transport.events.listen(
      _onNativeEvent,
      onError: (_) {
        // Events improve observability; awaited native results remain authoritative.
      },
    );
  }
  final DataStorage storage;
  final BackupTransport transport;
  final Future<void> Function() closeDatabase, reopenDatabase;
  final FileFingerprintStore _fingerprints;
  final _states = StreamController<BackupJobState>.broadcast();
  StreamSubscription<BackupTransferEvent>? _subscription;
  BackupJobState? get currentJob => _job?.state;
  BackupFailure? get recoveryNotice => _recoveryNotice;
  BackupFailure? _recoveryNotice;
  Stream<BackupJobState> watchJob() => _states.stream;
  _Job? _job;
  Future<void>? _running;
  Completer<void>? _settlement;
  Future<void> _writes = Future.value();
  bool _busy = false, _cancelRequested = false, _controlBusy = false;
  int _nativeSequence = -1;
  String? _nativeProgressPath, _nativeProgressPhase;
  DateTime _lastProgress = DateTime.fromMillisecondsSinceEpoch(0);
  String _writerId = newBackupId();
  int _writerSequence = 0;
  Directory get _jobs =>
      Directory(p.join(storage.controlDirectory.path, 'backup-jobs'));

  Future<BackupAvailability> availability() => transport.availability();
  Future<BackupAvailability> _requireAccount([String? expected]) async {
    final state = await availability();
    if (!state.available || state.accountId == null) {
      throw BackupFailure(
        state.errorCode ?? 'unavailable',
        state.message ?? '请检查 iCloud 账户与网络后重试',
      );
    }
    if (expected != null && state.accountId != expected) {
      throw const BackupFailure('account_changed', 'iCloud 账户已切换，请重新开始');
    }
    return state;
  }

  Future<BackupHistory> listBackups() async {
    final account = await _requireAccount();
    final catalog = await transport.catalog(account.accountId!);
    return BackupHistory(
      snapshots: catalog.snapshots,
      retiredCount: catalog.retired.length,
    );
  }

  /// Only SQLite and stat metadata are read. Listing never hashes all media.
  Future<SnapshotContents> currentContents() async {
    if (storage.isRecoveryOnly) {
      throw const BackupFailure(
        'local_unreadable',
        '本机资料暂时无法读取，原文件已保留',
        retryable: false,
      );
    }
    final directory = Directory(p.join(_jobs.path, 'inspect-${newBackupId()}'));
    await directory.create(recursive: true);
    try {
      return await storage.exclusively(() async {
        final source = storage.activeDirectory;
        final database = await const SqliteSnapshotter().createSnapshot(
          liveSqlite: File(p.join(source.path, AppDatabase.sqliteFileName)),
          destDir: directory,
        );
        final sources = await normalizeSnapshotCovers(database, source);
        final inventory = await inspectBackupDatabase(database);
        final files = <SnapshotFile>[];
        for (final path in inventory.paths.toList()..sort()) {
          final file = File(sources[path] ?? p.join(source.path, path));
          if (!await file.exists()) {
            throw const BackupFailure('missing_file', '部分原始文件缺失，请检查本机资料');
          }
          files.add(
            SnapshotFile(
              kind: path.startsWith('covers/') ? 'cover' : 'asset',
              relativePath: path,
              objectId: newBackupId(),
              bytes: await file.length(),
              sha256: '0' * 64,
            ),
          );
        }
        return buildContents(
          snapshotId: newBackupId(),
          inventory: inventory,
          files: files,
          databaseBytes: await database.length(),
        );
      });
    } finally {
      if (await directory.exists()) await directory.delete(recursive: true);
    }
  }

  Future<SnapshotContents> contentsFor(BackupSource source) async {
    final account = await _requireAccount();
    final id = newBackupId();
    final directory = Directory(p.join(_jobs.path, 'inspect-$id'));
    await directory.create(recursive: true);
    var safeToRemove = true;
    try {
      if (source.legacy) {
        return (await LegacyBackupReader(transport).read(
          operationId: id,
          accountId: account.accountId!,
          directory: directory,
          downloadMedia: false,
          checkCancelled: () {},
        )).contents;
      }
      return (await _readMetadata(
        id,
        account.accountId!,
        source.descriptor!,
        directory,
      )).$2;
    } catch (_) {
      // Cancellation drains native writers before the owned inspect directory
      // can be removed. If draining fails leave this isolated path intact.
      safeToRemove = false;
      await transport.cancel(id);
      safeToRemove = true;
      rethrow;
    } finally {
      if (safeToRemove && await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }
  }

  Future<String> startBackup() async {
    await _awaitVisibleBoundary();
    final previous = _job;
    final job = _begin(BackupJobKind.backup);
    _launch(job, () async {
      await _reclaimAbandonedStage(previous, job);
      await _backup(job);
    });
    return job.state.operationId;
  }

  Future<String> prepareRestore(BackupSource source) async {
    await _awaitVisibleBoundary();
    final previous = _job;
    final job = _begin(BackupJobKind.restore, source: source);
    _launch(job, () async {
      await _reclaimAbandonedStage(previous, job);
      await _restore(job);
    });
    return job.state.operationId;
  }

  _Job _begin(BackupJobKind kind, {BackupSource? source}) {
    if (_busy || _controlBusy || (_job?.state.requiresConfirmation ?? false)) {
      throw const BackupFailure('busy', '已有备份或恢复任务，请先完成或取消');
    }
    final id = newBackupId();
    final job = _Job(
      state: BackupJobState(
        operationId: id,
        kind: kind,
        phase: BackupPhase.preparing,
        startedAtUtc: DateTime.now().toUtc(),
      ),
      directory: Directory(p.join(_jobs.path, id)),
      source: source,
    );
    _job = job;
    _settlement = Completer<void>();
    _busy = true;
    _cancelRequested = false;
    _nativeSequence = -1;
    _nativeProgressPath = null;
    _nativeProgressPhase = null;
    return job;
  }

  void _launch(_Job job, Future<void> Function() body) {
    final settlement = _settlement!;
    _running = () async {
      try {
        await job.directory.create(recursive: true);
        await _save(job);
        _states.add(job.state);
        await body();
      } catch (error) {
        final previousPhase = job.state.phase;
        final failure = _failure(error);
        try {
          if (job.state.phase == BackupPhase.completed) {
            await _update(job, job.state.copyWith(cleanupPending: true));
          } else {
            await _update(
              job,
              job.state.copyWith(
                phase: _cancelRequested
                    ? BackupPhase.cancelled
                    : BackupPhase.failed,
                error: failure,
                failedAtPhase: previousPhase,
              ),
            );
          }
        } on FileSystemException {
          // A full disk can prevent journaling the already-visible failure.
        }
      } finally {
        _busy = false;
        settlement.complete();
      }
    }();
  }

  /// A terminal/review state can be visible before its durable journal and
  /// release/cleanup tail finishes. Queue a subsequent intent behind that exact
  /// runner rather than exposing a spurious busy error or releasing the lock
  /// while file writers are still active. Competing new intents still go
  /// through the ordinary synchronous _begin gate after this await.
  Future<void> _awaitVisibleBoundary({bool review = false}) async {
    final state = currentJob;
    if (state != null &&
        (state.isTerminal || (review && state.requiresConfirmation))) {
      final pending = _settlement;
      if (pending != null) await pending.future;
    }
  }

  BackupFailure _failure(Object error) {
    if (error is BackupFailure) return error;
    if (error is FormatException) {
      return BackupFailure('invalid_backup', error.message, retryable: false);
    }
    if (error is FileSystemException) {
      return const BackupFailure('storage_error', '本机存储操作未完成，请检查剩余空间后重试');
    }
    return const BackupFailure('operation_failed', '操作未完成，请重试；原有资料会保留到校验和切换成功');
  }

  void _check() {
    if (_cancelRequested) throw const BackupFailure('cancelled', '任务已取消');
  }

  Future<void> _phase(_Job job, BackupPhase phase) => _update(
    job,
    job.state.copyWith(phase: phase, resetProgress: true, clearError: true),
  );
  Future<void> _update(_Job job, BackupJobState next) async {
    if (!identical(_job, job)) return;
    job.state = next;
    _states.add(next);
    try {
      await _save(job);
    } on FileSystemException {
      if (next.phase != BackupPhase.completed) rethrow;
      job.state = next.copyWith(cleanupPending: true);
      _states.add(job.state);
    }
  }

  Future<void> _save(_Job job) {
    final data = job.toJson();
    final id = job.state.operationId;
    final selectLatest = identical(job, _job);
    final contents = job.state.contents;
    final save = _writes.catchError((Object _) {}).then((_) async {
      await job.directory.create(recursive: true);
      if (contents != null && !identical(contents, job.persistedContents)) {
        final pendingScope = await writeBackupJson(
          job.directory,
          'scope.next',
          contents.toJson(),
        );
        await pendingScope.rename(p.join(job.directory.path, 'scope.json'));
        job.persistedContents = contents;
      }
      final next = File(p.join(job.directory.path, 'job.next'));
      await next.writeAsString(jsonEncode(data), flush: true);
      await next.rename(p.join(job.directory.path, 'job.json'));
      if (selectLatest) {
        final latest = File(p.join(_jobs.path, 'latest.next'));
        await latest.writeAsString(
          jsonEncode({'operationId': id}),
          flush: true,
        );
        await latest.rename(p.join(_jobs.path, 'latest.json'));
      }
    });
    _writes = save;
    return save;
  }

  Future<void> _backup(_Job job) async {
    final availability = await _requireAccount(job.accountId);
    job.accountId = availability.accountId;
    final accountId = job.accountId!;
    await _loadWriter(availability);
    _check();
    final catalog = await transport.catalog(accountId);
    // Native binds this writer to the installation and device, preserving
    // incremental reuse across launches without duplicating write credentials.
    final bases = catalog.snapshots
        .where((s) => s.writerId == _writerId)
        .toList();
    job.baseIds = bases.map((s) => s.snapshotId).toList();
    job.reservation = await transport.reserve(
      operationId: job.id,
      accountId: accountId,
      kind: 'backup',
      baseSnapshotIds: job.baseIds,
    );
    await _save(job);
    final candidates = <String, SnapshotFile>{};
    for (final base in bases) {
      final directory = Directory(
        p.join(job.directory.path, 'base-${base.snapshotId}'),
      );
      await directory.create(recursive: true);
      final info = await _readMetadata(job.id, accountId, base, directory);
      for (final file in info.$1.files) {
        candidates['${file.sha256}:${file.bytes}'] = file;
      }
    }
    await _phase(job, BackupPhase.hashing);
    final built = await SnapshotBuilder(storage, _fingerprints).build(
      job.directory,
      checkCancelled: _check,
      onProgress: (done, total, path) {
        _localProgress(job, done, total, path);
      },
    );
    try {
      _check();
      final files = <SnapshotFile>[];
      final toUpload = <SnapshotFile>[];
      var reusedFiles = 0, reusedBytes = 0;
      final thisSnapshot = <String, SnapshotFile>{};
      for (final source in built.files) {
        final key = '${source.sha256}:${source.bytes}';
        final reused = candidates[key];
        final duplicate = thisSnapshot[key];
        final mapped = SnapshotFile(
          kind: source.kind,
          relativePath: source.relativePath,
          objectId: reused?.objectId ?? duplicate?.objectId ?? source.objectId,
          bytes: source.bytes,
          sha256: source.sha256,
        );
        files.add(mapped);
        if (reused != null) {
          reusedFiles++;
          reusedBytes += source.bytes;
        } else if (duplicate == null) {
          toUpload.add(mapped);
        }
        thisSnapshot[key] = mapped;
      }
      final snapshotId = newBackupId();
      final databaseDigest = await hashBackupFile(
        built.database,
        'database.sqlite',
      );
      final contents = buildContents(
        snapshotId: snapshotId,
        inventory: built.inventory,
        files: files,
        databaseBytes: databaseDigest.bytes,
      );
      final contentsFile = await writeBackupJson(
        job.directory,
        'contents.json',
        contents.toJson(),
      );
      final contentsDigest = await hashBackupFile(
        contentsFile,
        'contents.json',
      );
      final manifest = SnapshotManifest(
        snapshotId: snapshotId,
        writerId: _writerId,
        writerSequence: await _nextWriterSequence(),
        createdAtUtc: built.createdAtUtc,
        appVersion: availability.appVersion,
        schemaVersion: built.inventory.schemaVersion,
        deviceLabel: availability.deviceName,
        database: databaseDigest,
        contents: contentsDigest,
        files: List.unmodifiable(files),
        summary: {
          'roleCount': contents.summary.roleCount,
          'revisionCount': contents.summary.revisionCount,
          'assetCount': contents.summary.assetCount,
          'fileCount': files.length,
          'totalBytes': contents.summary.logicalDataBytes,
        },
      );
      final manifestFile = await writeBackupJson(
        job.directory,
        'manifest.json',
        manifest.toJson(),
      );
      final manifestDigest = await hashBackupFile(
        manifestFile,
        'manifest.json',
      );
      final commit = SnapshotCommit(
        snapshotId: snapshotId,
        writerId: _writerId,
        writerSequence: manifest.writerSequence,
        manifestBytes: manifestDigest.bytes,
        manifestSha256: manifestDigest.sha256,
      );
      final commitFile = await writeBackupJson(
        job.directory,
        'commit.json',
        commit.toJson(),
      );
      final commitDigest = await hashBackupFile(commitFile, 'commit.json');
      job.descriptor = BackupDescriptor(
        snapshotId: snapshotId,
        writerId: _writerId,
        basePath: manifest.basePath,
        createdAtUtc: built.createdAtUtc,
        appVersion: availability.appVersion,
        schemaVersion: manifest.schemaVersion,
        roleCount: contents.summary.roleCount,
        revisionCount: contents.summary.revisionCount,
        assetCount: contents.summary.assetCount,
        fileCount: files.length,
        totalBytes: contents.summary.logicalDataBytes,
        manifestSha256: manifestDigest.sha256,
        commitSha256: commitDigest.sha256,
        deviceName: availability.deviceName,
      );
      job.manifest = manifest;
      final uploadBytes =
          toUpload.fold<int>(0, (n, f) => n + f.bytes) +
          databaseDigest.bytes +
          contentsDigest.bytes +
          manifestDigest.bytes +
          commitDigest.bytes;
      _checkSpace(availability.availableBytes, uploadBytes);
      await _update(
        job,
        job.state.copyWith(
          contents: contents,
          descriptor: job.descriptor,
          contentCreatedAtUtc: built.createdAtUtc,
          reusedFiles: reusedFiles,
          reusedBytes: reusedBytes,
          uploadBytes: uploadBytes,
          phase: BackupPhase.staging,
          totalFiles: toUpload.length,
          completedFiles: 0,
          resetProgress: true,
        ),
      );
      for (final file in toUpload) {
        _check();
        await _renew(job, 'backup');
        await _update(
          job,
          job.state.copyWith(currentItem: _friendly(job, file.relativePath)),
        );
        await _stage(
          job,
          File(built.sources[file.relativePath]!),
          file.objectPath(_writerId),
          file.bytes,
          file.sha256,
        );
        _check();
        await _update(
          job,
          job.state.copyWith(
            completedFiles: (job.state.completedFiles ?? 0) + 1,
            currentItem: _friendly(job, file.relativePath),
          ),
        );
      }
      for (final entry in [
        (built.database, databaseDigest),
        (contentsFile, contentsDigest),
        (manifestFile, manifestDigest),
      ]) {
        _check();
        await _stage(
          job,
          entry.$1,
          '${manifest.basePath}/${entry.$2.file}',
          entry.$2.bytes,
          entry.$2.sha256,
        );
      }
      job.allStaged = true;
      await _save(job);
    } finally {
      await built.pin.release();
    }
    await _finishBackup(job);
  }

  Future<void> _stage(
    _Job job,
    File file,
    String path,
    int bytes,
    String hash,
  ) => transport.stage(
    operationId: job.id,
    accountId: job.accountId!,
    localPath: file.path,
    relativePath: path,
    bytes: bytes,
    sha256: hash,
  );

  Future<void> _loadWriter(BackupAvailability availability) async {
    if (availability.writerId != null) {
      _writerId = BackupJson.uuid(availability.writerId);
    }
    final ledger = File(
      p.join(storage.controlDirectory.path, 'backup-writer.json'),
    );
    if (await ledger.exists()) {
      try {
        final value = await readBackupJson(ledger);
        if (value['writerId'] == _writerId) {
          _writerSequence = BackupJson.integer(value['sequence']);
        }
      } on FormatException {
        /* A diagnostic sequence may be rebuilt safely. */
      }
    }
  }

  Future<int> _nextWriterSequence() async {
    final sequence = ++_writerSequence;
    final file = File(
      p.join(storage.controlDirectory.path, 'backup-writer.next'),
    );
    await file.writeAsString(
      jsonEncode({'writerId': _writerId, 'sequence': sequence}),
      flush: true,
    );
    await file.rename(
      p.join(storage.controlDirectory.path, 'backup-writer.json'),
    );
    return sequence;
  }

  Future<void> _finishBackup(_Job job) async {
    final manifest = job.manifest!;
    _check();
    await _requireAccount(job.accountId);
    if (job.publishAttempted) {
      await _publish(job);
      return;
    }
    await _renew(job, 'backup', force: true);
    await _phase(job, BackupPhase.waitingForCloud);
    await transport.awaitUploaded(
      operationId: job.id,
      accountId: job.accountId!,
      relativePaths: {
        for (final file in manifest.files) file.objectPath(manifest.writerId),
        '${manifest.basePath}/database.sqlite',
        '${manifest.basePath}/contents.json',
        '${manifest.basePath}/manifest.json',
      }.toList(),
    );
    _check();
    final commitFile = File(p.join(job.directory.path, 'commit.json'));
    final commitDigest = await hashBackupFile(commitFile, 'commit.json');
    if (commitDigest.sha256 != job.descriptor!.commitSha256) {
      throw const BackupFailure('integrity', '待发布备份记录已变化');
    }
    await _stage(
      job,
      commitFile,
      '${manifest.basePath}/commit.json',
      commitDigest.bytes,
      commitDigest.sha256,
    );
    await transport.awaitUploaded(
      operationId: job.id,
      accountId: job.accountId!,
      relativePaths: ['${manifest.basePath}/commit.json'],
    );
    _check();
    await _renew(job, 'backup', force: true);
    job.publishAttempted = true;
    await _phase(job, BackupPhase.publishing);
    await _publish(job);
  }

  Future<void> _publish(_Job job) async {
    final result = await transport.publish(
      operationId: job.id,
      accountId: job.accountId!,
      reservationId: job.reservation!.reservationId,
      snapshot: job.descriptor!,
    );
    if (result.snapshotId != job.descriptor!.snapshotId ||
        result.commitSha256 != job.descriptor!.commitSha256 ||
        result.accountSequence == null) {
      throw const BackupFailure('catalog_mismatch', '云端完成记录不一致，请重试确认');
    }
    job.descriptor = result;
    await _update(
      job,
      job.state.copyWith(
        phase: BackupPhase.completed,
        descriptor: result,
        completedAtUtc: result.completedAtUtc,
        clearError: true,
        resetProgress: true,
      ),
    );
    // A cleanup failure cannot undo an acknowledged publication.
    try {
      await _release(job);
      await _cleanup(job);
    } catch (_) {
      await _update(job, job.state.copyWith(cleanupPending: true));
    }
    try {
      await _pruneCompletedWorkspace(job);
    } catch (_) {
      await _update(job, job.state.copyWith(cleanupPending: true));
    }
  }

  Future<void> _pruneCompletedWorkspace(_Job job) async {
    // Keep the lightweight scope/result journal. The detached SQLite and
    // absolute-cover staging copies are no longer needed after publication.
    final database = File(
      p.join(job.directory.path, AppDatabase.sqliteFileName),
    );
    for (final path in [
      database.path,
      '${database.path}-wal',
      '${database.path}-shm',
    ]) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    await for (final entry in job.directory.list(followLinks: false)) {
      if (entry is! Directory) continue;
      final name = p.basename(entry.path);
      if (name == 'external-covers' ||
          RegExp(r'^(?:base|gc)-[a-f0-9-]{36}$').hasMatch(name)) {
        await entry.delete(recursive: true);
      }
    }
  }

  Future<(SnapshotManifest, SnapshotContents)> _readMetadata(
    String operationId,
    String accountId,
    BackupDescriptor descriptor,
    Directory directory,
  ) async {
    final commitFile = File(p.join(directory.path, 'commit.json'));
    await transport.download(
      operationId: operationId,
      accountId: accountId,
      relativePath: '${descriptor.basePath}/commit.json',
      localPath: commitFile.path,
      sha256: descriptor.commitSha256,
    );
    final commit = SnapshotCommit.fromJson(await readBackupJson(commitFile));
    if (commit.snapshotId != descriptor.snapshotId ||
        commit.writerId != descriptor.writerId ||
        commit.manifestSha256 != descriptor.manifestSha256) {
      throw const FormatException('备份完成标记与目录不一致');
    }
    final manifestFile = File(p.join(directory.path, 'manifest.json'));
    await transport.download(
      operationId: operationId,
      accountId: accountId,
      relativePath: '${descriptor.basePath}/manifest.json',
      localPath: manifestFile.path,
      bytes: commit.manifestBytes,
      sha256: commit.manifestSha256,
    );
    final manifest = SnapshotManifest.fromJson(
      await readBackupJson(manifestFile),
    );
    if (manifest.snapshotId != descriptor.snapshotId ||
        manifest.writerId != descriptor.writerId ||
        manifest.writerSequence != commit.writerSequence ||
        manifest.schemaVersion != descriptor.schemaVersion ||
        manifest.summary['roleCount'] != descriptor.roleCount ||
        manifest.summary['revisionCount'] != descriptor.revisionCount ||
        manifest.summary['assetCount'] != descriptor.assetCount ||
        manifest.summary['fileCount'] != descriptor.fileCount ||
        manifest.summary['totalBytes'] != descriptor.totalBytes) {
      throw const FormatException('备份清单与目录不一致');
    }
    final contentsFile = File(p.join(directory.path, 'contents.json'));
    await transport.download(
      operationId: operationId,
      accountId: accountId,
      relativePath: '${descriptor.basePath}/contents.json',
      localPath: contentsFile.path,
      bytes: manifest.contents.bytes,
      sha256: manifest.contents.sha256,
    );
    final contents = SnapshotContents.fromJson(
      await readBackupJson(contentsFile),
    );
    if (!contents.summary.fileSizesComplete ||
        contents.files.any((file) => !file.sizeKnown) ||
        contents.snapshotId != manifest.snapshotId ||
        contents.schemaVersion != manifest.schemaVersion ||
        contents.summary.roleCount != descriptor.roleCount ||
        contents.summary.logicalDataBytes != descriptor.totalBytes) {
      throw const FormatException('备份内容目录不匹配');
    }
    return (manifest, contents);
  }

  Future<void> _restore(_Job job) async {
    final account = await _requireAccount(job.accountId);
    job.accountId = account.accountId;
    final source = job.source!;
    job.baseIds = source.legacy ? [] : [source.descriptor!.snapshotId];
    if (!source.legacy) {
      job.reservation = await transport.reserve(
        operationId: job.id,
        accountId: job.accountId!,
        kind: 'restore',
        baseSnapshotIds: job.baseIds,
      );
    }
    job.dataset = await storage.createStagingDataset();
    await _save(job);
    await _phase(job, BackupPhase.readingContents);
    // Native permits writes inside this operation-owned control directory even
    // when a damaged active pointer cannot identify the current dataset. Only
    // after every writer drains and validation succeeds do we rename it into
    // the fresh datasets directory; no media bytes are copied a second time.
    final dataset = Directory(p.join(job.directory.path, 'restore-data'));
    await dataset.create(recursive: true);
    if (source.legacy) {
      final legacy = await LegacyBackupReader(transport).read(
        operationId: job.id,
        accountId: job.accountId!,
        directory: dataset,
        downloadMedia: true,
        checkCancelled: _check,
        beforeMedia: (plan) async {
          _check();
          await _update(
            job,
            job.state.copyWith(
              contents: plan.contents,
              contentCreatedAtUtc: plan.createdAtUtc,
              resetProgress: true,
            ),
          );
          _checkSpace(
            await transport.availableCapacity(),
            plan.contents.summary.logicalDataBytes * 2,
          );
          await _update(
            job,
            job.state.copyWith(
              phase: BackupPhase.downloading,
              completedFiles: 0,
              totalFiles: plan.contents.files.length,
              resetProgress: true,
            ),
          );
        },
        beforeMediaFile: (file, remainingKnownBytes, databaseBytes) async {
          _check();
          // Known remaining bytes are a lower bound when a legacy cover has no
          // recorded size. The unknown size stays visible; native copy errors
          // (including ENOSPC) still abort safely in the operation-owned stage.
          _checkSpace(
            await transport.availableCapacity(),
            remainingKnownBytes * 2 + databaseBytes,
          );
          await _update(job, job.state.copyWith(currentItem: file.displayName));
        },
        onProgress: (done, total, path) =>
            _localProgress(job, done, total, path),
      );
      await _update(
        job,
        job.state.copyWith(
          contents: legacy.contents,
          contentCreatedAtUtc: legacy.createdAtUtc,
          phase: BackupPhase.validating,
          resetProgress: true,
        ),
      );
      await SnapshotValidator().migrateDatabase(
        File(p.join(dataset.path, AppDatabase.sqliteFileName)),
      );
      await inspectBackupDatabase(
        File(p.join(dataset.path, AppDatabase.sqliteFileName)),
      );
      job.limitedIntegrity = true;
    } else {
      final descriptor = source.descriptor!;
      final metadata = await _readMetadata(
        job.id,
        job.accountId!,
        descriptor,
        job.directory,
      );
      final manifest = metadata.$1;
      job.manifest = manifest;
      job.descriptor = descriptor;
      _checkSpace(account.availableBytes, descriptor.totalBytes * 2);
      await _update(
        job,
        job.state.copyWith(
          contents: metadata.$2,
          descriptor: descriptor,
          contentCreatedAtUtc: descriptor.createdAtUtc,
          phase: BackupPhase.downloading,
          totalFiles: manifest.files.length,
          completedFiles: 0,
          resetProgress: true,
        ),
      );
      final database = File(p.join(dataset.path, AppDatabase.sqliteFileName));
      _check();
      await transport.download(
        operationId: job.id,
        accountId: job.accountId!,
        relativePath: '${manifest.basePath}/database.sqlite',
        localPath: database.path,
        bytes: manifest.database.bytes,
        sha256: manifest.database.sha256,
      );
      var done = 0;
      for (final file in manifest.files) {
        _check();
        await _renew(job, 'restore');
        await _update(
          job,
          job.state.copyWith(currentItem: _friendly(job, file.relativePath)),
        );
        final target = File(p.join(dataset.path, file.relativePath));
        await target.parent.create(recursive: true);
        await transport.download(
          operationId: job.id,
          accountId: job.accountId!,
          relativePath: file.objectPath(manifest.writerId),
          localPath: target.path,
          bytes: file.bytes,
          sha256: file.sha256,
        );
        if (await target.length() != file.bytes) {
          throw const BackupFailure('integrity', '恢复文件长度不完整');
        }
        await _fingerprints.remember(
          target,
          FileFingerprint(sha256: file.sha256, bytes: file.bytes),
        );
        await _update(
          job,
          job.state.copyWith(
            completedFiles: ++done,
            currentItem: _friendly(job, file.relativePath),
          ),
        );
      }
      _check();
      await _phase(job, BackupPhase.validating);
      await SnapshotValidator().validateAndMigrate(
        dataset: dataset,
        manifest: manifest,
        contents: metadata.$2,
        verifyMedia: false,
      ); // Native copy verified the actual streamed bytes.
    }
    _check();
    final target = job.dataset!;
    if (await target.list().isEmpty) {
      await target.delete();
    } else {
      throw const BackupFailure('staging_conflict', '恢复准备区意外出现其他资料，已停止切换');
    }
    await dataset.rename(target.path);
    if (job.manifest != null) {
      for (final file in job.manifest!.files) {
        await _fingerprints.remember(
          File(p.join(target.path, file.relativePath)),
          FileFingerprint(sha256: file.sha256, bytes: file.bytes),
        );
      }
    }
    job.validated = true;
    await _review(job);
  }

  Future<void> _review(_Job job) async {
    await storage.exclusively(() async {
      SnapshotContents? current;
      if (!storage.isRecoveryOnly) {
        try {
          current = await currentContents();
        } catch (_) {
          // Incoming was strictly verified. Unknown current counts are shown
          // explicitly; preserve the entire old dataset on activation.
        }
      }
      final incoming = job.state.contents!;
      final preview = RestorePreview(
        incoming: incoming,
        current: current,
        datasetEpoch: storage.epoch,
        mutationRevision: storage.mutationRevision,
        additionalBytes: incoming.summary.logicalDataBytes,
        limitedIntegrity: job.limitedIntegrity,
        currentUnreadable: current == null,
      );
      await _update(
        job,
        job.state.copyWith(
          phase: BackupPhase.readyForReview,
          restorePreview: preview,
          resetProgress: true,
          clearError: true,
        ),
      );
    });
  }

  Future<void> confirmRestore(String operationId) async {
    if (_controlBusy || _cancelRequested) {
      throw const BackupFailure('not_ready', '该恢复正在取消，请等待');
    }
    await _awaitVisibleBoundary(review: true);
    final job = _requireJob(operationId);
    if (_busy ||
        _controlBusy ||
        _cancelRequested ||
        !job.state.requiresConfirmation ||
        !job.validated ||
        job.dataset == null) {
      throw const BackupFailure('not_ready', '请先完成下载与资料检查');
    }
    _busy = true;
    final settlement = _settlement = Completer<void>();
    try {
      await storage.exclusively(() async {
        final preview = job.state.restorePreview!;
        if (preview.datasetEpoch != storage.epoch ||
            preview.mutationRevision != storage.mutationRevision) {
          await _review(job);
          throw const BackupFailure(
            'review_changed',
            '本机资料刚刚发生变化，请查看更新后的范围再确认',
          );
        }
        await _phase(job, BackupPhase.activating);
        await storage.activate(
          job.dataset!,
          closeDatabase: closeDatabase,
          reopenDatabase: reopenDatabase,
        );
        await _update(
          job,
          job.state.copyWith(
            phase: BackupPhase.completed,
            completedAtUtc: DateTime.now().toUtc(),
            cleanupPending: storage.cleanupPending,
            resetProgress: true,
          ),
        );
      });
      try {
        await _release(job);
      } catch (_) {
        await _update(job, job.state.copyWith(cleanupPending: true));
      }
    } catch (error) {
      if (error is BackupFailure && error.code == 'review_changed') rethrow;
      await _update(
        job,
        job.state.copyWith(
          phase: BackupPhase.failed,
          error: _failure(error),
          failedAtPhase: BackupPhase.activating,
        ),
      );
      rethrow;
    } finally {
      _busy = false;
      settlement.complete();
    }
  }

  Future<void> _renew(_Job job, String kind, {bool force = false}) async {
    if (job.reservation == null) return;
    if (force ||
        job.reservation!.expiresAtUtc
                .difference(DateTime.now().toUtc())
                .inMinutes <
            30) {
      job.reservation = await transport.reserve(
        operationId: job.id,
        accountId: job.accountId!,
        kind: kind,
        baseSnapshotIds: job.baseIds,
      );
      await _save(job);
    }
  }

  Future<void> _release(_Job job) async {
    if (job.reservation != null && job.accountId != null) {
      await transport.release(
        operationId: job.id,
        accountId: job.accountId!,
        reservationId: job.reservation!.reservationId,
      );
      job.reservation = null;
      if (identical(job, _job)) await _save(job);
    }
  }

  _Job _requireJob(String id) {
    final job = _job;
    if (job == null || job.id != id) {
      throw const BackupFailure('stale_job', '该任务已结束，请返回当前任务');
    }
    return job;
  }

  Future<void> cancel(String operationId) async {
    if (_controlBusy) throw const BackupFailure('cannot_cancel', '取消操作正在处理中');
    await _awaitVisibleBoundary(review: true);
    final job = _requireJob(operationId);
    if (!job.state.canCancel ||
        _controlBusy ||
        (_busy && job.state.requiresConfirmation)) {
      throw const BackupFailure('cannot_cancel', '当前阶段正在确认结果，请等待');
    }
    _controlBusy = true;
    final settlement = _settlement = Completer<void>();
    _cancelRequested = true;
    try {
      await transport.cancel(operationId);
      await _running;
      if (job.state.kind == BackupJobKind.backup) {
        await _abandonBackup(job);
      } else {
        await _release(job);
      }
      if (job.state.phase != BackupPhase.completed) {
        await _update(
          job,
          job.state.copyWith(
            phase: BackupPhase.cancelled,
            error: const BackupFailure('cancelled', '任务已取消'),
            resetProgress: true,
          ),
        );
      }
      await _discardStaging(job);
    } finally {
      _controlBusy = false;
      settlement.complete();
    }
  }

  Future<void> _discardStaging(_Job job) async {
    final working = Directory(p.join(job.directory.path, 'restore-data'));
    if (await working.exists()) await working.delete(recursive: true);
    final dataset = job.dataset;
    if (dataset == null ||
        dataset.path == storage.activeDirectory.path ||
        dataset.path == storage.rollbackDirectory?.path) {
      return;
    }
    final datasets = p.join(storage.supportDirectory.path, 'datasets');
    if (p.dirname(dataset.path) != datasets ||
        !RegExp(r'^[a-f0-9]{32}$').hasMatch(p.basename(dataset.path))) {
      throw const BackupFailure('unsafe_cleanup', '准备区路径不明确，已保留文件');
    }
    if (await dataset.exists()) await dataset.delete(recursive: true);
    job.dataset = null;
    job.validated = false;
  }

  Future<void> _reclaimAbandonedStage(_Job? previous, _Job current) async {
    await _resumePendingAbandons(current);
    if (previous == null || !previous.state.isTerminal) return;
    if (previous.state.kind == BackupJobKind.backup &&
        previous.state.phase != BackupPhase.completed &&
        !(previous.abandoned && !previous.state.cleanupPending)) {
      try {
        await transport.cancel(previous.id);
        await _abandonBackup(previous);
        if (previous.state.cleanupPending) {
          await _update(current, current.state.copyWith(cleanupPending: true));
        }
      } catch (_) {
        await _update(current, current.state.copyWith(cleanupPending: true));
      }
      return;
    }
    if (previous.dataset == null ||
        previous.state.kind != BackupJobKind.restore ||
        previous.dataset!.path == storage.activeDirectory.path ||
        previous.dataset!.path == storage.rollbackDirectory?.path) {
      return;
    }
    try {
      await transport.cancel(previous.id);
      await _discardStaging(previous);
      await _release(previous);
    } catch (_) {
      await _update(current, current.state.copyWith(cleanupPending: true));
    }
  }

  Directory get _pendingAbandons =>
      Directory(p.join(_jobs.path, 'pending-abandons'));
  Future<void> _abandonBackup(_Job job) async {
    if (job.accountId == null || job.state.phase == BackupPhase.completed) {
      return;
    }
    job.abandonRequested = true;
    job.cleanupOperationId ??= newBackupId();
    await _save(job);
    await _pendingAbandons.create(recursive: true);
    final marker = File(p.join(_pendingAbandons.path, '${job.id}.json'));
    final pendingMarker = File('${marker.path}.next');
    await pendingMarker.writeAsString(
      jsonEncode({'operationId': job.id, 'accountId': job.accountId}),
      flush: true,
    );
    await pendingMarker.rename(marker.path);
    try {
      final result = await transport.abandonUpload(
        operationId: job.cleanupOperationId!,
        accountId: job.accountId!,
        abandonedOperationId: job.id,
      );
      final published = result.published;
      if (published != null) {
        if (job.descriptor != null &&
            (published.snapshotId != job.descriptor!.snapshotId ||
                published.commitSha256 != job.descriptor!.commitSha256)) {
          throw const BackupFailure(
            'catalog_mismatch',
            '取消操作发现不同的发布回执，已保留云端资料',
          );
        }
        job.descriptor = published;
        job.state = job.state.copyWith(
          phase: BackupPhase.completed,
          descriptor: published,
          completedAtUtc: published.completedAtUtc,
          clearError: true,
          cleanupPending: result.cleanupPending,
        );
      } else if (result.aborted) {
        job.abandoned = true;
        job.reservation = null;
        job.state = job.state.copyWith(
          phase: BackupPhase.cancelled,
          error: const BackupFailure(
            'abandoned',
            '此前上传已取消；重新备份会创建新的快照',
            retryable: false,
          ),
          cleanupPending: result.cleanupPending,
        );
      } else {
        throw const BackupFailure('cleanup_pending', '尚未确认此前上传是否完成，云端文件已保留');
      }
      if (!result.cleanupPending && await marker.exists()) {
        await marker.delete();
      }
    } catch (_) {
      job.state = job.state.copyWith(cleanupPending: true);
    }
    await _save(job);
    if (identical(job, _job)) _states.add(job.state);
  }

  Future<void> _resumePendingAbandons(_Job current) async {
    if (!await _pendingAbandons.exists()) return;
    BackupAvailability? account;
    try {
      account = await availability();
    } catch (_) {
      return;
    }
    if (!account.available || account.accountId == null) return;
    await for (final entry in _pendingAbandons.list(followLinks: false)) {
      if (entry is! File ||
          !RegExp(r'^[a-f0-9-]{36}\.json$').hasMatch(p.basename(entry.path))) {
        continue;
      }
      try {
        final marker = await readBackupJson(entry);
        if (marker['accountId'] != account.accountId) continue;
        final id = BackupJson.uuid(marker['operationId']);
        final pending = await _loadJob(id);
        if (!pending.abandonRequested ||
            pending.accountId != account.accountId) {
          continue;
        }
        await transport.cancel(id);
        await _abandonBackup(pending);
        if (pending.state.cleanupPending) {
          await _update(current, current.state.copyWith(cleanupPending: true));
        }
      } catch (_) {
        await _update(current, current.state.copyWith(cleanupPending: true));
      }
    }
  }

  Future<void> retry(String operationId) async {
    await _awaitVisibleBoundary();
    final job = _requireJob(operationId);
    if (_busy || _controlBusy || !job.state.canRetry) {
      throw const BackupFailure('busy', '当前任务无法重试');
    }
    _busy = true;
    final settlement = _settlement = Completer<void>();
    _cancelRequested = false;
    if (job.state.kind == BackupJobKind.backup &&
        !job.abandonRequested &&
        job.allStaged &&
        job.manifest != null &&
        job.descriptor != null) {
      _launch(job, () => _finishBackup(job));
      return;
    }
    // Before immutable staging completed, lost pins cannot be reconstructed.
    // Drain the old operation, then create a fresh snapshot with a fresh ID.
    try {
      await transport.cancel(job.id);
      await _discardStaging(job);
      if (job.state.kind == BackupJobKind.backup) {
        await _abandonBackup(job);
      } else {
        await _release(job);
      }
    } finally {
      _busy = false;
      settlement.complete();
    }
    if (job.state.kind == BackupJobKind.restore) {
      await prepareRestore(job.source!);
    } else if (job.state.kind == BackupJobKind.backup) {
      await startBackup();
    } else if (job.state.kind == BackupJobKind.cleanup) {
      await retryCleanup();
    }
  }

  Future<void> retryCleanup() async {
    await _awaitVisibleBoundary();
    final previous = _job;
    final job = _begin(BackupJobKind.cleanup);
    _launch(job, () async {
      await _reclaimAbandonedStage(previous, job);
      await storage.cleanupRetiredData();
      final account = await _requireAccount();
      job.accountId = account.accountId;
      await _cleanup(job);
      if (job.state.cleanupPending || storage.cleanupPending) {
        throw const BackupFailure(
          'cleanup_pending',
          '部分文件仍受其他任务保护，或尚待云端确认，请稍后重试',
        );
      }
      await _update(
        job,
        job.state.copyWith(
          phase: BackupPhase.completed,
          completedAtUtc: DateTime.now().toUtc(),
        ),
      );
    });
    await _running;
    if (job.state.phase == BackupPhase.failed) throw job.state.error!;
  }

  Future<void> recoverOnStartup() async {
    try {
      await _recoverJournal();
    } catch (_) {
      // Storage recovery is independent and ran before this coordinator. An
      // unreadable auxiliary job record must not block valid cloud recovery or
      // cause unknown stage/remote paths to be cleaned.
      _recoveryNotice = const BackupFailure(
        'job_journal_unreadable',
        '上次任务记录暂时无法读取。原有资料和准备区已保留，可以重新备份或选择云端记录恢复。',
      );
    }
  }

  Future<void> _recoverJournal() async {
    final pointer = File(p.join(_jobs.path, 'latest.json'));
    if (!await pointer.exists()) return;
    final id = BackupJson.uuid((await readBackupJson(pointer))['operationId']);
    final job = await _loadJob(id);
    _job = job;
    if (job.state.phase == BackupPhase.activating &&
        !storage.isRecoveryOnly &&
        job.dataset?.path == storage.activeDirectory.path) {
      await _update(
        job,
        job.state.copyWith(
          phase: BackupPhase.completed,
          clearError: true,
          cleanupPending: storage.cleanupPending,
        ),
      );
      return;
    }
    if (!job.state.isTerminal) {
      // Never auto-activate a saved review. A restart requires freshly checked
      // files and local scope; allStaged backups can resume immutable cloud work.
      await _update(
        job,
        job.state.copyWith(
          phase: BackupPhase.interrupted,
          failedAtPhase: job.state.phase,
          error: const BackupFailure('interrupted', '上次任务被中断，请重试；恢复需要重新检查和确认'),
          resetProgress: true,
        ),
      );
    }
  }

  Future<_Job> _loadJob(String id) async {
    final directory = Directory(p.join(_jobs.path, id));
    final journal = await readBackupJson(
      File(p.join(directory.path, 'job.json')),
    );
    if (journal['hasContents'] == true) {
      journal['contents'] = await readBackupJson(
        File(p.join(directory.path, 'scope.json')),
      );
    }
    if (journal['hasManifest'] == true) {
      journal['manifest'] = await readBackupJson(
        File(p.join(directory.path, 'manifest.json')),
      );
    }
    return _Job.fromJson(journal, directory, storage);
  }

  Future<void> _cleanup(_Job job) async {
    var catalog = await transport.catalog(job.accountId!);
    for (final claim in catalog.pendingCleanupClaims) {
      await transport.deleteAuthorized(
        operationId: job.id,
        accountId: job.accountId!,
        claimId: claim,
      );
    }
    if (catalog.pendingCleanupClaims.isNotEmpty) {
      catalog = await transport.catalog(job.accountId!);
    }
    if (catalog.retired.isEmpty) return;
    // Active reservations suppress this opportunistic pass. Native CAS checks
    // again, including new reservations that arrived after this read.
    if (catalog.reservations.isNotEmpty) {
      await _update(job, job.state.copyWith(cleanupPending: true));
      return;
    }
    final activePaths = <String>{};
    for (final descriptor in catalog.snapshots) {
      final directory = Directory(
        p.join(job.directory.path, 'gc-${descriptor.snapshotId}'),
      );
      await directory.create(recursive: true);
      final metadata = await _readMetadata(
        job.id,
        job.accountId!,
        descriptor,
        directory,
      );
      activePaths.addAll(
        metadata.$1.files.map((f) => f.objectPath(metadata.$1.writerId)),
      );
    }
    for (final descriptor in catalog.retired) {
      final directory = Directory(
        p.join(job.directory.path, 'gc-${descriptor.snapshotId}'),
      );
      await directory.create(recursive: true);
      final metadata = await _readMetadata(
        job.id,
        job.accountId!,
        descriptor,
        directory,
      );
      final dead = metadata.$1.files
          .map((f) => f.objectPath(metadata.$1.writerId))
          .toSet()
          .difference(activePaths)
          .toList();
      // Media first. Native remembers deletion tombstones; metadata is removed
      // only after every unshared object has been authorized and deleted.
      for (var offset = 0; offset < dead.length; offset += 256) {
        await _deleteBatch(job, dead.skip(offset).take(256).toList());
      }
      await _deleteBatch(
        job,
        [
          'database.sqlite',
          'contents.json',
          'manifest.json',
          'commit.json',
        ].map((name) => '${descriptor.basePath}/$name').toList(),
      );
    }
  }

  Future<void> _deleteBatch(_Job job, List<String> paths) async {
    await _requireAccount(job.accountId);
    final fresh = await transport.catalog(job.accountId!);
    final claim = await transport.claimCleanup(
      operationId: job.id,
      accountId: job.accountId!,
      revision: fresh.revision,
      relativePaths: paths,
    );
    await transport.deleteAuthorized(
      operationId: job.id,
      accountId: job.accountId!,
      claimId: claim,
    );
  }

  void _checkSpace(int? available, int extra) {
    final margin = extra ~/ 10 > 256 * 1024 * 1024
        ? extra ~/ 10
        : 256 * 1024 * 1024;
    if (available != null && available < extra + margin) {
      throw const BackupFailure(
        'insufficient_space',
        '本机剩余空间不足，请释放空间后重试；恢复成功前会保留原资料',
      );
    }
  }

  String? _friendly(_Job job, String? path) {
    if (path == null) return null;
    for (final file in job.state.contents?.files ?? <SnapshotContentFile>[]) {
      if (file.relativePath == path || path.endsWith('/${file.objectId}')) {
        return file.displayName;
      }
    }
    if (path.endsWith('database.sqlite') || path.endsWith('ochome.sqlite')) {
      return '角色资料与设定历史';
    }
    if (path.endsWith('contents.json')) return '资料目录';
    if (path.endsWith('manifest.json') || path.endsWith('commit.json')) {
      return '备份完成记录';
    }
    return null;
  }

  void _localProgress(_Job job, int done, int total, String? path) {
    final now = DateTime.now();
    if (done != total && now.difference(_lastProgress).inMilliseconds < 350) {
      return;
    }
    _lastProgress = now;
    unawaited(
      _update(
        job,
        job.state.copyWith(
          completedFiles: done,
          totalFiles: total,
          currentItem: _friendly(job, path),
        ),
      ).catchError((Object _) {}),
    );
  }

  void _onNativeEvent(BackupTransferEvent event) {
    final job = _job;
    if (job == null ||
        job.state.isTerminal ||
        job.state.requiresConfirmation ||
        event.operationId != job.id ||
        event.sequence <= _nativeSequence ||
        _cancelRequested) {
      return;
    }
    _nativeSequence = event.sequence;
    final now = DateTime.now();
    final changedItemOrPhase =
        event.relativePath != _nativeProgressPath ||
        event.phase != _nativeProgressPhase;
    if (!changedItemOrPhase &&
        now.difference(_lastProgress).inMilliseconds < 350) {
      return;
    }
    _lastProgress = now;
    _nativeProgressPath = event.relativePath;
    _nativeProgressPhase = event.phase;
    // Native byte counters describe this native phase/file, never overall job.
    unawaited(
      _update(
        job,
        job.state.copyWith(
          completedBytes: event.completedBytes,
          totalBytes: event.totalBytes,
          completedFiles: event.completedFiles ?? job.state.completedFiles,
          totalFiles: event.totalFiles ?? job.state.totalFiles,
          currentItem: _friendly(job, event.relativePath),
          resetProgress: true,
        ),
      ).catchError((Object _) {}),
    );
  }

  Future<void> dispose() async {
    await _settlement?.future;
    await _running;
    await _writes.catchError((Object _) {});
    await _subscription?.cancel();
    await _fingerprints.close();
    await _states.close();
  }
}

class _Job {
  _Job({required this.state, required this.directory, this.source});
  BackupJobState state;
  final Directory directory;
  BackupSource? source;
  String? accountId;
  String? cleanupOperationId;
  bool abandonRequested = false, abandoned = false;
  List<String> baseIds = [];
  BackupReservation? reservation;
  BackupDescriptor? descriptor;
  SnapshotManifest? manifest;
  SnapshotContents? persistedContents;
  Directory? dataset;
  bool allStaged = false,
      validated = false,
      limitedIntegrity = false,
      publishAttempted = false;
  String get id => state.operationId;
  Map<String, Object?> toJson() => {
    'format': 1,
    'operationId': id,
    'kind': state.kind.name,
    'phase': state.phase.name,
    'startedAtUtc': state.startedAtUtc.toIso8601String(),
    'contentCreatedAtUtc': state.contentCreatedAtUtc?.toIso8601String(),
    'completedAtUtc': state.completedAtUtc?.toIso8601String(),
    'accountId': accountId,
    'cleanupOperationId': cleanupOperationId,
    'abandonRequested': abandonRequested,
    'abandoned': abandoned,
    'baseIds': baseIds,
    'reservation': reservation == null
        ? null
        : {
            'reservationId': reservation!.reservationId,
            'expiresAtUtc': reservation!.expiresAtUtc.toIso8601String(),
          },
    'descriptor': descriptor?.toJson(),
    'hasManifest': manifest != null,
    'hasContents': state.contents != null,
    'source': source == null
        ? null
        : {
            'legacy': source!.legacy,
            'descriptor': source!.descriptor?.toJson(),
          },
    'datasetId': dataset == null ? null : p.basename(dataset!.path),
    'allStaged': allStaged,
    'validated': validated,
    'limitedIntegrity': limitedIntegrity,
    'publishAttempted': publishAttempted,
    'reusedFiles': state.reusedFiles,
    'reusedBytes': state.reusedBytes,
    'uploadBytes': state.uploadBytes,
    'cleanupPending': state.cleanupPending,
    'completedBytes': state.completedBytes,
    'totalBytes': state.totalBytes,
    'completedFiles': state.completedFiles,
    'totalFiles': state.totalFiles,
    'failedAtPhase': state.failedAtPhase?.name,
    'currentItem': state.currentItem,
    'error': state.error == null
        ? null
        : {
            'code': state.error!.code,
            'message': state.error!.message,
            'retryable': state.error!.retryable,
          },
  };
  factory _Job.fromJson(
    Map<String, Object?> j,
    Directory directory,
    DataStorage storage,
  ) {
    BackupJson.format(j, 1);
    final descriptor = j['descriptor'] == null
        ? null
        : BackupDescriptor.fromJson(j['descriptor']);
    final contents = j['contents'] == null
        ? null
        : SnapshotContents.fromJson(j['contents']);
    final error = j['error'] == null ? null : BackupJson.object(j['error']);
    DateTime? time(String key) =>
        j[key] == null ? null : BackupJson.time(j[key]);
    int? count(String key) =>
        j[key] == null ? null : BackupJson.integer(j[key]);
    final job = _Job(
      directory: directory,
      state: BackupJobState(
        operationId: BackupJson.uuid(j['operationId']),
        kind: BackupJobKind.values.byName(BackupJson.string(j['kind'])),
        phase: BackupPhase.values.byName(BackupJson.string(j['phase'])),
        startedAtUtc: BackupJson.time(j['startedAtUtc']),
        contentCreatedAtUtc: time('contentCreatedAtUtc'),
        completedAtUtc: time('completedAtUtc'),
        reusedFiles: BackupJson.integer(j['reusedFiles']),
        reusedBytes: BackupJson.integer(j['reusedBytes']),
        uploadBytes: count('uploadBytes'),
        completedBytes: count('completedBytes'),
        totalBytes: count('totalBytes'),
        completedFiles: count('completedFiles'),
        totalFiles: count('totalFiles'),
        contents: contents,
        currentItem: j['currentItem'] == null
            ? null
            : BackupJson.string(j['currentItem']),
        descriptor: descriptor,
        cleanupPending: BackupJson.boolean(j['cleanupPending']),
        failedAtPhase: j['failedAtPhase'] == null
            ? null
            : BackupPhase.values.byName(BackupJson.string(j['failedAtPhase'])),
        error: error == null
            ? null
            : BackupFailure(
                BackupJson.string(error['code']),
                BackupJson.string(error['message']),
                retryable: BackupJson.boolean(error['retryable']),
              ),
      ),
    );
    job.accountId = j['accountId'] == null
        ? null
        : BackupJson.string(j['accountId']);
    job.cleanupOperationId = j['cleanupOperationId'] == null
        ? null
        : BackupJson.uuid(j['cleanupOperationId']);
    job.abandonRequested = j['abandonRequested'] == null
        ? false
        : BackupJson.boolean(j['abandonRequested']);
    job.abandoned = j['abandoned'] == null
        ? false
        : BackupJson.boolean(j['abandoned']);
    job.baseIds = BackupJson.list(j['baseIds']).map(BackupJson.uuid).toList();
    job.reservation = j['reservation'] == null
        ? null
        : BackupReservation.fromJson(j['reservation']);
    job.descriptor = descriptor;
    job.persistedContents = contents;
    job.manifest = j['manifest'] == null
        ? null
        : SnapshotManifest.fromJson(j['manifest']);
    if (j['source'] != null) {
      final source = BackupJson.object(j['source']);
      job.source = BackupJson.boolean(source['legacy'])
          ? const BackupSource.legacy()
          : BackupSource.snapshot(
              BackupDescriptor.fromJson(source['descriptor']),
            );
    }
    if (j['datasetId'] != null) {
      final datasetId = BackupJson.string(j['datasetId']);
      if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(datasetId)) {
        throw const FormatException('恢复准备区标识不正确');
      }
      job.dataset = Directory(
        p.join(storage.supportDirectory.path, 'datasets', datasetId),
      );
    }
    job.allStaged = BackupJson.boolean(j['allStaged']);
    job.validated = BackupJson.boolean(j['validated']);
    job.limitedIntegrity = BackupJson.boolean(j['limitedIntegrity']);
    job.publishAttempted = BackupJson.boolean(j['publishAttempted']);
    return job;
  }
}
