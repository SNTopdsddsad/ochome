import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/zaidang_radius.dart';
import '../theme/zaidang_spacing.dart';
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
          titleSpacing: ZaidangSpacing.md,
          title: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelPadding: const EdgeInsets.symmetric(
              horizontal: ZaidangSpacing.xs,
            ),
            labelColor: tokens.accent,
            unselectedLabelColor: tokens.inkSecondary,
            dividerHeight: 0,
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorPadding: const EdgeInsets.symmetric(
              horizontal: ZaidangSpacing.xs,
              vertical: ZaidangSpacing.sm,
            ),
            splashBorderRadius: ZaidangRadius.smAll,
            indicator: BoxDecoration(
              color: tokens.accent.withValues(alpha: 0.08),
              borderRadius: ZaidangRadius.smAll,
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
        padding: const EdgeInsets.symmetric(horizontal: ZaidangSpacing.md),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: ZaidangTokens.of(context).border),
          borderRadius: ZaidangRadius.smAll,
        ),
        child: Text(label, maxLines: 1),
      ),
    );
  }
}
