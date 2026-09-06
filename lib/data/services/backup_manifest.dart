class BackupFileEntry {
  const BackupFileEntry({required this.file, required this.bytes});

  final String file;
  final int bytes;

  Map<String, Object?> toJson() => {'file': file, 'bytes': bytes};

  factory BackupFileEntry.fromJson(Map<String, Object?> json) {
    return BackupFileEntry(
      file: json['file'] as String? ?? '',
      bytes: (json['bytes'] as num?)?.toInt() ?? 0,
    );
  }
}

typedef CoverManifestEntry = BackupFileEntry;

class BackupManifest {
  const BackupManifest({
    required this.format,
    required this.schemaVersion,
    required this.appVersion,
    required this.createdAt,
    required this.covers,
    this.assets = const [],
  });

  static const int formatVersion = 2;

  final int format;
  final int schemaVersion;
  final String appVersion;
  final DateTime createdAt;
  final List<CoverManifestEntry> covers;
  final List<BackupFileEntry> assets;

  Map<String, Object?> toJson() => {
    'format': format,
    'schemaVersion': schemaVersion,
    'appVersion': appVersion,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'covers': [for (final cover in covers) cover.toJson()],
    'assets': [for (final asset in assets) asset.toJson()],
  };

  factory BackupManifest.fromJson(Map<String, Object?> json) {
    final rawCovers = json['covers'];
    final rawAssets = json['assets'];
    return BackupManifest(
      format: (json['format'] as num?)?.toInt() ?? formatVersion,
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 0,
      appVersion: json['appVersion'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      covers: [
        if (rawCovers is List)
          for (final item in rawCovers)
            if (item is Map)
              CoverManifestEntry.fromJson(Map<String, Object?>.from(item)),
      ],
      assets: [
        if (rawAssets is List)
          for (final item in rawAssets)
            if (item is Map)
              BackupFileEntry.fromJson(Map<String, Object?>.from(item)),
      ],
    );
  }
}
