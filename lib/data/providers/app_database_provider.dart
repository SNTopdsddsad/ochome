import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/app_database.dart';

part 'app_database_provider.g.dart';

/// 进程内共享的 [AppDatabase]。恢复前必须 `close` 再 `invalidate`。
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}
