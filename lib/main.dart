import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  // 入口只负责启动：包上 Riverpod 根，再交给 [MyApp] 做主题和路由。
  runApp(const ProviderScope(child: MyApp()));
}
