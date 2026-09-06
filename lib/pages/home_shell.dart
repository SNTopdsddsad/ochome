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
        body: navigationShell,
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
