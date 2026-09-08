import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/data/database/app_database.dart' hide Role, RoleAsset;
import 'package:ochome/data/models/role.dart';
import 'package:ochome/data/models/role_asset.dart';
import 'package:ochome/data/repositories/drift_role_asset_repository.dart';
import 'package:ochome/data/repositories/drift_role_repository.dart';
import 'package:ochome/data/services/role_asset_store.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory support;
  late AppDatabase database;
  late DriftRoleRepository roles;
  late DriftRoleAssetRepository assets;
  late Role role;

  setUp(() async {
    support = await Directory.systemTemp.createTemp('role-assets-test');
    database = AppDatabase(NativeDatabase.memory());
    roles = DriftRoleRepository(database);
    assets = DriftRoleAssetRepository(
      database,
      supportDirectory: () async => support,
    );
    role = await _createRole(roles, '白鸦');
  });

  tearDown(() async {
    await database.close();
    await support.delete(recursive: true);
  });

  test(
    'imports all four types, retains original names and isolates each OC',
    () async {
      final other = await _createRole(roles, '第二个 OC');
      final files = [
        _file('设定.PNG', [1, 2, 3]),
        _file('片段.mov', [4, 5]),
        _file('声音.mp3', [6]),
        _file('说明.pdf', [7, 8]),
      ];
      await assets.importFiles(role.id, files);
      await assets.importFiles(other.id, [
        _file('说明.pdf', [9]),
      ]);
      final rows = await assets.listForRole(role.id);
      expect(rows, hasLength(4));
      expect(rows.map((row) => row.kind).toSet(), RoleAssetKind.values.toSet());
      for (final row in rows) {
        expect(RoleAssetStore.isValidPath(row.relativePath), isTrue);
        final source = files.singleWhere((file) => file.name == row.name);
        expect(
          await (await assets.fileFor(row)).readAsBytes(),
          await source.readAsBytes(),
        );
        expect(row.bytes, await source.length());
      }
      expect((await assets.listForRole(other.id)).single.name, '说明.pdf');
      final snapshot = await assets.watchForRole(role.id).first;
      expect(snapshot.map((row) => row.id), rows.map((row) => row.id));
    },
  );

  test('same filename never overwrites an earlier asset and temp source may disappear', () async {
    final source = File(p.join(support.path, 'notes.txt'));
    await source.writeAsString('first');
    await assets.importFiles(role.id, [XFile(source.path)]);
    await source.writeAsString('second');
    await assets.importFiles(role.id, [XFile(source.path)]);
    await source.delete();
    final rows = await assets.listForRole(role.id);
    expect(rows.map((row) => row.relativePath).toSet(), hasLength(2));
    expect(await (await assets.fileFor(rows[0])).readAsString(), 'second');
    expect(await (await assets.fileFor(rows[1])).readAsString(), 'first');
  });

  test('rename persists only the display name and keeps files, ownership and ordering', () async {
    final source = File(p.join(support.path, '原始立绘.PNG'));
    await source.writeAsBytes([1, 2, 3]);
    await assets.importFiles(role.id, [
      XFile(source.path),
      _file('notes.txt', [4]),
    ]);
    final before = await assets.listForRole(role.id);
    final original = before.singleWhere((asset) => asset.name == '原始立绘.PNG');
    final stored = await assets.fileFor(original);
    await stored.setLastModified(DateTime(2020));
    final modified = await stored.lastModified();
    final updated = assets
        .watchForRole(role.id)
        .firstWhere(
          (items) => items.any((asset) => asset.name == '白鸦·冬装.v2.PNG'),
        );

    await assets.rename(
      roleId: role.id,
      assetId: original.id,
      baseName: '  白鸦·冬装.v2  ',
    );
    final rows = await updated;
    expect(rows.map((asset) => asset.id), before.map((asset) => asset.id));
    final renamed = rows.singleWhere((asset) => asset.id == original.id);
    expect(renamed.name, '白鸦·冬装.v2.PNG');
    expect(renamed.roleId, original.roleId);
    expect(renamed.kind, original.kind);
    expect(renamed.relativePath, original.relativePath);
    expect(renamed.bytes, original.bytes);
    expect(renamed.createdAt, original.createdAt);
    expect((await assets.fileFor(renamed)).path, stored.path);
    expect(await stored.readAsBytes(), [1, 2, 3]);
    expect(await stored.lastModified(), modified);
    expect(await source.readAsBytes(), [1, 2, 3]);
    expect((await roles.getById(role.id))!.name, role.name);
    final reopened = DriftRoleAssetRepository(database);
    expect(
      (await reopened.listForRole(role.id))
          .singleWhere((asset) => asset.id == original.id)
          .name,
      renamed.name,
    );
  });

  test(
    'rename rejects wrong-role and missing ids and leaves other assets intact',
    () async {
      final other = await _createRole(roles, '另一个角色');
      await assets.importFiles(role.id, [
        _file('notes.pdf', [1]),
      ]);
      await assets.importFiles(other.id, [
        _file('notes.pdf', [2]),
      ]);
      final asset = (await assets.listForRole(role.id)).single;
      for (final (roleId, assetId) in [(other.id, asset.id), (role.id, -1)]) {
        await expectLater(
          assets.rename(roleId: roleId, assetId: assetId, baseName: '修改'),
          throwsA(isA<StateError>()),
        );
      }
      expect((await assets.listForRole(role.id)).single.name, 'notes.pdf');
      expect((await assets.listForRole(other.id)).single.name, 'notes.pdf');
    },
  );

  test(
    'rename validates basenames and preserves the final extension',
    () async {
      await assets.importFiles(role.id, [
        _file('archive.tar.GZ', [1]),
      ]);
      final asset = (await assets.listForRole(role.id)).single;
      for (final name in [
        '',
        '   ',
        '.',
        '..',
        'folder/name',
        r'folder\name',
        'a\nb',
        'a\u0000b',
        '\tname',
        '\n\t',
        'name\u007f',
      ]) {
        await expectLater(
          assets.rename(roleId: role.id, assetId: asset.id, baseName: name),
          throwsFormatException,
          reason: name,
        );
      }
      expect((await assets.listForRole(role.id)).single.name, 'archive.tar.GZ');
      await assets.rename(
        roleId: role.id,
        assetId: asset.id,
        baseName: '说明.final',
      );
      expect((await assets.listForRole(role.id)).single.name, '说明.final.GZ');
      await assets.importFiles(role.id, [
        _file('README', [2]),
        _file('.hidden', [3]),
        _file('说明.非标准后缀', [4]),
      ]);
      final extensionless = (await assets.listForRole(role.id))
          .where((asset) => asset.name != '说明.final.GZ');
      for (final item in extensionless) {
        await assets.rename(
          roleId: role.id,
          assetId: item.id,
          baseName: '  无后缀.v2  ',
        );
        expect(
          (await assets.listForRole(role.id))
              .singleWhere((row) => row.id == item.id)
              .name,
          '无后缀.v2',
        );
        await assets.rename(
          roleId: role.id,
          assetId: item.id,
          baseName: '最终说明',
        );
        expect(
          (await assets.listForRole(role.id))
              .singleWhere((row) => row.id == item.id)
              .name,
          '最终说明',
        );
      }
    },
  );

  test('same-name rename performs no write and failed writes leave metadata and file usable', () async {
    await assets.importFiles(role.id, [
      _file('notes.pdf', [1]),
    ]);
    final asset = (await assets.listForRole(role.id)).single;
    await database.customStatement('''
      CREATE TRIGGER reject_asset_rename BEFORE UPDATE ON role_asset
      BEGIN SELECT RAISE(ABORT, 'simulated rename failure'); END
    ''');
    await assets.rename(
      roleId: role.id,
      assetId: asset.id,
      baseName: ' notes ',
    );
    await expectLater(
      assets.rename(roleId: role.id, assetId: asset.id, baseName: 'changed'),
      throwsA(anything),
    );
    expect((await assets.listForRole(role.id)).single.name, 'notes.pdf');
    expect(await (await assets.fileFor(asset)).readAsBytes(), [1]);
    await database.customStatement('DROP TRIGGER reject_asset_rename');
    await assets.rename(
      roleId: role.id,
      assetId: asset.id,
      baseName: 'changed',
    );
    expect((await assets.listForRole(role.id)).single.name, 'changed.pdf');
  });

  test(
    'a failed copy rolls back the whole batch without damaging saved assets',
    () async {
      await assets.importFiles(role.id, [
        _file('keep.txt', [1]),
      ]);
      final kept = (await assets.listForRole(role.id)).single;
      await expectLater(
        assets.importFiles(role.id, [
          _file('first.txt', [2]),
          _BrokenFile(),
        ]),
        throwsA(isA<StateError>()),
      );
      expect((await assets.listForRole(role.id)).single.id, kept.id);
      final files = await RoleAssetStore(support).directory.list().toList();
      expect(files, hasLength(1));
      expect(await (await assets.fileFor(kept)).readAsBytes(), [1]);
    },
  );

  test('a role deleted during copying makes registration fail and cleans new files', () async {
    final file = _CallbackFile(() => roles.delete(role.id));
    await expectLater(assets.importFiles(role.id, [file]), throwsA(anything));
    expect(await assets.listForRole(role.id), isEmpty);
    expect(await RoleAssetStore(support).listLocal(), isEmpty);
  });

  test(
    'deletion is scoped to the role and removes only the imported copy',
    () async {
      final source = File(p.join(support.path, 'source.pdf'));
      await source.writeAsBytes([1, 2]);
      await assets.importFiles(role.id, [XFile(source.path)]);
      final row = (await assets.listForRole(role.id)).single;
      final file = await assets.fileFor(row);
      final changed = assets
          .watchForRole(role.id)
          .firstWhere((items) => items.isEmpty);
      await assets.delete(roleId: role.id + 1, assetId: row.id);
      expect(await file.exists(), isTrue);
      expect(await assets.listForRole(role.id), hasLength(1));
      await assets.delete(roleId: role.id, assetId: row.id);
      expect(await changed, isEmpty);
      expect(await file.exists(), isFalse);
      expect(await source.exists(), isTrue);
    },
  );

  test(
    'missing files fail clearly and metadata can still be removed',
    () async {
      await assets.importFiles(role.id, [
        _file('lost.mp4', [3]),
      ]);
      final row = (await assets.listForRole(role.id)).single;
      await (await assets.fileFor(row)).delete();
      await expectLater(
        assets.fileFor(row),
        throwsA(isA<FileSystemException>()),
      );
      await assets.delete(roleId: role.id, assetId: row.id);
      expect(await assets.listForRole(role.id), isEmpty);
    },
  );

  test('path validation rejects paths outside the asset directory', () {
    final store = RoleAssetStore(support);
    for (final path in [
      '/tmp/private',
      'role_assets/../notes',
      'role_assets/a/b',
      'role_assets/..',
      'role_assets/.hidden',
      'covers/image.png',
    ]) {
      expect(() => store.resolve(path), throwsFormatException, reason: path);
    }
  });

  test('v7 migration keeps existing role, attributes and history, then permits assets', () async {
    final file = File(p.join(support.path, 'v7.sqlite'));
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
    ''');
    raw.execute('INSERT INTO role VALUES (7, ?, ?, ?, ?, ?, ?, ?, ?, ?)', [
      '旧 OC',
      '',
      '20',
      '',
      '',
      '',
      '设定',
      'covers/old.png',
      '[{"name":"能力","content":"冰"}]',
    ]);
    raw.execute(
      "INSERT INTO role_desc_revision VALUES (12, 7, '设定', 1700000000)",
    );
    raw.userVersion = 7;
    raw.close();
    await database.close();
    final upgraded = AppDatabase(NativeDatabase(file));
    database = upgraded;
    final repository = DriftRoleRepository(upgraded);
    final preserved = (await repository.list()).single;
    expect(preserved.id, 7);
    expect(preserved.name, '旧 OC');
    expect(preserved.customAttributes.single.content, '冰');
    expect((await repository.listDescRevisions(7)).single.id, 12);
    final assetRepository = DriftRoleAssetRepository(
      upgraded,
      supportDirectory: () async => support,
    );
    await assetRepository.importFiles(7, [
      _file('asset.pdf', [1]),
    ]);
    expect(await assetRepository.listForRole(7), hasLength(1));
    await repository.delete(7);
    expect(await assetRepository.listForRole(7), isEmpty);
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

XFile _file(String name, List<int> bytes) =>
    XFile.fromData(Uint8List.fromList(bytes), path: name);

class _BrokenFile extends XFile {
  _BrokenFile() : super('broken', name: 'broken.mp4');
  @override
  Future<int> length() async => 8;
  @override
  Stream<Uint8List> openRead([int? start, int? end]) async* {
    yield Uint8List.fromList([1]);
    throw StateError('simulated interrupted read');
  }
}

class _CallbackFile extends XFile {
  _CallbackFile(this.beforeRead) : super('callback', name: 'callback.pdf');
  final Future<void> Function() beforeRead;
  @override
  Future<int> length() async => 1;
  @override
  Stream<Uint8List> openRead([int? start, int? end]) async* {
    await beforeRead();
    yield Uint8List.fromList([1]);
  }
}
