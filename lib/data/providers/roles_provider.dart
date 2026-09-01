import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/role.dart';
import 'role_repository_provider.dart';

part 'roles_provider.g.dart';

/// 角色列表的响应式数据源，底层订阅 [RoleRepository.watchAll]。
@riverpod
Stream<List<Role>> roles(Ref ref) {
  return ref.watch(roleRepositoryProvider).watchAll();
}
