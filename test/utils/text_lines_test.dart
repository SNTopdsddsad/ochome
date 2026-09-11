import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/utils/text_lines.dart';

void main() {
  test('firstLine keeps only the trimmed first line and accepts CRLF', () {
    expect(firstLine('  第一行  \r\n第二行'), '第一行');
    expect(firstLine('\n\n第三行\n'), '第三行');
    expect(firstLine(''), '');
    expect(firstLine(' \n \n '), '');
  });
}
