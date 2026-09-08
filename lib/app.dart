import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_router.dart';
import 'data/services/data_storage.dart';
import 'theme/zaidang_theme.dart';

/// 应用根组件：主题和路由。
///
/// 每个实例持有一份 [GoRouter]，测试里多次 [pumpWidget] 不会共用 location。
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final GoRouter _router = createAppRouter(
    initialLocation: DataStorage.current?.isRecoveryOnly == true
        ? '/backup'
        : '/archive',
  );
  StreamSubscription<int>? _storageChanges;

  @override
  void initState() {
    super.initState();
    _storageChanges = DataStorage.current?.changes.listen((_) {
      if (mounted) _router.go('/backup');
    });
  }

  @override
  void dispose() {
    unawaited(_storageChanges?.cancel());
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '崽档',
      theme: zaidangLightTheme(),
      darkTheme: zaidangDarkTheme(),
      routerConfig: _router,
    );
  }
}
