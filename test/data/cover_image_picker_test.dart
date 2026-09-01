import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ochome/data/services/cover_image_picker.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cover_image_picker');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('savePickedFile copies bytes into covers/', () async {
    final source = File(p.join(tempDir.path, 'picked.png'));
    await source.writeAsBytes(const [1, 2, 3, 4]);

    final picker = CoverImagePicker(supportDirectory: () async => tempDir);
    final savedPath = await picker.savePickedFile(XFile(source.path));

    expect(savedPath, startsWith('${CoverImagePicker.directoryName}/'));
    expect(p.isAbsolute(savedPath), isFalse);
    expect(savedPath, endsWith('.png'));
    final written = File(p.join(tempDir.path, savedPath));
    expect(await written.readAsBytes(), const [1, 2, 3, 4]);
  });
}
