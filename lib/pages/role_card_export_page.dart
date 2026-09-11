import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/role_card/role_card_content.dart';
import '../features/role_card/role_card_delivery.dart';
import '../features/role_card/role_card_export_service.dart';
import '../features/role_card/role_card_field_picker.dart';
import '../features/role_card/role_card_renderer.dart';
import '../theme/zaidang_spacing.dart';
import '../theme/zaidang_tokens.dart';
import '../theme/zaidang_type.dart';
import '../widgets/zaidang_snack_bar.dart';

class RoleCardExportPage extends StatefulWidget {
  const RoleCardExportPage({
    super.key,
    required this.snapshot,
    this.supportDirectory,
    this.renderer = const RoleCardRenderer(),
    this.delivery,
    this.exportService,
  });

  final RoleCardSnapshot snapshot;
  final Future<Directory> Function()? supportDirectory;
  final RoleCardRenderer renderer;
  final RoleCardDelivery? delivery;
  final RoleCardExportService? exportService;

  @override
  State<RoleCardExportPage> createState() => _RoleCardExportPageState();
}

class _RoleCardExportPageState extends State<RoleCardExportPage> {
  /// 紧凑布局下预览区高度的夹取范围，按 3:4 卡面随宽度缩放。
  static const double _compactPreviewMinHeight = 240;
  static const double _compactPreviewMaxHeight = 520;

  late RoleCardSelection _selection = RoleCardSelection.defaults(
    widget.snapshot,
  );
  late final _delivery = widget.delivery ?? PlatformRoleCardDelivery();
  late final _exportService = widget.exportService ?? RoleCardExportService();
  final _pages = PageController();
  final _shareKey = GlobalKey();
  RoleCardDocument? _document;
  Object? _error;
  bool _loading = true;
  bool _busy = false;
  int _generation = 0;
  int _page = 0;
  String _progress = '';
  double? _fraction;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void dispose() {
    _generation++;
    _pages.dispose();
    // An in-flight export retains its document until its finally block.
    if (!_busy) _document?.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    if (_busy) return;
    final generation = ++_generation;
    final old = _document;
    setState(() {
      _document = null;
      _loading = true;
      _error = null;
      _page = 0;
    });
    old?.dispose();
    try {
      final document = await widget.renderer.prepare(
        widget.snapshot.select(_selection),
        supportDirectory: widget.supportDirectory,
      );
      if (!mounted || generation != _generation) {
        document.dispose();
        return;
      }
      setState(() {
        _document = document;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && generation == _generation && _pages.hasClients) {
          _pages.jumpToPage(0);
        }
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  Future<void> _chooseFields() async {
    if (_busy) return;
    final selection = await showModalBottomSheet<RoleCardSelection>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) =>
          RoleCardFieldPicker(snapshot: widget.snapshot, selection: _selection),
    );
    if (selection == null || !mounted || _busy) return;
    _selection = selection;
    await _prepare();
  }

  Future<void> _export({required bool share}) async {
    final document = _document;
    if (_busy || _loading || document == null) return;
    final originBox =
        _shareKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = originBox != null && originBox.hasSize
        ? originBox.localToGlobal(Offset.zero) & originBox.size
        : const Rect.fromLTWH(0, 0, 1, 1);
    setState(() {
      _busy = true;
      _progress = '正在生成角色卡…';
      _fraction = 0;
    });
    RoleCardExportJob? job;
    var retainForShare = false;
    try {
      job = await _exportService.render(
        pageCount: document.pageCount,
        renderPage: document.renderPng,
        isCancelled: () => !mounted,
        onProgress: (completed, total) {
          if (!mounted) return;
          setState(() {
            _progress = '正在生成角色卡 $completed / $total';
            _fraction = completed / total;
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _progress = share ? '正在打开分享…' : '正在保存角色卡…';
        _fraction = null;
      });
      retainForShare = share;
      final result = share
          ? await _delivery.share(job.paths, origin)
          : await _delivery.save(job.paths);
      if (!mounted) return;
      switch (result.status) {
        case RoleCardDeliveryStatus.saved:
          _snack(
            result.directory == null
                ? '已保存 ${result.count} 张角色卡到相册'
                : '已保存 ${result.count} 张角色卡到所选文件夹',
            tone: ZaidangSnackBarTone.success,
          );
        case RoleCardDeliveryStatus.shared:
        case RoleCardDeliveryStatus.cancelled:
        case RoleCardDeliveryStatus.unknown:
          // Some platforms report success when a share target is chosen,
          // before the user sends anything. Let the system UI report its result.
          break;
      }
    } on RoleCardExportCancelled {
      // Closing the preview while encoding is an ordinary cancellation.
    } catch (error) {
      if (mounted) {
        _snack(_errorMessage(error), tone: ZaidangSnackBarTone.error);
      }
    } finally {
      await job?.release(retainForShare: retainForShare);
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = '';
          _fraction = null;
        });
      } else {
        document.dispose();
      }
    }
  }

  String _errorMessage(Object error) {
    if (error is RoleCardRenderException) return error.message;
    if (error is PlatformException) {
      if (error.code == 'permissionDenied' || error.code == 'restricted') {
        return '没有添加相册的权限，可以在系统设置中开启，或改用分享。';
      }
      return error.message ?? '保存失败，请重试';
    }
    if (error is FileSystemException) return '无法生成或保存图片，请检查可用空间后重试。';
    return '角色卡导出失败，请重试。';
  }

  void _snack(
    String message, {
    ZaidangSnackBarTone tone = ZaidangSnackBarTone.info,
  }) {
    showZaidangSnackBar(context, message, tone: tone);
  }

  Future<void> _enlarge(int index) async {
    final document = _document;
    if (_busy || document == null) return;
    await showDialog<void>(
      context: context,
      useSafeArea: false,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: Text('第 ${index + 1} 张'),
            leading: IconButton(
              tooltip: '关闭大图',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              maxScale: 5,
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: _paint(document, index),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _paint(RoleCardDocument document, int index) => Semantics(
    label: document.semanticsForPage(index),
    image: true,
    child: ExcludeSemantics(
      child: SizedBox.fromSize(
        size: RoleCardDocument.pageSize,
        child: CustomPaint(painter: _CardPainter(document, index)),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('导出角色卡')),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact =
                constraints.maxHeight < 500 ||
                MediaQuery.textScalerOf(context).scale(14) > 23;
            final controls = _controls();
            if (compact) {
              return SingleChildScrollView(
                child: Column(
                  children: [
                    _header(),
                    SizedBox(
                      height: math.min(
                        _compactPreviewMaxHeight,
                        math.max(
                          _compactPreviewMinHeight,
                          constraints.maxWidth * 4 / 3,
                        ),
                      ),
                      child: _preview(),
                    ),
                    _pagination(),
                    controls,
                  ],
                ),
              );
            }
            return Column(
              children: [
                _header(),
                Expanded(child: _preview()),
                _pagination(),
                controls,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: ZaidangSpacing.page,
      vertical: ZaidangSpacing.sm,
    ),
    child: Wrap(
      spacing: ZaidangSpacing.xl,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('同人设定纸'),
        TextButton.icon(
          key: const Key('role-card-fields'),
          onPressed: _busy ? null : _chooseFields,
          icon: const Icon(Icons.tune, size: 18),
          label: const Text('显示内容'),
        ),
      ],
    ),
  );

  Widget _preview() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final document = _document;
    if (document == null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(ZaidangSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.description_outlined, size: 36),
              const SizedBox(height: ZaidangSpacing.lg),
              Text(
                _error == null ? '请选择要展示的内容' : _errorMessage(_error!),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: ZaidangSpacing.md),
              TextButton(onPressed: _prepare, child: const Text('重试')),
            ],
          ),
        ),
      );
    }
    return PageView.builder(
      key: const Key('role-card-pages'),
      controller: _pages,
      itemCount: document.pageCount,
      onPageChanged: (value) => setState(() => _page = value),
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ZaidangSpacing.page,
          vertical: ZaidangSpacing.sm,
        ),
        child: Tooltip(
          message: '点按放大预览',
          child: GestureDetector(
            onTap: () => _enlarge(index),
            child: FittedBox(
              fit: BoxFit.contain,
              child: _paint(document, index),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pagination() {
    final document = _document;
    if (document == null) return const SizedBox(height: ZaidangSpacing.sm);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (document.pageCount > 1)
          IconButton(
            tooltip: '上一张',
            onPressed: _page == 0
                ? null
                : () => _pages.previousPage(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                  ),
            icon: const Icon(Icons.chevron_left),
          ),
        Text(
          '${_page + 1} / ${document.pageCount}',
          key: const Key('role-card-page-count'),
        ),
        if (document.pageCount > 1)
          IconButton(
            tooltip: '下一张',
            onPressed: _page >= document.pageCount - 1
                ? null
                : () => _pages.nextPage(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                  ),
            icon: const Icon(Icons.chevron_right),
          ),
      ],
    );
  }

  Widget _controls() {
    final canExport = !_loading && !_busy && _document != null;
    final tokens = ZaidangTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ZaidangSpacing.page,
        ZaidangSpacing.md,
        ZaidangSpacing.page,
        ZaidangSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_busy) ...[
            LinearProgressIndicator(value: _fraction),
            const SizedBox(height: ZaidangSpacing.sm),
            Text(_progress, style: ZaidangType.of(context).body),
            const SizedBox(height: ZaidangSpacing.md),
          ],
          const Text('使用当前编辑内容，导出不会保存角色修改。'),
          const SizedBox(height: ZaidangSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final buttons = <Widget>[
                if (_delivery.canSave)
                  FilledButton.icon(
                    key: const Key('role-card-save'),
                    onPressed: canExport ? () => _export(share: false) : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    icon: const Icon(Icons.download_outlined, size: 20),
                    label: Text(_delivery.saveLabel),
                  ),
                if (_delivery.canShare)
                  OutlinedButton.icon(
                    key: _shareKey,
                    onPressed: canExport ? () => _export(share: true) : null,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      foregroundColor: tokens.ink,
                    ),
                    icon: const Icon(Icons.ios_share_outlined, size: 20),
                    label: const Text(
                      '分享图片',
                      key: Key('role-card-share-label'),
                    ),
                  ),
              ];
              if (buttons.isEmpty) return const Text('当前平台暂不支持图片保存与分享。');
              final stack =
                  constraints.maxWidth < 340 ||
                  MediaQuery.textScalerOf(context).scale(14) > 20;
              if (stack) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < buttons.length; i++) ...[
                      if (i > 0) const SizedBox(height: ZaidangSpacing.md),
                      buttons[i],
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  for (var i = 0; i < buttons.length; i++) ...[
                    if (i > 0) const SizedBox(width: ZaidangSpacing.md),
                    Expanded(child: buttons[i]),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CardPainter extends CustomPainter {
  const _CardPainter(this.document, this.index);
  final RoleCardDocument document;
  final int index;

  @override
  void paint(Canvas canvas, Size size) => document.paintPage(canvas, index);

  @override
  bool shouldRepaint(covariant _CardPainter oldDelegate) =>
      document != oldDelegate.document || index != oldDelegate.index;
}
