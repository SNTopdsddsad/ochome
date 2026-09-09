import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/backup/backup_coordinator.dart';
import '../../features/backup/backup_models.dart';

/// Session-only feedback survives the router reset caused by dataset activation.
/// It is deliberately not persisted alongside the coordinator's job journal.
final backupCompletionFeedbackProvider =
    Provider.family<BackupCompletionFeedback, BackupCoordinator>((
      ref,
      coordinator,
    ) {
      final feedback = BackupCompletionFeedback(coordinator);
      ref.onDispose(feedback.dispose);
      return feedback;
    });

class BackupCompletionFeedback extends ChangeNotifier {
  BackupCompletionFeedback(BackupCoordinator coordinator)
    : _previous = coordinator.currentJob {
    _subscription = coordinator.watchJob().listen((job) {
      final before = _previous;
      _previous = job;
      if (!job.isTerminal) {
        _pending = null;
      } else if (job.phase == BackupPhase.completed &&
          before?.operationId == job.operationId &&
          before?.isTerminal == false) {
        _pending = job;
        _completedAt = DateTime.now();
        notifyListeners();
      }
    });
  }

  late final StreamSubscription<BackupJobState> _subscription;
  BackupJobState? _previous, _pending;
  DateTime? _completedAt;

  BackupJobState? takeCompletion() {
    final pending = _pending;
    _pending = null;
    // This bridges a route rebuild, not a historical notification inbox.
    if (_completedAt == null ||
        DateTime.now().difference(_completedAt!) >
            const Duration(seconds: 30)) {
      return null;
    }
    return pending;
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
