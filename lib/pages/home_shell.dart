import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 底栏壳：档案 / 我的。创建、编辑、备份走根路由，盖住这一层。
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final onArchive = navigationShell.currentIndex == 0;
    return PopScope(
      canPop: onArchive,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        navigationShell.goBranch(0);
      },
      child: Scaffold(
        extendBody: false,
        // 躲键盘交给各分支页自己的 Scaffold；壳层一缩，档案页的整屏背景图
        // 会跟着重新 cover 缩放，看起来像整张纸往上滑。
        resizeToAvoidBottomInset: false,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final media = MediaQuery.of(context);
            // 键盘先盖住底栏，只有露出底栏顶边的那部分才真的压到分支页；
            // 原样下发会让分支页多减一段底栏高度，列表和 FAB 悬在键盘上方。
            final coveredByBar = media.size.height - constraints.maxHeight;
            final bottomInset = math.max(
              0.0,
              media.viewInsets.bottom - coveredByBar,
            );
            return MediaQuery(
              data: media.copyWith(
                viewInsets: media.viewInsets.copyWith(bottom: bottomInset),
              ),
              child: navigationShell,
            );
          },
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(key: Key('home-shell-tab-edge'), height: 1),
            NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: navigationShell.goBranch,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.folder_outlined),
                  selectedIcon: Icon(Icons.folder),
                  label: '档案',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: '我的',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
