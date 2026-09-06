import 'package:flutter/material.dart';

/// 「我的」占位页。本迭代只有标题和空白纸面。
class MinePage extends StatelessWidget {
  const MinePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('我的')));
  }
}
