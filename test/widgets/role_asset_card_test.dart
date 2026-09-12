import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/data/models/role_asset.dart';
import 'package:ochome/theme/zaidang_asset_colors.dart';
import 'package:ochome/theme/zaidang_theme.dart';
import 'package:ochome/theme/zaidang_tokens.dart';
import 'package:ochome/widgets/role_asset_card.dart';
import 'package:ochome/widgets/role_asset_tag.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      '${dark ? 'dark' : 'light'} card keeps metadata, tags and menu accessible on a narrow phone',
      (tester) async {
        final semantics = tester.ensureSemantics();
        tester.view.physicalSize = const Size(320, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var opened = 0;
        var menus = 0;
        final asset = RoleAsset(
          id: 1,
          roleId: 1,
          name: '角色设定集与世界观参考资料完整版 v1.0.pdf',
          kind: RoleAssetKind.document,
          relativePath: 'role_assets/book.pdf',
          bytes: 13421772,
          createdAt: DateTime(2024, 2, 14, 20, 18),
          tags: const ['设定', '世界观', '十六个汉字以内的长标签测试'],
        );
        for (final scale in [1.0, 2.0]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? zaidangDarkTheme() : zaidangLightTheme(),
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: RoleAssetCard(
                        asset: asset,
                        thumbnail: const ColoredBox(color: Colors.grey),
                        onTap: () => opened++,
                        onMore: (_) => menus++,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('文档 · 12.8 MB'), findsOneWidget);
          expect(find.text('2024年2月14日  20:18'), findsOneWidget);
          final card = tester.getRect(find.byType(RoleAssetCard));
          final preview = tester.getRect(
            find.byKey(const ValueKey('role-asset-preview-1')),
          );
          expect(preview.width, greaterThanOrEqualTo(88));
          expect(preview.height, preview.width);
          final menu = find.byKey(const ValueKey('role-asset-more-1'));
          expect(tester.getSize(menu).width, greaterThanOrEqualTo(48));
          expect(tester.getSize(menu).height, greaterThanOrEqualTo(48));
          final menuSemantics = tester.getSemantics(menu);
          expect(menuSemantics.tooltip, '更多操作：${asset.name}');
          expect(menuSemantics.label, isEmpty);
          for (final tag in find.byType(RoleAssetTag).evaluate()) {
            final rect = tester.getRect(
              find.byElementPredicate((e) => identical(e, tag)),
            );
            expect(card.contains(rect.topLeft), isTrue);
            expect(card.contains(rect.bottomRight), isTrue);
          }
          await tester.tap(menu);
          expect(menus, scale == 1 ? 1 : 2);
          expect(opened, scale == 1 ? 0 : 1);
          await tester.tap(find.byKey(const ValueKey('role-asset-preview-1')));
          expect(opened, scale == 1 ? 1 : 2);
        }
        semantics.dispose();
      },
    );

    testWidgets(
      '${dark ? 'dark' : 'light'} tag text contrasts with its tinted paper',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? zaidangDarkTheme() : zaidangLightTheme(),
            home: const Scaffold(body: RoleAssetTag('设定')),
          ),
        );
        final context = tester.element(find.byType(RoleAssetTag));
        final surface = ZaidangTokens.of(context).surface;
        for (final label in ['设定', '世界观', '立绘']) {
          final color = ZaidangAssetColors.tagForeground(context, label);
          final background = Color.alphaBlend(
            color.withValues(alpha: 0.08),
            surface,
          );
          final a = color.computeLuminance();
          final b = background.computeLuminance();
          final contrast = ((a > b ? a : b) + 0.05) / ((a > b ? b : a) + 0.05);
          expect(contrast, greaterThanOrEqualTo(4.5));
        }
      },
    );
  }
}
