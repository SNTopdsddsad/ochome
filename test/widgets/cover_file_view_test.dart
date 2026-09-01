import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/widgets/cover_file_view.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cover_file_view');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  const placeholderKey = Key('cover-placeholder');
  const placeholder = SizedBox(key: placeholderKey);

  testWidgets('empty coverImg shows placeholder', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CoverFileView(coverImg: '', placeholder: placeholder),
      ),
    );
    expect(find.byKey(placeholderKey), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('missing relative coverImg shows placeholder', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CoverFileView(
          coverImg: 'covers/missing.png',
          placeholder: placeholder,
          supportDirectory: () async => tempDir,
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(placeholderKey), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('missing absolute coverImg shows placeholder', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CoverFileView(
          coverImg: '${tempDir.path}/gone.png',
          placeholder: placeholder,
          supportDirectory: () async => tempDir,
        ),
      ),
    );
    expect(find.byKey(placeholderKey), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });
}
