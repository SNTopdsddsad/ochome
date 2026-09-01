import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/data/services/restore_progress.dart';

void main() {
  test('formats file counts and remaining', () {
    const progress = RestoreProgress(
      total: 10,
      current: 3,
      elapsed: Duration(seconds: 20),
    );
    expect(progress.remaining, 8);
    expect(
      progress.message,
      contains('共 10 个文件，正在恢复第 3 个，还剩 8 个'),
    );
    expect(progress.fraction, 0.3);
  });

  test('estimates minutes from elapsed time', () {
    const progress = RestoreProgress(
      total: 10,
      current: 3,
      elapsed: Duration(minutes: 2),
    );
    expect(progress.etaLabel, '预估约 8 分钟');
  });

  test('first file has no estimate yet', () {
    const progress = RestoreProgress(
      total: 5,
      current: 1,
      elapsed: Duration.zero,
    );
    expect(progress.etaLabel, '正在估算时间…');
    expect(progress.message, contains('正在估算时间'));
  });

  test('short remaining shows under one minute', () {
    const progress = RestoreProgress(
      total: 4,
      current: 3,
      elapsed: Duration(seconds: 4),
    );
    expect(progress.etaLabel, '预估不到 1 分钟');
  });
}
