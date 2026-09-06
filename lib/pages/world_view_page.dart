import 'package:flutter/material.dart';

import '../theme/zaidang_tokens.dart';

/// 世界观页，后续承载世界观内容。
class WorldViewPage extends StatelessWidget {
  const WorldViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '暂无世界观',
        style: TextStyle(
          color: ZaidangTokens.of(context).inkSecondary,
          fontSize: 14,
        ),
      ),
    );
  }
}
