/// 恢复前比较快照 `user_version` / manifest 与当前 App schema。
enum RestoreVersionDecision { proceed, refuseNewer, refuseTooOld }

class RestoreVersionGate {
  RestoreVersionGate._();

  /// v3 会 `deleteTable('role')` 再空表重建，低于此版本的备份拒绝恢复。
  static const int minSupportedSchema = 3;

  /// 任一处版本比 App 新则拒绝；任一处低于 [minSupportedSchema] 则拒绝。
  static RestoreVersionDecision compare({
    required int appSchemaVersion,
    required int sqliteUserVersion,
    int? manifestSchemaVersion,
  }) {
    final versions = <int>[sqliteUserVersion, ?manifestSchemaVersion];
    if (versions.any((version) => version > appSchemaVersion)) {
      return RestoreVersionDecision.refuseNewer;
    }
    if (versions.any((version) => version < minSupportedSchema)) {
      return RestoreVersionDecision.refuseTooOld;
    }
    return RestoreVersionDecision.proceed;
  }
}
