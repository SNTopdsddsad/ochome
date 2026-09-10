import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/models/role.dart';
import '../theme/zaidang_tokens.dart';
import 'cover_file_view.dart';

/// 角色列表行：立绘缩略图 + 名字 + 种族/身份/性别。OC 列表与世界观「角色」页签共用。
class RoleListTile extends StatelessWidget {
  const RoleListTile({super.key, required this.role});

  final Role role;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      role.race,
      role.occupation,
      role.sex,
    ].where((text) => text.isNotEmpty).join(' · ');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: RoleCoverThumb(path: role.coverImg),
      title: Text(role.name),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      onTap: () {
        context.push('/roles/${role.id}', extra: role);
      },
    );
  }
}

/// 立绘缩略图用圆角方图，避免看起来像通讯录头像。
class RoleCoverThumb extends StatelessWidget {
  const RoleCoverThumb({
    super.key,
    required this.path,
    this.placeholderIcon = Icons.person_outline,
  });

  final String path;
  final IconData placeholderIcon;

  static const double size = 56;

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    final placeholder = ColoredBox(
      color: tokens.surface,
      child: Icon(placeholderIcon, color: tokens.inkSecondary),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: size,
        height: size,
        child: CoverFileView(coverImg: path, placeholder: placeholder),
      ),
    );
  }
}
