import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/data/database/app_database.dart' hide Role;
import 'package:ochome/data/repositories/drift_role_repository.dart';
import 'package:ochome/data/services/restore_version_gate.dart';
import 'package:ochome/data/services/sqlite_snapshotter.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory tempDir;
  const snapshotter = SqliteSnapshotter();

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sqlite_snapshotter');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<File> openPopulatedDb(String name) async {
    final file = File(p.join(tempDir.path, name));
    final database = AppDatabase(NativeDatabase(file));
    final repository = DriftRoleRepository(database);
    await repository.create(
      name: 'Ada',
      sex: 'female',
      age: '17',
      birthday: '三月三日',
      race: 'human',
      occupation: 'engineer',
      desc: 'sample',
      coverImg: 'covers/ada.png',
    );
    await snapshotter.checkpoint(database);
    await database.close();
    return file;
  }

  test('checkpoint then copy snapshot contains committed rows', () async {
    final live = await openPopulatedDb('live.sqlite');
    final destDir = Directory(p.join(tempDir.path, 'snap'));
    final snapshot = await snapshotter.copySnapshot(
      liveSqlite: live,
      destDir: destDir,
    );

    expect(snapshot.path, endsWith(AppDatabase.sqliteFileName));
    expect(await File('${snapshot.path}-wal').exists(), isFalse);
    expect(await File('${snapshot.path}-shm').exists(), isFalse);

    final restored = AppDatabase(NativeDatabase(snapshot));
    addTearDown(restored.close);
    final names = await restored
        .customSelect('SELECT name FROM role')
        .get()
        .then((rows) => rows.map((row) => row.read<String>('name')).toList());
    expect(names, ['Ada']);
    expect(
      snapshotter.readUserVersion(snapshot),
      AppDatabase.currentSchemaVersion,
    );
  });

  test('replaceLive swaps sqlite and deletes leftover wal/shm', () async {
    final live = await openPopulatedDb('live.sqlite');
    final wal = File('${live.path}-wal');
    final shm = File('${live.path}-shm');
    await wal.writeAsBytes(const [1]);
    await shm.writeAsBytes(const [2]);

    final snapshotFile = File(p.join(tempDir.path, 'incoming.sqlite'));
    final incoming = sqlite3.open(snapshotFile.path);
    incoming.execute('CREATE TABLE marker (id INTEGER PRIMARY KEY);');
    incoming.execute('INSERT INTO marker (id) VALUES (7);');
    incoming.userVersion = AppDatabase.currentSchemaVersion;
    incoming.close();

    await snapshotter.replaceLive(snapshot: snapshotFile, liveSqlite: live);

    expect(await wal.exists(), isFalse);
    expect(await shm.exists(), isFalse);
    expect(await File('${live.path}.next').exists(), isFalse);
    expect(await File('${live.path}.bak').exists(), isFalse);

    final check = sqlite3.open(live.path, mode: OpenMode.readOnly);
    addTearDown(check.close);
    expect(check.select('SELECT id FROM marker').first.columnAt(0), 7);
  });

  test(
    'replaceLive leaves the live sqlite if the snapshot is missing',
    () async {
      final live = await openPopulatedDb('live.sqlite');
      final missing = File(p.join(tempDir.path, 'missing.sqlite'));

      await expectLater(
        snapshotter.replaceLive(snapshot: missing, liveSqlite: live),
        throwsA(isA<FileSystemException>()),
      );

      expect(await live.exists(), isTrue);
      expect(await File('${live.path}.bak').exists(), isFalse);
      final restored = AppDatabase(NativeDatabase(live));
      addTearDown(restored.close);
      final names = await restored
          .customSelect('SELECT name FROM role')
          .get()
          .then((rows) => rows.map((row) => row.read<String>('name')).toList());
      expect(names, ['Ada']);
    },
  );

  test('version gate refuses newer and too-old snapshots', () {
    expect(
      snapshotter.compareVersion(
        sqliteUserVersion: AppDatabase.currentSchemaVersion + 1,
        appSchemaVersion: AppDatabase.currentSchemaVersion,
      ),
      RestoreVersionDecision.refuseNewer,
    );
    expect(
      snapshotter.compareVersion(
        sqliteUserVersion: 2,
        appSchemaVersion: AppDatabase.currentSchemaVersion,
      ),
      RestoreVersionDecision.refuseTooOld,
    );
    expect(
      snapshotter.compareVersion(
        sqliteUserVersion: 4,
        appSchemaVersion: AppDatabase.currentSchemaVersion,
      ),
      RestoreVersionDecision.proceed,
    );
    expect(
      RestoreVersionGate.compare(
        appSchemaVersion: AppDatabase.currentSchemaVersion,
        sqliteUserVersion: 5,
        manifestSchemaVersion: AppDatabase.currentSchemaVersion + 1,
      ),
      RestoreVersionDecision.refuseNewer,
    );
  });
}
