import 'package:flutter/material.dart';

/// 资产标签的语义色，仅用于参考图中的小面积分类标记。
abstract final class ZaidangAssetColors {
  static const _light = [
    Color(0xFFA83E2E),
    Color(0xFF3566A0),
    Color(0xFF706091),
  ];
  static const _dark = [
    Color(0xFFED9D8E),
    Color(0xFFA0C6F0),
    Color(0xFFCBB9E8),
  ];

  /// 同名标签在不同卡片上保持同一颜色，不随排序变化。
  static Color tagForeground(BuildContext context, String label) {
    final index =
        label.runes.fold(0, (sum, rune) => sum + rune) % _light.length;
    return Theme.of(context).brightness == Brightness.dark
        ? _dark[index]
        : _light[index];
  }
}
