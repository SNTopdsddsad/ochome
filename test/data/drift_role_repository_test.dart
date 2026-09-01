import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
// hide Drift 生成的 Role，测试里只用领域模型。
import 'package:ochome/data/database/app_database.dart' hide Role;
import 'package:ochome/data/models/role.dart';
import 'package:ochome/data/repositories/drift_role_repository.dart';

void main() {
  late AppDatabase database;
  late DriftRoleRepository repository;

  setUp(() {
    // 内存库，不写磁盘，用例之间互不影响。
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftRoleRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  final birthday = DateTime.utc(1990, 5, 20);

  Future<Role> insertSample({String name = 'Ada'}) {
    return repository.create(
      name: name,
      sex: 'female',
      birthday: birthday,
      occupation: 'engineer',
      desc: 'sample',
    );
  }

  test('create and getById persist a role', () async {
    final created = await insertSample();

    expect(created.id, greaterThan(0));
    expect(created.name, 'Ada');

    final loaded = await repository.getById(created.id);
    expect(loaded, created);
  });

  test('list returns all roles', () async {
    await insertSample(name: 'Ada');
    await insertSample(name: 'Bob');

    final roles = await repository.list();
    expect(roles.map((role) => role.name), ['Ada', 'Bob']);
  });

  test('update changes fields and throws when missing', () async {
    final created = await insertSample();
    final updated = await repository.update(
      Role(
        id: created.id,
        name: 'Ada Lovelace',
        sex: created.sex,
        birthday: created.birthday,
        occupation: 'mathematician',
        desc: created.desc,
      ),
    );

    expect(updated.name, 'Ada Lovelace');
    expect(updated.occupation, 'mathematician');

    expect(
      () => repository.update(
        Role(
          id: 999,
          name: 'Ghost',
          sex: 'female',
          birthday: birthday,
          occupation: 'none',
          desc: '',
        ),
      ),
      throwsStateError,
    );
  });

  test('delete removes a role', () async {
    final created = await insertSample();
    await repository.delete(created.id);

    expect(await repository.getById(created.id), isNull);
    expect(await repository.list(), isEmpty);
  });

  test('watchAll emits after inserts', () async {
    final seen = expectLater(
      repository.watchAll(),
      emitsThrough(
        isA<List<Role>>().having((roles) => roles.single.name, 'name', 'Ada'),
      ),
    );

    await insertSample();
    await seen;
  });
}
