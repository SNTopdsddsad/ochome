import 'package:flutter/material.dart';

import '../theme/zaidang_radius.dart';
import '../theme/zaidang_spacing.dart';
import '../theme/zaidang_tokens.dart';
import '../theme/zaidang_type.dart';

/// 纸底细描边的小标签，不用色块区分类别，保持「纸 + 墨」的底子。
///
/// 档案列表卡与角色身份头共用；只收文案，不读 provider。
class ArchiveTag extends StatelessWidget {
  const ArchiveTag(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ZaidangSpacing.sm,
        vertical: ZaidangSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: tokens.bg,
        border: Border.all(color: tokens.border),
        borderRadius: ZaidangRadius.smAll,
      ),
      child: Text(
        label,
        style: ZaidangType.of(context).micro.copyWith(color: tokens.ink),
      ),
    );
  }
}
