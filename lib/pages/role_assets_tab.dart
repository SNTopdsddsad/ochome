import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../data/models/role_asset.dart';
import '../data/providers/role_assets_provider.dart';
import '../data/repositories/role_asset_repository.dart';
import '../data/services/video_thumbnail_service.dart';
import '../data/services/data_storage.dart';
import '../theme/zaidang_tokens.dart';
import '../widgets/role_asset_rename_dialog.dart';
import '../widgets/zaidang_confirm_dialog.dart';
import '../widgets/zaidang_snack_bar.dart';
import 'cover_preview_page.dart';

enum _AssetAction { rename, delete }

/// 使用父级 NestedScrollView 的纵向控制器，与详情共享立绘和吸顶标签。
class RoleAssetsTab extends ConsumerStatefulWidget {
  const RoleAssetsTab({
    super.key,
    required this.roleId,
    required this.overlapHandle,
    required this.onBusyChanged,
    this.enabled = true,
    this.isEnabled,
  });

  final int roleId;
  final SliverOverlapAbsorberHandle overlapHandle;
  final ValueChanged<bool> onBusyChanged;
  final bool enabled;

  /// Check parent save state even before its disabled-state rebuild.
  final bool Function()? isEnabled;

  @override
  ConsumerState<RoleAssetsTab> createState() => _RoleAssetsTabState();
}

class _RoleAssetsTabState extends ConsumerState<RoleAssetsTab>
    with AutomaticKeepAliveClientMixin {
  RoleAssetKind? _filter;
  bool _busy = false;
  bool _importing = false;

  @override
  bool get wantKeepAlive => true;

  bool get _enabled => widget.enabled && (widget.isEnabled?.call() ?? true);

  bool get _canAct => _enabled && !_busy;

  void _setBusy(bool busy) {
    setState(() => _busy = busy);
    widget.onBusyChanged(busy);
  }

  Future<void> _addAssets() async {
    if (!_canAct) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _setBusy(true);
    try {
      final fromGallery = await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('从相册添加'),
                subtitle: const Text('图片和视频'),
                onTap: () => Navigator.pop(context, true),
              ),
              ListTile(
                leading: const Icon(Icons.folder_open_outlined),
                title: const Text('从文件添加'),
                subtitle: const Text('图片、视频、音频和文档'),
                onTap: () => Navigator.pop(context, false),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
      if (fromGallery == null || !mounted || !_enabled) return;
      final picker = ref.read(roleAssetPickerProvider);
      final repository = ref.read(roleAssetRepositoryProvider);
      final files = await (fromGallery
          ? picker.pickMedia()
          : picker.pickFiles());
      if (files.isEmpty || !mounted || !_enabled) return;
      setState(() => _importing = true);
      await repository.importFiles(widget.roleId, files);
      if (mounted) {
        setState(() => _filter = null);
        showZaidangSnackBar(context, '已添加 ${files.length} 份资产');
      }
    } catch (error) {
      if (mounted) {
        showZaidangSnackBar(
          context,
          '添加失败：$error',
          tone: ZaidangSnackBarTone.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _importing = false);
        _setBusy(false);
      }
    }
  }

  bool _previewable(RoleAsset asset) =>
      asset.kind == RoleAssetKind.image &&
      const {
        '.jpg',
        '.jpeg',
        '.png',
        '.gif',
        '.webp',
        '.bmp',
      }.contains(p.extension(asset.relativePath).toLowerCase());

  Future<void> _openAsset(RoleAsset asset, List<RoleAsset> all) async {
    if (!_canAct) return;
    _setBusy(true);
    StoragePin? filePin;
    try {
      final file = await ref.read(roleAssetRepositoryProvider).fileFor(asset);
      if (!mounted || !_enabled) return;
      final storage = DataStorage.current;
      if (storage != null &&
          p.isWithin(storage.supportDirectory.path, file.path)) {
        filePin = storage.pinFiles([file.path]);
      }
      if (_previewable(asset)) {
        final images = all.where(_previewable).toList();
        final root = file.parent.parent;
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => CoverPreviewPage(
              coverImages: images.map((item) => item.relativePath).toList(),
              initialIndex: images.indexWhere((item) => item.id == asset.id),
              supportDirectory: () async => root,
            ),
          ),
        );
      } else {
        await ref
            .read(roleAssetOpenerProvider)
            .open(file, displayName: asset.name);
      }
    } catch (error) {
      if (mounted) {
        showZaidangSnackBar(
          context,
          '打开失败：$error',
          tone: ZaidangSnackBarTone.error,
        );
      }
    } finally {
      await filePin?.release();
      if (mounted) _setBusy(false);
    }
  }

  Future<void> _showAssetActions(RoleAsset asset, BuildContext anchor) async {
    if (!_canAct) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _setBusy(true);
    try {
      final overlay =
          Navigator.of(context).overlay!.context.findRenderObject()
              as RenderBox;
      final button = anchor.findRenderObject()! as RenderBox;
      final action = await showMenu<_AssetAction>(
        context: context,
        position: RelativeRect.fromRect(
          Rect.fromPoints(
            button.localToGlobal(Offset.zero, ancestor: overlay),
            button.localToGlobal(
              button.size.bottomRight(Offset.zero),
              ancestor: overlay,
            ),
          ),
          Offset.zero & overlay.size,
        ),
        items: const [
          PopupMenuItem(
            value: _AssetAction.rename,
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 20),
                SizedBox(width: 12),
                Text('重命名'),
              ],
            ),
          ),
          PopupMenuItem(
            value: _AssetAction.delete,
            child: Row(
              children: [
                Icon(Icons.delete_outline, size: 20),
                SizedBox(width: 12),
                Text('删除'),
              ],
            ),
          ),
        ],
      );
      if (!mounted || !_enabled || action == null) return;
      switch (action) {
        case _AssetAction.rename:
          final changed = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (_) => RoleAssetRenameDialog(
              name: asset.name,
              relativePath: asset.relativePath,
              canSave: () => mounted && _enabled,
              onSave: (baseName) async {
                if (!mounted || !_enabled) return;
                await ref
                    .read(roleAssetRepositoryProvider)
                    .rename(
                      roleId: widget.roleId,
                      assetId: asset.id,
                      baseName: baseName,
                    );
              },
            ),
          );
          if (changed == true && mounted) {
            showZaidangSnackBar(context, '资产已重命名');
          }
        case _AssetAction.delete:
          await _deleteAsset(asset);
      }
    } finally {
      if (mounted) _setBusy(false);
    }
  }

  Future<void> _deleteAsset(RoleAsset asset) async {
    try {
      final confirmed = await showZaidangConfirmDialog(
        context: context,
        title: '删除这份资产？',
        body: '「${asset.name}」将从此角色的资产中移除。',
        consequence: '删除立即生效，原始导入文件不受影响。',
        confirmLabel: '删除资产',
      );
      if (!confirmed || !mounted || !_enabled) return;
      await ref
          .read(roleAssetRepositoryProvider)
          .delete(roleId: widget.roleId, assetId: asset.id);
      if (mounted) showZaidangSnackBar(context, '资产已删除');
    } catch (error) {
      if (mounted) {
        showZaidangSnackBar(
          context,
          '删除失败：$error',
          tone: ZaidangSnackBarTone.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final assets = ref.watch(roleAssetsProvider(widget.roleId));
    final tokens = ZaidangTokens.of(context);
    final inset =
        20 +
        ((MediaQuery.sizeOf(context).width - 600).clamp(0, double.infinity) /
            2);
    return CustomScrollView(
      key: const PageStorageKey('role-assets-scroll'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverOverlapInjector(handle: widget.overlapHandle),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(inset, 12, inset, 8),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _importing
                            ? '正在保存文件…'
                            : '${assets.asData?.value.length ?? 0} 份资产',
                        style: TextStyle(
                          color: tokens.inkSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      key: const Key('role-asset-add'),
                      onPressed: _canAct ? _addAssets : null,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('添加资产'),
                    ),
                  ],
                ),
                if (_importing)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: LinearProgressIndicator(),
                  ),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final kind in [null, ...RoleAssetKind.values])
                      ChoiceChip(
                        label: Text(kind?.label ?? '全部'),
                        selected: _filter == kind,
                        backgroundColor: tokens.bg,
                        selectedColor: tokens.accent.withValues(alpha: 0.08),
                        side: BorderSide(
                          color: _filter == kind
                              ? tokens.accent.withValues(alpha: 0.25)
                              : tokens.border,
                        ),
                        labelStyle: TextStyle(
                          color: _filter == kind
                              ? tokens.accent
                              : tokens.inkSecondary,
                        ),
                        showCheckmark: false,
                        onSelected: _canAct
                            ? (_) => setState(() => _filter = kind)
                            : null,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        ...assets.when(
          data: (all) {
            final items = all
                .where((asset) => _filter == null || asset.kind == _filter)
                .toList();
            if (items.isEmpty) {
              return <Widget>[
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_open_outlined,
                          size: 40,
                          color: tokens.inkSecondary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _filter == null ? '还没有资产' : '暂无${_filter!.label}',
                          style: TextStyle(color: tokens.ink),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '保存属于这个 OC 的图片、视频、音频和文档',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: tokens.inkSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ];
            }
            return <Widget>[
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  inset,
                  8,
                  inset,
                  24 + MediaQuery.paddingOf(context).bottom,
                ),
                sliver: SliverList.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final asset = items[index];
                    return ListTile(
                      key: ValueKey('role-asset-${asset.id}'),
                      contentPadding: const EdgeInsets.symmetric(vertical: 6),
                      leading: _AssetThumbnail(
                        asset: asset,
                        repository: ref.read(roleAssetRepositoryProvider),
                        videoThumbnails: ref.read(
                          videoThumbnailServiceProvider,
                        ),
                      ),
                      title: Text(
                        asset.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${asset.kind.label} · ${_formatBytes(asset.bytes)}',
                      ),
                      onTap: _canAct ? () => _openAsset(asset, all) : null,
                      trailing: Builder(
                        builder: (context) => IconButton(
                          tooltip: '更多操作：${asset.name}',
                          icon: Icon(
                            Icons.more_horiz,
                            size: 20,
                            semanticLabel: '更多操作：${asset.name}',
                          ),
                          onPressed: _canAct
                              ? () => _showAssetActions(asset, context)
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ];
          },
          loading: () => const <Widget>[
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
          error: (error, _) => <Widget>[
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('资产加载失败'),
                    TextButton(
                      onPressed: () =>
                          ref.invalidate(roleAssetsProvider(widget.roleId)),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

class _AssetThumbnail extends StatefulWidget {
  const _AssetThumbnail({
    required this.asset,
    required this.repository,
    required this.videoThumbnails,
  });
  final RoleAsset asset;
  final RoleAssetRepository repository;
  final VideoThumbnailService videoThumbnails;

  @override
  State<_AssetThumbnail> createState() => _AssetThumbnailState();
}

class _AssetThumbnailState extends State<_AssetThumbnail> {
  late final Future<File?>? _file = switch (widget.asset.kind) {
    RoleAssetKind.image => widget.repository.fileFor(widget.asset),
    RoleAssetKind.video => _videoCover(),
    _ => null,
  };

  Future<File?> _videoCover() async {
    final video = await widget.repository.fileFor(widget.asset);
    return widget.videoThumbnails.thumbnailFor(video);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    final placeholder = ColoredBox(
      color: tokens.surface,
      child: Center(
        child: Icon(switch (widget.asset.kind) {
          RoleAssetKind.image => Icons.image_outlined,
          RoleAssetKind.video => Icons.movie_outlined,
          RoleAssetKind.audio => Icons.audio_file_outlined,
          RoleAssetKind.document => Icons.description_outlined,
        }, color: tokens.inkSecondary),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox.square(
        dimension: 52,
        child: _file == null
            ? placeholder
            : FutureBuilder<File?>(
                future: _file,
                builder: (context, snapshot) => snapshot.hasData
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(
                            snapshot.data!,
                            fit: BoxFit.cover,
                            cacheWidth: 156,
                            errorBuilder: (_, _, _) => placeholder,
                          ),
                          if (widget.asset.kind == RoleAssetKind.video)
                            Positioned(
                              right: 3,
                              bottom: 3,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: ZaidangTokens.dark.bg.withValues(
                                    alpha: 0.8,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.all(2),
                                  child: Icon(
                                    Icons.play_arrow,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      )
                    : placeholder,
              ),
      ),
    );
  }
}
