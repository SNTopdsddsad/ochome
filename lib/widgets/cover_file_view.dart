import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../data/services/data_storage.dart';

import '../data/services/cover_path.dart';

/// 按 [CoverPath] 合同显示立绘：相对路径拼沙盒，绝对路径直接读，缺文件走空态。
class CoverFileView extends StatelessWidget {
  const CoverFileView({
    super.key,
    required this.coverImg,
    required this.placeholder,
    this.fit = BoxFit.cover,
    this.supportDirectory,
  });

  final String coverImg;
  final Widget placeholder;
  final BoxFit fit;
  final Future<Directory> Function()? supportDirectory;

  Future<Directory> _supportDir() {
    final lookup = supportDirectory;
    if (lookup != null) {
      return lookup();
    }
    return getActiveDataDirectory();
  }

  /// 立绘文件是否可读（路径非空且文件存在）。相对路径需 [supportDirectory]。
  ///
  /// 供页面判断「有可读立绘」：预览入口、是否出现「更换」都取决于此。
  static Future<bool> exists(
    String coverImg, {
    Future<Directory> Function()? supportDirectory,
  }) async {
    if (coverImg.isEmpty) {
      return false;
    }
    if (p.isAbsolute(coverImg)) {
      return File(coverImg).existsSync();
    }
    final lookup = supportDirectory;
    final dir = await (lookup != null ? lookup() : getActiveDataDirectory());
    return File(CoverPath.resolve(dir.path, coverImg)).existsSync();
  }

  @override
  Widget build(BuildContext context) {
    if (coverImg.isEmpty) {
      return placeholder;
    }
    if (p.isAbsolute(coverImg)) {
      return _fileOrPlaceholder(File(coverImg));
    }
    return FutureBuilder<Directory>(
      future: _supportDir(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return placeholder;
        }
        return _fileOrPlaceholder(
          File(CoverPath.resolve(snapshot.data!.path, coverImg)),
        );
      },
    );
  }

  Widget _fileOrPlaceholder(File file) {
    if (!file.existsSync()) {
      return placeholder;
    }
    // DecorationImage paints into the parent box. Image.file uses the file's
    // pixel size, so a 立绘 narrower than the screen leaves side gaps.
    return DecoratedBox(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: FileImage(file),
          fit: fit,
          alignment: Alignment.center,
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}
