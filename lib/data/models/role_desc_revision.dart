/// 角色设定的一版修订。
class RoleDescRevision {
  const RoleDescRevision({
    required this.id,
    required this.roleId,
    required this.content,
    required this.createdAt,
  });

  final int id;
  final int roleId;

  /// 这一版的设定全文。
  final String content;

  final DateTime createdAt;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is RoleDescRevision &&
            other.id == id &&
            other.roleId == roleId &&
            other.content == content &&
            other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(id, roleId, content, createdAt);
}
