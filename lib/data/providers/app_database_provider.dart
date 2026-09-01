import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/app_database.dart';

part 'app_database_provider.g.dart';

/// 进程内共享的 [AppDatabase]。
///
/// [keepAlive] 避免页面销毁后反复开关库；[Ref.onDispose] 在 ProviderScope
/// 拆除时关闭连接。测试可传入 `NativeDatabase.memory()` 覆盖本 provider。
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}
