import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:ochome/data/services/role_asset_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ImagePickerPlatform originalPlatform;

  setUp(() {
    originalPlatform = ImagePickerPlatform.instance;
  });

  tearDown(() {
    ImagePickerPlatform.instance = originalPlatform;
  });

  test(
    'Android enables Photo Picker before requesting multiple media',
    () async {
      final platform = _FakeAndroidPicker([
        XFile('/tmp/one.png'),
        XFile('/tmp/two.mp4'),
      ]);
      ImagePickerPlatform.instance = platform;

      final result = await RoleAssetPicker().pickMedia();

      expect(platform.photoPickerEnabledAtCall, isTrue);
      expect(platform.options!.allowMultiple, isTrue);
      expect(platform.options!.limit, isNull);
      expect(platform.options!.imageOptions.requestFullMetadata, isFalse);
      expect(result.map((file) => file.path), ['/tmp/one.png', '/tmp/two.mp4']);
    },
  );

  test(
    'non-Android implementations retain the existing media request',
    () async {
      final platform = _FakePicker([XFile('/tmp/other.jpg')]);
      ImagePickerPlatform.instance = platform;

      final result = await RoleAssetPicker().pickMedia();

      expect(platform.calls, 1);
      expect(platform.options!.allowMultiple, isTrue);
      expect(platform.options!.imageOptions.requestFullMetadata, isFalse);
      expect(result.single.path, '/tmp/other.jpg');
    },
  );

  test('cancellation stays an empty result', () async {
    final platform = _FakePicker(const []);
    ImagePickerPlatform.instance = platform;

    expect(await RoleAssetPicker().pickMedia(), isEmpty);
  });

  test('platform selection errors are propagated unchanged', () async {
    final failure = StateError('simulated picker failure');
    final platform = _FakePicker(const [], failure: failure);
    ImagePickerPlatform.instance = platform;

    await expectLater(RoleAssetPicker().pickMedia(), throwsA(same(failure)));
  });
}

class _FakeAndroidPicker extends ImagePickerAndroid {
  _FakeAndroidPicker(this.result);

  final List<XFile> result;
  MediaOptions? options;
  bool? photoPickerEnabledAtCall;

  @override
  Future<List<XFile>> getMedia({required MediaOptions options}) async {
    this.options = options;
    photoPickerEnabledAtCall = useAndroidPhotoPicker;
    return result;
  }
}

class _FakePicker extends ImagePickerPlatform {
  _FakePicker(this.result, {this.failure});

  final List<XFile> result;
  final Object? failure;
  MediaOptions? options;
  int calls = 0;

  @override
  Future<List<XFile>> getMedia({required MediaOptions options}) async {
    calls++;
    this.options = options;
    if (failure != null) throw failure!;
    return result;
  }
}
