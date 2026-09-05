import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/features/role_card/role_card_delivery.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(PlatformRoleCardDelivery.channelName);
  late Directory temp;
  late List<String> paths;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('role-card-delivery-test-');
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a3ioAAAAASUVORK5CYII=',
    );
    paths = [];
    for (final name in ['hidden-role-name.png', 'second.png']) {
      final file = File('${temp.path}/$name');
      await file.writeAsBytes(png);
      paths.add(file.path);
    }
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await temp.delete(recursive: true);
  });

  test(
    'passes a complete ordered job and reports the actual saved destination',
    () async {
      MethodCall? call;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (value) async {
            call = value;
            return {
              'status': 'saved',
              'count': 2,
              'directory': '/chosen/generated-folder',
            };
          });
      final delivery = PlatformRoleCardDelivery(
        channel: channel,
        platform: TargetPlatform.macOS,
      );
      final result = await delivery.save(paths);
      expect(call!.method, 'saveImages');
      expect(call!.arguments, {'paths': paths});
      expect(result.status, RoleCardDeliveryStatus.saved);
      expect(result.count, 2);
      expect(result.directory, '/chosen/generated-folder');
      expect(delivery.saveLabel, '保存到文件夹');
    },
  );

  test(
    'directory cancellation is not success, and incomplete save results fail',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final delivery = PlatformRoleCardDelivery(
        channel: channel,
        platform: TargetPlatform.macOS,
      );
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => {'status': 'cancelled', 'count': 0},
      );
      expect(
        (await delivery.save(paths)).status,
        RoleCardDeliveryStatus.cancelled,
      );
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => {'status': 'saved', 'count': 1},
      );
      await expectLater(delivery.save(paths), throwsFormatException);
    },
  );

  test(
    'invalid files do not invoke native save and permissions remain distinct',
    () async {
      var calls = 0;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (_) async {
        calls++;
        throw PlatformException(code: 'permissionDenied', message: '禁止保存');
      });
      final delivery = PlatformRoleCardDelivery(
        channel: channel,
        platform: TargetPlatform.iOS,
      );
      await expectLater(
        delivery.save(['${temp.path}/missing.png']),
        throwsA(isA<FileSystemException>()),
      );
      expect(calls, 0);
      await expectLater(
        delivery.save(paths),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'permissionDenied',
          ),
        ),
      );
      expect(calls, 1);
    },
  );

  for (final status in ShareResultStatus.values) {
    test(
      'share $status preserves cancellation semantics and generic metadata',
      () async {
        ShareParams? sent;
        final delivery = PlatformRoleCardDelivery(
          platform: TargetPlatform.iOS,
          shareFiles: (params) async {
            sent = params;
            return ShareResult('test', status);
          },
        );
        const origin = Rect.fromLTWH(20, 30, 100, 48);
        final result = await delivery.share(paths, origin);
        expect(sent!.files!.map((file) => file.path), paths);
        expect(sent!.fileNameOverrides, [
          'zaidang-card-001.png',
          'zaidang-card-002.png',
        ]);
        expect(sent!.title, '角色卡');
        expect(sent!.text, isNull);
        expect(sent!.subject, isNull);
        expect(sent!.sharePositionOrigin, origin);
        expect(result.status, switch (status) {
          ShareResultStatus.success => RoleCardDeliveryStatus.shared,
          ShareResultStatus.dismissed => RoleCardDeliveryStatus.cancelled,
          ShareResultStatus.unavailable => RoleCardDeliveryStatus.unknown,
        });
      },
    );
  }

  test('platform capabilities expose only supported image actions', () {
    final android = PlatformRoleCardDelivery(platform: TargetPlatform.android);
    expect(android.canSave, isFalse);
    expect(android.canShare, isTrue);
    final linux = PlatformRoleCardDelivery(platform: TargetPlatform.linux);
    expect(linux.canSave, isFalse);
    expect(linux.canShare, isFalse);
  });
}
