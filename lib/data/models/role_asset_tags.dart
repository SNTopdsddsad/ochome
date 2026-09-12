import 'dart:convert';

import 'package:characters/characters.dart';

const int roleAssetTagMaxCount = 8;
const int roleAssetTagMaxGraphemes = 16;

/// Trims tags, preserves their first-seen order and removes duplicates.
///
/// An empty list is valid. Individual empty tags and values beyond the
/// supported limits are rejected with user-facing validation messages.
List<String> normalizeRoleAssetTags(Iterable<String> tags) {
  final normalized = <String>[];
  final seen = <String>{};
  for (final raw in tags) {
    final tag = raw.trim();
    if (tag.isEmpty) throw const FormatException('标签不能为空');
    if (tag.characters.length > roleAssetTagMaxGraphemes) {
      throw const FormatException('每个标签最多 16 个字');
    }
    if (seen.add(tag)) normalized.add(tag);
  }
  if (normalized.length > roleAssetTagMaxCount) {
    throw const FormatException('每份资产最多 8 个标签');
  }
  return List.unmodifiable(normalized);
}

String encodeRoleAssetTags(Iterable<String> tags) =>
    jsonEncode(normalizeRoleAssetTags(tags));

/// Decodes the canonical JSON representation stored in SQLite.
///
/// Storage and backup reads are strict: non-string values, whitespace that
/// was not normalized before writing and duplicate tags are considered
/// malformed instead of being repaired silently.
List<String> decodeRoleAssetTags(String source) {
  final Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException {
    throw const FormatException('资产标签格式不正确');
  }
  if (decoded is! List || decoded.any((value) => value is! String)) {
    throw const FormatException('资产标签必须是字符串数组');
  }
  final raw = decoded.cast<String>();
  late final List<String> normalized;
  try {
    normalized = normalizeRoleAssetTags(raw);
  } on FormatException {
    rethrow;
  }
  if (raw.length != normalized.length) {
    throw const FormatException('资产标签不能重复');
  }
  for (var index = 0; index < raw.length; index++) {
    if (raw[index] != normalized[index]) {
      throw const FormatException('资产标签格式不正确');
    }
  }
  return normalized;
}
