import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/role.dart';
import 'database_switch_provider.dart';
import 'role_repository_provider.dart';

part 'roles_provider.g.dart';

/// 角色列表的响应式数据源，底层订阅 [RoleRepository.watchAll]。
@riverpod
Stream<List<Role>> roles(Ref ref) {
  if (ref.watch(databaseSwitchProvider)) return const Stream.empty();
  return ref.watch(roleRepositoryProvider).watchAll();
}
