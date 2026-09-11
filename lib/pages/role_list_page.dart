import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models/role.dart';
import '../data/providers/role_assets_provider.dart';
import '../data/providers/roles_provider.dart';
import '../theme/zaidang_tokens.dart';
import '../widgets/archive_list_card.dart';
import '../widgets/archive_list_view.dart';

/// OC 页：纸面上的角色卡列表。立绘是主体，火漆红只给添加按钮。
class RoleListPage extends ConsumerStatefulWidget {
  const RoleListPage({super.key, this.query = ''});

  /// 档案首页的搜索词原文；过滤时忽略首尾空白与大小写，空串表示不过滤。
  final String query;

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
    // 整张列表只订阅一条计数流；`null` 表示还没算出来。
    final assetCounts = ref.watch(roleAssetCountsProvider).value;
    final tokens = ZaidangTokens.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: roles.when(
        data: (items) => ArchiveListView<Role>(
          items: items,
          query: widget.query,
          searchFields: _searchFields,
          emptyHint: '还没有角色',
          noMatchHint: '没有匹配的角色',
          itemBuilder: (context, role) => _RoleCard(
            key: Key('role-card-${role.id}'),
            role: role,
            assetCount: assetCounts == null ? null : assetCounts[role.id] ?? 0,
          ),
        ),
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

/// 名字、种族 / 身份 / 性别标签、设定正文和自定义属性都参与匹配。
Iterable<String> _searchFields(Role role) => [
  role.name,
  role.race,
  role.occupation,
  role.sex,
  role.desc,
  for (final attribute in role.customAttributes) ...[
    attribute.name,
    attribute.content,
  ],
];

class _RoleCard extends StatelessWidget {
  const _RoleCard({super.key, required this.role, required this.assetCount});

  final Role role;

  /// 资产数；`null` 表示计数还没到，卡片只留箭头。
  final int? assetCount;

  @override
  Widget build(BuildContext context) {
    return ArchiveListCard(
      coverImg: role.coverImg,
      title: role.name,
      tags: [
        role.race,
        role.occupation,
        role.sex,
      ].where((text) => text.isNotEmpty).toList(),
      summary: role.desc,
      meta: assetCount == null ? null : '$assetCount 份资产',
      onTap: () {
        context.push('/roles/${role.id}', extra: role);
      },
    );
  }
}
