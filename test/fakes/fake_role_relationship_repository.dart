import 'dart:async';

import 'package:ochome/data/models/role_relationship.dart';
import 'package:ochome/data/repositories/role_relationship_repository.dart';

/// 关系 Tab 测试用的内存假实现，不碰 Drift。
class FakeRoleRelationshipRepository implements RoleRelationshipRepository {
  FakeRoleRelationshipRepository([
    List<RoleRelationship> relationships = const [],
  ]) : items = [...relationships];

  final List<RoleRelationship> items;
  final changes = StreamController<void>.broadcast(sync: true);
  Completer<void>? pendingSave;
  bool failSave = false;
  int createCalls = 0;
  int updateCalls = 0;

  @override
  Future<List<RoleRelationship>> listForRole(int roleId) async =>
      items.where((item) => item.involves(roleId)).toList();

  @override
  Stream<List<RoleRelationship>> watchForRole(int roleId) async* {
    yield await listForRole(roleId);
    await for (final _ in changes.stream) {
      yield await listForRole(roleId);
    }
  }

  @override
  Future<RoleRelationship> create({
    required int fromRoleId,
    required int toRoleId,
    required String fromLabel,
    required String toLabel,
  }) async {
    createCalls++;
    if (pendingSave != null) await pendingSave!.future;
    if (failSave) throw StateError('模拟写入失败');
    final id = items.fold(0, (max, item) => item.id > max ? item.id : max) + 1;
    final created = RoleRelationship(
      id: id,
      fromRoleId: fromRoleId,
      toRoleId: toRoleId,
      fromLabel: normalizeRelationshipLabel(fromLabel),
      toLabel: normalizeRelationshipLabel(toLabel),
      createdAt: DateTime(2026, 9, 10),
    );
    items.insert(0, created);
    changes.add(null);
    return created;
  }

  @override
  Future<RoleRelationship> update(RoleRelationship relationship) async {
    updateCalls++;
    if (pendingSave != null) await pendingSave!.future;
    if (failSave) throw StateError('模拟写入失败');
    final index = items.indexWhere((item) => item.id == relationship.id);
    if (index == -1) throw StateError('关系不存在');
    final saved = relationship.copyWith(
      fromLabel: normalizeRelationshipLabel(relationship.fromLabel),
      toLabel: normalizeRelationshipLabel(relationship.toLabel),
    );
    items[index] = saved;
    changes.add(null);
    return saved;
  }

  @override
  Future<bool> delete({
    required int roleId,
    required int relationshipId,
  }) async {
    final before = items.length;
    items.removeWhere(
      (item) => item.id == relationshipId && item.involves(roleId),
    );
    changes.add(null);
    return items.length < before;
  }

  Future<void> dispose() => changes.close();
}
