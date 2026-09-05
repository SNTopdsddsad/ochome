import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
// hide Drift 生成的 Role，测试里只用领域模型。
import 'package:ochome/data/database/app_database.dart' hide Role;
import 'package:ochome/data/models/role.dart';
import 'package:ochome/data/models/role_custom_attribute.dart';
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

  Future<Role> insertSample({
    String name = 'Ada',
    List<RoleCustomAttribute> customAttributes = const [],
  }) {
    return repository.create(
      name: name,
      sex: 'female',
      age: '17',
      birthday: birthday,
      race: 'human',
      occupation: 'engineer',
      desc: 'sample',
      coverImg: 'covers/ada.png',
      customAttributes: customAttributes,
    );
  }

  Role editedRole(
    Role role, {
    List<RoleCustomAttribute>? customAttributes,
    String? desc,
  }) {
    return Role(
      id: role.id,
      name: role.name,
      sex: role.sex,
      age: role.age,
      birthday: role.birthday,
      race: role.race,
      occupation: role.occupation,
      desc: desc ?? role.desc,
      coverImg: role.coverImg,
      customAttributes: customAttributes ?? role.customAttributes,
    );
  }

  test('create and getById persist a role', () async {
    final created = await insertSample();

    expect(created.id, greaterThan(0));
    expect(created.name, 'Ada');
    expect(created.coverImg, 'covers/ada.png');
    expect(created.customAttributes, isEmpty);

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

  test(
    'restoreDescRevision writes current 设定 and appends a revision',
    () async {
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
      final first = (await repository.listDescRevisions(created.id)).last;

      final restored = await repository.restoreDescRevision(
        roleId: created.id,
        revisionId: first.id,
      );

      expect(restored.desc, 'sample');
      final revisions = await repository.listDescRevisions(created.id);
      expect(revisions.first.content, 'sample');
      expect(revisions.map((item) => item.content), [
        'sample',
        'rewritten',
        'sample',
      ]);
    },
  );

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

  group('custom attributes', () {
    const attributes = [
      RoleCustomAttribute(name: '魔法属性', content: '冰 ❄️'),
      RoleCustomAttribute(name: '能力代价', content: '失去记忆\n  留下痕迹'),
      RoleCustomAttribute(name: '待补充', content: ''),
    ];

    test(
      'persist ordered Unicode, multiline and empty content snapshots',
      () async {
        final input = attributes.toList();
        final pending = insertSample(customAttributes: input);
        input.clear();
        final created = await pending;

        expect(created.customAttributes, attributes);
        expect(
          (await repository.getById(created.id))!.customAttributes,
          attributes,
        );
        expect((await repository.list()).single.customAttributes, attributes);
        expect(() => created.customAttributes.clear(), throwsUnsupportedError);
      },
    );

    test(
      'trim outside whitespace, keep duplicate names and internal lines',
      () async {
        final created = await insertSample(
          customAttributes: const [
            RoleCustomAttribute(name: ' 魔法属性\n', content: ' 冰\n 火 '),
            RoleCustomAttribute(name: '魔法属性', content: '   '),
          ],
        );
        expect(created.customAttributes, const [
          RoleCustomAttribute(name: '魔法属性', content: '冰\n 火'),
          RoleCustomAttribute(name: '魔法属性', content: ''),
        ]);
      },
    );

    test(
      'update preserves pairs and isolation without a new desc revision',
      () async {
        final first = await insertSample(customAttributes: attributes);
        final second = await insertSample(
          name: 'Bob',
          customAttributes: attributes,
        );
        final changed = [
          attributes.last,
          const RoleCustomAttribute(name: '冰系魔法', content: '霜\n雪'),
        ];
        final expected = List<RoleCustomAttribute>.of(changed);
        final pending = repository.update(
          editedRole(first, customAttributes: changed),
        );
        changed.clear();
        final updated = await pending;

        expect(updated.customAttributes, expected);
        expect(await repository.getById(second.id), second);
        expect(
          (await repository.getById(first.id))!.customAttributes,
          expected,
        );
        expect(await repository.listDescRevisions(first.id), hasLength(1));
        expect(updated, editedRole(first, customAttributes: expected));
        expect(
          updated.hashCode,
          editedRole(first, customAttributes: expected).hashCode,
        );
        expect(
          updated,
          isNot(
            editedRole(first, customAttributes: expected.reversed.toList()),
          ),
        );

        await repository.update(
          editedRole(updated, customAttributes: const []),
        );
        expect((await repository.getById(first.id))!.customAttributes, isEmpty);
      },
    );

    test(
      'invalid names fail create and update before modifying saved data',
      () async {
        const invalid = [RoleCustomAttribute(name: ' \n\t ', content: 'ice')];
        await expectLater(
          insertSample(customAttributes: invalid),
          throwsArgumentError,
        );
        expect(await repository.list(), isEmpty);

        final created = await insertSample(customAttributes: attributes);
        await expectLater(
          repository.update(
            editedRole(created, customAttributes: invalid, desc: 'changed'),
          ),
          throwsArgumentError,
        );
        expect(await repository.getById(created.id), created);
        expect(await repository.listDescRevisions(created.id), hasLength(1));
      },
    );

    test(
      'restoring a desc revision retains the latest saved attributes',
      () async {
        final created = await insertSample(customAttributes: attributes);
        final updated = await repository.update(
          editedRole(
            created,
            desc: 'rewritten',
            customAttributes: attributes.reversed.toList(),
          ),
        );
        final original = (await repository.listDescRevisions(created.id)).last;
        final restored = await repository.restoreDescRevision(
          roleId: created.id,
          revisionId: original.id,
        );
        expect(restored.desc, created.desc);
        expect(restored.customAttributes, updated.customAttributes);
        expect(
          (await repository.getById(created.id))!.customAttributes,
          updated.customAttributes,
        );
      },
    );

    test('watchAll emits custom attribute changes', () async {
      final created = await insertSample();
      final seen = expectLater(
        repository.watchAll(),
        emitsThrough(
          isA<List<Role>>().having(
            (roles) => roles.single.customAttributes,
            'custom attributes',
            attributes,
          ),
        ),
      );
      await repository.update(
        editedRole(created, customAttributes: attributes),
      );
      await seen;
    });

    for (final malformed in [
      'not json',
      '{}',
      '[null]',
      '[{"name":"magic"}]',
      '[{"name":1,"content":"ice"}]',
      '[{"name":"magic","content":false}]',
      '[{"name":"magic","content":"ice","extra":1}]',
      '[{"name":" ","content":"ice"}]',
    ]) {
      test('malformed saved attributes are surfaced: $malformed', () async {
        final created = await insertSample(customAttributes: attributes);
        await database.customStatement(
          'UPDATE role SET custom_attributes = ? WHERE id = ?',
          [malformed, created.id],
        );
        await expectLater(
          repository.getById(created.id),
          throwsFormatException,
        );
        await expectLater(repository.list(), throwsFormatException);
        await expectLater(repository.watchAll().first, throwsFormatException);
        await expectLater(repository.update(created), throwsFormatException);
        final row = await database
            .customSelect('SELECT custom_attributes FROM role')
            .getSingle();
        expect(row.read<String>('custom_attributes'), malformed);
      });
    }
  });
}
