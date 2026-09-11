import 'dart:async';

import 'package:ochome/data/models/world.dart';
import 'package:ochome/data/models/world_entry.dart';
import 'package:ochome/data/repositories/world_repository.dart';

/// 列表 / 表单测试用的内存假实现，不碰 Drift。
class FakeWorldRepository implements WorldRepository {
  FakeWorldRepository([List<World> worlds = const []])
    : _worlds = List<World>.of(worlds) {
    for (final world in _worlds) {
      if (world.id >= _nextId) {
        _nextId = world.id + 1;
      }
    }
  }

  final List<World> _worlds;
  final _controller = StreamController<List<World>>.broadcast();
  var _nextId = 1;

  /// 测试可让下一次写入失败，验证表单保留草稿。
  Object? nextWriteError;

  /// 删除过的 id，供测试断言。
  final deletedIds = <int>[];

  /// 删除世界观时的回调，测试里用来联动 `FakeRoleRepository.detachWorld`。
  void Function(int worldId)? onDelete;

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(List<World>.from(_worlds));
    }
  }

  void _throwIfArmed() {
    final error = nextWriteError;
    if (error != null) {
      nextWriteError = null;
      throw error;
    }
  }

  @override
  Future<List<World>> list() async => List<World>.from(_worlds);

  @override
  Future<World?> getById(int id) async {
    for (final world in _worlds) {
      if (world.id == id) {
        return world;
      }
    }
    return null;
  }

  @override
  Future<World> create({
    required String name,
    required String summary,
    required String coverImg,
    List<WorldEntry> entries = const [],
  }) async {
    _throwIfArmed();
    final world = World(
      id: _nextId++,
      name: _requireName(name),
      summary: summary.trim(),
      coverImg: coverImg,
      entries: _entriesForWrite(entries),
    );
    _worlds.add(world);
    _emit();
    return world;
  }

  @override
  Future<World> update(World world) async {
    _throwIfArmed();
    final index = _worlds.indexWhere((item) => item.id == world.id);
    if (index < 0) {
      throw StateError('World ${world.id} not found');
    }
    final saved = World(
      id: world.id,
      name: _requireName(world.name),
      summary: world.summary.trim(),
      coverImg: world.coverImg,
      entries: _entriesForWrite(world.entries),
    );
    _worlds[index] = saved;
    _emit();
    return saved;
  }

  @override
  Future<void> delete(int id) async {
    _throwIfArmed();
    _worlds.removeWhere((item) => item.id == id);
    deletedIds.add(id);
    onDelete?.call(id);
    _emit();
  }

  @override
  Stream<List<World>> watchAll() async* {
    yield List<World>.from(_worlds);
    yield* _controller.stream;
  }

  String _requireName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', '世界观名称不能为空');
    }
    return trimmed;
  }

  List<WorldEntry> _entriesForWrite(List<WorldEntry> entries) {
    return List.unmodifiable(
      entries.map((entry) {
        final title = entry.title.trim();
        if (title.isEmpty) {
          throw ArgumentError.value(entry.title, 'title', '词条标题不能为空');
        }
        return WorldEntry(title: title, content: entry.content.trim());
      }),
    );
  }
}
