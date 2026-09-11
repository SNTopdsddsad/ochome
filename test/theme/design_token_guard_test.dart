import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 字号 / 间距 / 圆角只允许来自 `lib/theme/` 的 Token。
///
/// 导出卡渲染器画的是图片而不是 App 界面，走自己的排版常量，不在此列。
const _exemptPaths = {
  'lib/features/role_card/role_card_renderer.dart',
  'lib/features/role_card/role_card_fonts.dart',
};

final _fontLiteral = RegExp(r'\b(fontSize|fontWeight):');
final _radiusLiteral = RegExp(r'Radius\.circular\(\s*\d');
final _wrapSpacingLiteral = RegExp(
  r'\b(spacing|runSpacing|titleSpacing):\s*\d',
);
final _edgeInsetsCall = RegExp(r'EdgeInsets\.(all|symmetric|only|fromLTRB)\(');
final _sizedBoxCall = RegExp(r'\bSizedBox\(');
final _bareNumber = RegExp(r'(?<![\w.])\d+(\.\d+)?(?![\w])');

void main() {
  test('app sources use design tokens instead of literals', () {
    final violations = <String>[];
    final files =
        Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))
            .where((file) => !file.path.startsWith('lib/theme/'))
            .where((file) => !_exemptPaths.contains(file.path))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    for (final file in files) {
      final source = file.readAsStringSync();
      void report(int offset, String rule) {
        final line = source.substring(0, offset).split('\n').length;
        violations.add('${file.path}:$line  $rule');
      }

      for (final match in _fontLiteral.allMatches(source)) {
        report(match.start, 'font size/weight literal');
      }
      for (final match in _radiusLiteral.allMatches(source)) {
        report(match.start, 'radius literal');
      }
      for (final match in _wrapSpacingLiteral.allMatches(source)) {
        report(match.start, 'spacing literal');
      }
      for (final match in _edgeInsetsCall.allMatches(source)) {
        final args = _balancedArguments(source, match.end - 1);
        if (_hasNonZeroNumber(args)) {
          report(match.start, 'EdgeInsets literal');
        }
      }
      for (final match in _sizedBoxCall.allMatches(source)) {
        final args = _topLevelArguments(
          _balancedArguments(source, match.end - 1),
        );
        // 只有一个方向、没有 child 的 SizedBox 是间隔；给了宽高两个方向
        // 或包着 child 的是尺寸容器，不管。
        final sides = args
            .where(
              (arg) => arg.startsWith('height:') || arg.startsWith('width:'),
            )
            .toList();
        final hasChild = args.any((arg) => arg.startsWith('child:'));
        if (sides.length == 1 && !hasChild && _hasNonZeroNumber(sides.single)) {
          report(match.start, 'SizedBox gap literal');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Use ZaidangType / ZaidangSpacing / ZaidangRadius instead:\n'
          '${violations.join('\n')}',
    );
  });
}

/// 返回 `open` 处左括号到配对右括号之间的文本，跳过字符串与嵌套括号。
String _balancedArguments(String source, int open) {
  var depth = 0;
  String? quote;
  for (var i = open; i < source.length; i++) {
    final char = source[i];
    if (quote != null) {
      if (char == r'\') {
        i++;
      } else if (char == quote) {
        quote = null;
      }
      continue;
    }
    if (char == "'" || char == '"') {
      quote = char;
    } else if (char == '(') {
      depth++;
    } else if (char == ')') {
      depth--;
      if (depth == 0) return source.substring(open + 1, i);
    }
  }
  return source.substring(open + 1);
}

/// 按顶层逗号拆分实参，忽略字符串与嵌套括号内的逗号，并去掉首尾空白。
List<String> _topLevelArguments(String args) {
  final result = <String>[];
  final buffer = StringBuffer();
  var depth = 0;
  String? quote;
  for (var i = 0; i < args.length; i++) {
    final char = args[i];
    if (quote != null) {
      buffer.write(char);
      if (char == r'\') {
        i++;
        if (i < args.length) buffer.write(args[i]);
      } else if (char == quote) {
        quote = null;
      }
      continue;
    }
    if (char == "'" || char == '"') {
      quote = char;
    } else if (char == '(' || char == '[' || char == '{') {
      depth++;
    } else if (char == ')' || char == ']' || char == '}') {
      depth--;
    } else if (char == ',' && depth == 0) {
      result.add(buffer.toString().trim());
      buffer.clear();
      continue;
    }
    buffer.write(char);
  }
  final tail = buffer.toString().trim();
  if (tail.isNotEmpty) result.add(tail);
  return result;
}

bool _hasNonZeroNumber(String args) {
  return _bareNumber
      .allMatches(args)
      .any((match) => double.parse(match.group(0)!) != 0);
}
