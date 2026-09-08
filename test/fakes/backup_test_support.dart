import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'package:ochome/features/backup/backup_coordinator.dart';
import 'package:ochome/features/backup/backup_models.dart';
import 'package:ochome/features/backup/backup_protocol.dart';
import 'package:ochome/features/backup/backup_transport.dart';

void createFixture(Directory root) {
  final db = sqlite3.open(p.join(root.path, 'ochome.sqlite'));
  db.execute('''CREATE TABLE role (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
    sex TEXT NOT NULL, age TEXT NOT NULL, birthday TEXT NOT NULL, race TEXT NOT NULL,
    occupation TEXT NOT NULL, desc TEXT NOT NULL, coverimg TEXT NOT NULL, custom_attributes TEXT NOT NULL DEFAULT '[]');
    CREATE TABLE role_desc_revision (id INTEGER PRIMARY KEY AUTOINCREMENT, role_id INTEGER NOT NULL REFERENCES role(id) ON DELETE CASCADE,
    content TEXT NOT NULL, created_at INTEGER NOT NULL);
    CREATE TABLE role_asset (id INTEGER PRIMARY KEY AUTOINCREMENT, role_id INTEGER NOT NULL REFERENCES role(id) ON DELETE CASCADE,
    name TEXT NOT NULL, kind TEXT NOT NULL, relative_path TEXT NOT NULL UNIQUE, bytes INTEGER NOT NULL, created_at INTEGER NOT NULL);
    CREATE INDEX role_asset_role_id ON role_asset(role_id);
    PRAGMA user_version = 8;''');
  db.execute('INSERT INTO role VALUES (1, ?, ?, ?, ?, ?, ?, ?, ?, ?)', [
    '白鸦',
    '',
    '',
    '',
    '',
    '',
    '完整设定',
    'covers/cover.png',
    '[{"name":"能力","content":"冰"},{"name":"能力","content":"火"}]',
  ]);
  db.execute("INSERT INTO role_desc_revision VALUES (1, 1, '旧设定', 1000)");
  db.execute(
    "INSERT INTO role_asset VALUES (1, 1, '空白笔记.txt', 'document', 'role_assets/empty.txt', 0, 1000)",
  );
  db.close();
  Directory(p.join(root.path, 'covers')).createSync();
  File(p.join(root.path, 'covers', 'cover.png')).writeAsBytesSync([1, 2, 3, 4]);
  Directory(p.join(root.path, 'role_assets')).createSync();
  File(p.join(root.path, 'role_assets', 'empty.txt')).writeAsBytesSync([]);
}

void updateName(Directory root, String name) {
  final db = sqlite3.open(p.join(root.path, 'ochome.sqlite'));
  db.execute('UPDATE role SET name = ?', [name]);
  db.close();
}

String readName(Directory root) {
  final db = sqlite3.open(
    p.join(root.path, 'ochome.sqlite'),
    mode: OpenMode.readOnly,
  );
  try {
    return db.select('SELECT name FROM role').single['name'] as String;
  } finally {
    db.close();
  }
}

Future<BackupJobState> waitForJob(
  BackupCoordinator coordinator,
  bool Function(BackupJobState) predicate,
) async {
  final current = coordinator.currentJob;
  if (current != null && predicate(current)) return current;
  return coordinator
      .watchJob()
      .firstWhere(predicate)
      .timeout(const Duration(seconds: 30));
}

class FakeBackupTransport implements BackupTransport {
  final controller = StreamController<BackupTransferEvent>.broadcast();
  final files = <String, List<int>>{};
  final legacy = <String, List<int>>{};
  final active = <BackupDescriptor>[];
  final retired = <BackupDescriptor>[];
  final reservations = <String, BackupReservation>{};
  final receipts = <String, BackupDescriptor>{};
  final staged = <String>[];
  final downloaded = <String>[];
  final downloadTargets = <String>[];
  final deleted = <String>[];
  final claims = <String, List<String>>{};
  final createdByOperation = <String, Set<String>>{};
  final abortedOperations = <String>{};
  final abandonCalls = <(String, String)>[];
  bool failAbandonOnce = false;
  final writer = newBackupId();
  int? localAvailableBytes = 100000000000;
  final capacityResults = <int?>[];
  int capacityChecks = 0, nativeEventSequence = 0;
  bool emitStageByteEvents = false, emitDownloadByteEvents = false;
  String? failDownloadRelativePath;
  final cancelled = <String>{};
  int sequence = 0, revision = 0;
  Completer<void>? uploadBarrier;
  Completer<void>? cancelBarrier;
  Completer<void>? releaseBarrier;
  String? failStageSuffix;
  bool losePublicationResponse = false;
  @override
  Stream<BackupTransferEvent> get events => controller.stream;
  @override
  Future<BackupAvailability> availability() async => BackupAvailability(
    supported: true,
    available: true,
    accountId: 'test-account',
    deviceName: '测试设备',
    appVersion: '1.0.0+100',
    availableBytes: localAvailableBytes,
    writerId: writer,
  );
  @override
  Future<int?> availableCapacity() async {
    capacityChecks++;
    return capacityResults.isEmpty
        ? localAvailableBytes
        : capacityResults.removeAt(0);
  }

  @override
  Future<AccountBackupCatalog> catalog(String accountId) async =>
      AccountBackupCatalog(
        revision: '${revision + 1}',
        snapshots: List.of(active),
        reservations: reservations.values.toList(),
        retired: List.of(retired),
      );
  @override
  Future<BackupReservation> reserve({
    required String operationId,
    required String accountId,
    required String kind,
    required List<String> baseSnapshotIds,
  }) async {
    if (abortedOperations.contains(operationId)) {
      throw const BackupFailure('operation_aborted', '任务已永久取消');
    }
    final value = BackupReservation(
      reservationId: operationId,
      expiresAtUtc: DateTime.now().toUtc().add(const Duration(days: 1)),
      baseSnapshotIds: baseSnapshotIds,
    );
    reservations[operationId] = value;
    return value;
  }

  @override
  Future<BackupDescriptor> publish({
    required String operationId,
    required String accountId,
    required String reservationId,
    required BackupDescriptor snapshot,
  }) async {
    if (receipts.containsKey(operationId)) return receipts[operationId]!;
    if (abortedOperations.contains(operationId)) {
      throw const BackupFailure('operation_aborted', '任务已永久取消');
    }
    final json = snapshot.toJson()
      ..['accountSequence'] = ++sequence
      ..['completedAtUtc'] = DateTime.now().toUtc().toIso8601String();
    final result = BackupDescriptor.fromJson(json);
    active.insert(0, result);
    if (active.length > 3) retired.add(active.removeLast());
    receipts[operationId] = result;
    reservations.remove(operationId);
    revision++;
    if (losePublicationResponse) {
      losePublicationResponse = false;
      throw const BackupFailure('publication_pending', '确认响应丢失');
    }
    return result;
  }

  @override
  Future<void> release({
    required String operationId,
    required String accountId,
    required String reservationId,
  }) async {
    await releaseBarrier?.future;
    reservations.remove(operationId);
  }

  @override
  Future<void> stage({
    required String operationId,
    required String accountId,
    required String localPath,
    required String relativePath,
    required int bytes,
    required String sha256,
  }) async {
    if (failStageSuffix != null && relativePath.endsWith(failStageSuffix!)) {
      throw const BackupFailure('upload_failed', '测试上传失败');
    }
    final data = await File(localPath).readAsBytes();
    if (data.length != bytes ||
        crypto.sha256.convert(data).toString() != sha256) {
      throw const BackupFailure('integrity', '源文件校验不一致');
    }
    if (files.containsKey(relativePath) &&
        crypto.sha256.convert(files[relativePath]!).toString() != sha256) {
      throw const BackupFailure('immutable_conflict', '禁止覆盖');
    }
    if (!files.containsKey(relativePath)) {
      createdByOperation.putIfAbsent(operationId, () => {}).add(relativePath);
    }
    files[relativePath] = List.of(data);
    staged.add(relativePath);
    if (emitStageByteEvents) {
      controller.add(
        BackupTransferEvent(
          operationId: operationId,
          sequence: ++nativeEventSequence,
          phase: 'staging',
          relativePath: relativePath,
          completedBytes: data.length,
          totalBytes: data.length,
        ),
      );
    }
  }

  @override
  Future<void> awaitUploaded({
    required String operationId,
    required String accountId,
    required List<String> relativePaths,
  }) async {
    await uploadBarrier?.future;
    if (cancelled.contains(operationId)) {
      throw const BackupFailure('cancelled', '已取消');
    }
    if (relativePaths.any((path) => !files.containsKey(path))) {
      throw const BackupFailure('upload_pending', '上传未完成');
    }
  }

  @override
  Future<DownloadReceipt> download({
    required String operationId,
    required String accountId,
    required String relativePath,
    required String localPath,
    int? bytes,
    String? sha256,
    bool legacy = false,
  }) async {
    final data = (legacy ? this.legacy : files)[relativePath];
    if (data == null) throw const BackupFailure('file_not_found', '文件不存在');
    final digest = crypto.sha256.convert(data).toString();
    if ((bytes != null && bytes != data.length) ||
        (sha256 != null && sha256 != digest)) {
      throw const BackupFailure('integrity', '文件内容不一致');
    }
    if (relativePath == failDownloadRelativePath) {
      throw const BackupFailure('local_space', '本机存储空间不足');
    }
    final target = File(localPath);
    await target.parent.create(recursive: true);
    await target.writeAsBytes(data, flush: true);
    downloaded.add(relativePath);
    downloadTargets.add(localPath);
    if (emitDownloadByteEvents) {
      controller.add(
        BackupTransferEvent(
          operationId: operationId,
          sequence: ++nativeEventSequence,
          phase: 'downloading',
          relativePath: relativePath,
          completedBytes: data.length,
          totalBytes: data.length,
        ),
      );
    }
    return DownloadReceipt(bytes: data.length, sha256: digest);
  }

  @override
  Future<LegacyDiscovery> legacyInfo(String accountId) async =>
      LegacyDiscovery(exists: legacy.isNotEmpty, discoveryComplete: true);
  @override
  Future<void> cancel(String operationId) async {
    cancelled.add(operationId);
    await cancelBarrier?.future;
    if (uploadBarrier != null && !uploadBarrier!.isCompleted) {
      uploadBarrier!.complete();
    }
  }

  @override
  Future<AbandonUploadResult> abandonUpload({
    required String operationId,
    required String accountId,
    required String abandonedOperationId,
  }) async {
    abandonCalls.add((operationId, abandonedOperationId));
    expect(operationId, isNot(abandonedOperationId));
    expect(cancelled, contains(abandonedOperationId));
    if (failAbandonOnce) {
      failAbandonOnce = false;
      throw const BackupFailure('cloud_pending', '无法确定取消结果');
    }
    if (receipts.containsKey(abandonedOperationId)) {
      return AbandonUploadResult(
        aborted: false,
        published: receipts[abandonedOperationId],
        cleanupPending: false,
      );
    }
    abortedOperations.add(abandonedOperationId);
    reservations.remove(abandonedOperationId);
    final referenced = <String>{};
    for (final snapshot in active) {
      referenced.addAll(
        [
          'database.sqlite',
          'contents.json',
          'manifest.json',
          'commit.json',
        ].map((name) => '${snapshot.basePath}/$name'),
      );
      final manifest = SnapshotManifest.fromJson(
        jsonDecode(utf8.decode(files['${snapshot.basePath}/manifest.json']!)),
      );
      referenced.addAll(
        manifest.files.map((file) => file.objectPath(manifest.writerId)),
      );
    }
    for (final path in createdByOperation[abandonedOperationId] ?? <String>{}) {
      if (!referenced.contains(path)) {
        files.remove(path);
        deleted.add(path);
      }
    }
    createdByOperation.remove(abandonedOperationId);
    return const AbandonUploadResult(aborted: true, cleanupPending: false);
  }

  @override
  Future<String> claimCleanup({
    required String operationId,
    required String accountId,
    required String revision,
    required List<String> relativePaths,
  }) async {
    final id = newBackupId();
    claims[id] = relativePaths;
    return id;
  }

  @override
  Future<void> deleteAuthorized({
    required String operationId,
    required String accountId,
    required String claimId,
  }) async {
    for (final path in claims.remove(claimId)!) {
      files.remove(path);
      deleted.add(path);
    }
    retired.removeWhere((s) => !files.containsKey('${s.basePath}/commit.json'));
    revision++;
  }
}
