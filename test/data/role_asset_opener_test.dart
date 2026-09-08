import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/data/services/role_asset_opener.dart';
import 'package:open_file/open_file.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/role_asset_preview');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  final fallbackPaths = <String>[];
  late Directory root;
  late File file;
  late RoleAssetOpener opener;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('role-asset-opener-test');
    file = File('${root.path}/immutable-id.mp4');
    await file.writeAsBytes([1, 2, 3]);
    calls.clear();
    fallbackPaths.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
    opener = RoleAssetOpener(
      channel: channel,
      isIOS: () => true,
      fallbackOpen: (path) async {
        fallbackPaths.add(path);
        return OpenResult();
      },
    );
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    await root.delete(recursive: true);
  });

  test('iOS forwards each current display name with the same original absolute path', () async {
    for (final name in ['白鸦·参考视频.mp4', '白鸦·新参考.mp4']) {
      await opener.open(file, displayName: name);
      expect(calls.last.method, 'openPreview');
      expect(calls.last.arguments, {
        'path': file.absolute.path,
        'displayName': name,
      });
    }
    expect(calls, hasLength(2));
    expect(fallbackPaths, isEmpty);
    expect(await file.readAsBytes(), [1, 2, 3]);
    expect(await root.list().toList(), hasLength(1));
  });

  test('iOS open remains pending until the native preview dismisses', () async {
    final started = Completer<void>();
    final dismissed = Completer<bool>();
    messenger.setMockMethodCallHandler(channel, (call) {
      started.complete();
      return dismissed.future;
    });
    var completed = false;
    final request = opener
        .open(file, displayName: '参考视频.mp4')
        .then((_) => completed = true);
    await started.future;
    expect(completed, isFalse);
    expect(fallbackPaths, isEmpty);
    dismissed.complete(true);
    await request;
    expect(completed, isTrue);
  });

  test('unsupported iOS preview falls back to the same file and awaits the existing opener', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => false);
    final started = Completer<void>();
    final finished = Completer<OpenResult>();
    opener = RoleAssetOpener(
      channel: channel,
      isIOS: () => true,
      fallbackOpen: (path) {
        fallbackPaths.add(path);
        started.complete();
        return finished.future;
      },
    );
    var completed = false;
    final request = opener
        .open(file, displayName: '参考视频.mp4')
        .then((_) => completed = true);
    await started.future;
    expect(fallbackPaths, [file.path]);
    expect(completed, isFalse);
    finished.complete(OpenResult());
    await request;
    expect(completed, isTrue);
  });

  test(
    'iOS channel failure preserves useful error text and permits a later retry',
    () async {
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(
          code: 'fileNotFound',
          message: '文件不存在，请重新添加或恢复备份',
        );
      });
      await expectLater(
        opener.open(file, displayName: '新名字.mp4'),
        throwsA(
          isA<AssetOpenException>().having(
            (error) => error.message,
            'message',
            '文件不存在，请重新添加或恢复备份',
          ),
        ),
      );
      expect(fallbackPaths, isEmpty);
      messenger.setMockMethodCallHandler(channel, (_) async => true);
      await opener.open(file, displayName: '新名字.mp4');
    },
  );

  test('busy and other channel errors without messages remain understandable and do not fall back', () async {
    for (final (code, message) in [
      ('busy', '已有预览正在打开，请关闭后重试'),
      ('fileNotFound', '文件不存在，请重新添加或恢复备份'),
      ('invalidArguments', '资产信息无效，暂时无法预览'),
      ('noPresenter', '暂时无法显示预览，请重试'),
      ('unknown', '暂时无法预览此文件，请重试'),
    ]) {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: code),
      );
      await expectLater(
        opener.open(file, displayName: '参考视频.mp4'),
        throwsA(
          isA<AssetOpenException>().having(
            (error) => error.message,
            'message',
            message,
          ),
        ),
      );
    }
    expect(fallbackPaths, isEmpty);
  });

  test('missing or malformed iOS channel response is an error, not an unsupported-file fallback', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    await expectLater(
      opener.open(file, displayName: '参考视频.mp4'),
      throwsA(isA<AssetOpenException>()),
    );
    messenger.setMockMethodCallHandler(channel, null);
    await expectLater(
      opener.open(file, displayName: '参考视频.mp4'),
      throwsA(
        isA<AssetOpenException>().having(
          (error) => error.message,
          'message',
          '预览服务不可用，请重新打开应用后重试',
        ),
      ),
    );
    expect(fallbackPaths, isEmpty);
  });

  test('other platforms retain the original opener and never invoke the iOS channel', () async {
    opener = RoleAssetOpener(
      channel: channel,
      isIOS: () => false,
      fallbackOpen: (path) async {
        fallbackPaths.add(path);
        return OpenResult();
      },
    );
    await opener.open(file, displayName: '参考视频.mp4');
    expect(calls, isEmpty);
    expect(fallbackPaths, [file.path]);
  });

  test(
    'fallback result errors retain their existing user-facing messages',
    () async {
      messenger.setMockMethodCallHandler(channel, (_) async => false);
      for (final isIOS in [true, false]) {
        for (final (type, message) in [
          (ResultType.noAppToOpen, '没有可打开此文件的应用'),
          (ResultType.fileNotFound, '文件不存在，请重新添加或恢复备份'),
          (ResultType.permissionDenied, '无法访问此文件'),
          (ResultType.error, '暂时无法打开此文件'),
        ]) {
          opener = RoleAssetOpener(
            channel: channel,
            isIOS: () => isIOS,
            fallbackOpen: (_) async => OpenResult(type: type),
          );
          await expectLater(
            opener.open(file, displayName: '参考视频.mp4'),
            throwsA(
              isA<AssetOpenException>().having(
                (error) => error.message,
                'message',
                message,
              ),
            ),
          );
        }
      }
    },
  );
}
