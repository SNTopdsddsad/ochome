import 'package:path/path.dart' as p;

/// Editable display name; renaming never changes the stored file path.
class RoleAssetName {
  factory RoleAssetName({required String name, required String relativePath}) {
    final storedExtension = p.extension(relativePath);
    final displayExtension = p.extension(name);
    final hasMatchingExtension =
        storedExtension.isNotEmpty &&
        displayExtension.toLowerCase() == storedExtension.toLowerCase();
    return RoleAssetName._(
      hasMatchingExtension ? p.withoutExtension(name) : name,
      hasMatchingExtension ? displayExtension : storedExtension,
    );
  }

  const RoleAssetName._(this.baseName, this.extension);

  final String baseName;
  final String extension;

  static String? validateBaseName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return '请输入资产名称';
    if (name == '.' || name == '..') return '名称不能是 . 或 ..';
    if (RegExp(r'[/\\]').hasMatch(name)) return '名称不能包含 / 或 \\';
    if (RegExp(r'[\x00-\x1f\x7f-\x9f]').hasMatch(value ?? '')) {
      return '名称不能包含换行或控制字符';
    }
    return null;
  }

  String renamed(String value) {
    final error = validateBaseName(value);
    if (error != null) throw FormatException(error);
    return '${value.trim()}$extension';
  }
}
