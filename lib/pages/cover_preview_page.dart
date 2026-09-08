import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../data/services/data_storage.dart';

import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../data/services/cover_path.dart';
import '../theme/zaidang_tokens.dart';

/// 全屏浏览本地原图，支持左右切换、双指及双击缩放，单击退出。
class CoverPreviewPage extends StatefulWidget {
  const CoverPreviewPage({
    super.key,
    required this.coverImages,
    this.initialIndex = 0,
    this.supportDirectory,
  });

  /// 进入预览时获取列表快照；相对路径按 [CoverPath] 合同解析。
  final List<String> coverImages;
  final int initialIndex;
  final Future<Directory> Function()? supportDirectory;

  @override
  State<CoverPreviewPage> createState() => _CoverPreviewPageState();
}

class _CoverPreviewPageState extends State<CoverPreviewPage> {
  late final List<String> _coverImages;
  late final PageController _pageController;
  late final Future<List<String?>> _resolvedPaths;
  late int _currentIndex;
  bool _closing = false;
  StoragePin? _filePin;

  @override
  void initState() {
    super.initState();
    _coverImages = List<String>.unmodifiable(widget.coverImages);
    _currentIndex = _coverImages.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, _coverImages.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _resolvedPaths = _resolvePaths();
  }

  Future<List<String?>> _resolvePaths() async {
    String? supportPath;
    if (_coverImages.any((path) => path.isNotEmpty && !p.isAbsolute(path))) {
      try {
        final directory =
            await (widget.supportDirectory ?? getActiveDataDirectory)();
        supportPath = directory.path;
      } catch (_) {
        // 目录查询失败仅影响相对路径，绝对路径仍可浏览。
      }
    }
    final resolved = _coverImages
        .map((path) {
          if (path.isEmpty || (!p.isAbsolute(path) && supportPath == null)) {
            return null;
          }
          return CoverPath.resolve(supportPath ?? '', path);
        })
        .toList(growable: false);
    final storage = DataStorage.current;
    if (mounted && storage != null) {
      _filePin = storage.pinFiles(
        resolved.whereType<String>().where(
          (file) => p.isWithin(storage.supportDirectory.path, file),
        ),
      );
    }
    return resolved;
  }

  @override
  void dispose() {
    unawaited(_filePin?.release());
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_closing || !mounted || ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    _closing = true;
    final didPop = await Navigator.of(context).maybePop();
    if (!didPop && mounted) {
      _closing = false;
    }
  }

  Widget _dismissibleStatus({String? message}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _close,
      child: Center(
        child: message == null
            ? CircularProgressIndicator(color: ZaidangTokens.light.surface)
            : Text(
                message,
                style: TextStyle(color: ZaidangTokens.light.surface),
              ),
      ),
    );
  }

  Widget _buildGallery() {
    if (_coverImages.isEmpty) {
      return _dismissibleStatus(message: '暂无图片');
    }
    return FutureBuilder<List<String?>>(
      future: _resolvedPaths,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _dismissibleStatus();
        }
        final paths = snapshot.data!;
        return PhotoViewGallery.builder(
          itemCount: paths.length,
          pageController: _pageController,
          backgroundDecoration: BoxDecoration(color: ZaidangTokens.dark.bg),
          loadingBuilder: (context, event) => _dismissibleStatus(),
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          builder: (context, index) {
            final path = paths[index];
            if (path == null) {
              return PhotoViewGalleryPageOptions.customChild(
                child: _dismissibleStatus(message: '图片无法加载'),
                disableGestures: true,
              );
            }
            return PhotoViewGalleryPageOptions(
              imageProvider: FileImage(File(path)),
              semanticLabel: '立绘 ${index + 1}',
              initialScale: PhotoViewComputedScale.contained,
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.contained * 5,
              gestureDetectorBehavior: HitTestBehavior.opaque,
              onTapUp: (context, details, value) => _close(),
              errorBuilder: (context, error, stackTrace) =>
                  _dismissibleStatus(message: '图片无法加载'),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZaidangTokens.dark.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildGallery(),
          if (_coverImages.length > 1)
            IgnorePointer(
              child: SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: ZaidangTokens.dark.bg.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Text(
                          '${_currentIndex + 1} / ${_coverImages.length}',
                          style: TextStyle(color: ZaidangTokens.light.surface),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  tooltip: '关闭',
                  onPressed: _close,
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: ZaidangTokens.dark.bg.withValues(
                      alpha: 0.8,
                    ),
                    foregroundColor: ZaidangTokens.light.surface,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
