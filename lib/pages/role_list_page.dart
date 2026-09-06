import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models/role.dart';
import '../data/providers/roles_provider.dart';
import '../theme/zaidang_tokens.dart';
import '../widgets/cover_file_view.dart';

/// OC 页：纸面上的角色档案列表。立绘是主体，火漆红只给添加按钮。
class RoleListPage extends ConsumerStatefulWidget {
  const RoleListPage({super.key});

  @override
  ConsumerState<RoleListPage> createState() => _RoleListPageState();
}

class _RoleListPageState extends ConsumerState<RoleListPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final roles = ref.watch(rolesProvider);
    final tokens = ZaidangTokens.of(context);

    return Scaffold(
      body: roles.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Text(
                '还没有角色',
                style: TextStyle(color: tokens.inkSecondary, fontSize: 14),
              ),
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              return _RoleTile(role: items[index]);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('加载失败：$error', style: TextStyle(color: tokens.ink)),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: '添加角色',
        onPressed: () {
          context.push('/roles/new');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _RoleTile extends StatelessWidget {
  const _RoleTile({required this.role});

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
      leading: _CoverThumb(path: role.coverImg),
      title: Text(role.name),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      onTap: () {
        context.push('/roles/${role.id}', extra: role);
      },
    );
  }
}

/// 立绘缩略图用圆角方图，避免看起来像通讯录头像。
class _CoverThumb extends StatelessWidget {
  const _CoverThumb({required this.path});

  final String path;

  static const double _size = 56;

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    final placeholder = ColoredBox(
      color: tokens.surface,
      child: Icon(Icons.person_outline, color: tokens.inkSecondary),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: _size,
        height: _size,
        child: CoverFileView(coverImg: path, placeholder: placeholder),
      ),
    );
  }
}
