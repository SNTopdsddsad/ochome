import 'dart:io';

import 'package:drift/native.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/data/database/app_database.dart';
import 'package:ochome/data/repositories/drift_role_asset_repository.dart';
import 'package:ochome/data/repositories/drift_role_repository.dart';
import 'package:ochome/data/services/data_storage.dart';
import 'package:ochome/data/services/sqlite_snapshotter.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late DataStorage storage;
  late AppDatabase database;
  late DriftRoleRepository roles;
  late DriftRoleAssetRepository assets;
  late int roleId;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('storage-repository');
    storage = await DataStorage.open(root);
    database = AppDatabase.forStorage(
      storage,
      executor: NativeDatabase(
        File(p.join(root.path, AppDatabase.sqliteFileName)),
      ),
    );
    roles = DriftRoleRepository(database);
    assets = DriftRoleAssetRepository(database);
    roleId = (await roles.create(
      name: '白鸦',
      sex: '',
      age: '',
      birthday: '',
      race: '',
      occupation: '',
      desc: '',
      coverImg: '',
    )).id;
  });
  tearDown(() async {
    await database.close();
    await storage.close();
    await root.delete(recursive: true);
  });

  Future<void> import() async {
    final source = await File(p.join(root.path, 'source.txt'))
        .writeAsString('original');
    await assets.importFiles(roleId, [XFile(source.path)]);
  }

  test('asset metadata deletes immediately but pinned original survives until release', () async {
    await import();
    final row = (await assets.listForRole(roleId)).single;
    final file = await assets.fileFor(row);
    final pin = storage.pinFiles([file.path]);
    await assets.delete(roleId: roleId, assetId: row.id);
    expect(await assets.listForRole(roleId), isEmpty);
    expect(await file.readAsString(), 'original');
    await pin.release();
    expect(await file.exists(), isFalse);
  });

  test('failed metadata deletion keeps original name and bytes', () async {
    await import();
    final row = (await assets.listForRole(roleId)).single;
    final file = await assets.fileFor(row);
    await database.customStatement(
      "CREATE TRIGGER reject_asset_delete BEFORE DELETE ON role_asset BEGIN SELECT RAISE(ABORT, 'simulated'); END",
    );
    await expectLater(
      assets.delete(roleId: roleId, assetId: row.id),
      throwsA(anything),
    );
    expect(await assets.listForRole(roleId), hasLength(1));
    expect(await file.readAsString(), 'original');
  });

  test(
    'all stale repository mutators reject before opening files or writing',
    () async {
      final stage = await storage.createStagingDataset();
      await const SqliteSnapshotter().createSnapshot(
        liveSqlite: File(p.join(root.path, AppDatabase.sqliteFileName)),
        destDir: stage,
      );
      await storage.activate(
        stage,
        closeDatabase: database.close,
        reopenDatabase: () async {},
      );
      final source = await File(p.join(root.path, 'later.txt'))
          .writeAsString('later');
      await expectLater(
        assets.importFiles(roleId, [XFile(source.path)]),
        throwsStateError,
      );
      await expectLater(
        assets.rename(roleId: roleId, assetId: 1, baseName: 'later'),
        throwsStateError,
      );
      await expectLater(
        assets.delete(roleId: roleId, assetId: 1),
        throwsStateError,
      );
      await expectLater(roles.delete(roleId), throwsStateError);
      expect(
        await Directory(p.join(stage.path, 'role_assets')).exists(),
        isFalse,
      );
    },
  );
}
