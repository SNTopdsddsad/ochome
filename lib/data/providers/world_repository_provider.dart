import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../repositories/drift_world_repository.dart';
import '../repositories/world_repository.dart';
import 'app_database_provider.dart';

part 'world_repository_provider.g.dart';

/// 对外只提供 [WorldRepository]，默认实现为 [DriftWorldRepository]。
///
/// 页面应 `ref.watch/read(worldRepositoryProvider)`，不要直接 new 实现类。
/// 测试时 `overrideWithValue` 即可换成假实现。
@Riverpod(keepAlive: true)
WorldRepository worldRepository(Ref ref) {
  return DriftWorldRepository(ref.watch(appDatabaseProvider));
}
