import 'package:flutter/material.dart';

import '../theme/zaidang_asset_colors.dart';
import '../theme/zaidang_radius.dart';
import '../theme/zaidang_spacing.dart';
import '../theme/zaidang_type.dart';

/// 资产卡片的浅色标签；内容来自用户保存的标签。
class RoleAssetTag extends StatelessWidget {
  const RoleAssetTag(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = ZaidangAssetColors.tagForeground(context, label);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: color.withValues(alpha: 0.08),
        shape: ZaidangRadius.pill,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ZaidangSpacing.sm,
          vertical: ZaidangSpacing.xs,
        ),
        child: Text(
          label,
          style: ZaidangType.of(context).micro.copyWith(color: color),
        ),
      ),
    );
  }
}
