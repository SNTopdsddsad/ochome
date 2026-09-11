import 'dart:io';

import 'package:flutter/material.dart';

import '../../theme/zaidang_radius.dart';
import '../../theme/zaidang_spacing.dart';
import '../../theme/zaidang_tokens.dart';
import '../../theme/zaidang_type.dart';
import '../cover_file_view.dart';

/// 吸顶时保留识别信息（圆形头像 + 名字），长名字截断，不挤占两侧操作按钮。
class PinnedIdentity extends StatelessWidget {
  const PinnedIdentity({
    super.key,
    required this.name,
    required this.coverImg,
    this.supportDirectory,
    this.emptyName = '未命名角色',
    this.placeholderIcon = Icons.person_outline,
    this.boxKey = const Key('role-pinned-identity'),
    this.portraitKey = const Key('role-pinned-portrait'),
  });

  final String name;
  final String coverImg;
  final Future<Directory> Function()? supportDirectory;

  /// 名字为空时的占位文案。
  final String emptyName;
  final IconData placeholderIcon;

  /// 测试定位用的 key；两个编辑页各自传自己的前缀。
  final Key boxKey;
  final Key portraitKey;

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: DecoratedBox(
        key: boxKey,
        decoration: BoxDecoration(
          color: tokens.bg.withValues(alpha: 0.94),
          borderRadius: ZaidangRadius.smAll,
        ),
        child: Padding(
          padding: const EdgeInsets.all(ZaidangSpacing.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipOval(
                child: SizedBox.square(
                  dimension: 32,
                  child: CoverFileView(
                    key: portraitKey,
                    coverImg: coverImg,
                    supportDirectory: supportDirectory,
                    placeholder: ColoredBox(
                      color: tokens.surface,
                      child: Icon(
                        placeholderIcon,
                        size: 20,
                        color: tokens.inkSecondary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: ZaidangSpacing.sm),
              Flexible(
                child: Text(
                  name.isEmpty ? emptyName : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ZaidangType.of(context).subheading,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
