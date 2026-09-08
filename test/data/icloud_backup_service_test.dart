import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:file_selector/file_selector.dart';
import 'package:ochome/data/database/app_database.dart' hide Role;
import 'package:ochome/data/models/role.dart';
import 'package:ochome/data/models/role_custom_attribute.dart';
import 'package:ochome/data/repositories/drift_role_repository.dart';
import 'package:ochome/data/repositories/drift_role_asset_repository.dart';
import 'package:ochome/data/services/role_asset_store.dart';
import 'package:ochome/data/services/backup_exceptions.dart';
import 'package:ochome/data/services/backup_manifest.dart';
import 'package:ochome/data/services/icloud_backup_service.dart';
import 'package:ochome/data/services/sqlite_snapshotter.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../fakes/fake_icloud_container.dart';

void main() {
  late Directory support;
  late FakeICloudContainer cloud;
  late ICloudBackupService service;

  setUp(() async {
    support = await Directory.systemTemp.createTemp('icloud_backup_service');
    cloud = FakeICloudContainer();
    service = ICloudBackupService(
      container: cloud,
      supportDirectory: () async => support,
      clock: () => DateTime.utc(2026, 9, 1, 12),
    );
  });

  tearDown(() async {
    if (await support.exists()) {
      await support.delete(recursive: true);
    }
  });

  Future<AppDatabase> openLive() {
    return Future.value(
      AppDatabase(
        NativeDatabase(File(p.join(support.path, AppDatabase.sqliteFileName))),
      ),
    );
  }

  Future<void> seedRole(
    AppDatabase database, {
    String name = 'Ada',
    String desc = 'sample',
    String coverImg = 'covers/ada.png',
    List<RoleCustomAttribute> customAttributes = const [],
  }) {
    return DriftRoleRepository(database).create(
      name: name,
      sex: 'female',
      age: '17',
      birthday: '三月三日',
      race: 'human',
      occupation: 'engineer',
      desc: desc,
      coverImg: coverImg,
      customAttributes: customAttributes,
    );
  }

  Future<File> writeCover(String name, List<int> bytes) async {
    final dir = Directory(p.join(support.path, 'covers'));
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, name));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  test('backup uploads sqlite, manifest and changed covers only', () async {
    final database = await openLive();
    addTearDown(database.close);
    await writeCover('ada.png', const [1, 2, 3, 4]);
    await seedRole(database);

    final first = await service.backup(database: database);
    expect(first.schemaVersion, AppDatabase.currentSchemaVersion);
    expect(first.covers.single.file, 'covers/ada.png');
    expect(cloud.files.containsKey(AppDatabase.sqliteFileName), isTrue);
    expect(cloud.files.containsKey('manifest.json'), isTrue);
    final uploadsAfterFirst = cloud.uploadCount;

    await service.backup(database: database);
    expect(cloud.uploadCount, uploadsAfterFirst + 2);
    expect(
      utf8.decode(cloud.files['manifest.json']!),
      contains('covers/ada.png'),
    );
  });

  test('backup skips hidden files in covers/', () async {
    final database = await openLive();
    addTearDown(database.close);
    await writeCover('ada.png', const [1, 2, 3, 4]);
    await writeCover('.DS_Store', const [0]);
    await seedRole(database);

    final manifest = await service.backup(database: database);
    expect(manifest.covers.map((entry) => entry.file), ['covers/ada.png']);
    expect(cloud.files.containsKey('covers/.DS_Store'), isFalse);
  });

  test('backup deletes remote covers that are gone locally', () async {
    final database = await openLive();
    addTearDown(database.close);
    await writeCover('ada.png', const [1, 2, 3]);
    await writeCover('old.png', const [9, 9]);
    await seedRole(database);
    await service.backup(database: database);
    expect(cloud.files.containsKey('covers/old.png'), isTrue);

    await File(p.join(support.path, 'covers', 'old.png')).delete();
    await service.backup(database: database);
    expect(cloud.files.containsKey('covers/old.png'), isFalse);
    expect(cloud.files.containsKey('covers/ada.png'), isTrue);
  });

  test('same-version restore replaces sqlite and covers', () async {
    final database = await openLive();
    await writeCover('ada.png', const [1, 2, 3]);
    const attributes = [
      RoleCustomAttribute(name: '能力代价', content: '失去部分记忆\n无法回忆名字'),
      RoleCustomAttribute(name: '魔法属性', content: '冰 ❄️'),
      RoleCustomAttribute(name: '契约对象', content: ''),
    ];
    await seedRole(database, customAttributes: attributes);
    await service.backup(database: database);
    await database.close();

    await File(p.join(support.path, 'covers', 'ada.png'))
        .writeAsBytes(const [9]);
    final mutated = await openLive();
    final repo = DriftRoleRepository(mutated);
    final existing = await repo.getById(1);
    expect(existing!.customAttributes, attributes);
    await repo.update(
      Role(
        id: existing.id,
        name: 'Mutated',
        sex: existing.sex,
        age: existing.age,
        birthday: existing.birthday,
        race: existing.race,
        occupation: existing.occupation,
        desc: existing.desc,
        coverImg: existing.coverImg,
        customAttributes: const [],
      ),
    );
    expect((await repo.getById(1))!.customAttributes, isEmpty);
    await mutated.close();

    final plan = await service.prepareRestore();
    await service.commitRestore(plan);

    final restored = await openLive();
    addTearDown(restored.close);
    final rows = await restored.customSelect('SELECT name FROM role').get();
    expect(rows.single.read<String>('name'), 'Ada');
    final restoredRole = await DriftRoleRepository(restored).getById(1);
    expect(restoredRole!.customAttributes, attributes);
    expect(
      await File(p.join(support.path, 'covers', 'ada.png')).readAsBytes(),
      const [1, 2, 3],
    );
  });

  test('prepareRestore reports file index remaining and total', () async {
    final database = await openLive();
    await writeCover('ada.png', const [1, 2, 3]);
    await seedRole(database);
    await service.backup(database: database);
    await database.close();

    final messages = <String>[];
    final plan = await service.prepareRestore(
      onProgress: (progress) => messages.add(progress.message),
    );
    addTearDown(plan.dispose);

    expect(messages.first, '正在检查 iCloud…');
    expect(messages.any((line) => line.contains('正在恢复第 1 个')), isTrue);
  });

  test('inspectBackup then restore works when list is empty', () async {
    final database = await openLive();
    await writeCover('ada.png', const [1, 2, 3]);
    await seedRole(database);
    await service.backup(database: database);
    await database.close();
    cloud.hideFromList = true;

    final inspection = await service.inspectBackup();
    final plan = await service.prepareRestore(inspection: inspection);
    await service.commitRestore(plan);

    final restored = await openLive();
    addTearDown(restored.close);
    final rows = await restored.customSelect('SELECT name FROM role').get();
    expect(rows.single.read<String>('name'), 'Ada');
    expect(
      await File(p.join(support.path, 'covers', 'ada.png')).readAsBytes(),
      const [1, 2, 3],
    );
  });

  test('inspectBackup refuses newer schema before covers download', () async {
    cloud.files[AppDatabase.sqliteFileName] = _schemaSqlite(
      version: AppDatabase.currentSchemaVersion + 1,
      name: 'Future',
    );
    cloud.files['manifest.json'] = utf8.encode(
      jsonEncode({
        'format': 1,
        'schemaVersion': AppDatabase.currentSchemaVersion + 1,
        'appVersion': '9.0.0',
        'createdAt': '2026-09-01T00:00:00Z',
        'covers': [
          {'file': 'covers/skip.png', 'bytes': 1},
        ],
      }),
    );
    cloud.files['covers/skip.png'] = const [1];

    await expectLater(
      service.inspectBackup(),
      throwsA(isA<BackupNewerThanAppException>()),
    );
  });

  test('empty cover download is rejected', () async {
    final database = await openLive();
    await writeCover('ada.png', const [1, 2, 3, 4]);
    await seedRole(database);
    await service.backup(database: database);
    await database.close();
    cloud.files['covers/ada.png'] = const [];

    await expectLater(
      service.prepareRestore(),
      throwsA(isA<RestoreFailedException>()),
    );
  });

  test('schema 4 backup restores and onUpgrade creates 设定修订表', () async {
    final live = await openLive();
    await seedRole(live, name: 'Current');
    await live.close();

    cloud.files[AppDatabase.sqliteFileName] = _schemaSqlite(
      version: 4,
      name: 'OldAda',
      desc: 'from-v4',
    );
    cloud.files['manifest.json'] = utf8.encode(
      jsonEncode(
        BackupManifest(
          format: 1,
          schemaVersion: 4,
          appVersion: '0.9.0+1',
          createdAt: DateTime.utc(2026, 8, 1),
          covers: const [],
        ).toJson(),
      ),
    );

    final plan = await service.prepareRestore();
    await service.commitRestore(plan);

    final restored = await openLive();
    addTearDown(restored.close);
    final names = await restored
        .customSelect('SELECT name FROM role')
        .get()
        .then((rows) => rows.map((row) => row.read<String>('name')).toList());
    expect(names, ['OldAda']);
    final revisions = await restored
        .customSelect('SELECT content FROM role_desc_revision')
        .get();
    expect(revisions.single.read<String>('content'), 'from-v4');
    final restoredRole = (await DriftRoleRepository(restored).list()).single;
    expect(restoredRole.customAttributes, isEmpty);
    expect(restoredRole.desc, 'from-v4');
  });

  test('newer-schema backup is refused and local rows stay', () async {
    final live = await openLive();
    await seedRole(live, name: 'KeepMe');
    await live.close();

    cloud.files[AppDatabase.sqliteFileName] = _schemaSqlite(
      version: AppDatabase.currentSchemaVersion + 1,
      name: 'Newer',
    );
    cloud.files['manifest.json'] = utf8.encode(
      jsonEncode(
        BackupManifest(
          format: 1,
          schemaVersion: AppDatabase.currentSchemaVersion + 1,
          appVersion: '9.0.0+1',
          createdAt: DateTime.utc(2026, 9, 1),
          covers: const [],
        ).toJson(),
      ),
    );

    await expectLater(
      service.prepareRestore(),
      throwsA(isA<BackupNewerThanAppException>()),
    );

    final still = await openLive();
    addTearDown(still.close);
    final names = await still
        .customSelect('SELECT name FROM role')
        .get()
        .then((rows) => rows.map((row) => row.read<String>('name')).toList());
    expect(names, ['KeepMe']);
  });

  test('schema 2 backup is refused', () async {
    cloud.files[AppDatabase.sqliteFileName] = _schemaSqlite(
      version: 2,
      name: 'Ancient',
    );
    await expectLater(
      service.prepareRestore(),
      throwsA(isA<BackupTooOldException>()),
    );
  });

  test(
    'restore download failure leaves local db and covers unchanged',
    () async {
      final live = await openLive();
      await writeCover('ada.png', const [4, 5, 6]);
      await seedRole(live, name: 'KeepMe');
      await live.close();
      final sqliteBefore = await File(
        p.join(support.path, AppDatabase.sqliteFileName),
      ).readAsBytes();

      cloud.files[AppDatabase.sqliteFileName] = _schemaSqlite(
        version: AppDatabase.currentSchemaVersion,
        name: 'Incoming',
      );
      cloud.files['covers/x.png'] = const [1];
      cloud.failDownloadOf = 'covers/x.png';

      await expectLater(
        service.prepareRestore(),
        throwsA(isA<RestoreFailedException>()),
      );
      expect(
        await File(p.join(support.path, AppDatabase.sqliteFileName))
            .readAsBytes(),
        sqliteBefore,
      );
      expect(
        await File(p.join(support.path, 'covers', 'ada.png')).readAsBytes(),
        const [4, 5, 6],
      );
    },
  );

  test(
    'cancelling restore before commit leaves local files unchanged',
    () async {
      final live = await openLive();
      await writeCover('ada.png', const [4, 5, 6]);
      await seedRole(live, name: 'KeepMe');
      await service.backup(database: live);
      await live.close();

      await File(p.join(support.path, 'covers', 'ada.png'))
          .writeAsBytes(const [0]);
      final plan = await service.prepareRestore();
      await plan.dispose();

      expect(
        await File(p.join(support.path, 'covers', 'ada.png')).readAsBytes(),
        const [0],
      );
      final still = await openLive();
      addTearDown(still.close);
      final names = await still
          .customSelect('SELECT name FROM role')
          .get()
          .then((rows) => rows.map((row) => row.read<String>('name')).toList());
      expect(names, ['KeepMe']);
    },
  );

  test('sqlite replace failure rolls covers back', () async {
    final database = await openLive();
    await writeCover('ada.png', const [4, 5, 6]);
    await seedRole(database, name: 'KeepMe');
    await service.backup(database: database);
    await database.close();

    await File(p.join(support.path, 'covers', 'ada.png'))
        .writeAsBytes(const [9]);

    final plan = await service.prepareRestore();
    final failing = ICloudBackupService(
      container: cloud,
      supportDirectory: () async => support,
      snapshotter: _FailingReplaceSnapshotter(),
    );
    await expectLater(
      failing.commitRestore(plan),
      throwsA(isA<RestoreFailedException>()),
    );

    expect(
      await File(p.join(support.path, 'covers', 'ada.png')).readAsBytes(),
      const [9],
    );
    final still = await openLive();
    addTearDown(still.close);
    final names = await still
        .customSelect('SELECT name FROM role')
        .get()
        .then((rows) => rows.map((row) => row.read<String>('name')).toList());
    expect(names, ['KeepMe']);
  });

  test('unavailable iCloud refuses backup', () async {
    cloud.available = false;
    final live = await openLive();
    addTearDown(live.close);
    expect(
      () => service.backup(database: live),
      throwsA(isA<ICloudUnavailableException>()),
    );
  });

  test('assets restore from snapshot references even without a manifest or directory listing', () async {
    final database = await openLive();
    await seedRole(database, coverImg: '');
    final assets = DriftRoleAssetRepository(
      database,
      supportDirectory: () async => support,
    );
    await assets.importFiles(1, [
      XFile.fromData(Uint8List.fromList([1, 2, 3]), path: 'clip.mp4'),
      XFile.fromData(Uint8List.fromList([4, 5]), path: 'voice.mp3'),
      XFile.fromData(Uint8List(0), path: 'empty.txt'),
    ]);
    final before = await assets.listForRole(1);
    final manifest = await service.backup(database: database);
    expect(manifest.assets, hasLength(3));
    final uploadCount = cloud.uploadCount;
    await assets.rename(roleId: 1, assetId: before.first.id, baseName: '重命名资产');
    final renamed = await assets.listForRole(1);
    expect(renamed.first.name, '重命名资产.txt');
    await service.backup(database: database);
    expect(cloud.uploadCount, uploadCount + 2);
    await database.close();
    await RoleAssetStore(support).directory.delete(recursive: true);
    cloud.files.remove('manifest.json');
    cloud.hideFromList = true;
    final plan = await service.prepareRestore();
    await service.commitRestore(plan);
    final restored = await openLive();
    addTearDown(restored.close);
    final restoredAssets = DriftRoleAssetRepository(
      restored,
      supportDirectory: () async => support,
    );
    final rows = await restoredAssets.listForRole(1);
    expect(rows.map((asset) => asset.name), renamed.map((asset) => asset.name));
    expect(
      rows.map((asset) => asset.relativePath),
      before.map((asset) => asset.relativePath),
    );
    expect(
      rows.map((asset) => asset.bytes),
      before.map((asset) => asset.bytes),
    );
    for (final asset in rows) {
      expect(
        await (await restoredAssets.fileFor(asset)).readAsBytes(),
        cloud.files[asset.relativePath],
      );
    }
  });

  test(
    'truncated asset downloads are rejected before changing live files',
    () async {
      final database = await openLive();
      await seedRole(database, coverImg: '');
      final assets = DriftRoleAssetRepository(
        database,
        supportDirectory: () async => support,
      );
      await assets.importFiles(1, [
        XFile.fromData(Uint8List.fromList([1, 2, 3]), path: 'clip.mp4'),
      ]);
      final asset = (await assets.listForRole(1)).single;
      await service.backup(database: database);
      await database.close();
      cloud.files[asset.relativePath] = [1];
      await expectLater(
        service.prepareRestore(),
        throwsA(isA<RestoreFailedException>()),
      );
      expect(
        await RoleAssetStore(support).resolve(asset.relativePath).readAsBytes(),
        [1, 2, 3],
      );
    },
  );

  test(
    'database replacement failure rolls back both covers and assets',
    () async {
      final database = await openLive();
      await seedRole(database);
      await writeCover('ada.png', [1]);
      final assets = DriftRoleAssetRepository(
        database,
        supportDirectory: () async => support,
      );
      await assets.importFiles(1, [
        XFile.fromData(Uint8List.fromList([2, 3]), path: 'notes.pdf'),
      ]);
      final asset = (await assets.listForRole(1)).single;
      await service.backup(database: database);
      await database.close();
      await writeCover('ada.png', [8]);
      await RoleAssetStore(support)
          .resolve(asset.relativePath)
          .writeAsBytes([9]);
      final plan = await service.prepareRestore();
      final failing = ICloudBackupService(
        container: cloud,
        supportDirectory: () async => support,
        snapshotter: _FailingReplaceSnapshotter(),
      );
      await expectLater(
        failing.commitRestore(plan),
        throwsA(isA<RestoreFailedException>()),
      );
      expect(await File(p.join(support.path, 'covers/ada.png')).readAsBytes(), [
        8,
      ]);
      expect(
        await RoleAssetStore(support).resolve(asset.relativePath).readAsBytes(),
        [9],
      );
    },
  );

  test('restoring a pre-asset backup clears newer local assets and migrates to the new table', () async {
    final database = await openLive();
    await seedRole(database, coverImg: '');
    final assets = DriftRoleAssetRepository(
      database,
      supportDirectory: () async => support,
    );
    await assets.importFiles(1, [
      XFile.fromData(Uint8List.fromList([1]), path: 'new.pdf'),
    ]);
    await database.close();
    cloud.files[AppDatabase.sqliteFileName] = _schemaSqlite(
      version: 4,
      name: 'Old',
    );
    final plan = await service.prepareRestore();
    await service.commitRestore(plan);
    expect(await RoleAssetStore(support).listLocal(), isEmpty);
    final restored = await openLive();
    addTearDown(restored.close);
    expect((await DriftRoleRepository(restored).list()).single.name, 'Old');
    expect(
      await DriftRoleAssetRepository(
        restored,
        supportDirectory: () async => support,
      ).listForRole(1),
      isEmpty,
    );
  });
}

class _FailingReplaceSnapshotter extends SqliteSnapshotter {
  @override
  Future<void> replaceLive({required File snapshot, required File liveSqlite}) {
    return Future.error(StateError('simulated replace failure'));
  }
}

List<int> _schemaSqlite({
  required int version,
  required String name,
  String desc = 'sample',
}) {
  final file = File(
    p.join(
      Directory.systemTemp.path,
      'fixture_${version}_${name.hashCode}.sqlite',
    ),
  );
  if (file.existsSync()) {
    file.deleteSync();
  }
  final db = sqlite3.open(file.path);
  db.execute('''
    CREATE TABLE role (
      id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
      name TEXT NOT NULL,
      sex TEXT NOT NULL,
      age TEXT NOT NULL,
      birthday TEXT NOT NULL,
      race TEXT NOT NULL,
      occupation TEXT NOT NULL,
      desc TEXT NOT NULL,
      coverimg TEXT NOT NULL
    );
  ''');
  db.execute(
    'INSERT INTO role (name, sex, age, birthday, race, occupation, desc, coverimg) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
    [name, 'female', '17', '三月三日', 'human', 'engineer', desc, ''],
  );
  db.userVersion = version;
  db.close();
  final bytes = file.readAsBytesSync();
  file.deleteSync();
  return bytes;
}
