import 'dart:async';

import 'package:ochome/data/models/role.dart';
import 'package:ochome/data/repositories/role_repository.dart';

/// 列表 / 表单测试用的内存假实现，不碰 Drift。
class FakeRoleRepository implements RoleRepository {
  FakeRoleRepository([List<Role> roles = const []])
    : _roles = List<Role>.of(roles) {
    for (final role in _roles) {
      if (role.id >= _nextId) {
        _nextId = role.id + 1;
      }
    }
  }

  final List<Role> _roles;
  final _controller = StreamController<List<Role>>.broadcast();
  var _nextId = 1;

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(List<Role>.from(_roles));
    }
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
  }) async {
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
    );
    _roles.add(role);
    _emit();
    return role;
  }

  @override
  Future<Role> update(Role role) async {
    final index = _roles.indexWhere((item) => item.id == role.id);
    if (index < 0) {
      throw StateError('Role ${role.id} not found');
    }
    _roles[index] = role;
    _emit();
    return role;
  }

  @override
  Future<void> delete(int id) async {
    _roles.removeWhere((item) => item.id == id);
    _emit();
  }

  @override
  Stream<List<Role>> watchAll() async* {
    yield List<Role>.from(_roles);
    yield* _controller.stream;
  }
}
