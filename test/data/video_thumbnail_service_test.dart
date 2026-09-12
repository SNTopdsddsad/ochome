import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/data/services/video_thumbnail_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/video_thumbnail');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory root;
  late File video;
  late VideoThumbnailService service;
  final calls = <MethodCall>[];

  setUp(() async {
    root = await Directory.systemTemp.createTemp('video-thumbnail-test');
    video = File('${root.path}/original.mp4');
    await video.writeAsBytes([1, 2, 3]);
    service = VideoThumbnailService(
      channel: channel,
      cacheDirectory: () async => root,
    );
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      await File(call.arguments['thumbnailPath'] as String)
          .writeAsBytes([9, 8, 7]);
      return true;
    });
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    await root.delete(recursive: true);
  });

  test('generates a bounded first frame, caches it across service instances and keeps video untouched', () async {
    final image = await service.thumbnailFor(video);
    expect(image, isNotNull);
    expect(calls.single.method, 'firstFrame');
    expect(calls.single.arguments['videoPath'], video.absolute.path);
    expect(calls.single.arguments['maxDimension'], 320);
    expect(await image!.readAsBytes(), [9, 8, 7]);
    expect(await video.readAsBytes(), [1, 2, 3]);
    final recreated = VideoThumbnailService(
      channel: channel,
      cacheDirectory: () async => root,
    );
    expect((await recreated.thumbnailFor(video))!.path, image.path);
    expect(calls, hasLength(1));
  });

  test('concurrent requests for the same video share one generation', () async {
    final results = await Future.wait(
      List.generate(8, (_) => service.thumbnailFor(video)),
    );
    expect(calls, hasLength(1));
    expect(results.map((file) => file!.path).toSet(), hasLength(1));
  });

  test('changed video or removed cache gets a fresh frame', () async {
    final first = (await service.thumbnailFor(video))!;
    await first.delete();
    expect((await service.thumbnailFor(video))!.path, first.path);
    expect(calls, hasLength(2));
    await video.writeAsBytes([4, 5, 6, 7]);
    final changed = (await service.thumbnailFor(video))!;
    expect(changed.path, isNot(first.path));
    expect(calls, hasLength(3));
  });

  test('failed extraction clears partial output and does not repeatedly retry the same broken video', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      await File(call.arguments['thumbnailPath'] as String).writeAsBytes([0]);
      return false;
    });
    expect(await service.thumbnailFor(video), isNull);
    expect(await service.thumbnailFor(video), isNull);
    expect(calls, hasLength(1));
    expect(
      await Directory('${root.path}/${VideoThumbnailService.folderName}')
          .list()
          .toList(),
      isEmpty,
    );
    expect(await video.readAsBytes(), [1, 2, 3]);
  });

  test('native error does not poison subsequent requests', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.arguments['videoPath'] == video.absolute.path) {
        throw PlatformException(code: 'unsupportedVideo');
      }
      await File(call.arguments['thumbnailPath'] as String).writeAsBytes([9]);
      return true;
    });
    final other = File('${root.path}/other.mov');
    await other.writeAsBytes([3, 4]);
    final results = await Future.wait([
      service.thumbnailFor(video),
      service.thumbnailFor(other),
    ]);
    expect(results[0], isNull);
    expect(results[1], isNotNull);
    expect(calls, hasLength(2));
  });

  test('different videos are decoded serially', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    var active = 0;
    var maxActive = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      active++;
      if (active > maxActive) maxActive = active;
      if (calls.length == 1) {
        started.complete();
        await release.future;
      }
      await File(call.arguments['thumbnailPath'] as String).writeAsBytes([9]);
      active--;
      return true;
    });
    final other = File('${root.path}/other.mov');
    await other.writeAsBytes([4]);
    final first = service.thumbnailFor(video);
    await started.future;
    final second = service.thumbnailFor(other);
    release.complete();
    await Future.wait([first, second]);
    expect(calls, hasLength(2));
    expect(maxActive, 1);
  });

  test(
    'missing videos and unavailable native handlers return no cover',
    () async {
      expect(
        await service.thumbnailFor(File('${root.path}/missing.mp4')),
        isNull,
      );
      expect(calls, isEmpty);
      messenger.setMockMethodCallHandler(channel, null);
      expect(await service.thumbnailFor(video), isNull);
    },
  );

  test(
    'reads positive native duration and caches it across service instances',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        expect(call.method, 'duration');
        expect(call.arguments['videoPath'], video.absolute.path);
        return 24500;
      });

      expect(
        await service.durationFor(video),
        const Duration(milliseconds: 24500),
      );
      final recreated = VideoThumbnailService(
        channel: channel,
        cacheDirectory: () async => root,
      );
      expect(
        await recreated.durationFor(video),
        const Duration(milliseconds: 24500),
      );
      expect(calls, hasLength(1));
    },
  );

  test('concurrent duration requests share one native read', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      started.complete();
      await release.future;
      return 3723004;
    });

    final requests = List.generate(8, (_) => service.durationFor(video));
    await started.future;
    release.complete();
    expect(
      await Future.wait(requests),
      everyElement(const Duration(milliseconds: 3723004)),
    );
    expect(calls, hasLength(1));
  });

  test('changed video invalidates its cached duration', () async {
    var milliseconds = 1000;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return milliseconds;
    });

    expect(await service.durationFor(video), const Duration(seconds: 1));
    milliseconds = 2000;
    await video.writeAsBytes([1, 2, 3, 4]);
    expect(await service.durationFor(video), const Duration(seconds: 2));
    expect(calls, hasLength(2));
  });

  test('cache failure does not hide a duration read from the video', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return 4500;
    });
    final withoutCache = VideoThumbnailService(
      channel: channel,
      cacheDirectory: () async =>
          throw const FileSystemException('cache unavailable'),
    );

    expect(
      await withoutCache.durationFor(video),
      const Duration(milliseconds: 4500),
    );
    expect(calls, hasLength(1));
  });

  test(
    'unknown and broken durations return null without inventing zero',
    () async {
      for (final response in <int?>[null, 0, -1]) {
        final candidate = File('${root.path}/duration-$response.mp4');
        await candidate.writeAsBytes([1]);
        messenger.setMockMethodCallHandler(channel, (_) async => response);
        expect(await service.durationFor(candidate), isNull);
      }
      final broken = File('${root.path}/broken.mp4');
      await broken.writeAsBytes([1]);
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(code: 'unsupportedVideo');
      });
      expect(await service.durationFor(broken), isNull);
    },
  );

  test(
    'failed thumbnail extraction does not hide readable video duration',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'duration') return 3240;
        await File(call.arguments['thumbnailPath'] as String).writeAsBytes([0]);
        return false;
      });

      final results = await Future.wait<Object?>([
        service.thumbnailFor(video),
        service.durationFor(video),
      ]);
      expect(results[0], isNull);
      expect(results[1], const Duration(milliseconds: 3240));
      expect(
        calls.map((call) => call.method),
        containsAll(['firstFrame', 'duration']),
      );
    },
  );
}
