import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/data/database/app_database.dart';
import 'package:ochome/data/repositories/drift_role_repository.dart';
import 'package:ochome/data/services/data_storage.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory root;
  DataStorage? storage;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('data-storage');
  });
  tearDown(() async {
    await storage?.close();
    storage = null;
    await root.delete(recursive: true);
  });

  test('successful activations retire old data and preserve unrelated support files', () async {
    await _dataset(root, 'old');
    final unrelated = await File(p.join(root.path, 'settings.txt'))
        .writeAsString('keep');
    storage = await DataStorage.open(root);
    expect(storage!.activeDirectory.path, await root.resolveSymbolicLinks());
    final first = await storage!.createStagingDataset();
    await _dataset(first, 'first');
    await storage!.activate(first, closeDatabase: _noop, reopenDatabase: _noop);
    expect(storage!.rollbackDirectory, isNull);
    expect(await File(p.join(root.path, 'ochome.sqlite')).exists(), isFalse);
    final second = await storage!.createStagingDataset();
    await _dataset(second, 'second');
    await storage!.activate(
      second,
      closeDatabase: _noop,
      reopenDatabase: _noop,
    );
    expect(_name(storage!.activeDirectory), 'second');
    expect(storage!.rollbackDirectory, isNull);
    expect(await first.exists(), isFalse);
    expect(await File(p.join(root.path, 'ochome.sqlite')).exists(), isFalse);
    expect(await unrelated.readAsString(), 'keep');
  });

  test(
    'nested exclusive mutation is safe and late repository writes are rejected',
    () async {
      await _dataset(root, 'old');
      storage = await DataStorage.open(root);
      final database = AppDatabase.forStorage(
        storage!,
        executor: NativeDatabase.memory(),
      );
      final roles = DriftRoleRepository(database);
      await _createRole(roles);
      final before = storage!.mutationRevision;
      await storage!.exclusively(() => storage!.mutate(() async {}));
      expect(storage!.mutationRevision, before + 1);
      final stage = await storage!.createStagingDataset();
      await _dataset(stage, 'new');
      await storage!.exclusively(
        () => storage!.activate(
          stage,
          closeDatabase: database.close,
          reopenDatabase: _noop,
        ),
      );
      await expectLater(_createRole(roles), throwsStateError);
    },
  );

  test('failed open restores old root', () async {
    await _dataset(root, 'old');
    storage = await DataStorage.open(root);
    final stage = await storage!.createStagingDataset();
    await _dataset(stage, 'new');
    var opened = 0;
    await expectLater(
      storage!.activate(
        stage,
        closeDatabase: _noop,
        reopenDatabase: () async {
          opened++;
          if (opened == 1) throw StateError('failed new database open');
          expect(_name(storage!.activeDirectory), 'old');
        },
      ),
      throwsStateError,
    );
    expect(opened, 2);
    expect(_name(storage!.activeDirectory), 'old');
    await storage!.close();
    storage = await DataStorage.open(root);
    expect(_name(storage!.activeDirectory), 'old');
  });

  test(
    'startup retires a previously retained backup after checking current data',
    () async {
      await _dataset(root, 'old');
      storage = await DataStorage.open(root);
      final stage = await storage!.createStagingDataset();
      await _dataset(stage, 'new');
      final pointerFile = File(
        p.join(storage!.controlDirectory.path, 'active.json'),
      );
      await storage!.close();
      await pointerFile.writeAsString(
        jsonEncode({
          'format': 1,
          'current': {'kind': 'dataset', 'id': p.basename(stage.path)},
          'previous': {'kind': 'legacy'},
          'epoch': 1,
          'garbage': [],
        }),
        flush: true,
      );
      storage = await DataStorage.open(root);
      expect(_name(storage!.activeDirectory), 'new');
      expect(storage!.rollbackDirectory, isNull);
      expect(await File(p.join(root.path, 'ochome.sqlite')).exists(), isFalse);
    },
  );

  test('reference-counted pins defer physical deletion', () async {
    storage = await DataStorage.open(root);
    final file = await File(p.join(root.path, 'media')).writeAsBytes([1, 2]);
    final pin1 = storage!.pinFiles([file.path]);
    final pin2 = storage!.pinFiles([file.path]);
    await storage!.deleteWhenUnpinned(file);
    expect(await file.exists(), isTrue);
    await pin1.release();
    expect(await file.exists(), isTrue);
    await pin2.release();
    expect(await file.exists(), isFalse);
    await pin2.release();
  });

  test(
    'retirement failure keeps restored data active and cleanup can retry',
    () async {
      await _dataset(root, 'old');
      var failRetirement = true;
      storage = await DataStorage.open(
        root,
        atomicReplace: (temporary, target) async {
          final value = jsonDecode(await temporary.readAsString()) as Map;
          if (failRetirement &&
              p.basename(target.path) == 'active.json' &&
              value['previous'] == null &&
              (value['garbage'] as List).isNotEmpty) {
            throw const FileSystemException('retirement write failed');
          }
          await temporary.rename(target.path);
        },
      );
      final stage = await storage!.createStagingDataset();
      await _dataset(stage, 'new');
      await storage!.activate(
        stage,
        closeDatabase: _noop,
        reopenDatabase: _noop,
      );
      expect(_name(storage!.activeDirectory), 'new');
      expect(_name(root), 'old');
      expect(storage!.cleanupPending, isTrue);
      final intent = jsonDecode(
        await File(
          p.join(storage!.controlDirectory.path, 'restore-intent.json'),
        ).readAsString(),
      ) as Map;
      expect(intent['phase'], 'healthy');
      failRetirement = false;
      await storage!.cleanupRetiredData();
      expect(storage!.cleanupPending, isFalse);
      expect(storage!.rollbackDirectory, isNull);
      expect(await File(p.join(root.path, 'ochome.sqlite')).exists(), isFalse);
      expect(_name(storage!.activeDirectory), 'new');
    },
  );

  test('startup cleanup failure cannot leave a prepared rollback after accepting new data', () async {
    await _dataset(root, 'old');
    storage = await DataStorage.open(root);
    final stage = await storage!.createStagingDataset();
    await _dataset(stage, 'new');
    final activeFile = File(
      p.join(storage!.controlDirectory.path, 'active.json'),
    );
    final intentFile = File(
      p.join(storage!.controlDirectory.path, 'restore-intent.json'),
    );
    final old = jsonDecode(await activeFile.readAsString()) as Map;
    final next = {
      'format': 1,
      'current': {'kind': 'dataset', 'id': p.basename(stage.path)},
      'previous': old['current'],
      'epoch': 1,
      'garbage': [],
    };
    await storage!.close();
    await activeFile.writeAsString(jsonEncode(next), flush: true);
    await intentFile.writeAsString(
      jsonEncode({'format': 1, 'phase': 'prepared', 'old': old, 'next': next}),
      flush: true,
    );
    storage = await DataStorage.open(
      root,
      atomicReplace: (temporary, target) async {
        final value = jsonDecode(await temporary.readAsString()) as Map;
        if (p.basename(target.path) == 'active.json' &&
            value['previous'] == null) {
          throw const FileSystemException('retirement write failed');
        }
        await temporary.rename(target.path);
      },
    );
    expect(_name(storage!.activeDirectory), 'new');
    expect(
      (jsonDecode(await intentFile.readAsString()) as Map)['phase'],
      'healthy',
    );
    await storage!.close();
    await File(p.join(stage.path, 'ochome.sqlite'))
        .writeAsString('corrupt after accepted restore');
    await expectLater(DataStorage.open(root), throwsFormatException);
    expect(_name(root), 'old');
  });

  test('an ongoing write drains before activation starts', () async {
    await _dataset(root, 'old');
    storage = await DataStorage.open(root);
    final stage = await storage!.createStagingDataset();
    await _dataset(stage, 'new');
    final started = Completer<void>();
    final finish = Completer<void>();
    final write = storage!.mutate(() async {
      started.complete();
      await finish.future;
    });
    await started.future;
    var closed = false;
    final activation = storage!.activate(
      stage,
      closeDatabase: () async {
        closed = true;
      },
      reopenDatabase: _noop,
    );
    await Future<void>.delayed(Duration.zero);
    expect(closed, isFalse);
    finish.complete();
    await write;
    await activation;
    expect(closed, isTrue);
  });

  test(
    'prepared crash keeps old pointer; switched crash opens healthy new',
    () async {
      await _dataset(root, 'old');
      storage = await DataStorage.open(root);
      final stage = await storage!.createStagingDataset();
      await _dataset(stage, 'new');
      final activeFile = File(
        p.join(storage!.controlDirectory.path, 'active.json'),
      );
      final old = jsonDecode(await activeFile.readAsString()) as Map;
      final next = {
        'format': 1,
        'current': {'kind': 'dataset', 'id': p.basename(stage.path)},
        'previous': old['current'],
        'epoch': 1,
        'garbage': [],
      };
      final intentFile = File(
        p.join(storage!.controlDirectory.path, 'restore-intent.json'),
      );
      final intent = {
        'format': 1,
        'phase': 'prepared',
        'old': old,
        'next': next,
      };
      await storage!.close();
      await intentFile.writeAsString(jsonEncode(intent), flush: true);
      storage = await DataStorage.open(root);
      expect(_name(storage!.activeDirectory), 'old');
      await storage!.close();
      await intentFile.writeAsString(jsonEncode(intent), flush: true);
      await activeFile.writeAsString(jsonEncode(next), flush: true);
      storage = await DataStorage.open(root);
      expect(_name(storage!.activeDirectory), 'new');
      expect(storage!.rollbackDirectory, isNull);
      expect(await File(p.join(root.path, 'ochome.sqlite')).exists(), isFalse);
    },
  );

  test('unhealthy switched dataset falls back using durable intent', () async {
    await _dataset(root, 'old');
    storage = await DataStorage.open(root);
    final stage = await storage!.createStagingDataset();
    await _dataset(stage, 'new');
    final activeFile = File(
      p.join(storage!.controlDirectory.path, 'active.json'),
    );
    final old = jsonDecode(await activeFile.readAsString()) as Map;
    final next = {
      'format': 1,
      'current': {'kind': 'dataset', 'id': p.basename(stage.path)},
      'previous': old['current'],
      'epoch': 1,
      'garbage': [],
    };
    final intentFile = File(
      p.join(storage!.controlDirectory.path, 'restore-intent.json'),
    );
    await storage!.close();
    await File(p.join(stage.path, 'ochome.sqlite')).writeAsString('broken');
    await intentFile.writeAsString(
      jsonEncode({'format': 1, 'phase': 'prepared', 'old': old, 'next': next}),
      flush: true,
    );
    await activeFile.writeAsString(jsonEncode(next), flush: true);
    storage = await DataStorage.open(root);
    expect(_name(storage!.activeDirectory), 'old');
    expect(
      await File(p.join(stage.path, 'ochome.sqlite')).readAsString(),
      'broken',
    );
  });

  test(
    'corrupt controls never create an empty database over old files',
    () async {
      await _dataset(root, 'old');
      storage = await DataStorage.open(root);
      final active = File(
        p.join(storage!.controlDirectory.path, 'active.json'),
      );
      await storage!.close();
      await active.writeAsString('{broken');
      await expectLater(DataStorage.open(root), throwsFormatException);
      expect(_name(root), 'old');
    },
  );

  test(
    'native pointer replacement failure is a startup error, not recovery-only',
    () async {
      var replacements = 0;
      await expectLater(
        DataStorage.open(
          root,
          allowRecovery: true,
          atomicReplace: (temporary, target) async {
            replacements++;
            throw PlatformException(
              code: 'backup_io',
              message: 'injected native replacement failure',
            );
          },
        ),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'backup_io',
          ),
        ),
      );
      expect(replacements, 1);

      // The failed open released process ownership and kept the pending
      // control evidence, so a later healthy bootstrap can retry safely.
      expect(
        await File(p.join(root.path, 'storage-control', 'active.json.pending'))
            .exists(),
        isTrue,
      );
      storage = await DataStorage.open(root);
      expect(storage!.isRecoveryOnly, isFalse);
      expect(storage!.activeDirectory.path, await root.resolveSymbolicLinks());
    },
  );

  test(
    'filesystem pointer write failure also propagates from startup',
    () async {
      await expectLater(
        DataStorage.open(
          root,
          allowRecovery: true,
          atomicReplace: (temporary, target) async {
            throw FileSystemException(
              'injected filesystem replacement failure',
              target.path,
            );
          },
        ),
        throwsA(isA<FileSystemException>()),
      );

      // A failed bootstrap must release its process lock.
      storage = await DataStorage.open(root);
      expect(storage!.isRecoveryOnly, isFalse);
    },
  );

  test(
    'supported schema 3 database opens without recovery-only mode',
    () async {
      await _legacyDataset(root, version: 3);
      storage = await DataStorage.open(root, allowRecovery: true);
      expect(storage!.isRecoveryOnly, isFalse);
      expect(_name(storage!.activeDirectory), '旧角色');
    },
  );

  test(
    'unsupported schema 2 is preserved and requires explicit recovery',
    () async {
      await _legacyDataset(root, version: 2);
      storage = await DataStorage.open(root, allowRecovery: true);
      expect(storage!.isRecoveryOnly, isTrue);
      expect(storage!.recoveryError, isA<FormatException>());
      expect(_name(root), '旧角色');
    },
  );

  test(
    'post-activation cleanup failure leaves healthy data active and retryable',
    () async {
      await _dataset(root, 'old');
      var rejectGarbageCleanup = false;
      storage = await DataStorage.open(
        root,
        atomicReplace: (temporary, target) async {
          if (rejectGarbageCleanup &&
              p.basename(target.path) == 'active.json') {
            final value = jsonDecode(await temporary.readAsString()) as Map;
            if (value['previous'] == null &&
                (value['garbage'] as List).isEmpty) {
              throw StateError('injected cleanup persistence error');
            }
          }
          await temporary.rename(target.path);
        },
      );
      final first = await storage!.createStagingDataset();
      await _dataset(first, 'first');
      await storage!.activate(
        first,
        closeDatabase: _noop,
        reopenDatabase: _noop,
      );
      final second = await storage!.createStagingDataset();
      await _dataset(second, 'second');
      rejectGarbageCleanup = true;
      await storage!.activate(
        second,
        closeDatabase: _noop,
        reopenDatabase: _noop,
      );
      expect(_name(storage!.activeDirectory), 'second');
      expect(storage!.cleanupPending, isTrue);
      await storage!.close();
      storage = await DataStorage.open(root);
      expect(_name(storage!.activeDirectory), 'second');
      expect(storage!.cleanupPending, isFalse);
    },
  );

  test(
    'pinned earlier data survives retirement until snapshot releases',
    () async {
      await _dataset(root, 'old');
      storage = await DataStorage.open(root);
      final cover = File(p.join(root.path, 'covers', 'example.png'));
      final pin = storage!.pinFiles([cover.path]);
      final first = await storage!.createStagingDataset();
      await _dataset(first, 'first');
      await storage!.activate(
        first,
        closeDatabase: _noop,
        reopenDatabase: _noop,
      );
      final second = await storage!.createStagingDataset();
      await _dataset(second, 'second');
      await storage!.activate(
        second,
        closeDatabase: _noop,
        reopenDatabase: _noop,
      );
      expect(await cover.readAsString(), 'old');
      expect(storage!.cleanupPending, isTrue);
      await pin.release();
      expect(await cover.exists(), isFalse);
      expect(_name(storage!.activeDirectory), 'second');
    },
  );

  test('recovery-only startup preserves corrupt data and can activate validated cloud dataset', () async {
    await _dataset(root, 'old');
    storage = await DataStorage.open(root);
    final broken = File(p.join(root.path, 'ochome.sqlite'));
    final control = File(p.join(storage!.controlDirectory.path, 'active.json'));
    await storage!.close();
    await broken.writeAsString('corrupt database');
    await control.writeAsString('corrupt pointer');
    storage = await DataStorage.open(root, allowRecovery: true);
    expect(storage!.isRecoveryOnly, isTrue);
    expect(storage!.recoveryError, isNotNull);
    await expectLater(storage!.mutate(() async {}), throwsStateError);
    final stage = await storage!.createStagingDataset();
    await _dataset(stage, 'restored');
    await storage!.activate(
      stage,
      closeDatabase: _noop,
      reopenDatabase: () async {
        expect(storage!.isRecoveryOnly, isFalse);
      },
    );
    expect(_name(storage!.activeDirectory), 'restored');
    expect(await broken.readAsString(), 'corrupt database');
    final preserved = Directory(
      p.join(storage!.controlDirectory.path, 'recovery-controls'),
    );
    final archive = (await preserved.list().toList()).single as Directory;
    expect(
      await File(p.join(archive.path, 'active.json')).readAsString(),
      'corrupt pointer',
    );
    await storage!.mutate(() async {});
  });

  test('failed activation from recovery-only mode never reopens broken business DB', () async {
    await _dataset(root, 'old');
    storage = await DataStorage.open(root);
    await storage!.close();
    await File(p.join(root.path, 'ochome.sqlite')).writeAsString('corrupt');
    storage = await DataStorage.open(root, allowRecovery: true);
    final stage = await storage!.createStagingDataset();
    await _dataset(stage, 'new');
    var opened = 0;
    await expectLater(
      storage!.activate(
        stage,
        closeDatabase: _noop,
        reopenDatabase: () async {
          opened++;
          throw StateError('new open failed');
        },
      ),
      throwsStateError,
    );
    expect(opened, 1);
    expect(storage!.isRecoveryOnly, isTrue);
    expect(
      await File(p.join(root.path, 'ochome.sqlite')).readAsString(),
      'corrupt',
    );
  });

  test(
    'missing database with remaining WAL never initializes a fresh database',
    () async {
      final wal = await File(p.join(root.path, 'ochome.sqlite-wal'))
          .writeAsBytes([1, 2, 3]);
      await expectLater(DataStorage.open(root), throwsFormatException);
      expect(await wal.readAsBytes(), [1, 2, 3]);
      expect(await File(p.join(root.path, 'ochome.sqlite')).exists(), isFalse);
    },
  );

  test(
    'failed database close disables business writes without touching old data',
    () async {
      await _dataset(root, 'old');
      storage = await DataStorage.open(root);
      final stage = await storage!.createStagingDataset();
      await _dataset(stage, 'new');
      await expectLater(
        storage!.activate(
          stage,
          closeDatabase: () async {
            throw StateError('close failure');
          },
          reopenDatabase: _noop,
        ),
        throwsStateError,
      );
      expect(storage!.isRecoveryOnly, isTrue);
      await expectLater(storage!.mutate(() async {}), throwsStateError);
      expect(_name(root), 'old');
    },
  );

  test('failed rollback reopen keeps recovery-only guard instead of releasing stale writes', () async {
    await _dataset(root, 'old');
    storage = await DataStorage.open(root);
    final stage = await storage!.createStagingDataset();
    await _dataset(stage, 'new');
    await expectLater(
      storage!.activate(
        stage,
        closeDatabase: _noop,
        reopenDatabase: () async {
          throw StateError('open failure');
        },
      ),
      throwsStateError,
    );
    expect(storage!.isRecoveryOnly, isTrue);
    await expectLater(storage!.mutate(() async {}), throwsStateError);
    expect(_name(root), 'old');
  });

  test('second storage instance cannot bypass process ownership', () async {
    storage = await DataStorage.open(root);
    await expectLater(DataStorage.open(root), throwsStateError);
  });
}

Future<void> _noop() async {}
Future<void> _legacyDataset(Directory directory, {required int version}) async {
  await directory.create(recursive: true);
  final database = sqlite3.open(p.join(directory.path, 'ochome.sqlite'));
  try {
    database.execute('''
      CREATE TABLE role (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        sex TEXT NOT NULL,
        birthday TEXT NOT NULL,
        occupation TEXT NOT NULL,
        desc TEXT NOT NULL,
        coverimg TEXT NOT NULL
      )
    ''');
    database.execute(
      'INSERT INTO role '
      '(name, sex, birthday, occupation, desc, coverimg) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      ['旧角色', '', '', '', '', ''],
    );
    database.userVersion = version;
  } finally {
    database.close();
  }
}

Future<void> _dataset(Directory directory, String name) async {
  await directory.create(recursive: true);
  final database = sqlite3.open(p.join(directory.path, 'ochome.sqlite'));
  database.execute(
    'CREATE TABLE role(id INTEGER PRIMARY KEY, name TEXT NOT NULL)',
  );
  database.execute('INSERT INTO role(name) VALUES (?)', [name]);
  database.userVersion = AppDatabase.currentSchemaVersion;
  database.close();
  await Directory(p.join(directory.path, 'covers')).create();
  await File(p.join(directory.path, 'covers', 'example.png'))
      .writeAsString(name);
}

String _name(Directory directory) {
  final database = sqlite3.open(
    p.join(directory.path, 'ochome.sqlite'),
    mode: OpenMode.readOnly,
  );
  try {
    return database.select('SELECT name FROM role').single['name'] as String;
  } finally {
    database.close();
  }
}

Future<void> _createRole(DriftRoleRepository repository) async {
  await repository.create(
    name: 'role',
    sex: '',
    age: '',
    birthday: '',
    race: '',
    occupation: '',
    desc: '',
    coverImg: '',
  );
}
