import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/data/database/app_database.dart' hide Role;
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cover_path_migration');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'schema 5 to 6 rewrites covers/ absolute paths and keeps others',
    () async {
      final dbFile = File(p.join(tempDir.path, 'ochome.sqlite'));
      final coversDir = Directory(p.join(tempDir.path, 'covers'));
      await coversDir.create();
      final underCovers = File(p.join(coversDir.path, 'ada.png'));
      await underCovers.writeAsBytes(const [1, 2, 3]);
      final outside = File(p.join(tempDir.path, 'outside.png'));
      await outside.writeAsBytes(const [4, 5, 6]);

      final raw = sqlite3.open(dbFile.path);
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
        coverimg TEXT NOT NULL
      );
    ''');
      raw.execute(
        'INSERT INTO role (name, sex, age, birthday, race, occupation, desc, coverimg) '
        "VALUES ('Ada', 'female', '17', '三月三日', 'human', 'engineer', 'sample', ?)",
        [underCovers.path],
      );
      raw.execute(
        'INSERT INTO role (name, sex, age, birthday, race, occupation, desc, coverimg) '
        "VALUES ('Outside', '', '', '', '', '', '', ?)",
        [outside.path],
      );
      raw.execute(
        'INSERT INTO role (name, sex, age, birthday, race, occupation, desc, coverimg) '
        "VALUES ('Relative', '', '', '', '', '', '', 'covers/rel.png')",
      );
      raw.userVersion = 5;
      raw.close();

      final database = AppDatabase(NativeDatabase(dbFile));
      addTearDown(database.close);

      final rows = await database
          .customSelect('SELECT name, coverimg FROM role ORDER BY id')
          .get();
      expect(rows.map((row) => row.read<String>('name')), [
        'Ada',
        'Outside',
        'Relative',
      ]);
      expect(rows[0].read<String>('coverimg'), 'covers/ada.png');
      expect(rows[1].read<String>('coverimg'), outside.path);
      expect(rows[2].read<String>('coverimg'), 'covers/rel.png');

      final version = await database
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.data.values.single, AppDatabase.currentSchemaVersion);
    },
  );
}
