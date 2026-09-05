import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Export typefaces are loaded on demand and do not change the app's UI font.
abstract final class RoleCardFonts {
  static const serifFamily = 'RoleCardSerif';
  static const sansFamily = 'RoleCardSans';
  static const _assetRoot = 'assets/fonts/role_card';

  static Future<void>? _loading;
  static bool _licensesRegistered = false;

  static Future<void> ensureLoaded() {
    return _loading ??= _load().catchError((Object error, StackTrace stack) {
      _loading = null;
      Error.throwWithStackTrace(error, stack);
    });
  }

  static Future<void> _load() async {
    final serif = FontLoader(serifFamily)
      ..addFont(rootBundle.load('$_assetRoot/SourceHanSerifCN-Bold.otf'));
    final sans = FontLoader(sansFamily)
      ..addFont(rootBundle.load('$_assetRoot/SourceHanSansSC-Regular.otf'));
    await Future.wait([serif.load(), sans.load()]);
    registerLicenses();
  }

  /// Notices stay viewable even when no fields are selected for a preview.
  static void registerLicenses() {
    if (!_licensesRegistered) {
      LicenseRegistry.addLicense(() async* {
        yield LicenseEntryWithLineBreaks(
          ['Source Han Serif'],
          await rootBundle.loadString(
            '$_assetRoot/source-han-serif-LICENSE.txt',
          ),
        );
        yield LicenseEntryWithLineBreaks(
          ['Source Han Sans'],
          await rootBundle.loadString(
            '$_assetRoot/source-han-sans-LICENSE.txt',
          ),
        );
      });
      _licensesRegistered = true;
    }
  }
}
