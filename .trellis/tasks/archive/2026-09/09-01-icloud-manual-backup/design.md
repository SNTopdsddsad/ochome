# Design: iCloud 手动备份与恢复

## Architecture

本地 Drift 仍是运行时唯一数据源。iCloud 只存 **手动快照**，不参与日常读写。

```
RoleListPage → BackupRestorePage
                    │
                    ▼
            ICloudBackupService  (Dart)
                    │
        ┌───────────┼───────────┐
        ▼           ▼           ▼
  Snapshotter   CoverStore   ICloudContainer
  (checkpoint   (相对路径    (平台通道，
   sqlite)       解析)        iOS/macOS)
```

- **Snapshotter**：对活库 `PRAGMA wal_checkpoint(FULL)`，把 sqlite 拷到临时文件，不上传 WAL/SHM，也不把 Application Support 里的活库路径指到 ubiquity。
- **CoverStore**：选图仍复制到 `support/covers/`，库里只存相对路径 `covers/<id><ext>`。展示时 `File(p.join(support.path, relative))`。
- **ICloudContainer**：薄平台通道（Swift）。不把活库交给第三方 iCloud 插件直接 watch。插件若维护差，用 MethodChannel 包 `NSFileManager.url(forUbiquityContainerIdentifier:)` + `NSFileCoordinator`。

Android：`ICloudContainer` 实现为「不可用」，UI 走 R1。

## Backup package (one latest slot)

Ubiquity container 内固定目录（覆盖，不按日期开新文件夹）：

```
ochome-backup/
  manifest.json
  ochome.sqlite
  covers/<filename>    # 原图，与本地文件名一致
```

`manifest.json` 合同：

```json
{
  "format": 1,
  "schemaVersion": 5,
  "appVersion": "1.0.0+1",
  "createdAt": "2026-09-01T12:00:00Z",
  "covers": [{ "file": "covers/123.jpg", "bytes": 1048576 }]
}
```

- `schemaVersion` 必须与快照 sqlite 的 `PRAGMA user_version` 一致。
- 恢复时 **先读 manifest**；没有 manifest 再只读打开 sqlite 读 `user_version`。任一处显示备份比 App 新 → 拒绝。

增量规则：本地 `covers/` 与远程 `covers/` 按文件名 + size（可选 mtime）比较；只 upload 缺失或 size 不同的原图。远程多出来、本机已无引用的文件，备份结束时删除，避免删角色后云端残留占配额。

## Cover path contract

| 层 | 值 |
|----|----|
| DB / 领域 `Role.coverImg` | 相对路径 `covers/<file>`，空字符串表示无封面 |
| 选图 `CoverImagePicker.savePickedFile` | 写文件到 support/covers，返回相对路径 |
| UI `Image.file` | 解析为绝对路径后再读；文件不存在则走空态 |
| 备份 | 上传相对路径对应的原文件 |

Migration **schemaVersion 6**（实现时在当前 5 上升一档）：

- 把已有 `coverimg` 从绝对路径改成 `covers/<basename>`（仅当文件仍在 `covers/` 下）。
- 无法改写的绝对路径（文件已不在 covers 内）保留原值，展示层按「绝对或相对」两种都试，避免升级后封面全丢。

## Restore flow

1. 检查 iCloud 可用且 `ochome-backup/manifest.json` 存在。
2. 比较 `manifest.schemaVersion` 与 `AppDatabase.schemaVersion`。
   - 远程 > 本地 App：拒绝（AC5）。
   - 远程 < 3：拒绝（AC6，避开 v3 `deleteTable('role')`）。
   - 其它：确认对话框。
3. 确认后：下载 sqlite 到临时文件；按 manifest 把 covers 下载到临时目录（未本地下载的 ubiquity 项要 `startDownloadingUbiquitousItem` 并等待）。
4. **关闭** 当前 `AppDatabase` 连接。
5. 用临时快照替换本机 sqlite（含处理旧 WAL/SHM：删掉本机 `-wal`/`-shm`，避免混用）。
6. 用临时 covers 替换本机 `covers/`（先写旁路目录再 rename，失败可回滚）。
7. 重新打开 Drift。若备份更旧，`onUpgrade` 运行。
8. 任一步失败：不替换或把旁路目录丢掉，本机保持操作前状态（AC7）。

## Version / migration policy

`lib/data/database/app_database.dart` 的 `onUpgrade` 从此作为「旧备份 → 新 App」的唯一升级路径。

允许：`createTable`、`addColumn`、回填 SQL、旧表数据拷到新表后 `deleteTable` 旧表。

禁止：对仍要保留数据的表 `deleteTable` 再 `createTable` 空表。

`onDowngrade`：不实现数据降级；更低版本 App 打开更高 `user_version` 时 Drift 会失败，恢复流程在替换前拦截，用户看不到底层异常。

## Compatibility

- iOS、macOS 共用同一 iCloud container。bundle id 现为 `com.example.ochome`；container 建议 `iCloud.com.example.ochome`，正式签名时一并改。
- 需要 Apple 开发者账号、Xcode iCloud Documents capability、entitlements：
  - iOS：`com.apple.developer.icloud-container-identifiers`、`icloud-services` = CloudDocuments
  - macOS：上述 + sandbox `com.apple.security.files.user-selected.read-only` 不代替 ubiquity；需 `com.apple.developer.ubiquity-container-identifiers`（按 Xcode 生成为准）
- 无 iCloud 账号：备份/恢复按钮可点，结果为错误文案，不崩溃。

## Tradeoffs

| 选择 | 原因 |
|------|------|
| 快照文件而不是 CloudKit | 手动、原图、不动自增主键；影响面小于实时同步 |
| 一份最新槽位 | 原图多代备份会按代数占配额 |
| 原图增量而不是 zip 整包 | 第二次备份不重传未改立绘 |
| 相对路径 | 换机沙盒路径不同，绝对路径必挂 |
| 平台通道而不是直接 sync 活库 | 避免 WAL/冲突副本把库写坏 |

## Rollback

功能用入口开关：非 Apple 平台本来就没有。若 iCloud 能力出问题，可隐藏备份页，本机 Drift 与选图不受影响。相对路径 migration 一旦升到 6 不可在旧 App 打开；这与「备份比 App 新则拒绝」一致。
