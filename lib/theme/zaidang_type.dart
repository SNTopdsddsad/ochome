import 'package:flutter/material.dart';

import 'zaidang_tokens.dart';

/// 崽档字号刻度。11 个语义角色、7 个字号（26 / 22 / 20 / 17 / 15 / 13 / 12），
/// 颜色已按 [ZaidangTokens] 烘进样式。
///
/// 页面通过 `ZaidangType.of(context).body` 取样式；`copyWith` 只允许改
/// `color`（必须是 token 色）和 `height`，不允许改字号和字重。
@immutable
class ZaidangType extends ThemeExtension<ZaidangType> {
  const ZaidangType({
    required this.hero,
    required this.title,
    required this.heading,
    required this.pageTitle,
    required this.subheading,
    required this.bodyLarge,
    required this.body,
    required this.label,
    required this.sectionLabel,
    required this.caption,
    required this.micro,
  });

  /// 26 / w600。页面级大标题、超大数字。
  final TextStyle hero;

  /// 22 / w600。编辑页「新建 / 编辑角色 · 世界观」。
  final TextStyle title;

  /// 20 / w500。弹窗标题、统计数字、启动错误标题。
  final TextStyle heading;

  /// 17 / w600。AppBar、Sheet 标题。
  final TextStyle pageTitle;

  /// 17 / w500。列表项标题、卡片小标题、pinned 名字、句中人名。
  final TextStyle subheading;

  /// 17 / w400。输入框内容与提示、字段值、句中助词。
  final TextStyle bodyLarge;

  /// 15 / w400。正文、弹窗正文、SnackBar、空态主文案。
  final TextStyle body;

  /// 15 / w500。按钮、Tab 文字。
  final TextStyle label;

  /// 13 / w600 / inkSecondary。分区标签。
  final TextStyle sectionLabel;

  /// 13 / w400 / inkSecondary。副标题、提示、计数、空态辅助文案。
  final TextStyle caption;

  /// 12 / w400 / inkSecondary。序号、统计说明、导航栏文字、输入框错误。
  final TextStyle micro;

  factory ZaidangType.from(ZaidangTokens tokens) {
    final ink = tokens.ink;
    final secondary = tokens.inkSecondary;
    return ZaidangType(
      hero: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: ink,
      ),
      title: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: ink,
      ),
      heading: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        height: 1.3,
        color: ink,
      ),
      pageTitle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: ink,
      ),
      subheading: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: ink,
      ),
      bodyLarge: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: ink,
      ),
      body: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: ink,
      ),
      label: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        height: 1.3,
        color: ink,
      ),
      sectionLabel: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: secondary,
      ),
      caption: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: secondary,
      ),
      micro: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.3,
        color: secondary,
      ),
    );
  }

  static final ZaidangType light = ZaidangType.from(ZaidangTokens.light);
  static final ZaidangType dark = ZaidangType.from(ZaidangTokens.dark);

  static ZaidangType of(BuildContext context) {
    return Theme.of(context).extension<ZaidangType>() ?? light;
  }

  /// 把 15 个 Material 槽位全部填满，原生组件不再落回 M3 默认字号。
  TextTheme toTextTheme() {
    return TextTheme(
      displayLarge: hero,
      displayMedium: hero,
      displaySmall: hero,
      headlineLarge: title,
      headlineMedium: title,
      headlineSmall: title,
      titleLarge: heading,
      titleMedium: pageTitle,
      titleSmall: subheading,
      bodyLarge: bodyLarge,
      bodyMedium: body,
      bodySmall: caption,
      labelLarge: label,
      labelMedium: sectionLabel,
      labelSmall: micro,
    );
  }

  @override
  ZaidangType copyWith({
    TextStyle? hero,
    TextStyle? title,
    TextStyle? heading,
    TextStyle? pageTitle,
    TextStyle? subheading,
    TextStyle? bodyLarge,
    TextStyle? body,
    TextStyle? label,
    TextStyle? sectionLabel,
    TextStyle? caption,
    TextStyle? micro,
  }) {
    return ZaidangType(
      hero: hero ?? this.hero,
      title: title ?? this.title,
      heading: heading ?? this.heading,
      pageTitle: pageTitle ?? this.pageTitle,
      subheading: subheading ?? this.subheading,
      bodyLarge: bodyLarge ?? this.bodyLarge,
      body: body ?? this.body,
      label: label ?? this.label,
      sectionLabel: sectionLabel ?? this.sectionLabel,
      caption: caption ?? this.caption,
      micro: micro ?? this.micro,
    );
  }

  @override
  ZaidangType lerp(ThemeExtension<ZaidangType>? other, double t) {
    if (other is! ZaidangType) {
      return this;
    }
    return ZaidangType(
      hero: TextStyle.lerp(hero, other.hero, t)!,
      title: TextStyle.lerp(title, other.title, t)!,
      heading: TextStyle.lerp(heading, other.heading, t)!,
      pageTitle: TextStyle.lerp(pageTitle, other.pageTitle, t)!,
      subheading: TextStyle.lerp(subheading, other.subheading, t)!,
      bodyLarge: TextStyle.lerp(bodyLarge, other.bodyLarge, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      label: TextStyle.lerp(label, other.label, t)!,
      sectionLabel: TextStyle.lerp(sectionLabel, other.sectionLabel, t)!,
      caption: TextStyle.lerp(caption, other.caption, t)!,
      micro: TextStyle.lerp(micro, other.micro, t)!,
    );
  }
}
