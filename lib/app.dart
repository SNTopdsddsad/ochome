import 'package:flutter/material.dart';

import 'pages/role_list_page.dart';
import 'theme/zaidang_theme.dart';

/// 应用根组件：主题、路由、第一屏。
///
/// 不写具体业务；首页换成真实页面时，只改 [home] 或后续的路由表。
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '崽档',
      theme: zaidangLightTheme(),
      darkTheme: zaidangDarkTheme(),
      home: const RoleListPage(),
    );
  }
}
