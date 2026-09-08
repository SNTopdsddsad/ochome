import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/data/services/file_fingerprint_store.dart';
import 'package:ochome/data/services/managed_file_importer.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late FileFingerprintStore fingerprints;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('managed-import');
    fingerprints = FileFingerprintStore(
      Directory(p.join(root.path, 'control')),
    );
  });
  tearDown(() async {
    await fingerprints.close();
    await root.delete(recursive: true);
  });

  test(
    'source is streamed once, large chunks bounded, exact digest cached',
    () async {
      final source = _StreamFile([
        List.filled(150000, 1),
        [2, 3],
      ], expectedBytes: 150002);
      final target = File(p.join(root.path, 'target.mp4'));
      final digest = await ManagedFileImporter.copy(
        source,
        target,
        fingerprints: fingerprints,
      );
      expect(source.readCount, 1);
      expect(digest.bytes, 150002);
      expect(
        digest.sha256,
        (await sha256.bind(target.openRead()).first).toString(),
      );
      expect((await fingerprints.fingerprint(target)).sha256, digest.sha256);
    },
  );

  test('zero-byte document is a valid immutable import', () async {
    final target = File(p.join(root.path, 'empty.txt'));
    final digest = await ManagedFileImporter.copy(
      _StreamFile([], expectedBytes: 0),
      target,
      fingerprints: fingerprints,
    );
    expect(await target.length(), 0);
    expect(digest.sha256, sha256.convert([]).toString());
  });

  test(
    'source failure drains worker and removes partial file before returning',
    () async {
      final target = File(p.join(root.path, 'failed.mp4'));
      final source = _StreamFile(
        [
          [1, 2, 3],
        ],
        expectedBytes: 10,
        fail: true,
      );
      await expectLater(
        ManagedFileImporter.copy(source, target, fingerprints: fingerprints),
        throwsStateError,
      );
      expect(await target.exists(), isFalse);
      expect(
        await File(p.join(root.path, '.failed.mp4.pending')).exists(),
        isFalse,
      );
      // A subsequent job can safely use the worker slot and final target.
      await ManagedFileImporter.copy(
        _StreamFile([
          [4],
        ], expectedBytes: 1),
        target,
      );
      expect(await target.readAsBytes(), [4]);
    },
  );

  test(
    'truncated and oversized sources publish neither file nor fingerprint',
    () async {
      for (final expected in [1, 5]) {
        final target = File(p.join(root.path, 'failed-$expected'));
        await expectLater(
          ManagedFileImporter.copy(
            _StreamFile([
              [1, 2, 3],
            ], expectedBytes: expected),
            target,
            fingerprints: fingerprints,
          ),
          throwsA(isA<FileSystemException>()),
        );
        expect(await target.exists(), isFalse);
        expect(
          await File(p.join(root.path, '.failed-$expected.pending')).exists(),
          isFalse,
        );
      }
    },
  );

  test('immutable target cannot be overwritten', () async {
    final target = await File(p.join(root.path, 'saved')).writeAsString('old');
    await expectLater(
      ManagedFileImporter.copy(
        _StreamFile([
          [1],
        ], expectedBytes: 1),
        target,
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(await target.readAsString(), 'old');
  });
}

class _StreamFile extends XFile {
  _StreamFile(this.chunks, {required this.expectedBytes, this.fail = false})
    : super('memory.mp4');
  final List<List<int>> chunks;
  final int expectedBytes;
  final bool fail;
  int readCount = 0;
  @override
  Future<int> length() async => expectedBytes;
  @override
  Stream<Uint8List> openRead([int? start, int? end]) async* {
    readCount++;
    for (final chunk in chunks) {
      yield Uint8List.fromList(chunk);
    }
    if (fail) throw StateError('interrupted source');
  }

  @override
  Future<Never> readAsBytes() => throw StateError('must stream the source');
}
