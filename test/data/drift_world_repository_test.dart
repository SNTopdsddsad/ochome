import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
// hide Drift 生成的行类型，测试里只用领域模型。
import 'package:ochome/data/database/app_database.dart' hide Role, World;
import 'package:ochome/data/models/role.dart';
import 'package:ochome/data/models/world.dart';
import 'package:ochome/data/models/world_entry.dart';
import 'package:ochome/data/repositories/drift_role_repository.dart';
import 'package:ochome/data/repositories/drift_world_repository.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

void main() {
  late AppDatabase database;
  late DriftWorldRepository worlds;
  late DriftRoleRepository roles;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    worlds = DriftWorldRepository(database);
    roles = DriftRoleRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<World> insertWorld({
    String name = '艾尔登',
    String summary = '一个被火漆封印的大陆',
    List<WorldEntry> entries = const [],
  }) {
    return worlds.create(
      name: name,
      summary: summary,
      coverImg: 'covers/elden.png',
      entries: entries,
    );
  }

  Future<Role> insertRole({String name = 'Ada', int? worldId}) {
    return roles.create(
      name: name,
      sex: '',
      age: '',
      birthday: '',
      race: '',
      occupation: '',
      desc: '',
      coverImg: '',
      worldId: worldId,
    );
  }

  test('create and getById persist a world', () async {
    final created = await insertWorld();

    expect(created.id, greaterThan(0));
    expect(created.name, '艾尔登');
    expect(created.summary, '一个被火漆封印的大陆');
    expect(created.coverImg, 'covers/elden.png');
    expect(created.entries, isEmpty);
    expect(await worlds.getById(created.id), created);
    expect(await worlds.getById(created.id + 99), isNull);
  });

  test(
    'entries round trip in order with multiline and empty content',
    () async {
      const entries = [
        WorldEntry(title: '地理', content: '北方是雪原\n南方是海'),
        WorldEntry(title: '势力', content: ''),
        WorldEntry(title: '地理', content: '同名词条也保留'),
      ];
      final created = await insertWorld(entries: entries);

      expect(created.entries, entries);
      final loaded = await worlds.getById(created.id);
      expect(loaded!.entries, entries);
      expect(() => loaded.entries.add(entries.first), throwsUnsupportedError);
    },
  );

  test(
    'writes trim outer whitespace and reject blank names or titles',
    () async {
      final created = await worlds.create(
        name: '  边界  ',
        summary: '  简介 ',
        coverImg: '',
        entries: const [WorldEntry(title: ' 历史 ', content: ' 千年前 ')],
      );
      expect(created.name, '边界');
      expect(created.summary, '简介');
      expect(
        created.entries.single,
        const WorldEntry(title: '历史', content: '千年前'),
      );

      expect(
        () => worlds.create(name: '  ', summary: '', coverImg: ''),
        throwsArgumentError,
      );
      expect(
        () => worlds.create(
          name: '合法',
          summary: '',
          coverImg: '',
          entries: const [WorldEntry(title: ' ', content: 'x')],
        ),
        throwsArgumentError,
      );
      expect((await worlds.list()).single, created);
    },
  );

  test('update replaces every field and fails for unknown ids', () async {
    final created = await insertWorld();
    final updated = await worlds.update(
      World(
        id: created.id,
        name: '新名字',
        summary: '新简介',
        coverImg: 'covers/new.png',
        entries: const [WorldEntry(title: '魔法', content: '以血为引')],
      ),
    );

    expect(updated.name, '新名字');
    expect(updated.summary, '新简介');
    expect(updated.coverImg, 'covers/new.png');
    expect(updated.entries.single.title, '魔法');
    expect(await worlds.getById(created.id), updated);

    expect(
      () => worlds.update(
        const World(id: 404, name: 'x', summary: '', coverImg: ''),
      ),
      throwsStateError,
    );
  });

  test('watchAll emits on create, update and delete', () async {
    final events = <List<String>>[];
    final sub = worlds.watchAll().listen(
      (items) => events.add(items.map((w) => w.name).toList()),
    );
    addTearDown(sub.cancel);
    await Future<void>.delayed(Duration.zero);

    final a = await insertWorld(name: 'A');
    await insertWorld(name: 'B');
    await worlds.update(World(id: a.id, name: 'A2', summary: '', coverImg: ''));
    await worlds.delete(a.id);
    await Future<void>.delayed(Duration.zero);

    expect(events, [
      <String>[],
      ['A'],
      ['A', 'B'],
      ['A2', 'B'],
      ['B'],
    ]);
  });

  test('delete is silent for missing ids', () async {
    await worlds.delete(12345);
    expect(await worlds.list(), isEmpty);
  });

  test(
    'malformed stored entries fail loudly instead of becoming empty',
    () async {
      final created = await insertWorld();
      await database.customStatement(
        'UPDATE world SET entries = ? WHERE id = ?',
        ['{"title":"not a list"}', created.id],
      );
      expect(() => worlds.getById(created.id), throwsFormatException);

      await database.customStatement(
        'UPDATE world SET entries = ? WHERE id = ?',
        ['[{"title":"  ","content":"x"}]', created.id],
      );
      expect(() => worlds.list(), throwsFormatException);
    },
  );

  group('role membership', () {
    test('roles persist worldId and watchByWorld filters by it', () async {
      final world = await insertWorld(name: '甲');
      final other = await insertWorld(name: '乙');
      final inWorld = await insertRole(name: '甲的人', worldId: world.id);
      await insertRole(name: '乙的人', worldId: other.id);
      final free = await insertRole(name: '无归属');

      expect(inWorld.worldId, world.id);
      expect(free.worldId, isNull);
      expect((await roles.getById(inWorld.id))!.worldId, world.id);

      final members = await roles.watchByWorld(world.id).first;
      expect(members.map((r) => r.name), ['甲的人']);
    });

    test('update moves a role between worlds and can detach it', () async {
      final world = await insertWorld();
      final role = await insertRole();
      final attached = await roles.update(_withWorld(role, world.id));
      expect(attached.worldId, world.id);
      expect((await roles.watchByWorld(world.id).first).single.id, role.id);

      final detached = await roles.update(_withWorld(role, null));
      expect(detached.worldId, isNull);
      expect(await roles.watchByWorld(world.id).first, isEmpty);
    });

    test('unknown worldId is rejected by the foreign key', () async {
      expect(() => insertRole(worldId: 999), throwsA(anything));
      expect(await roles.list(), isEmpty);
    });

    test('deleting a world keeps its roles and clears their worldId', () async {
      final world = await insertWorld();
      final member = await insertRole(name: '成员', worldId: world.id);
      final outsider = await insertRole(name: '路人');

      await worlds.delete(world.id);

      expect(await worlds.getById(world.id), isNull);
      final remaining = await roles.list();
      expect(remaining.map((r) => r.name), ['成员', '路人']);
      expect((await roles.getById(member.id))!.worldId, isNull);
      expect((await roles.getById(outsider.id))!.worldId, isNull);
    });

    test('restoring a description revision preserves worldId', () async {
      final world = await insertWorld();
      final role = await roles.create(
        name: 'Ada',
        sex: '',
        age: '',
        birthday: '',
        race: '',
        occupation: '',
        desc: '第一版',
        coverImg: '',
        worldId: world.id,
      );
      await roles.update(_withWorld(role, world.id, desc: '第二版'));
      final history = await roles.listDescRevisions(role.id);
      final first = history.last;

      final restored = await roles.restoreDescRevision(
        roleId: role.id,
        revisionId: first.id,
      );
      expect(restored.desc, '第一版');
      expect(restored.worldId, world.id);
    });
  });

  group('schema 8 upgrade', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('world_migration');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test(
      'adds world table and nullable role.world_id without touching data',
      () async {
        final file = File(p.join(tempDir.path, 'v8.sqlite'));
        _seedV8Database(file);
        final upgraded = AppDatabase(NativeDatabase(file));
        addTearDown(upgraded.close);
        final roleRepo = DriftRoleRepository(upgraded);
        final worldRepo = DriftWorldRepository(upgraded);

        final role = (await roleRepo.list()).single;
        expect(role.id, 7);
        expect(role.name, '旧角色');
        expect(role.customAttributes.single.name, '魔法属性');
        expect(role.worldId, isNull);
        expect((await roleRepo.listDescRevisions(7)).map((r) => r.content), [
          '当前设定',
        ]);
        final assets = await upgraded
            .customSelect('SELECT name FROM role_asset')
            .get();
        expect(assets.single.read<String>('name'), 'old.png');
        final version = await upgraded
            .customSelect('PRAGMA user_version')
            .getSingle();
        expect(version.data.values.single, AppDatabase.currentSchemaVersion);

        expect(await worldRepo.list(), isEmpty);
        final world = await worldRepo.create(
          name: '升级后',
          summary: '',
          coverImg: '',
        );
        final attached = await roleRepo.update(_withWorld(role, world.id));
        expect(attached.worldId, world.id);
        await worldRepo.delete(world.id);
        expect((await roleRepo.getById(7))!.worldId, isNull);

        final columns = await upgraded
            .customSelect('PRAGMA table_info(role)')
            .get();
        expect(
          columns.where((row) => row.read<String>('name') == 'world_id'),
          hasLength(1),
        );
      },
    );
  });
}

Role _withWorld(Role role, int? worldId, {String? desc}) {
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
    customAttributes: role.customAttributes,
    worldId: worldId,
  );
}

void _seedV8Database(File file) {
  final raw = sqlite3.open(file.path);
  try {
    raw.execute('''
      CREATE TABLE role (
        id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
        name TEXT NOT NULL,
        sex TEXT NOT NULL,
        age TEXT NOT NULL,
        birthday TEXT NOT NULL,
        race TEXT NOT NULL,
        occupation TEXT NOT NULL,
        desc TEXT NOT NULL,
        coverimg TEXT NOT NULL,
        custom_attributes TEXT NOT NULL DEFAULT '[]'
      )
    ''');
    raw.execute(
      'INSERT INTO role (id, name, sex, age, birthday, race, occupation, desc, '
      'coverimg, custom_attributes) VALUES (7, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        '旧角色',
        '未知',
        '约三百岁',
        '三月三日',
        '精灵',
        '守林人',
        '当前设定',
        'covers/old.png',
        '[{"name":"魔法属性","content":"冰"}]',
      ],
    );
    raw.execute('''
      CREATE TABLE role_desc_revision (
        id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
        role_id INTEGER NOT NULL REFERENCES role (id) ON DELETE CASCADE,
        content TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    raw.execute(
      'INSERT INTO role_desc_revision (id, role_id, content, created_at) '
      'VALUES (11, 7, ?, 1700000000)',
      ['当前设定'],
    );
    raw.execute('''
      CREATE TABLE role_asset (
        id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
        role_id INTEGER NOT NULL REFERENCES role (id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        kind TEXT NOT NULL,
        relative_path TEXT NOT NULL UNIQUE,
        bytes INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    raw.execute('CREATE INDEX role_asset_role_id ON role_asset (role_id)');
    raw.execute(
      'INSERT INTO role_asset (role_id, name, kind, relative_path, bytes, '
      "created_at) VALUES (7, 'old.png', 'image', 'role_assets/a.png', 3, 1700000000)",
    );
    raw.userVersion = 8;
  } finally {
    raw.close();
  }
}
