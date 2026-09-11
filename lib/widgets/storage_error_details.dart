import 'package:flutter/material.dart';

import '../theme/zaidang_spacing.dart';

/// Keep the actual local failure available without mixing it with cloud status.
class StorageErrorDetails extends StatelessWidget {
  const StorageErrorDetails({super.key, required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    if (error == null) return const SizedBox.shrink();
    return ExpansionTile(
      title: const Text('查看本机错误详情'),
      childrenPadding: const EdgeInsets.all(ZaidangSpacing.lg),
      children: [SelectableText(error.toString())],
    );
  }
}
