import '../models/role.dart';
import '../models/role_custom_attribute.dart';
import '../models/role_desc_revision.dart';

/// 角色仓储接口。
///
/// 只暴露领域 [Role]，不出现 Drift 的 `AppDatabase` / `RolesCompanion`。
/// 页面通过 `roleRepositoryProvider` 获取本接口；测试时可 override 换成假实现。
abstract interface class RoleRepository {
  /// 返回全部角色，按数据库当前顺序。
  Future<List<Role>> list();

  /// 按主键查询；不存在时返回 `null`。
  Future<Role?> getById(int id);

  /// 插入一条角色，并返回带自增 [Role.id] 的完整记录。
  Future<Role> create({
    required String name,
    required String sex,
    required String age,
    required String birthday,
    required String race,
    required String occupation,
    required String desc,
    required String coverImg,
    List<RoleCustomAttribute> customAttributes = const [],
    int? worldId,
  });

  /// 按 [Role.id] 全量更新。
  ///
  /// 找不到对应行时抛出 [StateError]。
  Future<Role> update(Role role);

  /// 按主键删除。目标不存在时不报错。
  Future<void> delete(int id);

  /// 监听全部角色；表数据变化时重新发出列表。
  Stream<List<Role>> watchAll();

  /// 监听归属某世界观的角色；表数据变化时重新发出列表。
  Stream<List<Role>> watchByWorld(int worldId);

  /// 某角色设定修订，新的在前。
  Stream<List<RoleDescRevision>> watchDescRevisions(int roleId);

  /// 某角色设定修订快照，新的在前。
  Future<List<RoleDescRevision>> listDescRevisions(int roleId);

  /// 把 [revisionId] 写回当前设定，并追加一条新修订。
  ///
  /// 找不到角色或修订时抛 [StateError]。正文未变则原样返回。
  Future<Role> restoreDescRevision({
    required int roleId,
    required int revisionId,
  });
}
