import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/data/services/cover_path.dart';
import 'package:path/path.dart' as p;

void main() {
  test('resolve joins relative cover paths under support dir', () {
    expect(
      CoverPath.resolve('/tmp/support', 'covers/ada.png'),
      p.join('/tmp/support', 'covers/ada.png'),
    );
  });

  test('resolve keeps leftover absolute paths', () {
    const absolute = '/old/sandbox/covers/ada.png';
    expect(CoverPath.resolve('/tmp/support', absolute), absolute);
    expect(File(CoverPath.resolve('/tmp/support', absolute)).path, absolute);
  });

  test('empty coverImg resolves to empty', () {
    expect(CoverPath.resolve('/tmp/support', ''), '');
  });

  test('toRelativeIfUnderCovers rewrites only covers/ absolute paths', () {
    expect(
      CoverPath.toRelativeIfUnderCovers('/var/app/covers/ada.png'),
      'covers/ada.png',
    );
    expect(
      CoverPath.toRelativeIfUnderCovers('/tmp/outside.png'),
      '/tmp/outside.png',
    );
    expect(
      CoverPath.toRelativeIfUnderCovers('covers/ada.png'),
      'covers/ada.png',
    );
  });

  test(
    'relative cover resolves to an existing file under support/covers',
    () async {
      final dir = await Directory.systemTemp.createTemp('cover_path_rel');
      addTearDown(() async {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      });
      final covers = Directory(p.join(dir.path, CoverPath.directoryName));
      await covers.create();
      final file = File(p.join(covers.path, 'ada.png'));
      await file.writeAsBytes(const [1, 2, 3]);

      final resolved = CoverPath.resolve(dir.path, 'covers/ada.png');
      expect(p.isAbsolute(resolved), isTrue);
      expect(await File(resolved).readAsBytes(), const [1, 2, 3]);
    },
  );
}
