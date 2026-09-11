import 'package:flutter/material.dart';

import '../theme/zaidang_spacing.dart';
import '../theme/zaidang_tokens.dart';
import '../theme/zaidang_type.dart';

/// 档案首页的卡片列表：统一的空态 / 无匹配文案、搜索过滤、间距和 FAB 底部留白。
///
/// OC 与世界观页共用。只收已加载的数据，不读 provider；
/// 加载中 / 出错态由页面在 `AsyncValue.when` 里处理。
class ArchiveListView<T> extends StatelessWidget {
  const ArchiveListView({
    super.key,
    required this.items,
    required this.query,
    required this.searchFields,
    required this.emptyHint,
    required this.noMatchHint,
    required this.itemBuilder,
  });

  /// 列表底部留白，最后一张卡不被 FAB 盖住。
  static const double bottomInset = 96;

  final List<T> items;

  /// 原始搜索词，这里统一 trim 并忽略大小写；空串表示不过滤。
  final String query;

  /// 参与匹配的文本字段；任一字段包含搜索词即命中。
  final Iterable<String> Function(T item) searchFields;

  /// 仓库为空时的文案。
  final String emptyHint;

  /// 仓库非空但没有匹配项时的文案。
  final String noMatchHint;

  final Widget Function(BuildContext context, T item) itemBuilder;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _Hint(emptyHint);
    }
    final needle = query.trim().toLowerCase();
    final visible = needle.isEmpty
        ? items
        : items
              .where(
                (item) =>
                    searchFields(item)
                        .any((text) => text.toLowerCase().contains(needle)),
              )
              .toList();
    if (visible.isEmpty) {
      return _Hint(noMatchHint);
    }
    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
        ZaidangSpacing.page,
        ZaidangSpacing.sm,
        ZaidangSpacing.page,
        bottomInset,
      ),
      itemCount: visible.length,
      separatorBuilder: (_, _) => const SizedBox(height: ZaidangSpacing.md),
      itemBuilder: (context, index) => itemBuilder(context, visible[index]),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: ZaidangType.of(context).body
            .copyWith(color: ZaidangTokens.of(context).inkSecondary),
      ),
    );
  }
}
