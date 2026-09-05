import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/pages/cover_preview_page.dart';
import 'package:ochome/theme/zaidang_theme.dart';
import 'package:photo_view/photo_view_gallery.dart';

void main() {
  late Directory directory;
  late List<File> photos;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cover_gallery');
    photos = [
      await _writeImage(directory, 'portrait.png', 240, 480, Colors.red),
      await _writeImage(directory, 'landscape.png', 480, 240, Colors.green),
      await _writeImage(directory, 'square.png', 300, 300, Colors.blue),
    ];
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('close icon meets contrast requirements in $mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: zaidangLightTheme(),
          darkTheme: zaidangDarkTheme(),
          themeMode: mode,
          home: const CoverPreviewPage(coverImages: []),
        ),
      );

      // 从实际控件读取最终颜色；白图和黑图分别覆盖底图亮度的两端。
      final closeButton = find.byType(IconButton);
      final material = tester.widget<Material>(
        find.descendant(of: closeButton, matching: find.byType(Material)),
      );
      final iconColor = IconTheme.of(tester.element(find.byIcon(Icons.close)))
          .color!;
      for (final photoColor in [Colors.white, Colors.black]) {
        final background = Color.alphaBlend(material.color!, photoColor);
        final foreground = Color.alphaBlend(iconColor, background);
        final foregroundLuminance = foreground.computeLuminance();
        final backgroundLuminance = background.computeLuminance();
        final lighter = foregroundLuminance > backgroundLuminance
            ? foregroundLuminance
            : backgroundLuminance;
        final darker = foregroundLuminance < backgroundLuminance
            ? foregroundLuminance
            : backgroundLuminance;
        expect(
          (lighter + 0.05) / (darker + 0.05),
          greaterThanOrEqualTo(3),
          reason: 'Close must stay visible over $photoColor in $mode',
        );
      }
    });
  }

  testWidgets(
    'gallery opens the requested image and swipes in both directions',
    (tester) async {
      var directoryLookups = 0;
      await _openGallery(
        tester,
        photos: photos,
        paths: ['portrait.png', photos[1].path, 'square.png'],
        initialIndex: 1,
        supportDirectory: () async {
          directoryLookups++;
          return directory;
        },
      );

      expect(find.text('2 / 3'), findsOneWidget);
      final original = _imageRect(tester, photos[1]);
      expect(original.width, closeTo(400, 1));
      expect(original.height, closeTo(200, 1));
      expect(original.center.dx, closeTo(200, 0.01));
      expect(original.center.dy, closeTo(400, 0.01));

      await tester.drag(find.byType(PhotoViewGallery), const Offset(-350, 0));
      await _settle(tester);
      expect(find.text('3 / 3'), findsOneWidget);
      expect(_imageRect(tester, photos[2]).width, closeTo(400, 1));

      await tester.drag(find.byType(PhotoViewGallery), const Offset(350, 0));
      await _settle(tester);
      expect(find.text('2 / 3'), findsOneWidget);
      await tester.drag(find.byType(PhotoViewGallery), const Offset(350, 0));
      await _settle(tester);
      expect(find.text('1 / 3'), findsOneWidget);
      expect(_imageRect(tester, photos[0]).height, closeTo(800, 1));
      expect(directoryLookups, 1);
      expect(find.byType(CoverPreviewPage), findsOneWidget);
    },
  );

  testWidgets(
    'pinching and panning zoom the current image without dismissing',
    (tester) async {
      await _openGallery(tester, photos: photos, initialIndex: 2);
      final before = _imageRect(tester, photos[2]);
      final center = before.center;
      final first = await tester.startGesture(
        center - const Offset(30, 0),
        pointer: 1,
      );
      final second = await tester.startGesture(
        center + const Offset(30, 0),
        pointer: 2,
      );
      for (final distance in [50.0, 80.0, 120.0]) {
        await first.moveTo(center - Offset(distance, 0));
        await second.moveTo(center + Offset(distance, 0));
        await tester.pump(const Duration(milliseconds: 40));
      }
      await first.up();
      await second.up();
      await _settle(tester);

      final enlarged = _imageRect(tester, photos[2]);
      expect(enlarged.width, greaterThan(before.width * 1.5));
      expect(find.text('3 / 3'), findsOneWidget);
      await tester.drag(find.byType(PhotoViewGallery), const Offset(-40, 0));
      await _settle(tester);
      expect(_imageRect(tester, photos[2]).left, lessThan(enlarged.left));
      expect(find.text('3 / 3'), findsOneWidget);
      expect(find.byType(CoverPreviewPage), findsOneWidget);
    },
  );

  testWidgets('double tap zooms but a single tap dismisses only the preview', (
    tester,
  ) async {
    await _openGallery(tester, photos: [photos[2]]);
    expect(find.text('1 / 1'), findsNothing);
    final before = _imageRect(tester, photos[2]);
    await tester.tapAt(before.center);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(before.center);
    await _settle(tester);
    expect(find.byType(CoverPreviewPage), findsOneWidget);
    expect(_imageRect(tester, photos[2]).width, greaterThan(before.width));

    await tester.tapAt(before.center);
    await _settle(tester);
    expect(find.byType(CoverPreviewPage), findsNothing);
    expect(find.text('打开图库'), findsOneWidget);
  });

  for (final exit in ['background', 'close', 'system']) {
    testWidgets('$exit exits the preview without leaving its caller', (
      tester,
    ) async {
      await _openGallery(tester, photos: [photos[1]]);
      switch (exit) {
        case 'background':
          await tester.tapAt(const Offset(200, 100));
        case 'close':
          await tester.tap(find.byTooltip('关闭'));
        case 'system':
          await tester.binding.handlePopRoute();
      }
      await _settle(tester);
      expect(find.byType(CoverPreviewPage), findsNothing);
      expect(find.text('打开图库'), findsOneWidget);
    });
  }

  for (final index in [-10, 20]) {
    testWidgets('initial index $index is clamped to the gallery bounds', (
      tester,
    ) async {
      await _openGallery(tester, photos: photos, initialIndex: index);
      expect(find.text(index < 0 ? '1 / 3' : '3 / 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('an empty gallery can be dismissed', (tester) async {
    await _openGallery(tester, photos: []);
    expect(find.text('暂无图片'), findsOneWidget);
    await tester.tap(find.text('暂无图片'));
    await _settle(tester);
    expect(find.byType(CoverPreviewPage), findsNothing);
    expect(find.text('打开图库'), findsOneWidget);
  });

  testWidgets('a directory failure does not block absolute images or closing', (
    tester,
  ) async {
    await _openGallery(
      tester,
      photos: photos,
      paths: ['unavailable.png', photos[1].path],
      supportDirectory: () async =>
          throw const FileSystemException('unavailable'),
    );
    expect(find.text('图片无法加载'), findsOneWidget);
    await tester.drag(find.byType(PhotoViewGallery), const Offset(-350, 0));
    await _settle(tester);
    expect(find.text('2 / 2'), findsOneWidget);
    expect(_imageRect(tester, photos[1]).width, closeTo(400, 1));
    await tester.tap(find.byTooltip('关闭'));
    await _settle(tester);
    expect(find.text('打开图库'), findsOneWidget);
  });

  for (final failure in ['missing', 'corrupt']) {
    testWidgets('a $failure image shows an error and can be swiped past', (
      tester,
    ) async {
      final broken = File('${directory.path}/$failure.png');
      if (failure == 'corrupt') {
        await tester.runAsync(() => broken.writeAsString('not an image'));
      }
      await _openGallery(
        tester,
        photos: photos,
        paths: [broken.path, photos[0].path],
        errorImage: broken,
      );
      expect(find.text('图片无法加载'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(PhotoViewGallery), const Offset(-350, 0));
      await _settle(tester);
      expect(find.text('2 / 2'), findsOneWidget);
      expect(_imageRect(tester, photos[0]).height, closeTo(800, 1));
      await tester.tap(find.byTooltip('关闭'));
      await _settle(tester);
      expect(find.text('打开图库'), findsOneWidget);
    });
  }
}

Future<File> _writeImage(
  Directory directory,
  String name,
  int width,
  int height,
  Color color,
) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawColor(color, BlendMode.src);
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return await File('${directory.path}/$name')
        .writeAsBytes(bytes!.buffer.asUint8List());
  } finally {
    image.dispose();
    picture.dispose();
  }
}

Future<void> _openGallery(
  WidgetTester tester, {
  required List<File> photos,
  List<String>? paths,
  int initialIndex = 0,
  Future<Directory> Function()? supportDirectory,
  File? errorImage,
}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: zaidangLightTheme(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => CoverPreviewPage(
                  coverImages:
                      paths ?? photos.map((photo) => photo.path).toList(),
                  initialIndex: initialIndex,
                  supportDirectory: supportDirectory,
                ),
              ),
            ),
            child: const Text('打开图库'),
          ),
        ),
      ),
    ),
  );
  // 在真实异步区先解码，避免只测到了仍在加载的占位页面。
  await tester.runAsync(() async {
    final context = tester.element(find.text('打开图库'));
    for (final photo in photos) {
      await precacheImage(FileImage(photo), context);
    }
  });
  if (errorImage == null) {
    await tester.tap(find.text('打开图库'));
  } else {
    // 失败结果不会进入图片缓存，在真实异步区完成页面首次加载及失败通知。
    await tester.runAsync(() async {
      final context = tester.element(find.text('打开图库'));
      await tester.tap(find.text('打开图库'));
      await _settle(tester);
      await precacheImage(FileImage(errorImage), context, onError: (_, _) {});
    });
  }
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  // 单击要先等待双击识别窗口，再推进路由退出动画。
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
}

Rect _imageRect(WidgetTester tester, File photo) {
  final finder = find.byWidgetPredicate((widget) {
    if (widget is! Image || widget.image is! FileImage) {
      return false;
    }
    return (widget.image as FileImage).file.path == photo.path;
  });
  final render = tester.renderObject<RenderBox>(finder);
  return MatrixUtils.transformRect(
    render.getTransformTo(null),
    Offset.zero & render.size,
  );
}
