import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/data/database/app_database.dart' hide Role;
import 'package:ochome/data/models/role_custom_attribute.dart';
import 'package:ochome/data/repositories/drift_role_repository.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'role_attributes_migration',
    );
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  for (final version in [3, 4, 5, 6]) {
    test(
      'schema $version upgrades while preserving role data and history',
      () async {
        final file = File(p.join(tempDir.path, 'v$version.sqlite'));
        _seedOldDatabase(file, version);
        final database = AppDatabase(NativeDatabase(file));
        addTearDown(database.close);
        final repository = DriftRoleRepository(database);

        final role = (await repository.list()).single;
        expect(role.id, 7);
        expect(role.name, '旧角色');
        expect(role.sex, '未知');
        expect(role.age, version >= 4 ? '约三百岁' : '');
        expect(role.birthday, '三月三日');
        expect(role.race, version >= 4 ? '精灵' : '');
        expect(role.occupation, '守林人');
        expect(role.desc, '当前设定\n第二行');
        expect(role.coverImg, 'covers/old.png');
        expect(role.customAttributes, isEmpty);
        final history = await repository.listDescRevisions(role.id);
        expect(
          history.map((revision) => revision.content),
          version >= 5 ? ['当前设定\n第二行', '最初设定'] : ['当前设定\n第二行'],
        );
        if (version >= 5) {
          expect(history.map((revision) => revision.id), [12, 11]);
          expect(
            history.last.createdAt,
            DateTime.fromMillisecondsSinceEpoch(1700000000000),
          );
        }
        final schema = await database
            .customSelect('PRAGMA user_version')
            .getSingle();
        expect(schema.data.values.single, AppDatabase.currentSchemaVersion);

        final added = await repository.create(
          name: '新角色',
          sex: '',
          age: '',
          birthday: '',
          race: '',
          occupation: '',
          desc: '',
          coverImg: '',
          customAttributes: const [
            RoleCustomAttribute(name: '魔法属性', content: '冰'),
          ],
        );
        expect(added.customAttributes.single.content, '冰');
        expect((await repository.getById(role.id))!.customAttributes, isEmpty);
      },
    );
  }

  test('schema 2 rebuild uses the new column once and retains the existing rebuild policy', () async {
    final file = File(p.join(tempDir.path, 'v2.sqlite'));
    _seedOldDatabase(file, 2);
    final database = AppDatabase(NativeDatabase(file));
    addTearDown(database.close);
    final repository = DriftRoleRepository(database);
    expect(await repository.list(), isEmpty);
    final created = await repository.create(
      name: '重建后',
      sex: '',
      age: '',
      birthday: '',
      race: '',
      occupation: '',
      desc: '',
      coverImg: '',
    );
    expect(created.customAttributes, isEmpty);
    final columns = await database
        .customSelect('PRAGMA table_info(role)')
        .get();
    expect(
      columns.where((row) => row.read<String>('name') == 'custom_attributes'),
      hasLength(1),
    );
  });
}

void _seedOldDatabase(File file, int version) {
  final raw = sqlite3.open(file.path);
  try {
    raw.execute('''
      CREATE TABLE role (
        id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
        name TEXT NOT NULL,
        sex TEXT NOT NULL,
        ${version >= 4 ? 'age TEXT NOT NULL,' : ''}
        birthday TEXT NOT NULL,
        ${version >= 4 ? 'race TEXT NOT NULL,' : ''}
        occupation TEXT NOT NULL,
        desc TEXT NOT NULL,
        coverimg TEXT NOT NULL
      )
    ''');
    raw.execute(
      'INSERT INTO role (id, name, sex, birthday, occupation, desc, coverimg'
      '${version >= 4 ? ', age, race' : ''}) VALUES (7, ?, ?, ?, ?, ?, ?'
      '${version >= 4 ? ', ?, ?' : ''})',
      [
        '旧角色',
        '未知',
        '三月三日',
        '守林人',
        '当前设定\n第二行',
        version < 6 ? '/old/app/covers/old.png' : 'covers/old.png',
        if (version >= 4) ...['约三百岁', '精灵'],
      ],
    );
    if (version >= 5) {
      raw.execute('''
        CREATE TABLE role_desc_revision (
          id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
          role_id INTEGER NOT NULL REFERENCES role (id) ON DELETE CASCADE,
          content TEXT NOT NULL,
          created_at INTEGER NOT NULL
        )
      ''');
      raw.execute(
        'INSERT INTO role_desc_revision (id, role_id, content, created_at) VALUES '
        '(11, 7, ?, 1700000000), (12, 7, ?, 1700000001)',
        ['最初设定', '当前设定\n第二行'],
      );
    }
    raw.userVersion = version;
  } finally {
    raw.close();
  }
}
