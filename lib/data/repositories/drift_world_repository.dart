import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/app_database.dart' as db;
import '../models/world.dart';
import '../models/world_entry.dart';
import 'world_repository.dart';

/// [WorldRepository] 的 Drift 实现。
///
/// [db] 前缀用来避开生成行类型 `db.World` 与领域模型 [World] 的命名冲突。
class DriftWorldRepository implements WorldRepository {
  DriftWorldRepository(this._db);

  final db.AppDatabase _db;

  @override
  Future<List<World>> list() async {
    final rows = await _db.select(_db.worlds).get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<World?> getById(int id) async {
    final row = await (_db.select(
      _db.worlds,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<World> create({
    required String name,
    required String summary,
    required String coverImg,
    List<WorldEntry> entries = const [],
  }) async {
    final trimmedName = _requireName(name);
    // 事务让出前先编码，调用方之后改列表不影响本次写入。
    final encodedEntries = _encodeEntries(entries);
    return _db.mutate(
      () => _db.transaction(() async {
        final row = await _db
            .into(_db.worlds)
            .insertReturning(
              db.WorldsCompanion.insert(
                name: trimmedName,
                summary: summary.trim(),
                coverImg: coverImg,
                entries: Value(encodedEntries),
              ),
            );
        return _toDomain(row);
      }),
    );
  }

  @override
  Future<World> update(World world) async {
    final trimmedName = _requireName(world.name);
    final encodedEntries = _encodeEntries(world.entries);
    return _db.mutate(
      () => _db.transaction(() async {
        final existing = await getById(world.id);
        if (existing == null) {
          throw StateError('World ${world.id} not found');
        }
        final updated =
            await (_db.update(
              _db.worlds,
            )..where((t) => t.id.equals(world.id))).writeReturning(
              db.WorldsCompanion(
                name: Value(trimmedName),
                summary: Value(world.summary.trim()),
                coverImg: Value(world.coverImg),
                entries: Value(encodedEntries),
              ),
            );
        return _toDomain(updated.first);
      }),
    );
  }

  @override
  Future<void> delete(int id) {
    // role.world_id 的 ON DELETE SET NULL 由 SQLite 处理（已开 foreign_keys）。
    return _db.mutate(
      () => (_db.delete(_db.worlds)..where((t) => t.id.equals(id))).go(),
    );
  }

  @override
  Stream<List<World>> watchAll() {
    return _db
        .select(_db.worlds)
        .watch()
        .map((rows) => rows.map(_toDomain).toList());
  }

  String _requireName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', '世界观名称不能为空');
    }
    return trimmed;
  }

  World _toDomain(db.World row) {
    return World(
      id: row.id,
      name: row.name,
      summary: row.summary,
      coverImg: row.coverImg,
      entries: _decodeEntries(row.entries),
    );
  }

  String _encodeEntries(List<WorldEntry> entries) {
    return jsonEncode(
      entries.map((entry) {
        final title = entry.title.trim();
        if (title.isEmpty) {
          throw ArgumentError.value(entry.title, 'title', '词条标题不能为空');
        }
        return {'title': title, 'content': entry.content.trim()};
      }).toList(),
    );
  }

  List<WorldEntry> _decodeEntries(String encoded) {
    final decoded = jsonDecode(encoded);
    if (decoded is! List) {
      throw const FormatException('世界观词条必须是数组');
    }
    return List<WorldEntry>.unmodifiable(
      decoded.map((item) {
        if (item is! Map<String, dynamic> ||
            item.length != 2 ||
            item['title'] is! String ||
            item['content'] is! String) {
          throw const FormatException('世界观词条必须包含文本标题和内容');
        }
        final title = item['title'] as String;
        if (title.trim().isEmpty) {
          throw const FormatException('世界观词条标题不能为空');
        }
        return WorldEntry(title: title, content: item['content'] as String);
      }),
    );
  }
}
