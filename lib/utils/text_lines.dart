import 'dart:convert';

/// 多行文本只取首行；兼容 `\r\n`，首尾空白一并去掉，全空返回空串。
///
/// 列表卡的一句简介与角色身份头的引文都用它，别在各处重复 `split('\n')`。
String firstLine(String text) =>
    LineSplitter.split(text.trim()).firstOrNull?.trim() ?? '';
