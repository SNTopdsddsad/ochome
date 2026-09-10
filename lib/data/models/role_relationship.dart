import 'package:characters/characters.dart';

/// 两个 OC 之间的一条有向关系。
///
/// 一行同时保存两个视角的文案：[fromLabel] 表示 `from 是 to 的 ___`，
/// [toLabel] 表示 `to 是 from 的 ___`。两端页面共用同一行，通过
/// [otherRoleId] / [selfLabel] / [otherLabel] 按当前角色视角读取。
class RoleRelationship {
  const RoleRelationship({
    required this.id,
    required this.fromRoleId,
    required this.toRoleId,
    required this.fromLabel,
    required this.toLabel,
    required this.createdAt,
  });

  final int id;
  final int fromRoleId;
  final int toRoleId;
  final String fromLabel;
  final String toLabel;
  final DateTime createdAt;

  bool involves(int roleId) => roleId == fromRoleId || roleId == toRoleId;

  /// 从 [selfRoleId] 视角看，对方是谁。
  int otherRoleId(int selfRoleId) => _assertSide(selfRoleId) == fromRoleId
      ? toRoleId
      : fromRoleId;

  /// 从 [selfRoleId] 视角：我是对方的 ___。
  String selfLabel(int selfRoleId) => _assertSide(selfRoleId) == fromRoleId
      ? fromLabel
      : toLabel;

  /// 从 [selfRoleId] 视角：对方是我的 ___。
  String otherLabel(int selfRoleId) => _assertSide(selfRoleId) == fromRoleId
      ? toLabel
      : fromLabel;

  int _assertSide(int roleId) {
    if (!involves(roleId)) {
      throw ArgumentError.value(roleId, 'roleId', '不属于这条关系');
    }
    return roleId;
  }

  RoleRelationship copyWith({
    int? fromRoleId,
    int? toRoleId,
    String? fromLabel,
    String? toLabel,
  }) => RoleRelationship(
    id: id,
    fromRoleId: fromRoleId ?? this.fromRoleId,
    toRoleId: toRoleId ?? this.toRoleId,
    fromLabel: fromLabel ?? this.fromLabel,
    toLabel: toLabel ?? this.toLabel,
    createdAt: createdAt,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoleRelationship &&
          other.id == id &&
          other.fromRoleId == fromRoleId &&
          other.toRoleId == toRoleId &&
          other.fromLabel == fromLabel &&
          other.toLabel == toLabel &&
          other.createdAt == createdAt;

  @override
  int get hashCode =>
      Object.hash(id, fromRoleId, toRoleId, fromLabel, toLabel, createdAt);
}

/// 单段关系文案的最大字数（按用户可见字符计）。
const int relationshipLabelMaxLength = 30;

/// 关系文案的统一校验，编辑器和仓储共用。返回 trim 后的文案。
String normalizeRelationshipLabel(String raw) {
  final label = raw.trim();
  if (label.isEmpty) throw const FormatException('关系不能为空');
  if (label.contains('\n') || label.contains('\r')) {
    throw const FormatException('关系不能换行');
  }
  if (label.characters.length > relationshipLabelMaxLength) {
    throw const FormatException('关系最多 $relationshipLabelMaxLength 个字');
  }
  return label;
}

/// [normalizeRelationshipLabel] 的非抛出版本：合法返回 `null`，否则返回原因。
/// 编辑器用它做布尔判断，也可直接作为 `validator`。
String? validateRelationshipLabel(String? raw) {
  try {
    normalizeRelationshipLabel(raw ?? '');
    return null;
  } on FormatException catch (error) {
    return error.message;
  }
}
