import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models/world.dart';
import '../data/providers/worlds_provider.dart';
import '../theme/zaidang_tokens.dart';
import '../widgets/archive_list_card.dart';
import '../widgets/archive_list_view.dart';

/// 世界观页：纸面上的设定集卡列表，与 OC 页同构。
class WorldViewPage extends ConsumerStatefulWidget {
  const WorldViewPage({super.key, this.query = ''});

  /// 档案首页的搜索词原文；过滤时忽略首尾空白与大小写，空串表示不过滤。
  final String query;

  @override
  ConsumerState<WorldViewPage> createState() => _WorldViewPageState();
}

class _WorldViewPageState extends ConsumerState<WorldViewPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final worlds = ref.watch(worldsProvider);
    final tokens = ZaidangTokens.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: worlds.when(
        data: (items) => ArchiveListView<World>(
          items: items,
          query: widget.query,
          searchFields: _searchFields,
          emptyHint: '还没有世界观',
          noMatchHint: '没有匹配的世界观',
          itemBuilder: (context, world) =>
              _WorldCard(key: Key('world-card-${world.id}'), world: world),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('加载失败：$error', style: TextStyle(color: tokens.ink)),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: '添加世界观',
        onPressed: () {
          context.push('/worlds/new');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// 名称、简介和词条标题 / 内容都参与匹配。
Iterable<String> _searchFields(World world) => [
  world.name,
  world.summary,
  for (final entry in world.entries) ...[entry.title, entry.content],
];

class _WorldCard extends StatelessWidget {
  const _WorldCard({super.key, required this.world});

  final World world;

  @override
  Widget build(BuildContext context) {
    return ArchiveListCard(
      coverImg: world.coverImg,
      placeholderIcon: Icons.public_outlined,
      title: world.name,
      summary: world.summary,
      meta: '${world.entries.length} 个词条',
      onTap: () {
        context.push('/worlds/${world.id}', extra: world);
      },
    );
  }
}
