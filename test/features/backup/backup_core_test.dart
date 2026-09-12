import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/data/database/app_database.dart';
import 'package:ochome/data/repositories/drift_role_asset_repository.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'package:ochome/data/services/data_storage.dart';
import 'package:ochome/features/backup/backup_coordinator.dart';
import 'package:ochome/features/backup/backup_models.dart';
import 'package:ochome/features/backup/backup_protocol.dart';
import 'package:ochome/features/backup/snapshot_store.dart';

import '../../fakes/backup_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late DataStorage storage;
  late FakeBackupTransport cloud;
  late BackupCoordinator coordinator;
  var reopenCalls = 0;

  Future<void> createCoordinator() async {
    coordinator = BackupCoordinator(
      storage: storage,
      transport: cloud,
      closeDatabase: () async {},
      reopenDatabase: () async {
        reopenCalls++;
      },
    );
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('backup-core-');
    createFixture(root);
    storage = await DataStorage.open(root);
    cloud = FakeBackupTransport();
    reopenCalls = 0;
    await createCoordinator();
  });
  tearDown(() async {
    if (cloud.uploadBarrier != null && !cloud.uploadBarrier!.isCompleted) {
      cloud.uploadBarrier!.complete();
    }
    if (cloud.cancelBarrier != null && !cloud.cancelBarrier!.isCompleted) {
      cloud.cancelBarrier!.complete();
    }
    if (cloud.releaseBarrier != null && !cloud.releaseBarrier!.isCompleted) {
      cloud.releaseBarrier!.complete();
    }
    await coordinator.dispose();
    await storage.close();
    await cloud.controller.close();
    await root.delete(recursive: true);
  });

  Future<BackupJobState> backup() async {
    await coordinator.startBackup();
    return waitForJob(coordinator, (j) => j.isTerminal);
  }

  Future<int> seedLegacyForSpace({
    bool manifest = true,
    int assetBytes = 1024,
  }) async {
    final fixture = File(p.join(root.path, 'legacy-space.sqlite'));
    await File(p.join(root.path, 'ochome.sqlite')).copy(fixture.path);
    final database = sqlite3.open(fixture.path);
    database.execute('UPDATE role_asset SET bytes = ?', [assetBytes]);
    database.close();
    cloud.legacy['ochome.sqlite'] = await fixture.readAsBytes();
    cloud.legacy['covers/cover.png'] = [1, 2, 3, 4];
    cloud.legacy['role_assets/empty.txt'] = List.filled(assetBytes, 1);
    if (manifest) {
      cloud.legacy['manifest.json'] = utf8.encode(
        jsonEncode({
          'format': 2,
          'schemaVersion': 8,
          'appVersion': '1.0',
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'covers': [
            {'file': 'cover.png', 'bytes': 4},
          ],
          'assets': [
            {'file': 'empty.txt', 'bytes': assetBytes},
          ],
        }),
      );
    }
    return await fixture.length() + assetBytes + (manifest ? 4 : 0);
  }

  for (final transfer in ['stage', 'download']) {
    test(
      '$transfer byte-only events retain truthful original file counters',
      () async {
        final observed = <BackupJobState>[];
        final subscription = coordinator.watchJob().listen(observed.add);
        cloud.emitStageByteEvents = transfer == 'stage';
        final descriptor = (await backup()).descriptor!;
        if (transfer == 'download') {
          cloud.emitDownloadByteEvents = true;
          await coordinator.prepareRestore(BackupSource.snapshot(descriptor));
          await waitForJob(
            coordinator,
            (job) => job.requiresConfirmation || job.isTerminal,
          );
        }
        await subscription.cancel();
        final phase = transfer == 'stage'
            ? BackupPhase.staging
            : BackupPhase.downloading;
        final samples = observed.where(
          (job) =>
              job.phase == phase &&
              job.currentItem == '空白笔记.txt' &&
              job.completedBytes != null,
        );
        expect(samples, isNotEmpty);
        expect(samples.every((job) => job.totalFiles == 2), isTrue);
        expect(samples.any((job) => job.completedFiles == 1), isTrue);
      },
    );
  }

  test('legacy minimum space is checked before any media transfer', () async {
    final minimum = await seedLegacyForSpace();
    cloud.localAvailableBytes = 256 * 1024 * 1024 + minimum * 2 - 1;
    final originalRoot = storage.activeDirectory.path;
    await coordinator.prepareRestore(const BackupSource.legacy());
    final failed = await waitForJob(coordinator, (job) => job.isTerminal);
    expect(failed.error!.code, 'insufficient_space');
    expect(failed.contents!.summary.logicalDataBytes, minimum);
    expect(cloud.capacityChecks, 1);
    expect(cloud.downloaded, ['manifest.json', 'ochome.sqlite']);
    expect(storage.activeDirectory.path, originalRoot);
    expect(reopenCalls, 0);
  });

  test(
    'legacy capacity is rechecked before each subsequent media file',
    () async {
      await seedLegacyForSpace();
      cloud.capacityResults.addAll([
        100000000000,
        100000000000,
        128 * 1024 * 1024,
      ]);
      await coordinator.prepareRestore(const BackupSource.legacy());
      final failed = await waitForJob(coordinator, (job) => job.isTerminal);
      expect(failed.error!.code, 'insufficient_space');
      expect(cloud.downloaded, contains('covers/cover.png'));
      expect(cloud.downloaded, isNot(contains('role_assets/empty.txt')));
      expect(cloud.capacityChecks, 3);
      expect(readName(storage.activeDirectory), '白鸦');
      expect(reopenCalls, 0);
    },
  );

  test(
    'unknown legacy cover size stays explicit and ENOSPC cannot activate data',
    () async {
      await seedLegacyForSpace(manifest: false, assetBytes: 0);
      cloud.capacityResults.addAll([null, null]);
      cloud.failDownloadRelativePath = 'covers/cover.png';
      await coordinator.prepareRestore(const BackupSource.legacy());
      final failed = await waitForJob(coordinator, (job) => job.isTerminal);
      expect(failed.error!.code, 'local_space');
      expect(failed.contents!.summary.knownLogicalDataBytes, isNull);
      expect(
        failed.contents!.files
            .singleWhere((file) => file.kind == 'cover')
            .knownBytes,
        isNull,
      );
      expect(readName(storage.activeDirectory), '白鸦');
      expect(reopenCalls, 0);
    },
  );

  test(
    'pending upload never completes or changes the account catalog',
    () async {
      cloud.uploadBarrier = Completer<void>();
      await coordinator.startBackup();
      final waiting = await waitForJob(
        coordinator,
        (j) => j.phase == BackupPhase.waitingForCloud,
      );
      expect(waiting.completedAtUtc, isNull);
      expect(cloud.active, isEmpty);
      expect(
        cloud.files.keys.any((name) => name.endsWith('/commit.json')),
        isFalse,
      );
      cloud.uploadBarrier!.complete();
      cloud.uploadBarrier = null;
      final done = await waitForJob(
        coordinator,
        (j) => j.phase == BackupPhase.completed,
      );
      expect(done.descriptor!.accountSequence, 1);
      expect(done.completedAtUtc, isNotNull);
    },
  );

  test(
    'the next action queues behind a visible completion until release finishes',
    () async {
      cloud.releaseBarrier = Completer<void>();
      await coordinator.startBackup();
      final completed = await waitForJob(
        coordinator,
        (job) => job.phase == BackupPhase.completed,
      );
      final next = coordinator.prepareRestore(
        BackupSource.snapshot(completed.descriptor!),
      );
      expect(coordinator.currentJob!.operationId, completed.operationId);
      cloud.releaseBarrier!.complete();
      cloud.releaseBarrier = null;
      await next;
      final ready = await waitForJob(
        coordinator,
        (job) => job.requiresConfirmation || job.isTerminal,
      );
      expect(ready.requiresConfirmation, isTrue, reason: ready.error?.message);
    },
  );

  test(
    'failed next backup preserves every previously published byte',
    () async {
      expect((await backup()).phase, BackupPhase.completed);
      final first = cloud.active.single;
      final saved = Map<String, List<int>>.from(cloud.files);
      updateName(storage.activeDirectory, '新角色名称');
      cloud.failStageSuffix = '/database.sqlite';
      final failed = await backup();
      expect(failed.phase, BackupPhase.failed);
      expect(failed.failedAtPhase, BackupPhase.staging);
      expect(cloud.active.single.snapshotId, first.snapshotId);
      for (final entry in saved.entries) {
        expect(cloud.files[entry.key], entry.value);
      }
    },
  );

  test(
    'recreated coordinator reuses media and immutable historical names',
    () async {
      final first = await backup();
      final old = first.descriptor!;
      final uploadedMedia = cloud.staged
          .where((path) => path.contains('/objects/'))
          .length;
      await coordinator.dispose();
      await createCoordinator();
      updateName(storage.activeDirectory, '改名以后的白鸦');
      final second = await backup();
      expect(second.phase, BackupPhase.completed);
      expect(second.reusedFiles, 2);
      expect(
        cloud.staged.where((path) => path.contains('/objects/')).length,
        uploadedMedia,
      );
      final beforeDownloads = cloud.downloaded.length;
      final historical = await coordinator.contentsFor(
        BackupSource.snapshot(old),
      );
      expect(historical.roles.single.name, '白鸦');
      expect(historical.roles.single.customAttributeNamesInOrder, ['能力', '能力']);
      expect(
        cloud.downloaded
            .skip(beforeDownloads)
            .any((path) => path.contains('/objects/')),
        isFalse,
      );
    },
  );

  test('account list retains three publications and cleans retired media only after publish', () async {
    for (var n = 0; n < 4; n++) {
      updateName(storage.activeDirectory, '白鸦 $n');
      expect((await backup()).phase, BackupPhase.completed);
    }
    expect(cloud.active.map((s) => s.accountSequence), [4, 3, 2]);
    expect(cloud.active.length, 3);
    expect(cloud.deleted.where((path) => path.contains('/objects/')), isEmpty);
  });

  test(
    'restore verifies an empty document and waits for explicit confirmation',
    () async {
      final original = (await backup()).descriptor!;
      updateName(storage.activeDirectory, '本机后来修改');
      final oldRoot = storage.activeDirectory.path;
      await coordinator.prepareRestore(BackupSource.snapshot(original));
      final ready = await waitForJob(
        coordinator,
        (j) => j.requiresConfirmation || j.isTerminal,
      );
      expect(ready.error, isNull, reason: ready.error?.message);
      expect(ready.requiresConfirmation, isTrue);
      expect(storage.activeDirectory.path, oldRoot);
      expect(reopenCalls, 0);
      expect(ready.restorePreview!.current!.roles.single.name, '本机后来修改');
      expect(
        ready.restorePreview!.incoming.files
            .singleWhere((f) => f.kind == 'document')
            .bytes,
        0,
      );
      await coordinator.confirmRestore(ready.operationId);
      expect(coordinator.currentJob!.phase, BackupPhase.completed);
      expect(storage.activeDirectory.path, isNot(oldRoot));
      expect(storage.rollbackDirectory, isNull);
      expect(
        await File(p.join(oldRoot, AppDatabase.sqliteFileName)).exists(),
        isFalse,
      );
      expect(readName(storage.activeDirectory), '白鸦');
    },
  );

  test('same-length corruption is rejected before local activation', () async {
    final descriptor = (await backup()).descriptor!;
    final image = cloud.files.keys.firstWhere(
      (key) => key.contains('/objects/') && cloud.files[key]!.isNotEmpty,
    );
    cloud.files[image] = [9, 9, 9, 9];
    final oldRoot = storage.activeDirectory.path;
    await coordinator.prepareRestore(BackupSource.snapshot(descriptor));
    final failed = await waitForJob(coordinator, (j) => j.isTerminal);
    expect(failed.phase, BackupPhase.failed);
    expect(failed.error!.code, 'integrity');
    expect(storage.activeDirectory.path, oldRoot);
    expect(reopenCalls, 0);
  });

  test('restore retry drains old writer and reclaims only the failed staging dataset', () async {
    final descriptor = (await backup()).descriptor!;
    final path = cloud.files.keys.firstWhere(
      (key) => key.contains('/objects/') && cloud.files[key]!.isNotEmpty,
    );
    final original = cloud.files[path]!;
    cloud.files[path] = [9, 9, 9, 9];
    await coordinator.prepareRestore(BackupSource.snapshot(descriptor));
    final failed = await waitForJob(coordinator, (job) => job.isTerminal);
    final journalPath = p.join(
      storage.controlDirectory.path,
      'backup-jobs',
      failed.operationId,
      'job.json',
    );
    final journal = jsonDecode(await File(journalPath).readAsString()) as Map;
    final staging = Directory(
      p.join(root.path, 'datasets', journal['datasetId'] as String),
    );
    expect(await staging.exists(), isTrue);
    cloud.files[path] = original;
    await coordinator.retry(failed.operationId);
    final ready = await waitForJob(
      coordinator,
      (job) => job.requiresConfirmation || job.isTerminal,
    );
    expect(ready.requiresConfirmation, isTrue, reason: ready.error?.message);
    expect(cloud.cancelled, contains(failed.operationId));
    expect(await staging.exists(), isFalse);
    expect(readName(storage.activeDirectory), '白鸦');
  });

  test('local edits after review require a refreshed confirmation', () async {
    final descriptor = (await backup()).descriptor!;
    await coordinator.prepareRestore(BackupSource.snapshot(descriptor));
    final ready = await waitForJob(
      coordinator,
      (j) => j.requiresConfirmation || j.isTerminal,
    );
    expect(ready.requiresConfirmation, isTrue);
    await storage.mutate(() async {
      updateName(storage.activeDirectory, '刚保存的编辑');
    });
    await expectLater(
      coordinator.confirmRestore(ready.operationId),
      throwsA(
        isA<BackupFailure>().having((e) => e.code, 'code', 'review_changed'),
      ),
    );
    expect(
      coordinator.currentJob!.restorePreview!.current!.roles.single.name,
      '刚保存的编辑',
    );
    expect(reopenCalls, 0);
    await coordinator.confirmRestore(ready.operationId);
    expect(readName(storage.activeDirectory), '白鸦');
  });

  test('cancelled prepared restore cannot silently activate later', () async {
    final descriptor = (await backup()).descriptor!;
    await coordinator.prepareRestore(BackupSource.snapshot(descriptor));
    final ready = await waitForJob(
      coordinator,
      (j) => j.requiresConfirmation || j.isTerminal,
    );
    await coordinator.cancel(ready.operationId);
    expect(coordinator.currentJob!.phase, BackupPhase.cancelled);
    await expectLater(
      coordinator.confirmRestore(ready.operationId),
      throwsA(isA<BackupFailure>()),
    );
    expect(reopenCalls, 0);
    expect(readName(storage.activeDirectory), '白鸦');
  });

  test(
    'restore confirmation cannot overtake an in-flight cancellation drain',
    () async {
      final descriptor = (await backup()).descriptor!;
      await coordinator.prepareRestore(BackupSource.snapshot(descriptor));
      final ready = await waitForJob(
        coordinator,
        (job) => job.requiresConfirmation || job.isTerminal,
      );
      cloud.cancelBarrier = Completer<void>();
      final cancelling = coordinator.cancel(ready.operationId);
      await expectLater(
        coordinator.confirmRestore(ready.operationId),
        throwsA(isA<BackupFailure>()),
      );
      expect(reopenCalls, 0);
      cloud.cancelBarrier!.complete();
      cloud.cancelBarrier = null;
      await cancelling;
      expect(coordinator.currentJob!.phase, BackupPhase.cancelled);
      expect(reopenCalls, 0);
    },
  );

  test(
    'publication response loss retries receipt without duplicating a snapshot',
    () async {
      cloud.losePublicationResponse = true;
      final failed = await backup();
      expect(failed.phase, BackupPhase.failed);
      expect(cloud.active.length, 1);
      final sequence = cloud.active.single.accountSequence;
      await coordinator.retry(failed.operationId);
      final result = await waitForJob(
        coordinator,
        (j) => j.phase == BackupPhase.completed,
      );
      expect(result.descriptor!.accountSequence, sequence);
      expect(cloud.active.length, 1);
    },
  );

  test(
    'restart keeps interrupted restore isolated and never activates',
    () async {
      final descriptor = (await backup()).descriptor!;
      await coordinator.prepareRestore(BackupSource.snapshot(descriptor));
      await waitForJob(
        coordinator,
        (j) => j.requiresConfirmation || j.isTerminal,
      );
      await coordinator.dispose();
      await createCoordinator();
      await coordinator.recoverOnStartup();
      expect(coordinator.currentJob!.phase, BackupPhase.interrupted);
      expect(coordinator.currentJob!.failedAtPhase, BackupPhase.readyForReview);
      expect(coordinator.currentJob!.canRetry, isTrue);
      expect(reopenCalls, 0);
    },
  );

  test('strict v3 parser rejects future format, decimal count and unsafe or duplicate paths', () async {
    final descriptor = (await backup()).descriptor!;
    Map<String, Object?> manifest() => Map<String, Object?>.from(
      jsonDecode(
        utf8.decode(cloud.files['${descriptor.basePath}/manifest.json']!),
      ) as Map,
    );
    final future = manifest()..['format'] = 4;
    expect(() => SnapshotManifest.fromJson(future), throwsFormatException);
    final decimal = manifest()..['writerSequence'] = 1.2;
    expect(() => SnapshotManifest.fromJson(decimal), throwsFormatException);
    final traversal = manifest();
    (traversal['files'] as List).first['relativePath'] = 'covers/../secret';
    expect(() => SnapshotManifest.fromJson(traversal), throwsFormatException);
    final duplicates = manifest();
    (duplicates['files'] as List).add((duplicates['files'] as List).first);
    expect(() => SnapshotManifest.fromJson(duplicates), throwsFormatException);
    final feature = manifest()..['requiredFeatures'] = ['unimplemented'];
    expect(() => SnapshotManifest.fromJson(feature), throwsFormatException);
  });

  test(
    'current overview reads only stats and does not populate digest cache',
    () async {
      final contents = await coordinator.currentContents();
      expect(contents.summary.originalFileCount, 2);
      expect(contents.summary.customAttributeCount, 2);
      expect(
        await File(
          p.join(storage.controlDirectory.path, 'file-fingerprints.sqlite'),
        ).exists(),
        isFalse,
      );
      expect(cloud.downloaded, isEmpty);
      expect(contents.rolePage(limit: 1).length, 1);
      expect(contents.filePage(roleId: 1, offset: 1).length, 1);
    },
  );

  test(
    'legacy manifest schema disagreement fails closed without fallback',
    () async {
      cloud.legacy['ochome.sqlite'] = await File(
        p.join(root.path, 'ochome.sqlite'),
      ).readAsBytes();
      cloud.legacy['manifest.json'] = utf8.encode(
        jsonEncode({
          'format': 2,
          'schemaVersion': 7,
          'appVersion': '1.0',
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'covers': [
            {'file': 'cover.png', 'bytes': 4},
          ],
          'assets': [
            {'file': 'empty.txt', 'bytes': 0},
          ],
        }),
      );
      await coordinator.prepareRestore(const BackupSource.legacy());
      final failed = await waitForJob(coordinator, (j) => j.isTerminal);
      expect(failed.error!.code, 'schema_mismatch');
      expect(reopenCalls, 0);
      cloud.legacy['manifest.json'] = utf8.encode('{broken');
      await coordinator.prepareRestore(const BackupSource.legacy());
      final malformed = await waitForJob(coordinator, (j) => j.isTerminal);
      expect(malformed.error!.code, 'invalid_backup');
      expect(reopenCalls, 0);
    },
  );

  test(
    'legacy v2 restores referenced empty files and keeps source slot untouched',
    () async {
      cloud.legacy['ochome.sqlite'] = await File(
        p.join(root.path, 'ochome.sqlite'),
      ).readAsBytes();
      cloud.legacy['covers/cover.png'] = [1, 2, 3, 4];
      cloud.legacy['role_assets/empty.txt'] = [];
      cloud.legacy['manifest.json'] = utf8.encode(
        jsonEncode({
          'format': 2,
          'schemaVersion': 8,
          'appVersion': '1.0',
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'covers': [
            {'file': 'cover.png', 'bytes': 4},
          ],
          'assets': [
            {'file': 'empty.txt', 'bytes': 0},
          ],
        }),
      );
      final original = Map<String, List<int>>.from(cloud.legacy);
      await coordinator.prepareRestore(const BackupSource.legacy());
      final ready = await waitForJob(
        coordinator,
        (j) => j.requiresConfirmation || j.isTerminal,
      );
      expect(ready.requiresConfirmation, isTrue, reason: ready.error?.message);
      expect(ready.restorePreview!.limitedIntegrity, isTrue);
      await coordinator.confirmRestore(ready.operationId);
      expect(cloud.legacy, original);
    },
  );

  test('cancelled unpublished upload is drained and reclaimed with a separate cleanup id', () async {
    cloud.uploadBarrier = Completer<void>();
    await coordinator.startBackup();
    final waiting = await waitForJob(
      coordinator,
      (job) => job.phase == BackupPhase.waitingForCloud,
    );
    expect(cloud.files, isNotEmpty);
    await coordinator.cancel(waiting.operationId);
    cloud.uploadBarrier = null;
    expect(coordinator.currentJob!.phase, BackupPhase.cancelled);
    expect(coordinator.currentJob!.cleanupPending, isFalse);
    expect(cloud.files, isEmpty);
    expect(cloud.abortedOperations, contains(waiting.operationId));
    expect(cloud.abandonCalls.single.$1, isNot(waiting.operationId));
  });

  test('uncertain cancelled upload cleanup persists and resumes before a newer task', () async {
    cloud.uploadBarrier = Completer<void>();
    cloud.failAbandonOnce = true;
    await coordinator.startBackup();
    final waiting = await waitForJob(
      coordinator,
      (job) => job.phase == BackupPhase.waitingForCloud,
    );
    final oldFiles = cloud.files.keys.toSet();
    await coordinator.cancel(waiting.operationId);
    cloud.uploadBarrier = null;
    expect(coordinator.currentJob!.cleanupPending, isTrue);
    final marker = File(
      p.join(
        storage.controlDirectory.path,
        'backup-jobs',
        'pending-abandons',
        '${waiting.operationId}.json',
      ),
    );
    expect(await marker.exists(), isTrue);
    expect(cloud.files.keys, containsAll(oldFiles));
    expect((await backup()).phase, BackupPhase.completed);
    expect(await marker.exists(), isFalse);
    expect(cloud.files.keys.toSet().intersection(oldFiles), isEmpty);
    expect(
      await File(
        p.join(
          storage.controlDirectory.path,
          'backup-jobs',
          waiting.operationId,
          'job.json',
        ),
      ).exists(),
      isTrue,
    );
  });

  test('abandoning unknown publication reconciles its receipt without deleting completed bytes', () async {
    cloud.losePublicationResponse = true;
    final failed = await backup();
    final first = cloud.active.single;
    final originals = Map<String, List<int>>.from(cloud.files);
    expect(failed.phase, BackupPhase.failed);
    expect((await backup()).phase, BackupPhase.completed);
    for (final entry in originals.entries) {
      expect(cloud.files[entry.key], entry.value);
    }
    expect(
      cloud.active.map((snapshot) => snapshot.snapshotId),
      contains(first.snapshotId),
    );
    expect(cloud.abortedOperations, isNot(contains(failed.operationId)));
  });

  test('valid cloud recovery remains reviewable when current business data cannot be read', () async {
    final descriptor = (await backup()).descriptor!;
    final database = sqlite3.open(
      p.join(storage.activeDirectory.path, 'ochome.sqlite'),
    );
    database.execute("UPDATE role SET custom_attributes = 'malformed'");
    database.close();
    expect(storage.isRecoveryOnly, isFalse);
    await coordinator.prepareRestore(BackupSource.snapshot(descriptor));
    final ready = await waitForJob(
      coordinator,
      (job) => job.requiresConfirmation || job.isTerminal,
    );
    expect(ready.requiresConfirmation, isTrue, reason: ready.error?.message);
    expect(ready.restorePreview!.currentUnreadable, isTrue);
    expect(ready.restorePreview!.current, isNull);
    await coordinator.confirmRestore(ready.operationId);
    expect(readName(storage.activeDirectory), '白鸦');
  });

  test('legacy without manifest browses names without downloading unknown-size covers', () async {
    cloud.legacy['ochome.sqlite'] = await File(
      p.join(root.path, 'ochome.sqlite'),
    ).readAsBytes();
    cloud.legacy['covers/cover.png'] = [1, 2, 3, 4];
    cloud.legacy['role_assets/empty.txt'] = [];
    final contents = await coordinator.contentsFor(const BackupSource.legacy());
    expect(contents.roles.single.name, '白鸦');
    expect(contents.summary.knownLogicalDataBytes, isNull);
    expect(
      contents.files.singleWhere((file) => file.kind == 'cover').knownBytes,
      isNull,
    );
    expect(cloud.downloaded, ['ochome.sqlite']);
  });

  test('a fresh cloud restore can replace an unreadable local database after review', () async {
    final descriptor = (await backup()).descriptor!;
    await coordinator.dispose();
    await storage.close();
    await File(p.join(root.path, 'ochome.sqlite'))
        .writeAsString('damaged database');
    storage = await DataStorage.open(root, allowRecovery: true);
    expect(storage.isRecoveryOnly, isTrue);
    await createCoordinator();
    await coordinator.prepareRestore(BackupSource.snapshot(descriptor));
    final ready = await waitForJob(
      coordinator,
      (job) => job.requiresConfirmation || job.isTerminal,
    );
    expect(ready.requiresConfirmation, isTrue, reason: ready.error?.message);
    expect(ready.restorePreview!.currentUnreadable, isTrue);
    expect(ready.restorePreview!.current, isNull);
    await coordinator.confirmRestore(ready.operationId);
    expect(readName(storage.activeDirectory), '白鸦');
    expect(storage.isRecoveryOnly, isFalse);
    expect(storage.rollbackDirectory, isNull);
  });

  test(
    'corrupt active pointer can be rescued through operation-owned staging',
    () async {
      final descriptor = (await backup()).descriptor!;
      await coordinator.dispose();
      await storage.close();
      await File(p.join(root.path, 'storage-control', 'active.json'))
          .writeAsString('{broken');
      storage = await DataStorage.open(root, allowRecovery: true);
      expect(storage.isRecoveryOnly, isTrue);
      await createCoordinator();
      await coordinator.prepareRestore(BackupSource.snapshot(descriptor));
      final ready = await waitForJob(
        coordinator,
        (job) => job.requiresConfirmation || job.isTerminal,
      );
      expect(ready.requiresConfirmation, isTrue, reason: ready.error?.message);
      expect(
        cloud.downloadTargets.every(
          (path) => path.contains('/storage-control/backup-jobs/'),
        ),
        isTrue,
      );
      await coordinator.confirmRestore(ready.operationId);
      expect(storage.isRecoveryOnly, isFalse);
      expect(readName(storage.activeDirectory), '白鸦');
    },
  );

  // v9 曾同时存在「世界观」和「OC 关系」两种库；两种都必须升到当前版本。
  for (final fixture in [
    (label: '3', version: 3, world: false, relationship: false),
    (label: '4', version: 4, world: false, relationship: false),
    (label: '5', version: 5, world: false, relationship: false),
    (label: '6', version: 6, world: false, relationship: false),
    (label: '7', version: 7, world: false, relationship: false),
    (label: '8', version: 8, world: false, relationship: false),
    (label: '9-world', version: 9, world: true, relationship: false),
    (label: '9-relationship', version: 9, world: false, relationship: true),
  ]) {
    final version = fixture.version;
    test('legacy schema ${fixture.label} migrates in staging while retaining original fields', () async {
      final directory = Directory(p.join(root.path, 'legacy-${fixture.label}'))
        ..createSync();
      final path = p.join(directory.path, 'ochome.sqlite');
      final database = sqlite3.open(path);
      if (fixture.world) {
        database.execute(
          "CREATE TABLE world (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, summary TEXT NOT NULL, coverimg TEXT NOT NULL, entries TEXT NOT NULL DEFAULT '[]')",
        );
        database.execute(
          "INSERT INTO world (name, summary, coverimg) VALUES ('旧世界', '', '')",
        );
      }
      database.execute(
        "CREATE TABLE role (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, sex TEXT NOT NULL, birthday TEXT NOT NULL, occupation TEXT NOT NULL, desc TEXT NOT NULL, coverimg TEXT NOT NULL${version >= 4 ? ", age TEXT NOT NULL, race TEXT NOT NULL" : ""}${version >= 7 ? ", custom_attributes TEXT NOT NULL DEFAULT '[]'" : ""}${fixture.world ? ", world_id INTEGER NULL REFERENCES world(id) ON DELETE SET NULL" : ""})",
      );
      database.execute(
        "INSERT INTO role (name,sex,birthday,occupation,desc,coverimg${version >= 4 ? ",age,race" : ""}) VALUES ('旧版白鸦','','','','设定内容',''${version >= 4 ? ",'十七','人类'" : ""})",
      );
      if (version >= 5) {
        database.execute(
          'CREATE TABLE role_desc_revision (id INTEGER PRIMARY KEY AUTOINCREMENT, role_id INTEGER NOT NULL REFERENCES role(id) ON DELETE CASCADE, content TEXT NOT NULL, created_at INTEGER NOT NULL)',
        );
        database.execute(
          "INSERT INTO role_desc_revision VALUES (1,1,'早期设定',1000)",
        );
      }
      if (version >= 8) {
        database.execute(
          'CREATE TABLE role_asset (id INTEGER PRIMARY KEY AUTOINCREMENT, role_id INTEGER NOT NULL REFERENCES role(id) ON DELETE CASCADE, name TEXT NOT NULL,kind TEXT NOT NULL,relative_path TEXT NOT NULL UNIQUE,bytes INTEGER NOT NULL,created_at INTEGER NOT NULL)',
        );
        database.execute(
          'CREATE INDEX role_asset_role_id ON role_asset(role_id)',
        );
      }
      if (fixture.world) {
        database.execute('UPDATE role SET world_id = 1 WHERE id = 1');
      }
      if (fixture.relationship) {
        database.execute(
          "INSERT INTO role (name,sex,birthday,occupation,desc,coverimg,age,race) VALUES ('旧版徒弟','','','','','','','')",
        );
        database.execute(
          'CREATE TABLE role_relationship (id INTEGER PRIMARY KEY AUTOINCREMENT, from_role_id INTEGER NOT NULL REFERENCES role(id) ON DELETE CASCADE, to_role_id INTEGER NOT NULL REFERENCES role(id) ON DELETE CASCADE, from_label TEXT NOT NULL, to_label TEXT NOT NULL, created_at INTEGER NOT NULL)',
        );
        database.execute(
          'CREATE INDEX role_relationship_from_role_id ON role_relationship(from_role_id)',
        );
        database.execute(
          'CREATE INDEX role_relationship_to_role_id ON role_relationship(to_role_id)',
        );
        database.execute(
          "INSERT INTO role_relationship VALUES (1, 1, 2, '师父', '徒弟', 1000)",
        );
      }
      database.userVersion = version;
      database.close();
      cloud.legacy['ochome.sqlite'] = await File(path).readAsBytes();
      await coordinator.prepareRestore(const BackupSource.legacy());
      final ready = await waitForJob(
        coordinator,
        (job) => job.requiresConfirmation || job.isTerminal,
      );
      expect(ready.requiresConfirmation, isTrue, reason: ready.error?.message);
      expect(readName(storage.activeDirectory), '白鸦');
      await coordinator.confirmRestore(ready.operationId);
      final migrated = sqlite3.open(
        p.join(storage.activeDirectory.path, 'ochome.sqlite'),
      );
      try {
        expect(migrated.userVersion, AppDatabase.currentSchemaVersion);
        expect(
          migrated.select('SELECT desc FROM role WHERE id = 1').single['desc'],
          '设定内容',
        );
        expect(
          migrated.select('SELECT * FROM role_relationship'),
          hasLength(fixture.relationship ? 1 : 0),
        );
        expect(
          migrated
              .select('SELECT world_id FROM role WHERE id = 1')
              .single['world_id'],
          fixture.world ? 1 : isNull,
        );
        expect(
          migrated.select('SELECT * FROM world'),
          hasLength(fixture.world ? 1 : 0),
        );
        expect(
          migrated.select(
            "SELECT name FROM sqlite_master WHERE type = 'index' AND name LIKE 'role_relationship_%'",
          ),
          hasLength(2),
        );
        expect(
          migrated
              .select('SELECT custom_attributes FROM role WHERE id = 1')
              .single['custom_attributes'],
          '[]',
        );
        expect(
          migrated.select('SELECT * FROM role_desc_revision'),
          hasLength(1),
        );
      } finally {
        migrated.close();
      }
    });
  }

  test('database business validation rejects malformed custom attributes before review', () async {
    final db = sqlite3.open(p.join(root.path, 'ochome.sqlite'));
    db.execute(
      "UPDATE role SET custom_attributes = '[{\"name\":\"\",\"content\":\"x\"}]'",
    );
    db.close();
    await expectLater(
      inspectBackupDatabase(File(p.join(root.path, 'ochome.sqlite'))),
      throwsFormatException,
    );
    final job = await backup();
    expect(job.phase, BackupPhase.failed);
    expect(cloud.active, isEmpty);
  });

  test('asset tags survive a snapshot restore', () async {
    final live = AppDatabase.forStorage(
      storage,
      executor: NativeDatabase(
        File(p.join(storage.activeDirectory.path, AppDatabase.sqliteFileName)),
      ),
    );
    final assets = DriftRoleAssetRepository(live);
    final asset = (await assets.listForRole(1)).single;
    await assets.updateTags(
      roleId: 1,
      assetId: asset.id,
      tags: ['  设定 ', '世界观'],
    );
    await live.close();

    final descriptor = (await backup()).descriptor!;
    final local = sqlite3.open(
      p.join(storage.activeDirectory.path, AppDatabase.sqliteFileName),
    );
    local.execute("UPDATE role_asset SET tags = '[\"本机修改\"]'");
    local.close();
    await coordinator.prepareRestore(BackupSource.snapshot(descriptor));
    final ready = await waitForJob(
      coordinator,
      (job) => job.requiresConfirmation || job.isTerminal,
    );
    expect(ready.requiresConfirmation, isTrue, reason: ready.error?.message);
    await coordinator.confirmRestore(ready.operationId);

    final restored = sqlite3.open(
      p.join(storage.activeDirectory.path, AppDatabase.sqliteFileName),
      mode: OpenMode.readOnly,
    );
    try {
      expect(
        restored.select('SELECT tags FROM role_asset').single['tags'],
        '["设定","世界观"]',
      );
    } finally {
      restored.close();
    }
  });

  test('database business validation rejects malformed asset tags', () async {
    final live = AppDatabase.forStorage(
      storage,
      executor: NativeDatabase(
        File(p.join(storage.activeDirectory.path, AppDatabase.sqliteFileName)),
      ),
    );
    await live.customStatement(
      "UPDATE role_asset SET tags = '[\"重复\",\"重复\"]'",
    );
    await live.close();
    final database = File(
      p.join(storage.activeDirectory.path, AppDatabase.sqliteFileName),
    );
    await expectLater(inspectBackupDatabase(database), throwsFormatException);
    final job = await backup();
    expect(job.phase, BackupPhase.failed);
    expect(cloud.active, isEmpty);
  });

  test('database business validation rejects self-linked or empty relationships', () async {
    final path = p.join(root.path, 'ochome.sqlite');
    final db = sqlite3.open(path);
    // The shared fixture is schema 8; upgrade it by hand so the ≥9 branch runs.
    final roleId = db.select('SELECT id FROM role LIMIT 1').single['id'] as int;
    db.execute('''
      CREATE TABLE role_relationship (id INTEGER PRIMARY KEY AUTOINCREMENT,
        from_role_id INTEGER NOT NULL REFERENCES role(id) ON DELETE CASCADE,
        to_role_id INTEGER NOT NULL REFERENCES role(id) ON DELETE CASCADE,
        from_label TEXT NOT NULL, to_label TEXT NOT NULL, created_at INTEGER NOT NULL);
      PRAGMA user_version = 9;
    ''');
    db.execute(
      'INSERT INTO role_relationship (from_role_id, to_role_id, from_label, to_label, created_at) VALUES (?, ?, ?, ?, ?)',
      [roleId, roleId, '师父', '徒弟', 1000],
    );
    db.close();
    await expectLater(inspectBackupDatabase(File(path)), throwsFormatException);
    final job = await backup();
    expect(job.phase, BackupPhase.failed);
    expect(cloud.active, isEmpty);
  });
}
