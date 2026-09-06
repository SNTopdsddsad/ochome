import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/zaidang_tokens.dart';
import 'role_list_page.dart';
import 'world_view_page.dart';

/// 档案入口：OC 与世界观共用页签和备份入口。
class ArchivePage extends StatelessWidget {
  const ArchivePage({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: false,
          titleSpacing: 12,
          title: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            labelColor: tokens.accent,
            unselectedLabelColor: tokens.inkSecondary,
            labelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            dividerHeight: 0,
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorPadding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 8,
            ),
            splashBorderRadius: BorderRadius.circular(6),
            indicator: BoxDecoration(
              color: tokens.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            tabs: const [
              _ArchiveTab(label: 'OC'),
              _ArchiveTab(label: '世界观'),
            ],
          ),
          actions: [
            IconButton(
              tooltip: '备份与恢复',
              icon: const Icon(Icons.cloud_outlined),
              onPressed: () => context.push('/backup'),
            ),
          ],
        ),
        body: const TabBarView(children: [RoleListPage(), WorldViewPage()]),
      ),
    );
  }
}

class _ArchiveTab extends StatelessWidget {
  const _ArchiveTab({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Tab(
      height: 48,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: ZaidangTokens.of(context).border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, maxLines: 1),
      ),
    );
  }
}
