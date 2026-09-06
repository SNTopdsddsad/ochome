import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'data/models/role.dart';
import 'pages/archive_page.dart';
import 'pages/backup_restore_page.dart';
import 'pages/home_shell.dart';
import 'pages/mine_page.dart';
import 'pages/role_create_page.dart';

/// 应用路由表。每个 [MyApp] 实例调用一次，避免测试之间共用 location。
GoRouter createAppRouter({
  GlobalKey<NavigatorState>? rootNavigatorKey,
  String initialLocation = '/archive',
}) {
  final rootKey = rootNavigatorKey ?? GlobalKey<NavigatorState>();
  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: initialLocation,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return HomeShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/archive',
                builder: (context, state) => const ArchivePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/mine',
                builder: (context, state) => const MinePage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/roles/new',
        parentNavigatorKey: rootKey,
        builder: (context, state) => const RoleCreatePage(),
      ),
      GoRoute(
        path: '/roles/:id',
        parentNavigatorKey: rootKey,
        redirect: (context, state) {
          if (state.extra is! Role) {
            return '/archive';
          }
          return null;
        },
        builder: (context, state) {
          return RoleCreatePage(role: state.extra! as Role);
        },
      ),
      GoRoute(
        path: '/backup',
        parentNavigatorKey: rootKey,
        builder: (context, state) => const BackupRestorePage(),
      ),
    ],
  );
}
