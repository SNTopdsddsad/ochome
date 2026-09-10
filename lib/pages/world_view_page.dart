import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models/world.dart';
import '../data/providers/worlds_provider.dart';
import '../theme/zaidang_tokens.dart';
import '../widgets/role_list_tile.dart';

/// 世界观页：纸面上的设定集列表，与 OC 页同构。
class WorldViewPage extends ConsumerStatefulWidget {
  const WorldViewPage({super.key});

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
      body: worlds.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Text(
                '还没有世界观',
                style: TextStyle(color: tokens.inkSecondary, fontSize: 14),
              ),
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              return _WorldTile(world: items[index]);
            },
          );
        },
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

class _WorldTile extends StatelessWidget {
  const _WorldTile({required this.world});

  final World world;

  @override
  Widget build(BuildContext context) {
    final summary = world.summary.trim().split('\n').first;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: RoleCoverThumb(
        path: world.coverImg,
        placeholderIcon: Icons.public_outlined,
      ),
      title: Text(world.name),
      subtitle: summary.isEmpty
          ? null
          : Text(summary, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () {
        context.push('/worlds/${world.id}', extra: world);
      },
    );
  }
}
