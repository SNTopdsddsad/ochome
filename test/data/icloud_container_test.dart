import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/data/services/backup_exceptions.dart';
import 'package:ochome/data/services/icloud_container.dart';

void main() {
  test('non-Apple factory returns the unavailable stub', () {
    expect(
      createICloudContainer(applePlatform: false),
      isA<UnavailableICloudContainer>(),
    );
  });

  test('Android stub never reports available and does not upload', () async {
    const container = UnavailableICloudContainer();
    expect(await container.isAvailable(), isFalse);
    expect(await container.backupRoot(), isNull);
    expect(
      () =>
          container.upload(localPath: '/tmp/a', relativePath: 'ochome.sqlite'),
      throwsA(isA<ICloudUnavailableException>()),
    );
    expect(
      () => container.list('covers'),
      throwsA(isA<ICloudUnavailableException>()),
    );
    expect(
      () => container.exportToDrive(),
      throwsA(isA<ICloudUnavailableException>()),
    );
  });

  test('MethodChannelICloudContainer talks to a fake channel', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel(ICloudContainer.channelName);
    final stored = <String, List<int>>{};

    testerMessenger().setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'isAvailable':
          return true;
        case 'backupRoot':
          return '/fake/ochome-backup';
        case 'upload':
          final args = Map<String, dynamic>.from(call.arguments as Map);
          stored[args['relativePath'] as String] = [1, 2, 3];
          return null;
        case 'list':
          return [
            for (final entry in stored.entries)
              {'relativePath': entry.key, 'bytes': entry.value.length},
          ];
        case 'delete':
          final args = Map<String, dynamic>.from(call.arguments as Map);
          stored.remove(args['relativePath']);
          return null;
        default:
          return null;
      }
    });
    addTearDown(
      () => testerMessenger().setMockMethodCallHandler(channel, null),
    );

    final container = MethodChannelICloudContainer(channel: channel);
    expect(await container.isAvailable(), isTrue);
    expect(await container.backupRoot(), '/fake/ochome-backup');
    await container.upload(
      localPath: '/tmp/a.png',
      relativePath: 'covers/a.png',
    );
    expect(
      (await container.list('covers')).single.relativePath,
      'covers/a.png',
    );
    await container.delete('covers/a.png');
    expect(await container.list('covers'), isEmpty);
  });
}

TestDefaultBinaryMessenger testerMessenger() {
  return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
}
