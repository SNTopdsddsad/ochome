import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../repositories/drift_role_repository.dart';
import '../repositories/role_repository.dart';
import 'app_database_provider.dart';

part 'role_repository_provider.g.dart';

/// 对外只提供 [RoleRepository]，默认实现为 [DriftRoleRepository]。
///
/// 页面应 `ref.watch/read(roleRepositoryProvider)`，不要直接 new 实现类。
/// 测试时 `overrideWithValue` 即可换成假实现。
@Riverpod(keepAlive: true)
RoleRepository roleRepository(Ref ref) {
  return DriftRoleRepository(ref.watch(appDatabaseProvider));
}
