import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/data/database/app_database.dart'
    hide Role, RoleRelationship;
import 'package:ochome/data/models/role.dart';
import 'package:ochome/data/models/role_relationship.dart';
import 'package:ochome/data/repositories/drift_role_relationship_repository.dart';
import 'package:ochome/data/repositories/drift_role_repository.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

void main() {
  late AppDatabase database;
  late DriftRoleRepository roles;
  late DriftRoleRelationshipRepository relationships;
  late Role a;
  late Role b;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    roles = DriftRoleRepository(database);
    relationships = DriftRoleRelationshipRepository(database);
    a = await _createRole(roles, '甲');
    b = await _createRole(roles, '乙');
  });

  tearDown(() => database.close());

  test('one row serves both perspectives and supports several per pair', () async {
    final master = await relationships.create(
      fromRoleId: a.id,
      toRoleId: b.id,
      fromLabel: ' 师父 ',
      toLabel: '徒弟',
    );
    expect(master.fromLabel, '师父');
    expect(master.selfLabel(a.id), '师父');
    expect(master.otherLabel(a.id), '徒弟');
    expect(master.otherRoleId(a.id), b.id);
    expect(master.selfLabel(b.id), '徒弟');
    expect(master.otherLabel(b.id), '师父');
    expect(master.otherRoleId(b.id), a.id);

    final lovers = await relationships.create(
      fromRoleId: b.id,
      toRoleId: a.id,
      fromLabel: '恋人',
      toLabel: '恋人',
    );
    expect(lovers.id, isNot(master.id));
    final forA = await relationships.listForRole(a.id);
    final forB = await relationships.listForRole(b.id);
    expect(forA.map((r) => r.id).toSet(), {master.id, lovers.id});
    expect(forB.map((r) => r.id).toSet(), {master.id, lovers.id});
    expect(forA.first.id, lovers.id, reason: 'newest first');

    final c = await _createRole(roles, '丙');
    expect(await relationships.listForRole(c.id), isEmpty);
    expect(await relationships.watchForRole(c.id).first, isEmpty);
  });

  test('rejects self links, unknown roles and empty labels', () async {
    await expectLater(
      relationships.create(
        fromRoleId: a.id,
        toRoleId: a.id,
        fromLabel: '我',
        toLabel: '我',
      ),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      relationships.create(
        fromRoleId: a.id,
        toRoleId: 999,
        fromLabel: '师父',
        toLabel: '徒弟',
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          '对方 OC 已不存在，请重新选择',
        ),
      ),
    );
    await expectLater(
      relationships.create(
        fromRoleId: 999,
        toRoleId: b.id,
        fromLabel: '师父',
        toLabel: '徒弟',
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          '当前角色已不存在，请先保存角色',
        ),
      ),
    );
    for (final labels in [
      ('', '徒弟'),
      ('师父', '   '),
      ('师\n父', '徒弟'),
      ('师' * (relationshipLabelMaxLength + 1), '徒弟'),
    ]) {
      await expectLater(
        relationships.create(
          fromRoleId: a.id,
          toRoleId: b.id,
          fromLabel: labels.$1,
          toLabel: labels.$2,
        ),
        throwsA(isA<FormatException>()),
      );
    }
    expect(await relationships.listForRole(a.id), isEmpty);
    expect(() => RoleRelationship(
      id: 1,
      fromRoleId: 1,
      toRoleId: 2,
      fromLabel: 'x',
      toLabel: 'y',
      createdAt: DateTime(2026),
    ).otherRoleId(3), throwsArgumentError);
  });

  test('update rewrites labels and endpoints; missing rows fail', () async {
    final c = await _createRole(roles, '丙');
    final created = await relationships.create(
      fromRoleId: a.id,
      toRoleId: b.id,
      fromLabel: '师父',
      toLabel: '徒弟',
    );
    final updated = await relationships.update(
      created.copyWith(toRoleId: c.id, fromLabel: '兄长', toLabel: ' 弟弟'),
    );
    expect(updated.id, created.id);
    expect(updated.createdAt, created.createdAt);
    expect(updated.toRoleId, c.id);
    expect(updated.fromLabel, '兄长');
    expect(updated.toLabel, '弟弟');
    expect(await relationships.listForRole(b.id), isEmpty);
    expect((await relationships.listForRole(c.id)).single, updated);

    await expectLater(
      relationships.update(created.copyWith(toRoleId: a.id)),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      relationships.update(
        RoleRelationship(
          id: 4242,
          fromRoleId: a.id,
          toRoleId: b.id,
          fromLabel: 'x',
          toLabel: 'y',
          createdAt: DateTime(2026),
        ),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('delete is scoped to a participant and role deletion cascades', () async {
    final c = await _createRole(roles, '丙');
    final ab = await relationships.create(
      fromRoleId: a.id,
      toRoleId: b.id,
      fromLabel: '师父',
      toLabel: '徒弟',
    );
    final bc = await relationships.create(
      fromRoleId: b.id,
      toRoleId: c.id,
      fromLabel: '挚友',
      toLabel: '挚友',
    );
    expect(
      await relationships.delete(roleId: c.id, relationshipId: ab.id),
      isFalse,
    );
    expect((await relationships.listForRole(a.id)).single, ab);
    expect(
      await relationships.delete(roleId: b.id, relationshipId: ab.id),
      isTrue,
    );
    expect(await relationships.listForRole(a.id), isEmpty);
    expect(
      await relationships.delete(roleId: b.id, relationshipId: 999),
      isFalse,
    );

    final stream = relationships.watchForRole(c.id);
    expect(
      stream,
      emitsInOrder([
        [bc],
        isEmpty,
      ]),
    );
    await Future<void>.delayed(Duration.zero);
    await roles.delete(b.id);
    expect(await relationships.listForRole(c.id), isEmpty);
    expect(await relationships.listForRole(b.id), isEmpty);
  });

  test('v8 migration keeps roles, history and assets, then permits relationships', () async {
    final support = await Directory.systemTemp.createTemp('role-relationships');
    addTearDown(() => support.delete(recursive: true));
    final file = File(p.join(support.path, 'v8.sqlite'));
    final raw = sqlite3.open(file.path);
    raw.execute('''
      CREATE TABLE role (
        id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
        name TEXT NOT NULL, sex TEXT NOT NULL, age TEXT NOT NULL,
        birthday TEXT NOT NULL, race TEXT NOT NULL, occupation TEXT NOT NULL,
        desc TEXT NOT NULL, coverimg TEXT NOT NULL,
        custom_attributes TEXT NOT NULL DEFAULT '[]'
      );
      CREATE TABLE role_desc_revision (
        id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
        role_id INTEGER NOT NULL REFERENCES role(id) ON DELETE CASCADE,
        content TEXT NOT NULL, created_at INTEGER NOT NULL
      );
      CREATE TABLE role_asset (
        id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
        role_id INTEGER NOT NULL REFERENCES role(id) ON DELETE CASCADE,
        name TEXT NOT NULL, kind TEXT NOT NULL,
        relative_path TEXT NOT NULL UNIQUE, bytes INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      );
      CREATE INDEX role_asset_role_id ON role_asset(role_id);
    ''');
    for (final id in [7, 8]) {
      raw.execute('INSERT INTO role VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', [
        id,
        '旧 OC $id',
        '',
        '20',
        '',
        '',
        '',
        '设定',
        '',
        '[{"name":"能力","content":"冰"}]',
      ]);
    }
    raw.execute(
      "INSERT INTO role_desc_revision VALUES (12, 7, '设定', 1700000000)",
    );
    raw.execute(
      "INSERT INTO role_asset VALUES (3, 7, 'a.pdf', 'document', 'role_assets/a.pdf', 1, 1700000000)",
    );
    raw.userVersion = 8;
    raw.close();
    await database.close();
    final upgraded = AppDatabase(NativeDatabase(file));
    database = upgraded;
    final roleRepository = DriftRoleRepository(upgraded);
    final preserved = await roleRepository.list();
    expect(preserved.map((r) => r.id), [7, 8]);
    expect(preserved.first.customAttributes.single.content, '冰');
    expect((await roleRepository.listDescRevisions(7)).single.id, 12);
    expect(
      await upgraded.customSelect('SELECT id FROM role_asset').get(),
      hasLength(1),
    );
    final repository = DriftRoleRelationshipRepository(upgraded);
    await repository.create(
      fromRoleId: 7,
      toRoleId: 8,
      fromLabel: '师父',
      toLabel: '徒弟',
    );
    expect(await repository.listForRole(8), hasLength(1));
    final version = await upgraded.customSelect('PRAGMA user_version').get();
    expect(version.single.data.values.single, AppDatabase.currentSchemaVersion);
    final indexes = await upgraded
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = 'role_relationship'",
        )
        .get();
    expect(
      indexes.map((row) => row.data['name']),
      containsAll([
        'role_relationship_from_role_id',
        'role_relationship_to_role_id',
      ]),
    );
    await roleRepository.delete(7);
    expect(await repository.listForRole(8), isEmpty);
  });
}

Future<Role> _createRole(DriftRoleRepository repository, String name) =>
    repository.create(
      name: name,
      sex: '',
      age: '',
      birthday: '',
      race: '',
      occupation: '',
      desc: '',
      coverImg: '',
    );
