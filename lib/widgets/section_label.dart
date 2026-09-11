import 'package:flutter/material.dart';

import '../theme/zaidang_spacing.dart';
import '../theme/zaidang_type.dart';

/// 分区标签：档案卡片、关系编辑 Sheet 等处标注一组字段的小标题。
///
/// 默认带底部间距，紧跟内容时传 [padding] 为 `EdgeInsets.zero`。
class SectionLabel extends StatelessWidget {
  const SectionLabel(
    this.text, {
    super.key,
    this.padding = const EdgeInsets.only(bottom: ZaidangSpacing.sm),
  });

  final String text;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(text, style: ZaidangType.of(context).sectionLabel),
    );
  }
}
