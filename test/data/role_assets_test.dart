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
