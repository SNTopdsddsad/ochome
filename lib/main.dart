import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bootstrap.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 先恢复存储根，再开放应用的数据提供器与界面。
  runApp(const ProviderScope(child: AppStorageBootstrap()));
}
