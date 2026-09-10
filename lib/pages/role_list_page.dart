import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/providers/roles_provider.dart';
import '../theme/zaidang_tokens.dart';
import '../widgets/role_list_tile.dart';

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
              return RoleListTile(role: items[index]);
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
