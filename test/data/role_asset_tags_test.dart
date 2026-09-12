import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/data/models/role_asset_tags.dart';

void main() {
  test('normalization trims, deduplicates and preserves first-seen order', () {
    expect(normalizeRoleAssetTags(['  演出 ', '官方图', '演出']), ['演出', '官方图']);
    expect(normalizeRoleAssetTags(const []), isEmpty);
  });

  test('limits use distinct tags and Unicode grapheme clusters', () {
    const family = '👨‍👩‍👧‍👦';
    final atLimit = List.filled(roleAssetTagMaxGraphemes, family).join();
    final overLimit = List.filled(roleAssetTagMaxGraphemes + 1, family).join();
    expect(normalizeRoleAssetTags([atLimit]), [atLimit]);
    expect(() => normalizeRoleAssetTags([overLimit]), throwsFormatException);
    expect(
      normalizeRoleAssetTags([
        for (var i = 0; i < roleAssetTagMaxCount; i++) 'tag$i',
        'tag0',
      ]),
      hasLength(roleAssetTagMaxCount),
    );
    expect(
      () => normalizeRoleAssetTags([
        for (var i = 0; i <= roleAssetTagMaxCount; i++) 'tag$i',
      ]),
      throwsFormatException,
    );
  });

  test('empty tags and overlong tags are rejected with product messages', () {
    expect(
      () => normalizeRoleAssetTags(['  ']),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          '标签不能为空',
        ),
      ),
    );
    expect(
      () => normalizeRoleAssetTags(['12345678901234567']),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          '每个标签最多 16 个字',
        ),
      ),
    );
  });

  test('encoding is canonical and decoding rejects malformed storage', () {
    expect(encodeRoleAssetTags([' 演出 ', '官方图']), '["演出","官方图"]');
    expect(decodeRoleAssetTags('["演出","官方图"]'), ['演出', '官方图']);
    for (final source in [
      'not-json',
      '{}',
      '[1]',
      '[""]',
      '[" 演出"]',
      '["演出","演出"]',
    ]) {
      expect(
        () => decodeRoleAssetTags(source),
        throwsFormatException,
        reason: source,
      );
    }
  });
}
