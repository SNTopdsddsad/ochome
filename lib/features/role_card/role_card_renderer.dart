import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as path;

import '../../data/services/data_storage.dart';

import '../../data/services/cover_path.dart';
import 'role_card_content.dart';
import 'role_card_fonts.dart';

enum RoleCardRenderFailure {
  emptyContent,
  imageUnavailable,
  contentTooLarge,
  encodingFailed,
}

class RoleCardRenderException implements Exception {
  const RoleCardRenderException(this.code, this.message);

  final RoleCardRenderFailure code;
  final String message;

  @override
  String toString() => message;
}

/// The template owns its typography and geometry, independently of app chrome.
class RoleCardRenderer {
  const RoleCardRenderer();

  Future<RoleCardDocument> prepare(
    RoleCardContent content, {
    Future<Directory> Function()? supportDirectory,
  }) async {
    if (content.isEmpty) {
      throw const RoleCardRenderException(
        RoleCardRenderFailure.emptyContent,
        '请至少选择一项有内容的资料或立绘。',
      );
    }
    final textLength =
        content.name.length +
        [...content.profile, ...content.sections].fold<int>(
          0,
          (total, entry) => total + entry.label.length + entry.value.length,
        );
    if (textLength > 120000 || content.sections.length > 500) {
      throw const RoleCardRenderException(
        RoleCardRenderFailure.contentTooLarge,
        '这次选择的内容太多，请减少部分设定后分次导出。',
      );
    }
    await RoleCardFonts.ensureLoaded();
    ui.Image? image;
    _SheetBuilder? builder;
    try {
      if (content.coverImg.isNotEmpty) {
        image = await _loadImage(content.coverImg, supportDirectory);
      }
      builder = _SheetBuilder(content, image);
      return builder.build();
    } catch (_) {
      builder?.dispose();
      image?.dispose();
      rethrow;
    }
  }

  Future<ui.Image> _loadImage(
    String coverImg,
    Future<Directory> Function()? supportDirectory,
  ) async {
    StoragePin? filePin;
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      final String filePath;
      if (path.isAbsolute(coverImg)) {
        filePath = coverImg;
      } else {
        final directory = await (supportDirectory ?? getActiveDataDirectory)();
        filePath = CoverPath.resolve(directory.path, coverImg);
      }
      final storage = DataStorage.current;
      if (storage != null &&
          path.isWithin(storage.supportDirectory.path, filePath)) {
        filePin = storage.pinFiles([filePath]);
      }
      final file = File(filePath);
      if (await file.length() > 64 * 1024 * 1024) {
        throw const RoleCardRenderException(
          RoleCardRenderFailure.imageUnavailable,
          '立绘文件过大，请更换一张较小的图片或隐藏立绘。',
        );
      }
      buffer = await ui.ImmutableBuffer.fromFilePath(filePath);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final scale = math.min(
        1.0,
        1920 / math.max(descriptor.width, descriptor.height),
      );
      codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (descriptor.width * scale).round()),
        targetHeight: math.max(1, (descriptor.height * scale).round()),
      );
      final frame = await codec.getNextFrame();
      return frame.image;
    } on RoleCardRenderException {
      rethrow;
    } catch (_) {
      throw const RoleCardRenderException(
        RoleCardRenderFailure.imageUnavailable,
        '立绘无法加载，请更换图片或在显示内容中隐藏立绘。',
      );
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
      await filePin?.release();
    }
  }
}

/// Visible line ranges, retained for content-integrity checks and accessibility.
class RoleCardTextFragment {
  const RoleCardTextFragment({
    required this.page,
    required this.firstLine,
    required this.endLine,
    required this.bounds,
  });

  final int page;
  final int firstLine;
  final int endLine;
  final Rect bounds;
}

class RoleCardTextCoverage {
  RoleCardTextCoverage({
    required this.id,
    required this.label,
    required this.value,
    required this.lineCount,
    required List<RoleCardTextFragment> fragments,
  }) : fragments = List.unmodifiable(fragments);

  final String id;
  final String label;
  final String value;
  final int lineCount;
  final List<RoleCardTextFragment> fragments;
}

class RoleCardDocument {
  RoleCardDocument._(this._pages, this._paragraphs, this._image)
    : textCoverage = List.unmodifiable([
        for (final paragraph in _paragraphs)
          if (paragraph.source != null)
            RoleCardTextCoverage(
              id: paragraph.source!.id,
              label: paragraph.source!.label,
              value: paragraph.source!.value,
              lineCount: paragraph.lines.length,
              fragments: paragraph.fragments,
            ),
      ]);

  static const Size pageSize = Size(480, 640);
  static const Size pngSize = Size(1440, 1920);
  final List<_SheetPage> _pages;
  final List<_Paragraph> _paragraphs;
  final ui.Image? _image;
  final List<RoleCardTextCoverage> textCoverage;
  bool _disposed = false;

  int get pageCount => _pages.length;

  String semanticsForPage(int page) {
    _checkPage(page);
    return [
      '角色卡，第 ${page + 1} 页，共 $pageCount 页',
      ..._pages[page].semantics,
      '崽档',
    ].join('\n');
  }

  void paintPage(Canvas canvas, int page) {
    _checkPage(page);
    canvas.save();
    canvas.clipRect(Offset.zero & pageSize);
    canvas.drawColor(_paper, BlendMode.src);
    for (final drawing in _pages[page].drawings) {
      drawing(canvas);
    }
    canvas.restore();
  }

  Future<Uint8List> renderPng(int page) async {
    _checkPage(page);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(3);
    ui.Picture? picture;
    ui.Image? raster;
    try {
      paintPage(canvas, page);
      picture = recorder.endRecording();
      raster = await picture.toImage(1440, 1920);
      final bytes = await raster.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) {
        throw const RoleCardRenderException(
          RoleCardRenderFailure.encodingFailed,
          '图片生成失败，请重试。',
        );
      }
      return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
    } finally {
      raster?.dispose();
      picture?.dispose();
      if (recorder.isRecording) recorder.endRecording().dispose();
    }
  }

  void _checkPage(int page) {
    if (_disposed) throw StateError('RoleCardDocument has been disposed.');
    RangeError.checkValidIndex(page, _pages, 'page');
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final paragraph in _paragraphs) {
      paragraph.painter.dispose();
    }
    _image?.dispose();
  }
}

const _paper = Color(0xFFF4F1E9);
const _ink = Color(0xFF223B56);
const _subtle = Color(0xFF52627A);
const _rule = Color(0xFFB7C0C8);
const _blue = Color(0xFF1B2B42);
const _lightInk = Color(0xFFF2F2EC);
const _lightSubtle = Color(0xFFC3CDDA);
const _red = Color(0xFFC2402A);
const _fontFallbacks = [
  RoleCardFonts.sansFamily,
  'Apple Color Emoji',
  'Noto Color Emoji',
  'Segoe UI Emoji',
];

class _SheetPage {
  final drawings = <void Function(Canvas)>[];
  final semantics = <String>[];
}

class _Paragraph {
  _Paragraph(this.painter, {this.source, this.headingLines = 0})
    : lines = painter.computeLineMetrics();

  final TextPainter painter;
  final RoleCardText? source;
  final int headingLines;
  final List<ui.LineMetrics> lines;
  final fragments = <RoleCardTextFragment>[];

  double lineTop(int index) =>
      index == 0 ? 0 : lines[index].baseline - lines[index].ascent;
  double lineBottom(int end) =>
      end == lines.length ? painter.height : lineTop(end);
  double heightFor(int first, int end) => lineBottom(end) - lineTop(first);

  int endFitting(int first, double height) {
    var end = first;
    while (end < lines.length && heightFor(first, end + 1) <= height + .01) {
      end++;
    }
    return end;
  }
}

class _PendingParagraph {
  _PendingParagraph(this.paragraph);
  final _Paragraph paragraph;
  int nextLine = 0;
}

class _SheetBuilder {
  _SheetBuilder(this.content, this.image);
  final RoleCardContent content;
  final ui.Image? image;
  final pages = <_SheetPage>[];
  final paragraphs = <_Paragraph>[];
  final pending = <_PendingParagraph>[];
  bool _checkedContinuationTitle = false;
  _Paragraph? _continuationTitle;

  void _discard(_Paragraph paragraph) {
    paragraphs.remove(paragraph);
    paragraph.painter.dispose();
  }

  RoleCardDocument build() {
    final first = _newPage();
    if (image != null && content.profile.isEmpty && content.sections.isEmpty) {
      _sparseMain(first);
    } else if (image != null) {
      _illustratedMain(first);
    } else {
      _textMain(first);
    }
    while (pending.isNotEmpty) {
      if (pages.length >= 300) {
        throw const RoleCardRenderException(
          RoleCardRenderFailure.contentTooLarge,
          '内容超过了单次导出的页数，请减少部分设定后分次导出。',
        );
      }
      final page = _newPage();
      _continuationHeader(page);
      final previous = pending.first;
      final previousLine = previous.nextLine;
      _flow(page, const Rect.fromLTWH(28, 108, 424, 482));
      if (pending.isNotEmpty &&
          identical(pending.first, previous) &&
          previous.nextLine == previousLine) {
        throw const RoleCardRenderException(
          RoleCardRenderFailure.contentTooLarge,
          '有一段文字无法排入卡片，请减少这次选择的内容后重试。',
        );
      }
    }
    for (var index = 0; index < pages.length; index++) {
      _footer(pages[index], index);
    }
    return RoleCardDocument._(pages, paragraphs, image);
  }

  _SheetPage _newPage() {
    final page = _SheetPage();
    pages.add(page);
    return page;
  }

  _Paragraph _paragraph(
    String text, {
    required double width,
    double size = 15,
    double height = 1.6,
    Color color = _ink,
    bool serif = false,
    FontWeight weight = FontWeight.w400,
    double spacing = 0,
    RoleCardText? source,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: serif
              ? RoleCardFonts.serifFamily
              : RoleCardFonts.sansFamily,
          fontFamilyFallback: _fontFallbacks,
          fontSize: size,
          height: height,
          color: color,
          fontWeight: weight,
          letterSpacing: spacing,
        ),
      ),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
      locale: const Locale('zh', 'CN'),
    )..layout(maxWidth: width);
    final result = _Paragraph(painter, source: source);
    paragraphs.add(result);
    return result;
  }

  _Paragraph _section(RoleCardText text, {double width = 424}) {
    final heading = TextPainter(
      text: TextSpan(
        text: text.label,
        style: const TextStyle(
          fontFamily: RoleCardFonts.sansFamily,
          fontFamilyFallback: _fontFallbacks,
          fontSize: 12,
          height: 1.6,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
      locale: const Locale('zh', 'CN'),
    )..layout(maxWidth: width);
    final headingLines = heading.computeLineMetrics().length;
    heading.dispose();
    final painter = TextPainter(
      text: TextSpan(
        style: const TextStyle(
          fontFamily: RoleCardFonts.sansFamily,
          fontFamilyFallback: _fontFallbacks,
          fontSize: 15,
          height: 1.6,
          color: _ink,
        ),
        children: [
          TextSpan(
            text: '${text.label}\n',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _subtle,
            ),
          ),
          TextSpan(text: text.value),
        ],
      ),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
      locale: const Locale('zh', 'CN'),
    )..layout(maxWidth: width);
    final result = _Paragraph(
      painter,
      source: text,
      headingLines: headingLines,
    );
    paragraphs.add(result);
    return result;
  }

  void _place(
    _SheetPage page,
    _Paragraph paragraph,
    Offset offset, {
    int first = 0,
    int? end,
  }) {
    final last = end ?? paragraph.lines.length;
    final top = paragraph.lineTop(first);
    final bounds = Rect.fromLTWH(
      offset.dx,
      offset.dy,
      paragraph.painter.width,
      paragraph.heightFor(first, last),
    );
    page.drawings.add((canvas) {
      canvas.save();
      canvas.clipRect(bounds);
      paragraph.painter.paint(canvas, offset - Offset(0, top));
      canvas.restore();
    });
    if (paragraph.source != null) {
      paragraph.fragments.add(
        RoleCardTextFragment(
          page: pages.indexOf(page),
          firstLine: first,
          endLine: last,
          bounds: bounds,
        ),
      );
      // Accessible previews include the complete selected block, including on
      // continuation pages. No hidden snapshot values reach this document.
      final source = paragraph.source!;
      page.semantics.add('${source.label}\n${source.value}');
    }
  }

  void _label(
    _SheetPage page,
    String text,
    Offset offset, {
    double width = 424,
    double size = 11,
    Color color = _subtle,
    double spacing = 1,
  }) {
    _place(
      page,
      _paragraph(
        text,
        width: width,
        size: size,
        color: color,
        spacing: spacing,
      ),
      offset,
    );
  }

  void _line(
    _SheetPage page,
    Offset start,
    Offset end, {
    Color color = _rule,
    double width = 1,
  }) {
    page.drawings.add(
      (canvas) => canvas.drawLine(
        start,
        end,
        Paint()
          ..color = color
          ..strokeWidth = width,
      ),
    );
  }

  void _art(_SheetPage page, Rect rect) {
    final artwork = image!;
    final source = Rect.fromLTWH(
      0,
      0,
      artwork.width.toDouble(),
      artwork.height.toDouble(),
    );
    final fitted = applyBoxFit(BoxFit.contain, source.size, rect.size);
    final destination = Alignment.center.inscribe(fitted.destination, rect);
    page.drawings.add(
      (canvas) => canvas.drawImageRect(
        artwork,
        source,
        destination,
        Paint()..filterQuality = FilterQuality.high,
      ),
    );
    page.semantics.add('完整立绘');
  }

  void _header(_SheetPage page) {
    var paintedName = false;
    if (content.name.isNotEmpty) {
      final source = RoleCardText(
        id: 'field.name',
        label: '名字',
        value: content.name,
      );
      final name = _paragraph(
        content.name,
        width: 302,
        size: 46,
        height: 1.2,
        serif: true,
        weight: FontWeight.w700,
        spacing: 3,
      );
      if (name.lines.length == 1 && name.painter.height <= 66) {
        final named = _Paragraph(name.painter, source: source);
        paragraphs[paragraphs.indexOf(name)] = named;
        _place(page, named, const Offset(20, 20));
        paintedName = true;
      } else {
        _discard(name);
        pending.add(_PendingParagraph(_section(source)));
      }
    }
    if (!paintedName) {
      _place(
        page,
        _paragraph(
          '人设纸',
          width: 300,
          size: 36,
          height: 1.2,
          serif: true,
          weight: FontWeight.w700,
        ),
        const Offset(20, 30),
      );
    }
    _label(page, '人设纸', const Offset(378, 37), width: 82, size: 12, spacing: 3);
    _label(
      page,
      'CHARACTER SHEET',
      const Offset(334, 59),
      width: 126,
      size: 9,
      spacing: .7,
    );
    _line(
      page,
      const Offset(20, 90),
      const Offset(460, 90),
      color: _ink,
      width: 2,
    );
  }

  void _sparseMain(_SheetPage page) {
    final graphemes = content.name.characters.toList();
    final vertical =
        graphemes.isNotEmpty &&
        graphemes.length <= 5 &&
        !content.name.contains(RegExp(r'\s'));
    final title = vertical
        ? _paragraph(
            graphemes.join('\n'),
            width: 66,
            size: 48,
            height: 1.38,
            serif: true,
            weight: FontWeight.w700,
            source: RoleCardText(
              id: 'field.name',
              label: '名字',
              value: content.name,
            ),
          )
        : null;
    if (title != null &&
        title.lines.length == graphemes.length &&
        title.painter.height <= 430) {
      _art(page, const Rect.fromLTWH(20, 20, 344, 568));
      _line(page, const Offset(381, 20), const Offset(381, 588));
      _place(page, title, const Offset(394, 30));
      _label(page, '人\n设\n纸', const Offset(417, 498), width: 22, size: 11);
    } else {
      if (title != null) _discard(title);
      if (content.name.isEmpty) {
        _art(page, const Rect.fromLTWH(20, 20, 440, 568));
      } else {
        _header(page);
        _art(page, const Rect.fromLTWH(20, 108, 440, 480));
      }
    }
  }

  void _illustratedMain(_SheetPage page) {
    _header(page);
    final hasSections = content.sections.isNotEmpty;
    final bodyHeight = hasSections ? 356.0 : 480.0;
    if (content.profile.isNotEmpty) {
      final background = Rect.fromLTWH(20, 108, 440, bodyHeight);
      page.drawings.add(
        (canvas) => canvas.drawRect(background, Paint()..color = _blue),
      );
      _art(page, Rect.fromLTWH(30, 118, 284, bodyHeight - 20));
      _profile(page, Rect.fromLTWH(328, 120, 122, bodyHeight - 24));
    } else {
      _art(page, Rect.fromLTWH(20, 108, 440, bodyHeight));
    }
    if (hasSections) {
      _mainSections(page);
    }
  }

  void _mainSections(_SheetPage page) {
    var nextSection = 0;
    // Short settings use the paired blocks from the approved setting sheet.
    // Longer paragraphs keep a single width across the main and later pages.
    if (pending.isEmpty && content.sections.length >= 2) {
      final left = _section(content.sections[0], width: 202);
      final right = _section(content.sections[1], width: 202);
      if (left.painter.height <= 110 && right.painter.height <= 110) {
        _place(page, left, const Offset(28, 480));
        _place(page, right, const Offset(250, 480));
        nextSection = 2;
      } else {
        for (final paragraph in [left, right]) {
          _discard(paragraph);
        }
      }
    }
    for (final section in content.sections.skip(nextSection)) {
      pending.add(_PendingParagraph(_section(section)));
    }
    if (nextSection == 0) {
      _flow(page, const Rect.fromLTWH(28, 480, 424, 110));
    }
  }

  void _profile(_SheetPage page, Rect rect) {
    _label(
      page,
      '基本资料',
      rect.topLeft,
      width: rect.width,
      size: 12,
      color: _lightInk,
      spacing: 2,
    );
    _line(
      page,
      rect.topLeft + const Offset(0, 28),
      rect.topLeft + const Offset(18, 28),
      color: _lightSubtle,
    );
    final slotHeight = (rect.height - 47) / content.profile.length;
    var y = rect.top + 44;
    for (final entry in content.profile) {
      _label(
        page,
        entry.label,
        Offset(rect.left, y),
        width: rect.width,
        size: 10,
        color: _lightSubtle,
        spacing: 2,
      );
      final value = _paragraph(
        entry.value,
        width: rect.width,
        size: 15,
        height: 1.4,
        color: _lightInk,
      );
      if (value.painter.height <= slotHeight - 30) {
        final selected = _Paragraph(value.painter, source: entry);
        paragraphs[paragraphs.indexOf(value)] = selected;
        _place(page, selected, Offset(rect.left, y + 21));
      } else {
        _discard(value);
        _label(
          page,
          '见续页',
          Offset(rect.left, y + 21),
          width: rect.width,
          size: 13,
          color: _lightInk,
          spacing: 0,
        );
        pending.add(_PendingParagraph(_section(entry)));
      }
      _line(
        page,
        Offset(rect.left, y + slotHeight - 9),
        Offset(rect.right, y + slotHeight - 9),
        color: const Color(0xFF4C6078),
      );
      y += slotHeight;
    }
  }

  void _textMain(_SheetPage page) {
    _header(page);
    for (final entry in [...content.profile, ...content.sections]) {
      pending.add(_PendingParagraph(_section(entry)));
    }
    _flow(page, const Rect.fromLTWH(28, 112, 424, 478));
  }

  void _continuationHeader(_SheetPage page) {
    _label(
      page,
      'CHARACTER NOTES',
      const Offset(28, 24),
      width: 280,
      size: 10,
      spacing: 2,
    );
    if (!_checkedContinuationTitle && content.name.isNotEmpty) {
      _checkedContinuationTitle = true;
      final title = _paragraph(
        content.name,
        width: 424,
        size: 29,
        height: 1.2,
        serif: true,
        weight: FontWeight.w700,
      );
      if (title.lines.length == 1) {
        _continuationTitle = title;
      } else {
        _discard(title);
      }
    }
    if (_continuationTitle case final title?) {
      _place(page, title, const Offset(28, 49));
      page.semantics.add(content.name);
    } else {
      _place(
        page,
        _paragraph(
          '设定续页',
          width: 424,
          size: 29,
          height: 1.2,
          serif: true,
          weight: FontWeight.w700,
        ),
        const Offset(28, 49),
      );
    }
    _line(
      page,
      const Offset(28, 92),
      const Offset(452, 92),
      color: _ink,
      width: 1.5,
    );
  }

  void _flow(_SheetPage page, Rect region) {
    var y = region.top;
    while (pending.isNotEmpty) {
      final next = pending.first;
      final paragraph = next.paragraph;
      var end = paragraph.endFitting(next.nextLine, region.bottom - y);
      // Keep a normal heading with its first body line. An oversized custom
      // heading still advances across full pages instead of stalling forever.
      final headingAndBody = math.min(
        paragraph.headingLines + 1,
        paragraph.lines.length,
      );
      final keepHeading = paragraph.heightFor(0, headingAndBody) <= 482
          ? headingAndBody
          : 2;
      if (end == paragraph.headingLines && end < paragraph.lines.length) {
        end--;
      }
      if (end == next.nextLine ||
          (next.nextLine == 0 &&
              end < keepHeading &&
              end < paragraph.lines.length)) {
        return;
      }
      _place(
        page,
        paragraph,
        Offset(region.left, y),
        first: next.nextLine,
        end: end,
      );
      y += paragraph.heightFor(next.nextLine, end) + 20;
      next.nextLine = end;
      if (end == paragraph.lines.length) {
        pending.removeAt(0);
      } else {
        return;
      }
    }
  }

  void _footer(_SheetPage page, int index) {
    _label(
      page,
      pages.length > 1
          ? 'ORIGINAL CHARACTER  /  ${index + 1} · ${pages.length}'
          : 'ORIGINAL CHARACTER',
      const Offset(20, 612),
      width: 380,
      size: 9,
      spacing: 1.4,
    );
    final seal = _paragraph(
      '崽档',
      width: 33,
      size: 12,
      height: 1.3,
      serif: true,
      color: _red,
      spacing: 1,
    );
    page.drawings.add((canvas) {
      canvas.save();
      canvas.translate(434, 619);
      canvas.rotate(-.07);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-18, -12, 36, 23),
          const Radius.circular(2),
        ),
        Paint()
          ..color = _red
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      seal.painter.paint(canvas, const Offset(-13, -9));
      canvas.restore();
    });
  }

  void dispose() {
    for (final paragraph in paragraphs) {
      paragraph.painter.dispose();
    }
  }
}
