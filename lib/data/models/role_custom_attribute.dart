/// 一个角色自定义的文本属性，顺序由所属角色的属性列表决定。
class RoleCustomAttribute {
  const RoleCustomAttribute({required this.name, required this.content});

  final String name;
  final String content;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is RoleCustomAttribute &&
            other.name == name &&
            other.content == content;
  }

  @override
  int get hashCode => Object.hash(name, content);
}
