import '../models/world.dart';
import '../models/world_entry.dart';

/// 世界观仓储接口。
///
/// 只暴露领域 [World]，不出现 Drift 的 `AppDatabase` / `WorldsCompanion`。
/// 页面通过 `worldRepositoryProvider` 获取本接口；测试时可 override 换成假实现。
abstract interface class WorldRepository {
  /// 返回全部世界观，按数据库当前顺序。
  Future<List<World>> list();

  /// 按主键查询；不存在时返回 `null`。
  Future<World?> getById(int id);

  /// 插入一条世界观，并返回带自增 [World.id] 的完整记录。
  Future<World> create({
    required String name,
    required String summary,
    required String coverImg,
    List<WorldEntry> entries = const [],
  });

  /// 按 [World.id] 全量更新。找不到对应行时抛出 [StateError]。
  Future<World> update(World world);

  /// 按主键删除。目标不存在时不报错；归属角色由数据库置空 `worldId`，角色保留。
  Future<void> delete(int id);

  /// 监听全部世界观；表数据变化时重新发出列表。
  Stream<List<World>> watchAll();
}
