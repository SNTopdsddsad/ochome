import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers/app_database_provider.dart';
import '../data/providers/icloud_backup_provider.dart';
import '../data/providers/roles_provider.dart';
import '../data/services/backup_exceptions.dart';
import '../data/services/backup_manifest.dart';
import '../data/services/icloud_backup_service.dart';
import '../data/services/icloud_container.dart';
import '../data/services/restore_progress.dart';
import '../theme/zaidang_tokens.dart';
import '../widgets/zaidang_confirm_dialog.dart';
import '../widgets/zaidang_snack_bar.dart';

/// 手动备份 / 恢复。非 Apple 平台只展示不可用说明。
class BackupRestorePage extends ConsumerStatefulWidget {
  const BackupRestorePage({super.key, this.icloudSupported});

  /// 测试可强制成 Android 不可用态；正式运行看 [ICloudContainer.platformSupported]。
  final bool? icloudSupported;

  @override
  ConsumerState<BackupRestorePage> createState() => _BackupRestorePageState();
}

class _BackupRestorePageState extends ConsumerState<BackupRestorePage> {
  bool _busy = false;
  String? _progress;
  double? _progressFraction;
  bool? _available;
  BackupManifest? _manifest;
  List<String> _remoteFiles = const [];
  String? _statusError;

  bool get _supported =>
      widget.icloudSupported ?? ICloudContainer.platformSupported;

  @override
  void initState() {
    super.initState();
    if (_supported) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reloadStatus());
    }
  }

  Future<void> _reloadStatus() async {
    if (!_supported) {
      return;
    }
    try {
      final status = await ref.read(iCloudBackupServiceProvider).status();
      if (!mounted) {
        return;
      }
      setState(() {
        _available = status.available;
        _manifest = status.manifest;
        _remoteFiles = status.remoteFiles;
        _statusError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusError = '$error';
      });
    }
  }

  Future<void> _backup() async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _progress = '正在备份…';
    });
    try {
      final service = ref.read(iCloudBackupServiceProvider);
      final database = ref.read(appDatabaseProvider);
      final manifest = await service.backup(
        database: database,
        onProgress: (message) {
          if (mounted) {
            setState(() => _progress = message);
          }
        },
      );
      if (!mounted) {
        return;
      }
      setState(() => _manifest = manifest);
      _snack(
        '已备份到 iCloud。换机后可直接恢复；「保存到文件」只是额外拷贝',
        tone: ZaidangSnackBarTone.success,
      );
    } on BackupException catch (error) {
      _snack(error.userMessage, tone: ZaidangSnackBarTone.error);
    } catch (error) {
      _snack('备份失败：$error', tone: ZaidangSnackBarTone.error);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
          _progressFraction = null;
        });
        await _reloadStatus();
      }
    }
  }

  Future<void> _restore() async {
    if (_busy) {
      return;
    }
    final container = ProviderScope.containerOf(context, listen: false);
    final service = container.read(iCloudBackupServiceProvider);
    RestorePlan? inspection;
    setState(() {
      _busy = true;
      _progress = RestoreProgress.checking().message;
      _progressFraction = RestoreProgress.checking().fraction;
    });
    try {
      inspection = await service.inspectBackup();
      if (!mounted) {
        await inspection.dispose();
        return;
      }
      setState(() {
        _busy = false;
        _progress = null;
      });
      final confirmed = await _confirmRestore();
      if (confirmed != true || !mounted) {
        await inspection.dispose();
        return;
      }
      setState(() {
        _busy = true;
        _progress = '正在恢复…';
      });
      final plan = await service
          .prepareRestore(
            inspection: inspection,
            onProgress: (progress) {
              if (mounted) {
                setState(() {
                  _progress = progress.message;
                  _progressFraction = progress.fraction;
                });
              }
            },
          )
          .timeout(
            const Duration(minutes: 20),
            onTimeout: () =>
                throw const RestoreFailedException('恢复超时。请检查网络后重试'),
          );
      inspection = null;
      if (mounted) {
        setState(() {
          _progress = RestoreProgress.writing().message;
          _progressFraction = 1;
        });
      }
      await container.read(appDatabaseProvider).close();
      try {
        await service.commitRestore(plan);
      } catch (_) {
        container.invalidate(appDatabaseProvider);
        rethrow;
      }
      container.invalidate(appDatabaseProvider);
      container.invalidate(rolesProvider);
      imageCache.clear();
      imageCache.clearLiveImages();
      if (!mounted) {
        return;
      }
      _snack('已从 iCloud 恢复', tone: ZaidangSnackBarTone.success);
    } on BackupException catch (error) {
      await inspection?.dispose();
      _snack(error.userMessage, tone: ZaidangSnackBarTone.error);
    } catch (error) {
      await inspection?.dispose();
      _snack('恢复失败：$error', tone: ZaidangSnackBarTone.error);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
          _progressFraction = null;
        });
        await _reloadStatus();
      }
    }
  }

  Future<void> _exportToDrive() async {
    if (_busy) {
      return;
    }
    try {
      await ref.read(iCloudContainerProvider).exportToDrive();
    } on BackupException catch (error) {
      _snack(error.userMessage, tone: ZaidangSnackBarTone.error);
    } catch (error) {
      _snack('无法打开文件：$error', tone: ZaidangSnackBarTone.error);
    }
  }

  Future<bool> _confirmRestore() {
    return showZaidangConfirmDialog(
      context: context,
      title: '用云端备份替换本机内容？',
      body: '本机的角色资料、设定历史、立绘和资产都会被 iCloud 备份替换。',
      consequence: '这次替换无法撤销。',
      cancelLabel: '先不恢复',
      cancelSemanticLabel: '先不恢复，保留本机内容',
      confirmLabel: '覆盖恢复',
      showSparkle: false,
    );
  }

  void _snack(
    String message, {
    ZaidangSnackBarTone tone = ZaidangSnackBarTone.info,
  }) {
    if (!mounted) {
      return;
    }
    showZaidangSnackBar(context, message, tone: tone);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ZaidangTokens.of(context);
    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(title: const Text('备份与恢复')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            if (!_supported)
              Text(
                'iCloud 备份仅在 iPhone 和 Mac 上可用',
                style: TextStyle(color: tokens.inkSecondary, fontSize: 14),
              )
            else ...[
              Text(
                _statusCopy(),
                style: TextStyle(color: tokens.ink, fontSize: 14),
              ),
              if (_busy) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(value: _progressFraction),
                if (_progress != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _progress!,
                    style: TextStyle(color: tokens.inkSecondary, fontSize: 13),
                  ),
                ],
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy || _available == false ? null : _backup,
                child: const Text('备份到 iCloud'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _busy || _available == false ? null : _restore,
                style: OutlinedButton.styleFrom(
                  foregroundColor: tokens.ink,
                  side: BorderSide(color: tokens.border),
                ),
                child: const Text('从 iCloud 恢复'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _busy || _available == false ? null : _exportToDrive,
                style: OutlinedButton.styleFrom(
                  foregroundColor: tokens.ink,
                  side: BorderSide(color: tokens.border),
                ),
                child: const Text('保存到文件'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _statusCopy() {
    if (_statusError != null) {
      return _statusError!;
    }
    if (_available == false) {
      return '未登录 iCloud，或 iCloud 云盘不可用。请在系统设置里打开 iCloud 云盘后再试。';
    }
    const location =
        '备份在 App 专用 iCloud 容器里，换机后可直接恢复。icloud.com 通常看不到这个文件夹。「保存到文件」只是额外拷贝，不能用来恢复。';
    final files = _remoteFiles.where((name) => name != '崽档备份.txt').toList();
    final fileLine = files.isEmpty ? '' : ' 云端已有：${files.join('、')}。';
    final createdAt = _manifest?.createdAt;
    if (createdAt == null) {
      return '还没有 iCloud 备份。$location';
    }
    return '上次备份：${_formatTime(createdAt)}。$fileLine$location';
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}
