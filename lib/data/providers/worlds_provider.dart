import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/role.dart';
import '../models/world.dart';
import 'database_switch_provider.dart';
import 'role_repository_provider.dart';
import 'world_repository_provider.dart';

part 'worlds_provider.g.dart';

/// 世界观列表的响应式数据源，底层订阅 [WorldRepository.watchAll]。
@riverpod
Stream<List<World>> worlds(Ref ref) {
  if (ref.watch(databaseSwitchProvider)) return const Stream.empty();
  return ref.watch(worldRepositoryProvider).watchAll();
}

/// 归属某世界观的角色，供世界观编辑页「角色」页签使用。
@riverpod
Stream<List<Role>> rolesInWorld(Ref ref, int worldId) {
  if (ref.watch(databaseSwitchProvider)) return const Stream.empty();
  return ref.watch(roleRepositoryProvider).watchByWorld(worldId);
}
