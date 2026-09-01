/// 恢复备份时的文件进度，给页面展示「第 y / 共 x、还剩 z、预估时间」。
class RestoreProgress {
  const RestoreProgress({
    required this.total,
    required this.current,
    required this.elapsed,
    this.phase = RestoreProgressPhase.downloading,
  });

  factory RestoreProgress.checking() {
    return const RestoreProgress(
      total: 0,
      current: 0,
      elapsed: Duration.zero,
      phase: RestoreProgressPhase.checking,
    );
  }

  factory RestoreProgress.writing() {
    return const RestoreProgress(
      total: 0,
      current: 0,
      elapsed: Duration.zero,
      phase: RestoreProgressPhase.writing,
    );
  }

  /// 要拷的文件总数（库 + 清单 + 立绘）。
  final int total;

  /// 正在处理的文件序号，从 1 开始。
  final int current;

  final Duration elapsed;
  final RestoreProgressPhase phase;

  /// 含当前这条，还没完成的数量。
  int get remaining {
    if (total <= 0) {
      return 0;
    }
    final left = total - current + 1;
    return left < 0 ? 0 : left;
  }

  double? get fraction {
    switch (phase) {
      case RestoreProgressPhase.checking:
        return 0;
      case RestoreProgressPhase.writing:
        return 1;
      case RestoreProgressPhase.downloading:
        if (total <= 0) {
          return 0;
        }
        return (current / total).clamp(0, 1);
    }
  }

  String get message {
    switch (phase) {
      case RestoreProgressPhase.checking:
        return '正在检查 iCloud…';
      case RestoreProgressPhase.writing:
        return '正在写入本机数据…';
      case RestoreProgressPhase.downloading:
        if (total <= 0) {
          return '正在恢复…';
        }
        return '共 $total 个文件，正在恢复第 $current 个，还剩 $remaining 个，$etaLabel';
    }
  }

  String get etaLabel {
    if (current <= 1 || remaining <= 0) {
      return current <= 1 ? '正在估算时间…' : '即将完成';
    }
    final completed = current - 1;
    final avgMs = elapsed.inMilliseconds / completed;
    final remainMs = avgMs * remaining;
    if (remainMs < 30000) {
      return '预估不到 1 分钟';
    }
    final minutes = (remainMs / 60000).ceil();
    return '预估约 $minutes 分钟';
  }
}

enum RestoreProgressPhase { checking, downloading, writing }
