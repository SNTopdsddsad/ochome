import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/features/role_card/role_card_export_service.dart';
import 'package:path/path.dart' as p;

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a3ioAAAAASUVORK5CYII=',
);

void main() {
  late Directory temp;
  setUp(
    () async =>
        temp = await Directory.systemTemp.createTemp('role-card-job-test-'),
  );
  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test(
    'writes complete pages in order under generic names, then releases them',
    () async {
      final progress = <int>[];
      var encoding = 0;
      final service = RoleCardExportService(
        temporaryDirectory: () async => temp,
      );
      final job = await service.render(
        pageCount: 3,
        renderPage: (page) async {
          expect(encoding++, 0, reason: 'Pages must be encoded sequentially');
          await Future<void>.delayed(Duration.zero);
          encoding--;
          return _png;
        },
        onProgress: (completed, _) => progress.add(completed),
      );
      expect(progress, [0, 1, 2, 3]);
      expect(job.paths.map(p.basename), [
        'zaidang-card-001.png',
        'zaidang-card-002.png',
        'zaidang-card-003.png',
      ]);
      for (final path in job.paths) {
        expect(await File(path).readAsBytes(), _png);
      }
      expect(job.directory.listSync().whereType<File>(), hasLength(3));
      expect(() => job.paths.add('unexpected'), throwsUnsupportedError);
      await job.release();
      expect(await job.directory.exists(), isFalse);
      await job.release();
    },
  );

  test('encoding failure removes the incomplete job and never returns partial pages', () async {
    final service = RoleCardExportService(temporaryDirectory: () async => temp);
    await expectLater(
      service.render(
        pageCount: 3,
        renderPage: (page) async {
          if (page == 1) throw StateError('encoding failure');
          return _png;
        },
      ),
      throwsStateError,
    );
    expect(
      Directory(p.join(temp.path, RoleCardExportService.directoryName))
          .listSync(),
      isEmpty,
    );
  });

  test(
    'cancellation after encoding does not leave a partial file or proceed',
    () async {
      var cancelled = false;
      final service = RoleCardExportService(
        temporaryDirectory: () async => temp,
      );
      await expectLater(
        service.render(
          pageCount: 2,
          isCancelled: () => cancelled,
          renderPage: (_) async {
            cancelled = true;
            return _png;
          },
        ),
        throwsA(isA<RoleCardExportCancelled>()),
      );
      expect(
        Directory(p.join(temp.path, RoleCardExportService.directoryName))
            .listSync(),
        isEmpty,
      );
    },
  );

  test('invalid PNG is rejected before delivery can receive a job', () async {
    final service = RoleCardExportService(temporaryDirectory: () async => temp);
    await expectLater(
      service.render(pageCount: 1, renderPage: (_) async => Uint8List(0)),
      throwsFormatException,
    );
    expect(
      Directory(p.join(temp.path, RoleCardExportService.directoryName))
          .listSync(),
      isEmpty,
    );
  });

  test(
    'share retention keeps files while expired released jobs can be cleaned',
    () async {
      final service = RoleCardExportService(
        temporaryDirectory: () async => temp,
      );
      final job = await service.render(
        pageCount: 1,
        renderPage: (_) async => _png,
      );
      await job.release(retainForShare: true);
      expect(await File(job.paths.single).exists(), isTrue);
      final later = RoleCardExportService(
        temporaryDirectory: () async => temp,
        clock: () => DateTime.now().add(const Duration(days: 2)),
      );
      final newJob = await later.render(
        pageCount: 1,
        renderPage: (_) async => _png,
      );
      expect(await job.directory.exists(), isFalse);
      expect(await File(newJob.paths.single).exists(), isTrue);
      await newJob.release();
    },
  );

  test(
    'cleanup preserves a still leased job even with an old timestamp',
    () async {
      final service = RoleCardExportService(
        temporaryDirectory: () async => temp,
      );
      final pending = Completer<Uint8List>();
      final started = Completer<void>();
      final first = service.render(
        pageCount: 1,
        renderPage: (_) {
          started.complete();
          return pending.future;
        },
      );
      await started.future;
      final root = Directory(
        p.join(temp.path, RoleCardExportService.directoryName),
      );
      final oldDirectory = root.listSync().whereType<Directory>().single;
      final later = RoleCardExportService(
        temporaryDirectory: () async => temp,
        clock: () => DateTime.now().add(const Duration(days: 2)),
      );
      final second = await later.render(
        pageCount: 1,
        renderPage: (_) async => _png,
      );
      expect(await oldDirectory.exists(), isTrue);
      pending.complete(_png);
      final firstJob = await first;
      await firstJob.release();
      await second.release();
    },
  );
}
