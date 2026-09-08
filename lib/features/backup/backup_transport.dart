import 'dart:async';

import 'package:flutter/services.dart';

import 'backup_models.dart';
import 'backup_protocol.dart';

class BackupReservation {
  const BackupReservation({
    required this.reservationId,
    required this.expiresAtUtc,
    this.baseSnapshotIds = const [],
  });
  final String reservationId;
  final DateTime expiresAtUtc;
  final List<String> baseSnapshotIds;
  factory BackupReservation.fromJson(Object? value) {
    final j = BackupJson.object(value);
    return BackupReservation(
      reservationId: BackupJson.string(j['reservationId']),
      expiresAtUtc: BackupJson.time(j['expiresAtUtc']),
      baseSnapshotIds: j['baseSnapshotIds'] == null
          ? const []
          : List.unmodifiable(
              BackupJson.list(j['baseSnapshotIds']).map(BackupJson.uuid),
            ),
    );
  }
}

class AccountBackupCatalog {
  const AccountBackupCatalog({
    required this.revision,
    required this.snapshots,
    required this.reservations,
    required this.retired,
    this.pendingCleanupClaims = const [],
  });
  final String revision;
  final List<BackupDescriptor> snapshots, retired;
  final List<BackupReservation> reservations;
  final List<String> pendingCleanupClaims;
  factory AccountBackupCatalog.fromJson(Object? value) {
    final j = BackupJson.object(value);
    final snapshots = BackupJson.list(j['snapshots'])
        .map(BackupDescriptor.fromJson)
        .toList();
    if (snapshots.length > 3 ||
        snapshots.any((s) => s.accountSequence == null) ||
        snapshots.map((s) => s.snapshotId).toSet().length != snapshots.length ||
        snapshots.map((s) => s.accountSequence).toSet().length !=
            snapshots.length) {
      throw const FormatException('账户备份目录不一致');
    }
    snapshots.sort((a, b) => b.accountSequence!.compareTo(a.accountSequence!));
    return AccountBackupCatalog(
      revision: BackupJson.string(j['revision']),
      snapshots: List.unmodifiable(snapshots),
      reservations: List.unmodifiable(
        BackupJson.list(j['reservations']).map(BackupReservation.fromJson),
      ),
      retired: List.unmodifiable(
        BackupJson.list(j['retired']).map(BackupDescriptor.fromJson),
      ),
      pendingCleanupClaims: j['claims'] == null
          ? const []
          : List.unmodifiable(
              BackupJson.list(j['claims']).map(
                (claim) =>
                    BackupJson.string(BackupJson.object(claim)['claimId']),
              ),
            ),
    );
  }
}

class BackupTransferEvent {
  const BackupTransferEvent({
    required this.operationId,
    required this.sequence,
    required this.phase,
    this.relativePath,
    this.completedBytes,
    this.totalBytes,
    this.completedFiles,
    this.totalFiles,
  });
  final String operationId, phase;
  final int sequence;
  final String? relativePath;
  final int? completedBytes, totalBytes, completedFiles, totalFiles;
  factory BackupTransferEvent.fromJson(Object? value) {
    final j = BackupJson.object(value);
    int? optional(String key) =>
        j[key] == null ? null : BackupJson.integer(j[key]);
    return BackupTransferEvent(
      operationId: BackupJson.uuid(j['operationId']),
      sequence: BackupJson.integer(j['sequence']),
      phase: BackupJson.string(j['phase']),
      relativePath: j['relativePath'] == null
          ? null
          : BackupJson.string(j['relativePath']),
      completedBytes: optional('completedBytes'),
      totalBytes: optional('totalBytes'),
      completedFiles: optional('completedFiles'),
      totalFiles: optional('totalFiles'),
    );
  }
}

class DownloadReceipt {
  const DownloadReceipt({required this.bytes, required this.sha256});
  final int bytes;
  final String sha256;
}

class LegacyDiscovery {
  const LegacyDiscovery({
    required this.exists,
    required this.discoveryComplete,
  });
  final bool exists, discoveryComplete;
}

class AbandonUploadResult {
  const AbandonUploadResult({
    required this.aborted,
    required this.cleanupPending,
    this.published,
  });
  final bool aborted, cleanupPending;
  final BackupDescriptor? published;
}

abstract interface class BackupTransport {
  Stream<BackupTransferEvent> get events;
  Future<BackupAvailability> availability();
  Future<int?> availableCapacity();
  Future<AccountBackupCatalog> catalog(String accountId);
  Future<BackupReservation> reserve({
    required String operationId,
    required String accountId,
    required String kind,
    required List<String> baseSnapshotIds,
  });
  Future<BackupDescriptor> publish({
    required String operationId,
    required String accountId,
    required String reservationId,
    required BackupDescriptor snapshot,
  });
  Future<void> release({
    required String operationId,
    required String accountId,
    required String reservationId,
  });
  Future<void> stage({
    required String operationId,
    required String accountId,
    required String localPath,
    required String relativePath,
    required int bytes,
    required String sha256,
  });
  Future<void> awaitUploaded({
    required String operationId,
    required String accountId,
    required List<String> relativePaths,
  });
  Future<DownloadReceipt> download({
    required String operationId,
    required String accountId,
    required String relativePath,
    required String localPath,
    int? bytes,
    String? sha256,
    bool legacy = false,
  });
  Future<LegacyDiscovery> legacyInfo(String accountId);
  Future<void> cancel(String operationId);
  Future<AbandonUploadResult> abandonUpload({
    required String operationId,
    required String accountId,
    required String abandonedOperationId,
  });
  Future<String> claimCleanup({
    required String operationId,
    required String accountId,
    required String revision,
    required List<String> relativePaths,
  });
  Future<void> deleteAuthorized({
    required String operationId,
    required String accountId,
    required String claimId,
  });
}

/// Native failures retain distinct stable codes. Missing platform support never
/// yields an empty account or a successful backup.
class MethodChannelBackupTransport implements BackupTransport {
  MethodChannelBackupTransport({
    MethodChannel? channel,
    EventChannel? eventChannel,
  }) : _channel = channel ?? const MethodChannel('com.xuwudi.ochome/backup_v3'),
       _eventChannel =
           eventChannel ??
           const EventChannel('com.xuwudi.ochome/backup_v3/events');
  final MethodChannel _channel;
  final EventChannel _eventChannel;
  Stream<BackupTransferEvent>? _events;
  @override
  Stream<BackupTransferEvent> get events => _events ??= _eventChannel
      .receiveBroadcastStream()
      .map(BackupTransferEvent.fromJson)
      .asBroadcastStream();
  Future<Object?> _call(String method, [Map<String, Object?>? args]) async {
    try {
      return await _channel.invokeMethod<Object?>(method, args);
    } on MissingPluginException {
      throw const BackupFailure(
        'unsupported',
        '这台设备尚未启用 iCloud 备份服务',
        retryable: false,
      );
    } on PlatformException catch (e) {
      throw BackupFailure(
        e.code,
        e.message ?? 'iCloud 操作未完成，请稍后重试',
        retryable: !{
          'unsupported',
          'invalid_arguments',
          'invalid_path',
        }.contains(e.code),
      );
    }
  }

  @override
  Future<BackupAvailability> availability() async {
    try {
      final j = BackupJson.object(await _call('availability'));
      return BackupAvailability(
        supported: BackupJson.boolean(j['supported']),
        available: BackupJson.boolean(j['available']),
        deviceName: BackupJson.string(j['deviceName']),
        appVersion: BackupJson.string(j['appVersion']),
        writerId: j['writerId'] == null ? null : BackupJson.uuid(j['writerId']),
        accountId: j['accountId'] as String?,
        availableBytes: j['availableBytes'] == null
            ? null
            : BackupJson.integer(j['availableBytes']),
        errorCode: j['errorCode'] as String?,
        message: j['message'] as String?,
      );
    } on BackupFailure catch (e) {
      if (e.code != 'unsupported') rethrow;
      return BackupAvailability(
        supported: false,
        available: false,
        deviceName: '此设备',
        appVersion: '未知',
        errorCode: e.code,
        message: e.message,
      );
    }
  }

  @override
  Future<int?> availableCapacity() async {
    final value = BackupJson.object(await _call('availableCapacity'));
    return value['availableBytes'] == null
        ? null
        : BackupJson.integer(value['availableBytes']);
  }

  @override
  Future<AccountBackupCatalog> catalog(String accountId) async =>
      AccountBackupCatalog.fromJson(
        await _call('catalog', {'accountId': accountId}),
      );
  @override
  Future<BackupReservation> reserve({
    required String operationId,
    required String accountId,
    required String kind,
    required List<String> baseSnapshotIds,
  }) async => BackupReservation.fromJson(
    await _call('reserve', {
      'operationId': operationId,
      'accountId': accountId,
      'kind': kind,
      'baseSnapshotIds': baseSnapshotIds,
    }),
  );
  @override
  Future<BackupDescriptor> publish({
    required String operationId,
    required String accountId,
    required String reservationId,
    required BackupDescriptor snapshot,
  }) async => BackupDescriptor.fromJson(
    await _call('publish', {
      'operationId': operationId,
      'accountId': accountId,
      'reservationId': reservationId,
      'snapshot': snapshot.toJson(),
    }),
  );
  @override
  Future<void> release({
    required String operationId,
    required String accountId,
    required String reservationId,
  }) async {
    await _call('release', {
      'operationId': operationId,
      'accountId': accountId,
      'reservationId': reservationId,
    });
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
    await _call('stage', {
      'operationId': operationId,
      'accountId': accountId,
      'localPath': localPath,
      'relativePath': relativePath,
      'bytes': bytes,
      'sha256': sha256,
    });
  }

  @override
  Future<void> awaitUploaded({
    required String operationId,
    required String accountId,
    required List<String> relativePaths,
  }) async {
    await _call('awaitUploaded', {
      'operationId': operationId,
      'accountId': accountId,
      'relativePaths': relativePaths,
    });
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
    final j = BackupJson.object(
      await _call('download', {
        'operationId': operationId,
        'accountId': accountId,
        'relativePath': relativePath,
        'localPath': localPath,
        'bytes': ?bytes,
        'sha256': ?sha256,
        if (legacy) 'legacy': true,
      }),
    );
    final receipt = DownloadReceipt(
      bytes: BackupJson.integer(j['bytes']),
      sha256: BackupJson.hash(j['sha256']),
    );
    if ((bytes != null && receipt.bytes != bytes) ||
        (sha256 != null && receipt.sha256 != sha256)) {
      throw const BackupFailure('integrity', '下载文件与备份记录不一致');
    }
    return receipt;
  }

  @override
  Future<LegacyDiscovery> legacyInfo(String accountId) async {
    final j = BackupJson.object(
      await _call('legacyInfo', {'accountId': accountId}),
    );
    return LegacyDiscovery(
      exists: BackupJson.boolean(j['exists']),
      discoveryComplete: BackupJson.boolean(j['discoveryComplete']),
    );
  }

  @override
  Future<void> cancel(String operationId) async {
    await _call('cancel', {'operationId': operationId});
  }

  @override
  Future<AbandonUploadResult> abandonUpload({
    required String operationId,
    required String accountId,
    required String abandonedOperationId,
  }) async {
    final value = BackupJson.object(
      await _call('abandonUpload', {
        'operationId': operationId,
        'accountId': accountId,
        'abandonedOperationId': abandonedOperationId,
      }),
    );
    final aborted = BackupJson.boolean(value['aborted']);
    final published = value['published'] == null
        ? null
        : BackupDescriptor.fromJson(value['published']);
    if (aborted && published != null) {
      throw const FormatException('任务取消与发布回执矛盾');
    }
    return AbandonUploadResult(
      aborted: aborted,
      cleanupPending: BackupJson.boolean(value['cleanupPending']),
      published: published,
    );
  }

  @override
  Future<String> claimCleanup({
    required String operationId,
    required String accountId,
    required String revision,
    required List<String> relativePaths,
  }) async {
    final j = BackupJson.object(
      await _call('claimCleanup', {
        'operationId': operationId,
        'accountId': accountId,
        'revision': revision,
        'relativePaths': relativePaths,
      }),
    );
    return BackupJson.string(j['claimId']);
  }

  @override
  Future<void> deleteAuthorized({
    required String operationId,
    required String accountId,
    required String claimId,
  }) async {
    await _call('deleteAuthorized', {
      'operationId': operationId,
      'accountId': accountId,
      'claimId': claimId,
    });
  }
}
