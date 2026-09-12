import 'dart:async';
import 'dart:ui' as ui;
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/data/models/role.dart';
import 'package:ochome/data/models/role_asset.dart';
import 'package:ochome/data/providers/role_assets_provider.dart';
import 'package:ochome/data/providers/role_repository_provider.dart';
import 'package:ochome/data/services/role_asset_picker.dart';
import 'package:ochome/data/services/role_asset_opener.dart';
import 'package:ochome/data/services/video_thumbnail_service.dart';
import 'package:ochome/pages/role_create_page.dart';
import 'package:ochome/pages/cover_preview_page.dart';
import 'package:ochome/widgets/role_asset_card.dart';
import 'package:ochome/widgets/role_asset_tag.dart';
import 'package:ochome/widgets/role_asset_tags_dialog.dart';
import 'package:ochome/theme/zaidang_theme.dart';

import '../fakes/fake_role_asset_repository.dart';
import '../fakes/fake_role_repository.dart';

void main() {
  testWidgets(
    'asset tags save immediately while keeping the role draft and block navigation during a pending write',
    (tester) async {
      final assets = FakeRoleAssetRepository([
        _asset(1, '设定.pdf', RoleAssetKind.document),
      ]);
      addTearDown(assets.dispose);
      final roles = FakeRoleRepository([_role]);
      await _open(tester, assets, roles: roles);
      final name = find.byKey(const Key('role-field-name'));
      await tester.ensureVisible(name);
      await tester.enterText(name, '还没保存的名字');
      await tester.pumpAndSettle();
      await _assetsCollapsed(tester);
      await _assetAction(tester, '设定.pdf', '编辑标签');
      await tester.enterText(
        find.byKey(const Key('role-asset-tag-input')),
        '设定',
      );
      await tester.tap(find.byKey(const Key('role-asset-tags-save')));
      await tester.pumpAndSettle();
      expect(assets.items.single.tags, ['设定']);
      expect(assets.updateTagsCalls, 1);
      expect(find.widgetWithText(RoleAssetTag, '设定'), findsOneWidget);

      await _assetAction(tester, '设定.pdf', '编辑标签');
      await tester.enterText(
        find.byKey(const Key('role-asset-tag-input')),
        '官方图',
      );
      await tester.tap(find.byKey(const Key('role-asset-tags-cancel')));
      await tester.pumpAndSettle();
      expect(assets.items.single.tags, ['设定']);
      expect(assets.updateTagsCalls, 1);

      assets.pendingUpdateTags = Completer<void>();
      await _assetAction(tester, '设定.pdf', '编辑标签');
      await tester.enterText(
        find.byKey(const Key('role-asset-tag-input')),
        '世界观',
      );
      await tester.tap(find.byKey(const Key('role-asset-tags-save')));
      await tester.pump();
      expect(tester.widget<TextButton>(_roleSave()).onPressed, isNull);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(RoleAssetTagsDialog), findsOneWidget);
      assets.pendingUpdateTags!.complete();
      await tester.pumpAndSettle();
      expect(assets.items.single.tags, ['设定', '世界观']);
      expect((await roles.list()).single.name, '白鸦');
      await tester.tap(find.widgetWithText(Tab, '详情'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, '还没保存的名字'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'duration is shown without a thumbnail and unknown duration never becomes a zero label',
    (tester) async {
      for (final duration in [
        const Duration(hours: 1, minutes: 2, seconds: 3),
        null,
      ]) {
        final assets = FakeRoleAssetRepository([
          _asset(1, 'video.mp4', RoleAssetKind.video),
        ]);
        await _open(tester, assets, videoThumbnails: _DurationOnly(duration));
        await _assetsCollapsed(tester);
        final row = find.widgetWithText(RoleAssetCard, 'video.mp4');
        expect(
          find.descendant(of: row, matching: find.byIcon(Icons.play_arrow)),
          findsOneWidget,
        );
        if (duration != null) {
          expect(find.text('1:02:03'), findsOneWidget);
        } else {
          expect(
            find.byKey(const ValueKey('role-asset-duration-1')),
            findsNothing,
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await assets.dispose();
      }
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      '${dark ? 'dark' : 'light'} pinned header hides content scrolling under either tab',
      (tester) async {
        final assets = FakeRoleAssetRepository(
          List.generate(
            20,
            (index) =>
                _asset(index + 1, '文档 $index.pdf', RoleAssetKind.document),
          ),
        );
        addTearDown(assets.dispose);
        await _open(tester, assets, dark: dark);
        final nested = tester.state<NestedScrollViewState>(
          find.byKey(const Key('role-detail-nested-scroll')),
        );
        nested.outerController.jumpTo(
          nested.outerController.position.maxScrollExtent,
        );
        await tester.pumpAndSettle();

        for (final key in ['role-details-scroll', 'role-assets-scroll']) {
          if (key == 'role-assets-scroll') await _assets(tester);
          final scroll = tester.state<ScrollableState>(
            find
                .descendant(
                  of: find.byKey(PageStorageKey(key)),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          expect(scroll.position.maxScrollExtent, greaterThan(0));
          scroll.position.jumpTo(scroll.position.maxScrollExtent * 0.2);
          await tester.pumpAndSettle();
          final before = await _headerPixels(tester);
          final identity = tester.getRect(
            find.byKey(const Key('role-pinned-identity')),
          );
          scroll.position.jumpTo(scroll.position.maxScrollExtent * 0.8);
          await tester.pumpAndSettle();
          final after = await _headerPixels(tester);
          expect(
            listEquals(before, after),
            isTrue,
            reason: 'Scrolling $key must not change the pinned header pixels',
          );
          expect(
            tester.getRect(find.byKey(const Key('role-pinned-identity'))),
            identity,
          );
          expect(tester.takeException(), isNull);
        }
      },
    );

    testWidgets(
      '${dark ? 'dark' : 'light'} tabs pin below controls and preserve form, header and scroll position',
      (tester) async {
        final assets = FakeRoleAssetRepository();
        addTearDown(assets.dispose);
        final roles = FakeRoleRepository([_role]);
        await _open(tester, assets, roles: roles, dark: dark);
        expect(find.widgetWithText(Tab, '详情'), findsOneWidget);
        expect(find.widgetWithText(Tab, '资产'), findsOneWidget);
        final identity = find.byKey(const Key('role-pinned-identity'));
        double identityOpacity() => identity.evaluate().isEmpty
            ? 0
            : tester
                  .widget<Opacity>(
                    find
                        .ancestor(of: identity, matching: find.byType(Opacity))
                        .first,
                  )
                  .opacity;
        expect(identityOpacity(), 0);
        final name = find.widgetWithText(TextFormField, '白鸦');
        await tester.ensureVisible(name);
        await tester.enterText(name, '未保存的白鸦');
        await tester.pumpAndSettle();
        final details = find.byKey(const PageStorageKey('role-details-scroll'));
        await tester.dragFrom(const Offset(20, 700), const Offset(0, -550));
        await tester.pumpAndSettle();
        final scroll = tester.state<ScrollableState>(
          find.descendant(of: details, matching: find.byType(Scrollable)).first,
        );
        final detailOffset = scroll.position.pixels;
        expect(detailOffset, greaterThan(0));
        final tabRect = tester.getRect(
          find.byKey(const Key('role-detail-tabs')),
        );
        final back = tester.getRect(find.byTooltip('返回'));
        expect(tabRect.top, greaterThanOrEqualTo(back.bottom));
        expect(tabRect.bottom, lessThan(180));
        expect(identityOpacity(), 1);
        expect(
          find.descendant(of: identity, matching: find.text('未保存的白鸦')),
          findsOneWidget,
        );
        final portrait = tester.getRect(
          find.byKey(const Key('role-pinned-portrait')),
        );
        expect(portrait.size, const Size(32, 32));
        expect(
          find.ancestor(
            of: find.byKey(const Key('role-pinned-portrait')),
            matching: find.byType(ClipOval),
          ),
          findsOneWidget,
        );
        expect(tester.getRect(identity).center.dx, closeTo(195, 0.1));
        expect(tester.getRect(identity).left, greaterThan(back.right));
        expect(
          tester.getRect(identity).right,
          lessThan(tester.getRect(find.widgetWithText(TextButton, '保存')).left),
        );
        await _assets(tester);
        expect(find.text('还没有资产'), findsOneWidget);
        expect(identityOpacity(), 1);
        expect(
          tester.getRect(find.byKey(const Key('role-detail-tabs'))),
          tabRect,
        );
        await tester.drag(find.byType(TabBarView), const Offset(350, 0));
        await tester.pumpAndSettle();
        expect(scroll.position.pixels, closeTo(detailOffset, 1));
        final nested = tester.state<NestedScrollViewState>(
          find.byKey(const Key('role-detail-nested-scroll')),
        );
        scroll.position.jumpTo(0);
        nested.outerController.jumpTo(0);
        await tester.pumpAndSettle();
        expect(identityOpacity(), 0);
        nested.outerController.jumpTo(
          nested.outerController.position.maxScrollExtent,
        );
        tester.view.physicalSize = const Size(320, 844);
        await tester.pumpAndSettle();
        expect(identityOpacity(), 1);
        expect(tester.getRect(identity).center.dx, closeTo(160, 0.1));
        expect(
          tester.getRect(identity).right,
          lessThan(tester.getRect(find.widgetWithText(TextButton, '保存')).left),
        );
        await _assets(tester);
        await tester.tap(find.widgetWithText(TextButton, '保存'));
        await tester.pumpAndSettle();
        expect(find.byType(RoleCreatePage), findsNothing);
        expect((await roles.list()).single.name, '未保存的白鸦');
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final dark in [false, true]) {
    testWidgets(
      '${dark ? 'dark' : 'light'} rename protects extension and preserves role draft and scroll',
      (tester) async {
        final original = _asset(1, '原始设定.tar.PDF', RoleAssetKind.document);
        final assets = FakeRoleAssetRepository([original]);
        addTearDown(assets.dispose);
        final roles = FakeRoleRepository([_role]);
        final opener = _Opener();
        await _open(tester, assets, dark: dark, roles: roles, opener: opener);
        final name = find.widgetWithText(TextFormField, '白鸦');
        await tester.ensureVisible(name);
        await tester.enterText(name, '未保存的白鸦');
        await tester.pumpAndSettle();
        await _assets(tester);
        final scroll = tester.state<ScrollableState>(
          find
              .descendant(
                of: find.byKey(const PageStorageKey('role-assets-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        final offset = scroll.position.pixels;
        final semantics = tester.ensureSemantics();
        final menuSemantics = tester
            .getSemantics(_assetMenu(original.name))
            .getSemanticsData();
        expect(menuSemantics.tooltip, '更多操作：${original.name}');
        expect(menuSemantics.label, isEmpty);
        expect(menuSemantics.flagsCollection.isButton, isTrue);
        expect(menuSemantics.hasAction(ui.SemanticsAction.tap), isTrue);
        semantics.dispose();
        await _assetAction(tester, original.name, '重命名');
        final field = find.byKey(const Key('role-asset-rename-name'));
        final controller = tester.widget<TextFormField>(field).controller!;
        expect(controller.text, '原始设定.tar');
        expect(
          controller.selection,
          TextSelection(baseOffset: 0, extentOffset: controller.text.length),
        );
        expect(find.text('文件格式 .PDF（保留）'), findsOneWidget);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        expect(
          tester
              .getBottomRight(find.byKey(const Key('role-asset-rename-save')))
              .dy,
          lessThan(544),
        );
        await tester.enterText(field, '  白鸦·参考.v2  ');
        await tester.tap(find.byKey(const Key('role-asset-rename-save')));
        await tester.pumpAndSettle();
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        expect(assets.renameCalls, 1);
        expect(assets.items.single.name, '白鸦·参考.v2.PDF');
        expect(assets.items.single.relativePath, original.relativePath);
        expect(
          find.widgetWithText(RoleAssetCard, '白鸦·参考.v2.PDF'),
          findsOneWidget,
        );
        expect(scroll.position.pixels, closeTo(offset, 1));
        expect((await roles.list()).single.name, '白鸦');
        await tester.tap(find.widgetWithText(RoleAssetCard, '白鸦·参考.v2.PDF'));
        await tester.pumpAndSettle();
        expect(opener.opened.single.path, endsWith(original.relativePath));
        expect(opener.displayNames.single, '白鸦·参考.v2.PDF');
        await tester.tap(find.widgetWithText(Tab, '详情'));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(TextFormField, '未保存的白鸦'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final (kind, originalName, extension) in [
    (RoleAssetKind.video, 'internal-video.mp4', '.mp4'),
    (RoleAssetKind.audio, 'internal-audio.mp3', '.mp3'),
    (RoleAssetKind.document, 'internal-document.PDF', '.PDF'),
  ]) {
    testWidgets(
      'renamed ${kind.name} opens the same file with the latest display name',
      (tester) async {
        final original = _asset(1, originalName, kind);
        final assets = FakeRoleAssetRepository([original]);
        addTearDown(assets.dispose);
        final opener = _Opener();
        await _open(tester, assets, opener: opener);
        await _assetsCollapsed(tester);
        var currentName = originalName;
        for (final baseName in ['白鸦·参考', '白鸦·新参考']) {
          await _assetAction(tester, currentName, '重命名');
          await tester.enterText(
            find.byKey(const Key('role-asset-rename-name')),
            baseName,
          );
          await tester.tap(find.byKey(const Key('role-asset-rename-save')));
          await tester.pumpAndSettle();
          currentName = '$baseName$extension';
          await tester.tap(find.widgetWithText(RoleAssetCard, currentName));
          await tester.pumpAndSettle();
          expect(opener.displayNames.last, currentName);
          expect(opener.opened.last.path, endsWith(original.relativePath));
          expect(assets.items.single.relativePath, original.relativePath);
        }
        expect(opener.displayNames, ['白鸦·参考$extension', '白鸦·新参考$extension']);
        expect(opener.opened.map((file) => file.path).toSet(), hasLength(1));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'pending platform preview blocks parent actions until dismissal and recovers after failure',
    (tester) async {
      final assets = FakeRoleAssetRepository([
        _asset(1, 'clip.mp4', RoleAssetKind.video),
      ]);
      addTearDown(assets.dispose);
      final opener = _Opener()..pending = Completer<void>();
      final roles = _PendingRoles();
      await _open(tester, assets, opener: opener, roles: roles);
      await _assetsCollapsed(tester);
      final row = find.widgetWithText(RoleAssetCard, 'clip.mp4');
      final open = tester.widget<RoleAssetCard>(row).onTap!;
      final roleSave = tester.widget<TextButton>(_roleSave()).onPressed!;
      open();
      roleSave();
      await tester.pump();
      open();
      await tester.pump();
      expect(opener.opened, hasLength(1));
      expect(opener.displayNames, ['clip.mp4']);
      expect(roles.updateCalls, 0);
      expect(tester.widget<TextButton>(_roleSave()).onPressed, isNull);
      expect(
        tester.widget<IconButton>(_assetMenu('clip.mp4')).onPressed,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(RoleCreatePage), findsOneWidget);
      opener.pending!.complete();
      await tester.pumpAndSettle();
      expect(tester.widget<TextButton>(_roleSave()).onPressed, isNotNull);
      opener.pending = Completer<void>();
      await tester.tap(row);
      await tester.pump();
      opener.pending!.completeError(const AssetOpenException('暂时无法显示预览，请重试'));
      await tester.pumpAndSettle();
      expect(find.textContaining('暂时无法显示预览，请重试'), findsOneWidget);
      expect(tester.widget<TextButton>(_roleSave()).onPressed, isNotNull);
      expect(
        tester.widget<IconButton>(_assetMenu('clip.mp4')).onPressed,
        isNotNull,
      );
      opener.pending = null;
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(opener.opened, hasLength(3));
      expect(find.byType(RoleCreatePage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'rename validates input, supports extensionless names and ignores cancellation and no-op',
    (tester) async {
      final assets = FakeRoleAssetRepository([
        _asset(1, 'README', RoleAssetKind.document),
      ]);
      addTearDown(assets.dispose);
      await _open(tester, assets);
      await _assets(tester);
      await _assetAction(tester, 'README', '重命名');
      expect(
        find.byKey(const Key('role-asset-rename-extension')),
        findsNothing,
      );
      final field = find.byKey(const Key('role-asset-rename-name'));
      for (final (input, error) in [
        ('   ', '请输入资产名称'),
        ('.', '名称不能是 . 或 ..'),
        ('folder/name', r'名称不能包含 / 或 \'),
        ('line\u007fbreak', '名称不能包含换行或控制字符'),
      ]) {
        await tester.enterText(field, input);
        await tester.tap(find.byKey(const Key('role-asset-rename-save')));
        await tester.pumpAndSettle();
        expect(find.text(error), findsOneWidget);
        expect(assets.renameCalls, 0);
      }
      await tester.enterText(field, '新名称');
      final cancel = tester
          .widget<TextButton>(find.byKey(const Key('role-asset-rename-cancel')))
          .onPressed!;
      cancel();
      cancel();
      await tester.pumpAndSettle();
      expect(assets.items.single.name, 'README');
      expect(find.byType(RoleCreatePage), findsOneWidget);
      await _assetAction(tester, 'README', '重命名');
      await tester.enterText(field, ' README ');
      await tester.tap(find.byKey(const Key('role-asset-rename-save')));
      await tester.pumpAndSettle();
      expect(assets.renameCalls, 0);
      await _assetAction(tester, 'README', '重命名');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('role-asset-rename-dialog')), findsNothing);
      expect(find.byType(RoleCreatePage), findsOneWidget);
      await _assetAction(tester, 'README', '重命名');
      await tester.enterText(field, '无后缀说明');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(assets.items.single.name, '无后缀说明');
      expect(assets.renameCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pending rename blocks stale callbacks and navigation, then keeps failed input for retry',
    (tester) async {
      final assets =
          FakeRoleAssetRepository([
              _asset(1, 'notes.pdf', RoleAssetKind.document),
            ])
            ..pendingRename = Completer<void>()
            ..failRename = true;
      addTearDown(assets.dispose);
      final roles = _PendingRoles();
      await _open(tester, assets, roles: roles);
      await _assets(tester);
      final menu = tester
          .widget<IconButton>(_assetMenu('notes.pdf'))
          .onPressed!;
      final roleSave = tester.widget<TextButton>(_roleSave()).onPressed!;
      menu();
      menu();
      roleSave();
      await tester.pumpAndSettle();
      expect(roles.updateCalls, 0);
      expect(find.text('重命名'), findsOneWidget);
      await tester.tap(find.text('重命名'));
      await tester.pumpAndSettle();
      final field = find.byKey(const Key('role-asset-rename-name'));
      await tester.enterText(field, '新设定');
      final save = tester
          .widget<TextButton>(find.byKey(const Key('role-asset-rename-save')))
          .onPressed!;
      final cancel = tester
          .widget<TextButton>(find.byKey(const Key('role-asset-rename-cancel')))
          .onPressed!;
      save();
      save();
      cancel();
      menu();
      roleSave();
      await tester.pump();
      expect(assets.renameCalls, 1);
      expect(roles.updateCalls, 0);
      expect(tester.widget<TextButton>(_roleSave()).onPressed, isNull);
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const Key('role-asset-rename-cancel')),
            )
            .onPressed,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('role-asset-rename-dialog')), findsOneWidget);
      expect(find.byType(RoleCreatePage), findsOneWidget);
      assets.pendingRename!.complete();
      await tester.pumpAndSettle();
      expect(find.text('重命名失败，请重试'), findsOneWidget);
      expect(tester.widget<TextFormField>(field).controller!.text, '新设定');
      expect(assets.items.single.name, 'notes.pdf');
      assets.failRename = false;
      await tester.tap(find.byKey(const Key('role-asset-rename-save')));
      await tester.pumpAndSettle();
      expect(assets.renameCalls, 2);
      expect(assets.items.single.name, '新设定.pdf');
      expect(find.byKey(const Key('role-asset-rename-dialog')), findsNothing);
      expect(find.byType(RoleCreatePage), findsOneWidget);
      expect(tester.widget<TextButton>(_roleSave()).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'role save blocks stale asset menu before and after disabled-state rebuild',
    (tester) async {
      final assets = FakeRoleAssetRepository([
        _asset(1, 'notes.pdf', RoleAssetKind.document),
      ]);
      addTearDown(assets.dispose);
      final roles = _PendingRoles();
      await _open(tester, assets, roles: roles);
      await _assets(tester);
      final menu = tester
          .widget<IconButton>(_assetMenu('notes.pdf'))
          .onPressed!;
      tester.widget<TextButton>(_roleSave()).onPressed!();
      menu();
      await tester.pump();
      menu();
      await tester.pump();
      expect(
        tester.widget<IconButton>(_assetMenu('notes.pdf')).onPressed,
        isNull,
      );
      expect(find.text('重命名'), findsNothing);
      expect(assets.renameCalls, 0);
      roles.pending.complete();
      await tester.pumpAndSettle();
      expect(find.byType(RoleCreatePage), findsNothing);
      expect(roles.updateCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'imports files, filters four types and opens video/audio/document through system service',
    (tester) async {
      final assets = FakeRoleAssetRepository();
      addTearDown(assets.dispose);
      final picker = _Picker()
        ..files = [
          for (final name in ['立绘.png', '动作.mp4', '配音.mp3', '设定.pdf'])
            _file(name),
        ];
      final opener = _Opener();
      await _open(tester, assets, picker: picker, opener: opener);
      await _assetsCollapsed(tester);
      await _addFiles(tester);
      expect(assets.importCalls, 1);
      expect(find.text('4 份资产'), findsOneWidget);
      for (final (label, name) in [
        ('视频', '动作.mp4'),
        ('音频', '配音.mp3'),
        ('文档', '设定.pdf'),
      ]) {
        await tester.tap(find.widgetWithText(ChoiceChip, label));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(RoleAssetCard, name), findsOneWidget);
        expect(find.byType(RoleAssetCard), findsOneWidget);
        await tester.tap(find.widgetWithText(RoleAssetCard, name));
        await tester.pumpAndSettle();
        expect(opener.opened.last.path, endsWith(name));
      }
      await tester.tap(find.widgetWithText(ChoiceChip, '图片'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(RoleAssetCard, '立绘.png'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'dotted display names remain editable and never change extensionless image routing',
    (tester) async {
      final original = _asset(1, 'README', RoleAssetKind.image);
      final assets = FakeRoleAssetRepository([original]);
      addTearDown(assets.dispose);
      final opener = _Opener();
      await _open(tester, assets, opener: opener);
      await _assetsCollapsed(tester);
      await tester.tap(find.widgetWithText(RoleAssetCard, 'README'));
      await tester.pumpAndSettle();
      expect(opener.opened, hasLength(1));
      await _assetAction(tester, 'README', '重命名');
      final field = find.byKey(const Key('role-asset-rename-name'));
      await tester.enterText(field, '参考.v2.png');
      await tester.tap(find.byKey(const Key('role-asset-rename-save')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(RoleAssetCard, '参考.v2.png'));
      await tester.pumpAndSettle();
      expect(opener.opened, hasLength(2));
      expect(opener.opened.last.path, opener.opened.first.path);
      expect(find.byType(CoverPreviewPage), findsNothing);
      await _assetAction(tester, '参考.v2.png', '重命名');
      expect(tester.widget<TextFormField>(field).controller!.text, '参考.v2.png');
      expect(
        find.byKey(const Key('role-asset-rename-extension')),
        findsNothing,
      );
      await tester.enterText(field, '最终说明');
      await tester.tap(find.byKey(const Key('role-asset-rename-save')));
      await tester.pumpAndSettle();
      expect(assets.items.single.name, '最终说明');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'video row shows its generated cover and still opens the original video',
    (tester) async {
      final assets = FakeRoleAssetRepository([
        _asset(1, '动作.mp4', RoleAssetKind.video),
      ]);
      addTearDown(assets.dispose);
      late Directory root;
      late File cover;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('video-cover-ui');
        cover = File('${root.path}/cover.png');
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawColor(Colors.blue, BlendMode.src);
        final picture = recorder.endRecording();
        final image = await picture.toImage(80, 120);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await cover.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
        picture.dispose();
      });
      addTearDown(() => root.delete(recursive: true));
      final video = File('${root.path}/original.mp4');
      assets.files[1] = video;
      final thumbnails = _VideoThumbnails(cover);
      final opener = _Opener();
      await _open(tester, assets, opener: opener, videoThumbnails: thumbnails);
      await tester.runAsync(
        () => precacheImage(
          FileImage(cover),
          tester.element(find.byType(RoleCreatePage)),
        ),
      );
      await _assets(tester);
      final row = find.widgetWithText(RoleAssetCard, '动作.mp4');
      final image = tester.widget<Image>(
        find.descendant(of: row, matching: find.byType(Image)),
      );
      final provider = image.image is ResizeImage
          ? (image.image as ResizeImage).imageProvider
          : image.image;
      expect((provider as FileImage).file.path, cover.path);
      expect(
        find.descendant(of: row, matching: find.byIcon(Icons.play_arrow)),
        findsOneWidget,
      );
      expect(thumbnails.sources.single.path, video.path);
      expect(find.text('03:24'), findsOneWidget);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(opener.opened.single.path, video.path);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'gallery cancel and import failure leave assets intact; pending import blocks save and back',
    (tester) async {
      final assets = FakeRoleAssetRepository();
      addTearDown(assets.dispose);
      final picker = _Picker();
      await _open(tester, assets, picker: picker);
      await _assets(tester);
      await tester.tap(find.byKey(const Key('role-asset-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('从相册添加'));
      await tester.pumpAndSettle();
      expect(picker.galleryCalls, 1);
      expect(assets.importCalls, 0);
      picker.files = [_file('设定.pdf')];
      assets.failImport = true;
      await _addFiles(tester);
      expect(find.textContaining('添加失败'), findsOneWidget);
      expect(assets.items, isEmpty);
      assets.failImport = false;
      assets.pendingImport = Completer<void>();
      await tester.tap(find.byKey(const Key('role-asset-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('从文件添加'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final save = tester.widget<TextButton>(
        find.widgetWithText(TextButton, '保存'),
      );
      expect(save.onPressed, isNull);
      expect(find.text('正在保存文件…'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(RoleCreatePage), findsOneWidget);
      assets.pendingImport!.complete();
      await tester.pumpAndSettle();
      expect(assets.items.single.name, '设定.pdf');
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '保存'))
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('open failures are visible and deletion requires confirmation', (
    tester,
  ) async {
    final assets = FakeRoleAssetRepository([
      _asset(1, 'notes.pdf', RoleAssetKind.document),
    ]);
    addTearDown(assets.dispose);
    final opener = _Opener()..fail = true;
    await _open(tester, assets, opener: opener);
    await _assetsCollapsed(tester);
    await tester.tap(find.widgetWithText(RoleAssetCard, 'notes.pdf'));
    await tester.pumpAndSettle();
    expect(find.textContaining('没有可打开此文件的应用'), findsOneWidget);
    await _assetAction(tester, 'notes.pdf', '删除');
    await tester.tap(find.byKey(const Key('zaidang-confirm-cancel')));
    await tester.pumpAndSettle();
    expect(assets.items, hasLength(1));
    await _assetAction(tester, 'notes.pdf', '删除');
    await tester.tap(find.byKey(const Key('zaidang-confirm-action')));
    await tester.pumpAndSettle();
    expect(assets.items, isEmpty);
    expect(find.text('还没有资产'), findsOneWidget);
  });

  testWidgets(
    'images open the existing gallery and return to assets without losing the role',
    (tester) async {
      final assets = FakeRoleAssetRepository([
        _asset(1, 'portrait.png', RoleAssetKind.image),
      ]);
      addTearDown(assets.dispose);
      late Directory root;
      late File file;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('role-asset-preview');
        file = File('${root.path}/role_assets/1-portrait.png');
        await file.parent.create();
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawColor(Colors.teal, BlendMode.src);
        final picture = recorder.endRecording();
        final image = await picture.toImage(80, 120);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
        picture.dispose();
      });
      addTearDown(() async => root.delete(recursive: true));
      assets.files[1] = file;
      await _open(tester, assets);
      await tester.runAsync(
        () => precacheImage(
          FileImage(file),
          tester.element(find.byType(RoleCreatePage)),
        ),
      );
      await _assets(tester);
      await tester.tap(find.widgetWithText(RoleAssetCard, 'portrait.png'));
      await tester.pumpAndSettle();
      expect(find.byType(CoverPreviewPage), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(CoverPreviewPage), findsNothing);
      expect(find.byType(RoleCreatePage), findsOneWidget);
      expect(
        find.widgetWithText(RoleAssetCard, 'portrait.png'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '保存'))
            .onPressed,
        isNotNull,
      );
    },
  );
}

Future<Uint8List> _headerPixels(WidgetTester tester) async {
  final boundaryFinder = find
      .ancestor(
        of: find.byType(RoleCreatePage),
        matching: find.byType(RepaintBoundary),
      )
      .first;
  final boundary = tester.renderObject<RenderRepaintBoundary>(boundaryFinder);
  final height =
      (tester.getRect(find.byKey(const Key('role-detail-tabs'))).bottom -
              tester.getTopLeft(boundaryFinder).dy)
          .floor();
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return Uint8List.fromList(
        bytes!.buffer.asUint8List(0, image.width * height * 4),
      );
    } finally {
      image.dispose();
    }
  }))!;
}

Future<void> _open(
  WidgetTester tester,
  FakeRoleAssetRepository assets, {
  FakeRoleRepository? roles,
  _Picker? picker,
  _Opener? opener,
  VideoThumbnailService? videoThumbnails,
  bool dark = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
  addTearDown(tester.view.resetViewPadding);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        roleRepositoryProvider.overrideWithValue(
          roles ?? FakeRoleRepository([_role]),
        ),
        roleAssetRepositoryProvider.overrideWithValue(assets),
        roleAssetPickerProvider.overrideWithValue(picker ?? _Picker()),
        roleAssetOpenerProvider.overrideWithValue(opener ?? _Opener()),
        if (videoThumbnails != null)
          videoThumbnailServiceProvider.overrideWithValue(videoThumbnails),
      ],
      child: MaterialApp(
        theme: dark ? zaidangDarkTheme() : zaidangLightTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => const RoleCreatePage(role: _role),
                ),
              ),
              child: const Text('打开角色'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开角色'));
  await tester.pumpAndSettle();
}

Future<void> _assets(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(Tab, '资产'));
  await tester.pumpAndSettle();
}

/// 切到资产页并把立绘 + 身份头滚走：这些用例要点列表行与浮动通知同屏，
/// 头图展开时行会落到通知底下。
Future<void> _assetsCollapsed(WidgetTester tester) async {
  await _assets(tester);
  final nested = tester.state<NestedScrollViewState>(
    find.byKey(const Key('role-detail-nested-scroll')),
  );
  nested.outerController.jumpTo(
    nested.outerController.position.maxScrollExtent,
  );
  await tester.pumpAndSettle();
}

Finder _assetMenu(String name) => find.byWidgetPredicate(
  (widget) => widget is IconButton && widget.tooltip == '更多操作：$name',
);

Finder _roleSave() => find.descendant(
  of: find.byType(RoleCreatePage),
  matching: find.widgetWithText(TextButton, '保存'),
);

Future<void> _assetAction(
  WidgetTester tester,
  String name,
  String action,
) async {
  await tester.tap(find.byTooltip('更多操作：$name'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(action));
  await tester.pumpAndSettle();
}

Future<void> _addFiles(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('role-asset-add')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('从文件添加'));
  await tester.pumpAndSettle();
}

const _role = Role(
  id: 1,
  name: '白鸦',
  sex: '',
  age: '',
  birthday: '',
  race: '',
  occupation: '',
  desc: '角色设定',
  coverImg: '',
);

RoleAsset _asset(int id, String name, RoleAssetKind kind) => RoleAsset(
  id: id,
  roleId: 1,
  name: name,
  kind: kind,
  relativePath: 'role_assets/$id-$name',
  bytes: 42,
  createdAt: DateTime(2026, 9, 6),
);

XFile _file(String name) =>
    XFile.fromData(Uint8List.fromList([1, 2, 3]), path: name);

class _Picker extends RoleAssetPicker {
  List<XFile> files = [];
  int galleryCalls = 0;
  @override
  Future<List<XFile>> pickFiles() async => files;
  @override
  Future<List<XFile>> pickMedia() async {
    galleryCalls++;
    return files;
  }
}

class _PendingRoles extends FakeRoleRepository {
  _PendingRoles() : super([_role]);

  final pending = Completer<void>();
  int updateCalls = 0;

  @override
  Future<Role> update(Role role) async {
    updateCalls++;
    await pending.future;
    return super.update(role);
  }
}

class _Opener extends RoleAssetOpener {
  final opened = <File>[];
  final displayNames = <String>[];
  Completer<void>? pending;
  bool fail = false;
  @override
  Future<void> open(File file, {required String displayName}) async {
    if (fail) throw const AssetOpenException('没有可打开此文件的应用');
    opened.add(file);
    displayNames.add(displayName);
    if (pending != null) await pending!.future;
  }
}

class _VideoThumbnails extends VideoThumbnailService {
  _VideoThumbnails(this.cover);
  final File cover;
  final sources = <File>[];

  @override
  Future<File?> thumbnailFor(File video) async {
    sources.add(video);
    return cover;
  }

  @override
  Future<Duration?> durationFor(File video) async =>
      const Duration(minutes: 3, seconds: 24);
}

class _DurationOnly extends VideoThumbnailService {
  _DurationOnly(this.duration);
  final Duration? duration;

  @override
  Future<File?> thumbnailFor(File video) async => null;

  @override
  Future<Duration?> durationFor(File video) async => duration;
}
