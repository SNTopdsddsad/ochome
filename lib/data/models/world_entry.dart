/// 世界观里的一个词条（如 地理 / 势力 / 魔法体系），顺序由所属世界观的词条列表决定。
class WorldEntry {
  const WorldEntry({required this.title, required this.content});

  final String title;
  final String content;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is WorldEntry && other.title == title && other.content == content;
  }

  @override
  int get hashCode => Object.hash(title, content);
}
