import 'backup_protocol.dart';

enum BackupJobKind { backup, restore, cleanup }

enum BackupPhase {
  preparing,
  hashing,
  staging,
  uploading,
  waitingForCloud,
  publishing,
  readingContents,
  downloading,
  validating,
  readyForReview,
  activating,
  completed,
  failed,
  cancelled,
  interrupted,
}

class BackupFailure implements Exception {
  const BackupFailure(this.code, this.message, {this.retryable = true});
  final String code;
  final String message;
  final bool retryable;
  @override
  String toString() => message;
}

class BackupAvailability {
  const BackupAvailability({
    required this.supported,
    required this.available,
    required this.deviceName,
    required this.appVersion,
    this.accountId,
    this.availableBytes,
    this.errorCode,
    this.message,
    this.writerId,
  });
  final bool supported;
  final bool available;
  final String deviceName;
  final String appVersion;
  final String? accountId;
  final int? availableBytes;
  final String? errorCode;
  final String? message;

  /// Native identity bound to this installation/device, preserved on app update.
  final String? writerId;
}

class BackupHistory {
  const BackupHistory({required this.snapshots, this.retiredCount = 0});
  final List<BackupDescriptor> snapshots;
  final int retiredCount;
}

class BackupSource {
  const BackupSource.snapshot(this.descriptor) : legacy = false;
  const BackupSource.legacy() : descriptor = null, legacy = true;
  final BackupDescriptor? descriptor;
  final bool legacy;
}

class RestorePreview {
  const RestorePreview({
    required this.incoming,
    required this.current,
    required this.datasetEpoch,
    required this.mutationRevision,
    required this.additionalBytes,
    this.limitedIntegrity = false,
    this.currentUnreadable = false,
  });
  final SnapshotContents incoming;
  final SnapshotContents? current;
  final int datasetEpoch;
  final int mutationRevision;
  final int additionalBytes;
  final bool limitedIntegrity;
  final bool currentUnreadable;
}

class BackupJobState {
  const BackupJobState({
    required this.operationId,
    required this.kind,
    required this.phase,
    required this.startedAtUtc,
    this.contentCreatedAtUtc,
    this.completedAtUtc,
    this.completedBytes,
    this.totalBytes,
    this.completedFiles,
    this.totalFiles,
    this.reusedFiles = 0,
    this.reusedBytes = 0,
    this.uploadBytes,
    this.currentItem,
    this.contents,
    this.descriptor,
    this.restorePreview,
    this.error,
    this.cleanupPending = false,
    this.sequence = 0,
    this.failedAtPhase,
  });
  final String operationId;
  final BackupJobKind kind;
  final BackupPhase phase;
  final DateTime startedAtUtc;
  final DateTime? contentCreatedAtUtc;
  final DateTime? completedAtUtc;
  final int? completedBytes;
  final int? totalBytes;
  final int? completedFiles;
  final int? totalFiles;
  final int reusedFiles;
  final int reusedBytes;
  final int? uploadBytes;

  /// Friendly name resolved from the immutable contents index.
  final String? currentItem;
  final SnapshotContents? contents;
  final BackupDescriptor? descriptor;
  final RestorePreview? restorePreview;
  final BackupFailure? error;
  final bool cleanupPending;
  final int sequence;
  final BackupPhase? failedAtPhase;

  bool get isTerminal => const {
    BackupPhase.completed,
    BackupPhase.failed,
    BackupPhase.cancelled,
    BackupPhase.interrupted,
  }.contains(phase);
  bool get canCancel =>
      !isTerminal &&
      kind != BackupJobKind.cleanup &&
      phase != BackupPhase.activating &&
      phase != BackupPhase.publishing;
  bool get canRetry =>
      (phase == BackupPhase.failed || phase == BackupPhase.interrupted) &&
      (error?.retryable ?? true);
  bool get requiresConfirmation => phase == BackupPhase.readyForReview;

  BackupJobState copyWith({
    BackupPhase? phase,
    DateTime? contentCreatedAtUtc,
    DateTime? completedAtUtc,
    int? completedBytes,
    int? totalBytes,
    int? completedFiles,
    int? totalFiles,
    int? reusedFiles,
    int? reusedBytes,
    int? uploadBytes,
    String? currentItem,
    SnapshotContents? contents,
    BackupDescriptor? descriptor,
    RestorePreview? restorePreview,
    BackupFailure? error,
    bool? cleanupPending,
    bool resetProgress = false,
    bool clearError = false,
    BackupPhase? failedAtPhase,
  }) => BackupJobState(
    operationId: operationId,
    kind: kind,
    phase: phase ?? this.phase,
    startedAtUtc: startedAtUtc,
    contentCreatedAtUtc: contentCreatedAtUtc ?? this.contentCreatedAtUtc,
    completedAtUtc: completedAtUtc ?? this.completedAtUtc,
    completedBytes: resetProgress
        ? completedBytes
        : completedBytes ?? this.completedBytes,
    totalBytes: resetProgress ? totalBytes : totalBytes ?? this.totalBytes,
    completedFiles: resetProgress
        ? completedFiles
        : completedFiles ?? this.completedFiles,
    totalFiles: resetProgress ? totalFiles : totalFiles ?? this.totalFiles,
    reusedFiles: reusedFiles ?? this.reusedFiles,
    reusedBytes: reusedBytes ?? this.reusedBytes,
    uploadBytes: uploadBytes ?? this.uploadBytes,
    currentItem: resetProgress ? currentItem : currentItem ?? this.currentItem,
    contents: contents ?? this.contents,
    descriptor: descriptor ?? this.descriptor,
    restorePreview: restorePreview ?? this.restorePreview,
    error: clearError ? null : error ?? this.error,
    cleanupPending: cleanupPending ?? this.cleanupPending,
    sequence: sequence + 1,
    failedAtPhase: failedAtPhase ?? this.failedAtPhase,
  );
}
