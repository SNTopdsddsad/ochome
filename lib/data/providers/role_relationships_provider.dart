import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/role_relationship.dart';
import '../repositories/drift_role_relationship_repository.dart';
import '../repositories/role_relationship_repository.dart';
import 'app_database_provider.dart';
import 'database_switch_provider.dart';

final roleRelationshipRepositoryProvider = Provider<RoleRelationshipRepository>(
  (ref) => DriftRoleRelationshipRepository(ref.watch(appDatabaseProvider)),
);

/// 某角色参与的全部关系；数据库切换期间停止订阅。
final roleRelationshipsProvider = StreamProvider.autoDispose
    .family<List<RoleRelationship>, int>((ref, roleId) {
      if (ref.watch(databaseSwitchProvider)) return const Stream.empty();
      return ref.watch(roleRelationshipRepositoryProvider).watchForRole(roleId);
    });
