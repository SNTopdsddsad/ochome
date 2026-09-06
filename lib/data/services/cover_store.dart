import 'cover_path.dart';
import 'local_file_store.dart';

export 'local_file_store.dart' show LocalStoredFile;

typedef LocalCoverFile = LocalStoredFile;

/// 立绘目录，沿用通用附件目录的备份与回滚行为。
class CoverStore extends LocalFileStore {
  CoverStore(super.supportDir) : super(directoryName: CoverPath.directoryName);
}
