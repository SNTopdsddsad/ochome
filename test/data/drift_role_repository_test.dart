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

  const birthday = '1990-05-20';

  Future<Role> insertSample({String name = 'Ada'}) {
    return repository.create(
      name: name,
      sex: 'female',
      age: '17',
      birthday: birthday,
      race: 'human',
      occupation: 'engineer',
      desc: 'sample',
      coverImg: 'covers/ada.png',
    );
  }

  test('create and getById persist a role', () async {
    final created = await insertSample();

    expect(created.id, greaterThan(0));
    expect(created.name, 'Ada');
    expect(created.coverImg, 'covers/ada.png');

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
        age: created.age,
        birthday: created.birthday,
        race: created.race,
        occupation: 'mathematician',
        desc: created.desc,
        coverImg: created.coverImg,
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
          age: '',
          birthday: birthday,
          race: '',
          occupation: 'none',
          desc: '',
          coverImg: '',
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

  test('create stores a desc revision when 设定 is not empty', () async {
    final created = await insertSample();
    final revisions = await repository.listDescRevisions(created.id);

    expect(revisions, hasLength(1));
    expect(revisions.single.content, 'sample');
    expect(revisions.single.roleId, created.id);
  });

  test('create skips desc revision when 设定 is empty', () async {
    final created = await repository.create(
      name: 'Empty',
      sex: '',
      age: '',
      birthday: birthday,
      race: '',
      occupation: '',
      desc: '',
      coverImg: '',
    );

    expect(await repository.listDescRevisions(created.id), isEmpty);
  });

  test('update appends a desc revision only when 设定 changes', () async {
    final created = await insertSample();

    await repository.update(
      Role(
        id: created.id,
        name: 'Ada Lovelace',
        sex: created.sex,
        age: created.age,
        birthday: created.birthday,
        race: created.race,
        occupation: created.occupation,
        desc: created.desc,
        coverImg: created.coverImg,
      ),
    );
    expect(await repository.listDescRevisions(created.id), hasLength(1));

    await repository.update(
      Role(
        id: created.id,
        name: 'Ada Lovelace',
        sex: created.sex,
        age: created.age,
        birthday: created.birthday,
        race: created.race,
        occupation: created.occupation,
        desc: 'rewritten',
        coverImg: created.coverImg,
      ),
    );
    final revisions = await repository.listDescRevisions(created.id);
    expect(revisions.map((item) => item.content), ['rewritten', 'sample']);
  });

  test('restoreDescRevision writes current 设定 and appends a revision', () async {
    final created = await insertSample();
    await repository.update(
      Role(
        id: created.id,
        name: created.name,
        sex: created.sex,
        age: created.age,
        birthday: created.birthday,
        race: created.race,
        occupation: created.occupation,
        desc: 'rewritten',
        coverImg: created.coverImg,
      ),
    );
    final first = (await repository.listDescRevisions(
      created.id,
    )).last;

    final restored = await repository.restoreDescRevision(
      roleId: created.id,
      revisionId: first.id,
    );

    expect(restored.desc, 'sample');
    final revisions = await repository.listDescRevisions(created.id);
    expect(revisions.first.content, 'sample');
    expect(revisions.map((item) => item.content), ['sample', 'rewritten', 'sample']);
  });

  test('delete role also removes desc revisions', () async {
    final created = await insertSample();
    await repository.delete(created.id);

    expect(await repository.listDescRevisions(created.id), isEmpty);
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
