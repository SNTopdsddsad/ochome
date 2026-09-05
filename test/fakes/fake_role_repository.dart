import 'dart:async';

import 'package:ochome/data/models/role.dart';
import 'package:ochome/data/models/role_custom_attribute.dart';
import 'package:ochome/data/models/role_desc_revision.dart';
import 'package:ochome/data/repositories/role_repository.dart';

/// 列表 / 表单测试用的内存假实现，不碰 Drift。
class FakeRoleRepository implements RoleRepository {
  FakeRoleRepository([List<Role> roles = const []])
    : _roles = List<Role>.of(roles) {
    for (final role in _roles) {
      if (role.id >= _nextId) {
        _nextId = role.id + 1;
      }
      if (role.desc.isNotEmpty) {
        _appendDescRevision(role.id, role.desc);
      }
    }
  }

  final List<Role> _roles;
  final _revisions = <RoleDescRevision>[];
  final _controller = StreamController<List<Role>>.broadcast();
  final _revisionController =
      StreamController<List<RoleDescRevision>>.broadcast();
  var _nextId = 1;
  var _nextRevisionId = 1;

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(List<Role>.from(_roles));
    }
  }

  void _emitRevisions() {
    if (!_revisionController.isClosed) {
      _revisionController.add(List<RoleDescRevision>.from(_revisions));
    }
  }

  List<RoleDescRevision> _revisionsFor(int roleId) {
    final items = _revisions.where((item) => item.roleId == roleId).toList()
      ..sort((a, b) {
        final byTime = b.createdAt.compareTo(a.createdAt);
        if (byTime != 0) {
          return byTime;
        }
        return b.id.compareTo(a.id);
      });
    return items;
  }

  void _appendDescRevision(int roleId, String content) {
    _revisions.add(
      RoleDescRevision(
        id: _nextRevisionId++,
        roleId: roleId,
        content: content,
        createdAt: DateTime.now(),
      ),
    );
    _emitRevisions();
  }

  @override
  Future<List<Role>> list() async => List<Role>.from(_roles);

  @override
  Future<Role?> getById(int id) async {
    for (final role in _roles) {
      if (role.id == id) {
        return role;
      }
    }
    return null;
  }

  @override
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
  }) async {
    final attributes = _attributesForWrite(customAttributes);
    final role = Role(
      id: _nextId++,
      name: name,
      sex: sex,
      age: age,
      birthday: birthday,
      race: race,
      occupation: occupation,
      desc: desc,
      coverImg: coverImg,
      customAttributes: attributes,
    );
    _roles.add(role);
    if (desc.isNotEmpty) {
      _appendDescRevision(role.id, desc);
    }
    _emit();
    return role;
  }

  @override
  Future<Role> update(Role role) async {
    final attributes = _attributesForWrite(role.customAttributes);
    final index = _roles.indexWhere((item) => item.id == role.id);
    if (index < 0) {
      throw StateError('Role ${role.id} not found');
    }
    final previous = _roles[index].desc;
    final saved = Role(
      id: role.id,
      name: role.name,
      sex: role.sex,
      age: role.age,
      birthday: role.birthday,
      race: role.race,
      occupation: role.occupation,
      desc: role.desc,
      coverImg: role.coverImg,
      customAttributes: attributes,
    );
    _roles[index] = saved;
    if (previous != role.desc) {
      _appendDescRevision(role.id, role.desc);
    }
    _emit();
    return saved;
  }

  List<RoleCustomAttribute> _attributesForWrite(
    List<RoleCustomAttribute> attributes,
  ) {
    return List.unmodifiable(
      attributes.map((attribute) {
        final name = attribute.name.trim();
        if (name.isEmpty) {
          throw ArgumentError.value(attribute.name, 'name', '属性名称不能为空');
        }
        return RoleCustomAttribute(
          name: name,
          content: attribute.content.trim(),
        );
      }),
    );
  }

  @override
  Future<void> delete(int id) async {
    _roles.removeWhere((item) => item.id == id);
    _revisions.removeWhere((item) => item.roleId == id);
    _emit();
    _emitRevisions();
  }

  @override
  Stream<List<Role>> watchAll() async* {
    yield List<Role>.from(_roles);
    yield* _controller.stream;
  }

  @override
  Stream<List<RoleDescRevision>> watchDescRevisions(int roleId) async* {
    yield _revisionsFor(roleId);
    await for (final _ in _revisionController.stream) {
      yield _revisionsFor(roleId);
    }
  }

  @override
  Future<List<RoleDescRevision>> listDescRevisions(int roleId) async {
    return _revisionsFor(roleId);
  }

  @override
  Future<Role> restoreDescRevision({
    required int roleId,
    required int revisionId,
  }) async {
    final role = await getById(roleId);
    if (role == null) {
      throw StateError('Role $roleId not found');
    }
    RoleDescRevision? revision;
    for (final item in _revisions) {
      if (item.id == revisionId && item.roleId == roleId) {
        revision = item;
        break;
      }
    }
    if (revision == null) {
      throw StateError('Desc revision $revisionId not found');
    }
    if (revision.content == role.desc) {
      return role;
    }
    return update(
      Role(
        id: role.id,
        name: role.name,
        sex: role.sex,
        age: role.age,
        birthday: role.birthday,
        race: role.race,
        occupation: role.occupation,
        desc: revision.content,
        coverImg: role.coverImg,
        customAttributes: role.customAttributes,
      ),
    );
  }
}
