import '../models/role_relationship.dart';

/// OC 关系仓储。只暴露领域 [RoleRelationship]，不出现 Drift 类型。
abstract interface class RoleRelationshipRepository {
  /// 某角色作为任一端参与的全部关系，新的在前。
  Stream<List<RoleRelationship>> watchForRole(int roleId);
  Future<List<RoleRelationship>> listForRole(int roleId);

  /// 两端必须是不同的已保存角色，文案 trim 后非空且不超过
  /// [relationshipLabelMaxLength]；否则抛 [StateError]（角色缺失，文案区分
  /// 当前角色与对方）或 [FormatException]（文案不合法）。
  Future<RoleRelationship> create({
    required int fromRoleId,
    required int toRoleId,
    required String fromLabel,
    required String toLabel,
  });

  /// 按 [RoleRelationship.id] 全量更新两端与文案；校验同 [create]。
  Future<RoleRelationship> update(RoleRelationship relationship);

  /// [roleId] 必须是这条关系的一端，否则不删除任何数据。
  /// 返回是否真的删掉了一行；目标不存在时返回 `false` 而不报错。
  Future<bool> delete({required int roleId, required int relationshipId});
}
