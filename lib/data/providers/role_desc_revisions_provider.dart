import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/role_desc_revision.dart';
import 'role_repository_provider.dart';

part 'role_desc_revisions_provider.g.dart';

/// 单个角色的设定修订列表，新的在前。
@riverpod
Stream<List<RoleDescRevision>> roleDescRevisions(Ref ref, int roleId) {
  return ref.watch(roleRepositoryProvider).watchDescRevisions(roleId);
}
