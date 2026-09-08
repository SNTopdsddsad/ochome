import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/data/services/file_fingerprint_store.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late FileFingerprintStore store;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('fingerprints');
    store = FileFingerprintStore(Directory(p.join(root.path, 'control')));
  });
  tearDown(() async {
    await store.close();
    await root.delete(recursive: true);
  });

  test(
    'hash is correct for an old file and persists across cache reopen',
    () async {
      final file = await File(p.join(root.path, 'old')).writeAsBytes([1, 2, 3]);
      final first = await store.fingerprint(file);
      expect(first.sha256, sha256.convert([1, 2, 3]).toString());
      expect(first.bytes, 3);
      await store.close();
      store = FileFingerprintStore(Directory(p.join(root.path, 'control')));
      expect((await store.fingerprint(file)).sha256, first.sha256);
    },
  );

  test(
    'same relative name under another dataset never reuses digest',
    () async {
      final a = await Directory(p.join(root.path, 'a')).create();
      final b = await Directory(p.join(root.path, 'b')).create();
      final fileA = await File(p.join(a.path, 'video.mp4'))
          .writeAsBytes([1, 2]);
      final fileB = await File(p.join(b.path, 'video.mp4'))
          .writeAsBytes([3, 4]);
      expect(
        (await store.fingerprint(fileA)).sha256,
        isNot((await store.fingerprint(fileB)).sha256),
      );
    },
  );

  test(
    'size and version changes invalidate same-path cached fingerprint',
    () async {
      final file = await File(p.join(root.path, 'video')).writeAsBytes([1, 2]);
      final first = await store.fingerprint(file);
      await file.writeAsBytes([3, 4]);
      await file.setLastModified(DateTime(2020));
      final second = await store.fingerprint(file);
      expect(first.sha256, isNot(second.sha256));
      await file.writeAsBytes([5, 6, 7]);
      expect((await store.fingerprint(file)).bytes, 3);
    },
  );

  test('missing file invalidates stored cache and does not look like empty document', () async {
    final file = await File(p.join(root.path, 'document')).writeAsString('');
    final value = await store.fingerprint(file);
    expect(value.bytes, 0);
    expect(value.sha256, sha256.convert([]).toString());
    await file.delete();
    await expectLater(
      store.fingerprint(file),
      throwsA(isA<FileSystemException>()),
    );
  });

  test(
    'corrupt derived cache is rebuilt without touching source media',
    () async {
      final dir = await Directory(p.join(root.path, 'control')).create();
      await File(p.join(dir.path, 'file-fingerprints.sqlite'))
          .writeAsString('corrupt');
      final file = await File(p.join(root.path, 'document'))
          .writeAsBytes([1, 2]);
      expect(
        (await store.fingerprint(file)).sha256,
        sha256.convert([1, 2]).toString(),
      );
      expect(await file.readAsBytes(), [1, 2]);
    },
  );

  test('cache-only lookup never reads media or creates a missing index', () async {
    final file = await File(p.join(root.path, 'original')).writeAsBytes([1, 2]);
    expect(await store.cachedFingerprint(file), isNull);
    expect(await Directory(p.join(root.path, 'control')).exists(), isFalse);
    final expected = FileFingerprint(
      sha256: sha256.convert([1, 2]).toString(),
      bytes: 2,
    );
    await store.remember(file, expected);
    await store.close();
    store = FileFingerprintStore(Directory(p.join(root.path, 'control')));
    expect((await store.cachedFingerprint(file))!.sha256, expected.sha256);
    await file.writeAsBytes([3, 4]);
    await file.setLastModified(DateTime(2020));
    expect(await store.cachedFingerprint(file), isNull);
    // A validation of an immutable prior dataset must compare actual bytes to
    // this expectation instead of blessing corruption with a fresh cache entry.
    expect(
      (await store.cachedFingerprint(file, requireCurrentStat: false))!.sha256,
      expected.sha256,
    );
    expect(await file.readAsBytes(), [3, 4]);
  });

  test('cache-only lookup preserves corrupt index evidence', () async {
    final file = await File(p.join(root.path, 'original')).writeAsBytes([1]);
    final dir = await Directory(p.join(root.path, 'control')).create();
    final index = await File(p.join(dir.path, 'file-fingerprints.sqlite'))
        .writeAsString('broken');
    expect(await store.cachedFingerprint(file), isNull);
    expect(await index.readAsString(), 'broken');
  });

  test('untrusted remembered length is rejected, forced scan verifies actual bytes', () async {
    final file = await File(p.join(root.path, 'document')).writeAsBytes([1, 2]);
    await expectLater(
      store.remember(
        file,
        FileFingerprint(sha256: sha256.convert([1]).toString(), bytes: 1),
      ),
      throwsFormatException,
    );
    // Simulates stat-unobservable corruption: a historical record is never a
    // substitute for actual-byte verification during upload/restore.
    await store.remember(
      file,
      FileFingerprint(sha256: sha256.convert([9, 9]).toString(), bytes: 2),
    );
    expect(
      (await store.fingerprint(file, force: true)).sha256,
      sha256.convert([1, 2]).toString(),
    );
  });
}
