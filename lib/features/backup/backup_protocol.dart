import 'dart:convert';
import 'dart:math';

/// The sole decoder for cloud, job, and contents payloads. No coercion/defaults
/// at this boundary: an unknown format must never become an empty backup.
class BackupJson {
  static const maxMetadataBytes = 16 * 1024 * 1024;
  static const maxEntries = 100000;
  static const maxInteger = 9007199254740991;
  static final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );
  static final _hash = RegExp(r'^[0-9a-f]{64}$');
  static Map<String, Object?> object(Object? value) {
    if (value is! Map || value.keys.any((k) => k is! String)) {
      throw const FormatException('备份资料结构不正确');
    }
    return Map<String, Object?>.from(value);
  }

  static Map<String, Object?> decode(List<int> bytes) {
    if (bytes.isEmpty || bytes.length > maxMetadataBytes) {
      throw const FormatException('备份目录大小超出支持范围');
    }
    return object(jsonDecode(utf8.decode(bytes)));
  }

  static String string(Object? value, {bool empty = false}) {
    if (value is! String ||
        (!empty && value.isEmpty) ||
        value.length > 1000000) {
      throw const FormatException('备份文字字段不正确');
    }
    return value;
  }

  static int integer(Object? value, {int min = 0}) {
    if (value is! int || value < min || value > maxInteger) {
      throw const FormatException('备份数量字段不正确');
    }
    return value;
  }

  static bool boolean(Object? value) {
    if (value is! bool) throw const FormatException('备份状态不正确');
    return value;
  }

  static List<Object?> list(Object? value) {
    if (value is! List || value.length > maxEntries) {
      throw const FormatException('备份目录条目超出支持范围');
    }
    return value;
  }

  static String uuid(Object? value) {
    final result = string(value);
    if (!_uuid.hasMatch(result)) throw const FormatException('备份标识不正确');
    return result;
  }

  static String hash(Object? value) {
    final result = string(value);
    if (!_hash.hasMatch(result)) throw const FormatException('备份校验值不正确');
    return result;
  }

  static DateTime time(Object? value) {
    final raw = string(value);
    final parsed = DateTime.tryParse(raw);
    final parts = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,6})?Z$',
    ).firstMatch(raw);
    if (parts == null ||
        parsed == null ||
        !parsed.isUtc ||
        parsed.year != int.parse(parts.group(1)!) ||
        parsed.month != int.parse(parts.group(2)!) ||
        parsed.day != int.parse(parts.group(3)!) ||
        parsed.hour != int.parse(parts.group(4)!) ||
        parsed.minute != int.parse(parts.group(5)!) ||
        parsed.second != int.parse(parts.group(6)!)) {
      throw const FormatException('备份时间不正确');
    }
    return parsed;
  }

  static String logicalPath(Object? value) {
    final path = string(value);
    final parts = path.split('/');
    if (parts.length != 2 ||
        !{'covers', 'role_assets'}.contains(parts[0]) ||
        parts[1].isEmpty ||
        parts[1].startsWith('.') ||
        path.contains('\\') ||
        path.contains(RegExp(r'[\x00-\x1f\x7f]'))) {
      throw const FormatException('备份文件路径不安全');
    }
    return path;
  }

  static void format(Map<String, Object?> json, int expected) {
    if (integer(json['format']) != expected) {
      throw const FormatException('不支持这份备份的格式，请更新 App');
    }
  }
}

String newBackupId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class BackupDescriptor {
  const BackupDescriptor({
    required this.snapshotId,
    required this.writerId,
    required this.basePath,
    required this.createdAtUtc,
    required this.appVersion,
    required this.schemaVersion,
    required this.roleCount,
    required this.revisionCount,
    required this.assetCount,
    required this.fileCount,
    required this.totalBytes,
    required this.manifestSha256,
    required this.commitSha256,
    required this.deviceName,
    this.accountSequence,
    this.completedAtUtc,
  });
  final String snapshotId,
      writerId,
      basePath,
      appVersion,
      manifestSha256,
      commitSha256,
      deviceName;
  final DateTime createdAtUtc;
  final DateTime? completedAtUtc;
  final int schemaVersion,
      roleCount,
      revisionCount,
      assetCount,
      fileCount,
      totalBytes;
  final int? accountSequence;
  Map<String, Object?> toJson() => {
    'snapshotId': snapshotId,
    'writerId': writerId,
    'basePath': basePath,
    'createdAtUtc': createdAtUtc.toIso8601String(),
    'appVersion': appVersion,
    'schemaVersion': schemaVersion,
    'roleCount': roleCount,
    'revisionCount': revisionCount,
    'assetCount': assetCount,
    'fileCount': fileCount,
    'totalBytes': totalBytes,
    'manifestSha256': manifestSha256,
    'commitSha256': commitSha256,
    'deviceName': deviceName,
    if (accountSequence != null) 'accountSequence': accountSequence,
    if (completedAtUtc != null)
      'completedAtUtc': completedAtUtc!.toIso8601String(),
  };
  factory BackupDescriptor.fromJson(Object? value) {
    final j = BackupJson.object(value);
    final snapshot = BackupJson.uuid(j['snapshotId']);
    final writer = BackupJson.uuid(j['writerId']);
    final base = BackupJson.string(j['basePath']);
    if (base != 'writers/$writer/snapshots/$snapshot') {
      throw const FormatException('备份来源路径不匹配');
    }
    return BackupDescriptor(
      snapshotId: snapshot,
      writerId: writer,
      basePath: base,
      createdAtUtc: BackupJson.time(j['createdAtUtc']),
      appVersion: BackupJson.string(j['appVersion']),
      schemaVersion: BackupJson.integer(j['schemaVersion'], min: 1),
      roleCount: BackupJson.integer(j['roleCount']),
      revisionCount: BackupJson.integer(j['revisionCount']),
      assetCount: BackupJson.integer(j['assetCount']),
      fileCount: BackupJson.integer(j['fileCount']),
      totalBytes: BackupJson.integer(j['totalBytes']),
      manifestSha256: BackupJson.hash(j['manifestSha256']),
      commitSha256: BackupJson.hash(j['commitSha256']),
      deviceName: BackupJson.string(j['deviceName']),
      accountSequence: j['accountSequence'] == null
          ? null
          : BackupJson.integer(j['accountSequence'], min: 1),
      completedAtUtc: j['completedAtUtc'] == null
          ? null
          : BackupJson.time(j['completedAtUtc']),
    );
  }
}

class SnapshotSummary {
  const SnapshotSummary({
    required this.roleCount,
    required this.revisionCount,
    required this.customAttributeCount,
    required this.coverCount,
    required this.assetCount,
    required this.originalFileCount,
    required this.logicalDataBytes,
    required this.assetCountsByKind,
    this.fileSizesComplete = true,
  });
  final int roleCount,
      revisionCount,
      customAttributeCount,
      coverCount,
      assetCount,
      originalFileCount,
      logicalDataBytes;
  final Map<String, int> assetCountsByKind;
  final bool fileSizesComplete;
  int? get knownLogicalDataBytes => fileSizesComplete ? logicalDataBytes : null;
  Map<String, Object?> toJson() => {
    'roleCount': roleCount,
    'revisionCount': revisionCount,
    'customAttributeCount': customAttributeCount,
    'coverCount': coverCount,
    'assetCount': assetCount,
    'originalFileCount': originalFileCount,
    'logicalDataBytes': logicalDataBytes,
    'assetCountsByKind': assetCountsByKind,
    if (!fileSizesComplete) 'fileSizesComplete': false,
  };
  factory SnapshotSummary.fromJson(Object? value) {
    final j = BackupJson.object(value);
    final kinds = BackupJson.object(j['assetCountsByKind']);
    if (kinds.keys.toSet().difference({
      'image',
      'video',
      'audio',
      'document',
    }).isNotEmpty) {
      throw const FormatException('未知资产种类');
    }
    return SnapshotSummary(
      roleCount: BackupJson.integer(j['roleCount']),
      revisionCount: BackupJson.integer(j['revisionCount']),
      customAttributeCount: BackupJson.integer(j['customAttributeCount']),
      coverCount: BackupJson.integer(j['coverCount']),
      assetCount: BackupJson.integer(j['assetCount']),
      originalFileCount: BackupJson.integer(j['originalFileCount']),
      logicalDataBytes: BackupJson.integer(j['logicalDataBytes']),
      fileSizesComplete: j['fileSizesComplete'] == null
          ? true
          : BackupJson.boolean(j['fileSizesComplete']),
      assetCountsByKind: Map.unmodifiable({
        for (final kind in ['image', 'video', 'audio', 'document'])
          kind: BackupJson.integer(kinds[kind]),
      }),
    );
  }
}

class SnapshotRole {
  const SnapshotRole({
    required this.roleId,
    required this.name,
    required this.customAttributeNamesInOrder,
    required this.revisionCount,
    required this.assetIds,
    this.coverRelativePath,
  });
  final int roleId, revisionCount;
  final String name;
  final List<String> customAttributeNamesInOrder;
  final String? coverRelativePath;
  final List<int> assetIds;
  Map<String, Object?> toJson() => {
    'roleId': roleId,
    'name': name,
    'customAttributeNamesInOrder': customAttributeNamesInOrder,
    'revisionCount': revisionCount,
    'coverRelativePath': coverRelativePath,
    'assetIds': assetIds,
  };
  factory SnapshotRole.fromJson(Object? value) {
    final j = BackupJson.object(value);
    return SnapshotRole(
      roleId: BackupJson.integer(j['roleId'], min: 1),
      name: BackupJson.string(j['name']),
      revisionCount: BackupJson.integer(j['revisionCount']),
      customAttributeNamesInOrder: List.unmodifiable(
        BackupJson.list(j['customAttributeNamesInOrder'])
            .map(BackupJson.string),
      ),
      coverRelativePath: j['coverRelativePath'] == null
          ? null
          : BackupJson.logicalPath(j['coverRelativePath']),
      assetIds: List.unmodifiable(
        BackupJson.list(j['assetIds'])
            .map((id) => BackupJson.integer(id, min: 1)),
      ),
    );
  }
}

class SnapshotContentFile {
  const SnapshotContentFile({
    required this.relativePath,
    required this.objectId,
    required this.roleIds,
    required this.displayName,
    required this.kind,
    required this.bytes,
    this.assetId,
    this.sizeKnown = true,
  });
  final String relativePath, objectId, displayName, kind;
  final List<int> roleIds;
  final int bytes;
  final int? assetId;
  final bool sizeKnown;
  int? get knownBytes => sizeKnown ? bytes : null;
  Map<String, Object?> toJson() => {
    'relativePath': relativePath,
    'objectId': objectId,
    'roleIds': roleIds,
    'assetId': assetId,
    'displayName': displayName,
    'kind': kind,
    'bytes': bytes,
    if (!sizeKnown) 'sizeKnown': false,
  };
  factory SnapshotContentFile.fromJson(Object? value) {
    final j = BackupJson.object(value);
    final kind = BackupJson.string(j['kind']);
    if (!{'cover', 'image', 'video', 'audio', 'document'}.contains(kind)) {
      throw const FormatException('未知备份文件种类');
    }
    return SnapshotContentFile(
      relativePath: BackupJson.logicalPath(j['relativePath']),
      objectId: BackupJson.uuid(j['objectId']),
      roleIds: List.unmodifiable(
        BackupJson.list(j['roleIds'])
            .map((id) => BackupJson.integer(id, min: 1)),
      ),
      assetId: j['assetId'] == null
          ? null
          : BackupJson.integer(j['assetId'], min: 1),
      displayName: BackupJson.string(j['displayName']),
      kind: kind,
      bytes: BackupJson.integer(j['bytes']),
      sizeKnown: j['sizeKnown'] == null
          ? true
          : BackupJson.boolean(j['sizeKnown']),
    );
  }
}

class SnapshotContents {
  const SnapshotContents({
    required this.snapshotId,
    required this.schemaVersion,
    required this.summary,
    required this.roles,
    required this.files,
  });
  final String snapshotId;
  final int schemaVersion;
  final SnapshotSummary summary;
  final List<SnapshotRole> roles;
  final List<SnapshotContentFile> files;
  List<SnapshotRole> rolePage({int offset = 0, int limit = 50}) =>
      roles.skip(offset).take(limit).toList(growable: false);
  List<SnapshotContentFile> filePage({
    int? roleId,
    int offset = 0,
    int limit = 50,
  }) => files
      .where((f) => roleId == null || f.roleIds.contains(roleId))
      .skip(offset)
      .take(limit)
      .toList(growable: false);
  Map<String, Object?> toJson() => {
    'format': 1,
    'snapshotId': snapshotId,
    'schemaVersion': schemaVersion,
    'summary': summary.toJson(),
    'roles': roles.map((r) => r.toJson()).toList(),
    'files': files.map((f) => f.toJson()).toList(),
  };
  factory SnapshotContents.fromJson(Object? value) {
    final j = BackupJson.object(value);
    BackupJson.format(j, 1);
    final result = SnapshotContents(
      snapshotId: BackupJson.uuid(j['snapshotId']),
      schemaVersion: BackupJson.integer(j['schemaVersion'], min: 1),
      summary: SnapshotSummary.fromJson(j['summary']),
      roles: List.unmodifiable(
        BackupJson.list(j['roles']).map(SnapshotRole.fromJson),
      ),
      files: List.unmodifiable(
        BackupJson.list(j['files']).map(SnapshotContentFile.fromJson),
      ),
    );
    final roleIds = result.roles.map((r) => r.roleId).toSet();
    if (roleIds.length != result.roles.length ||
        result.files.map((f) => f.relativePath).toSet().length !=
            result.files.length ||
        result.summary.roleCount != result.roles.length ||
        result.summary.originalFileCount != result.files.length ||
        result.files.any(
          (f) =>
              f.roleIds.isEmpty || f.roleIds.any((id) => !roleIds.contains(id)),
        )) {
      throw const FormatException('备份目录数量或角色引用不一致');
    }
    final covers = result.files.where((file) => file.kind == 'cover').toList();
    final assets = result.files.where((file) => file.kind != 'cover').toList();
    if (result.summary.revisionCount !=
            result.roles.fold<int>(0, (n, role) => n + role.revisionCount) ||
        result.summary.customAttributeCount !=
            result.roles.fold<int>(
              0,
              (n, role) => n + role.customAttributeNamesInOrder.length,
            ) ||
        result.summary.coverCount != covers.length ||
        result.summary.assetCount != assets.length ||
        assets.any(
          (file) =>
              file.assetId == null ||
              file.roleIds.length != 1 ||
              !file.relativePath.startsWith('role_assets/'),
        ) ||
        assets.map((file) => file.assetId).toSet().length != assets.length ||
        covers.any(
          (file) =>
              file.assetId != null ||
              !file.relativePath.startsWith('covers/') ||
              (file.sizeKnown && file.bytes <= 0),
        ) ||
        result.summary.fileSizesComplete !=
            result.files.every((file) => file.sizeKnown)) {
      throw const FormatException('备份目录统计不一致');
    }
    for (final kind in ['image', 'video', 'audio', 'document']) {
      if (result.summary.assetCountsByKind[kind] !=
          assets.where((file) => file.kind == kind).length) {
        throw const FormatException('备份资产分类统计不一致');
      }
    }
    for (final role in result.roles) {
      final owned = assets
          .where((file) => file.roleIds.single == role.roleId)
          .map((file) => file.assetId!)
          .toSet();
      if (owned.length != role.assetIds.length ||
          !owned.containsAll(role.assetIds) ||
          (role.coverRelativePath != null &&
              !covers.any(
                (file) =>
                    file.relativePath == role.coverRelativePath &&
                    file.roleIds.contains(role.roleId),
              ))) {
        throw const FormatException('备份角色与文件归属不一致');
      }
    }
    for (final cover in covers) {
      final owners = result.roles
          .where((role) => role.coverRelativePath == cover.relativePath)
          .map((role) => role.roleId)
          .toSet();
      if (owners.length != cover.roleIds.length ||
          !owners.containsAll(cover.roleIds)) {
        throw const FormatException('备份立绘与角色归属不一致');
      }
    }
    return result;
  }
}

class SnapshotFileDigest {
  const SnapshotFileDigest({
    required this.file,
    required this.bytes,
    required this.sha256,
  });
  final String file, sha256;
  final int bytes;
  Map<String, Object?> toJson() => {
    'file': file,
    'bytes': bytes,
    'sha256': sha256,
  };
  factory SnapshotFileDigest.fromJson(Object? value, String expected) {
    final j = BackupJson.object(value);
    if (j['file'] != expected) throw const FormatException('备份文件名不匹配');
    final bytes = BackupJson.integer(j['bytes'], min: 1);
    if (expected == 'contents.json' && bytes > BackupJson.maxMetadataBytes) {
      throw const FormatException('备份内容目录过大');
    }
    return SnapshotFileDigest(
      file: expected,
      bytes: bytes,
      sha256: BackupJson.hash(j['sha256']),
    );
  }
}

class SnapshotFile {
  const SnapshotFile({
    required this.kind,
    required this.relativePath,
    required this.objectId,
    required this.bytes,
    required this.sha256,
  });
  final String kind, relativePath, objectId, sha256;
  final int bytes;
  String objectPath(String writerId) => 'writers/$writerId/objects/$objectId';
  Map<String, Object?> toJson() => {
    'kind': kind,
    'relativePath': relativePath,
    'objectId': objectId,
    'bytes': bytes,
    'sha256': sha256,
  };
  factory SnapshotFile.fromJson(Object? value) {
    final j = BackupJson.object(value);
    final kind = BackupJson.string(j['kind']);
    final path = BackupJson.logicalPath(j['relativePath']);
    if ((kind != 'cover' && kind != 'asset') ||
        (kind == 'cover') != path.startsWith('covers/')) {
      throw const FormatException('备份文件类型与路径不一致');
    }
    return SnapshotFile(
      kind: kind,
      relativePath: path,
      objectId: BackupJson.uuid(j['objectId']),
      bytes: BackupJson.integer(j['bytes'], min: kind == 'cover' ? 1 : 0),
      sha256: BackupJson.hash(j['sha256']),
    );
  }
}

class SnapshotManifest {
  const SnapshotManifest({
    required this.snapshotId,
    required this.writerId,
    required this.writerSequence,
    required this.createdAtUtc,
    required this.appVersion,
    required this.schemaVersion,
    required this.deviceLabel,
    required this.database,
    required this.contents,
    required this.files,
    required this.summary,
  });
  final String snapshotId, writerId, appVersion, deviceLabel;
  final int writerSequence, schemaVersion;
  final DateTime createdAtUtc;
  final SnapshotFileDigest database, contents;
  final List<SnapshotFile> files;
  final Map<String, int> summary;
  String get basePath => 'writers/$writerId/snapshots/$snapshotId';
  Map<String, Object?> toJson() => {
    'format': 3,
    'snapshotId': snapshotId,
    'writerId': writerId,
    'writerSequence': writerSequence,
    'createdAtUtc': createdAtUtc.toIso8601String(),
    'appVersion': appVersion,
    'schemaVersion': schemaVersion,
    'requiredFeatures': <String>[],
    'deviceLabel': deviceLabel,
    'database': database.toJson(),
    'contents': contents.toJson(),
    'files': files.map((f) => f.toJson()).toList(),
    'summary': summary,
  };
  factory SnapshotManifest.fromJson(Object? value) {
    final j = BackupJson.object(value);
    BackupJson.format(j, 3);
    if (BackupJson.list(j['requiredFeatures']).isNotEmpty) {
      throw const FormatException('此备份需要更新版本的 App');
    }
    final rawSummary = BackupJson.object(j['summary']);
    final files = BackupJson.list(j['files'])
        .map(SnapshotFile.fromJson)
        .toList();
    final objects = <String, String>{};
    for (final file in files) {
      final key = '${file.sha256}:${file.bytes}';
      if (objects.containsKey(file.objectId) && objects[file.objectId] != key) {
        throw const FormatException('共享文件摘要不一致');
      }
      objects[file.objectId] = key;
    }
    if (files.map((f) => f.relativePath).toSet().length != files.length) {
      throw const FormatException('备份含有重复文件路径');
    }
    final result = SnapshotManifest(
      snapshotId: BackupJson.uuid(j['snapshotId']),
      writerId: BackupJson.uuid(j['writerId']),
      writerSequence: BackupJson.integer(j['writerSequence'], min: 1),
      createdAtUtc: BackupJson.time(j['createdAtUtc']),
      appVersion: BackupJson.string(j['appVersion']),
      schemaVersion: BackupJson.integer(j['schemaVersion'], min: 1),
      deviceLabel: BackupJson.string(j['deviceLabel']),
      database: SnapshotFileDigest.fromJson(j['database'], 'database.sqlite'),
      contents: SnapshotFileDigest.fromJson(j['contents'], 'contents.json'),
      files: List.unmodifiable(files),
      summary: Map.unmodifiable({
        for (final key in [
          'roleCount',
          'revisionCount',
          'assetCount',
          'fileCount',
          'totalBytes',
        ])
          key: BackupJson.integer(rawSummary[key]),
      }),
    );
    if (result.summary['fileCount'] != files.length ||
        result.summary['totalBytes'] !=
            result.database.bytes + files.fold<int>(0, (n, f) => n + f.bytes)) {
      throw const FormatException('备份总量与文件清单不一致');
    }
    return result;
  }
}

class SnapshotCommit {
  const SnapshotCommit({
    required this.snapshotId,
    required this.writerId,
    required this.writerSequence,
    required this.manifestBytes,
    required this.manifestSha256,
  });
  final String snapshotId, writerId, manifestSha256;
  final int writerSequence, manifestBytes;
  Map<String, Object?> toJson() => {
    'format': 3,
    'snapshotId': snapshotId,
    'writerId': writerId,
    'writerSequence': writerSequence,
    'manifestBytes': manifestBytes,
    'manifestSha256': manifestSha256,
  };
  factory SnapshotCommit.fromJson(Object? value) {
    final j = BackupJson.object(value);
    BackupJson.format(j, 3);
    final length = BackupJson.integer(j['manifestBytes'], min: 1);
    if (length > BackupJson.maxMetadataBytes) {
      throw const FormatException('备份清单过大');
    }
    return SnapshotCommit(
      snapshotId: BackupJson.uuid(j['snapshotId']),
      writerId: BackupJson.uuid(j['writerId']),
      writerSequence: BackupJson.integer(j['writerSequence'], min: 1),
      manifestBytes: length,
      manifestSha256: BackupJson.hash(j['manifestSha256']),
    );
  }
}
