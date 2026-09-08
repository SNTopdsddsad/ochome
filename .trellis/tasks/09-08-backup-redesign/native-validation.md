# Apple 备份 v3 实施与验证

2026-09-08；原生实现由 iOS 与 macOS 共同编译，同一份 Foundation/CloudKit 核心，不复制两套业务实现。

## 文件与接口

- `ios/Runner/BackupV3Support.swift`：安全路径、分块 SHA-256、精确长度/摘要校验、不可变目标、取消、fsync 原子指针切换。
- `ios/Runner/BackupV3Catalog.swift`：CloudKit 私有 custom zone、目录条件更新、服务器时间、任务保护、账户合计最近 3 份、发布回执、退休与清理许可。
- `ios/Runner/BackupV3Transport.swift`：Documents 暂存/上传确认/下载、元数据发现、旧槽只读兼容、持久上传记录、安装身份与容量查询。
- `ios/Runner/BackupV3ChannelHandler.swift`：Flutter 方法/事件通道、串行后台 worker、取消排空、账户变化。
- 两端 Xcode project 引用同一源文件；保留资产预览、视频缩略图和设定卡导出注册；移除旧 iCloud 方法通道注册，旧实现只保留作兼容测试源码，生产只走 v3 只读旧槽入口。
- 两端 entitlements 加入 CloudKit；macOS 同时启用出站网络和 iCloud capability。未修改签名身份或远程 Apple 配置。

通道为 `com.xuwudi.ochome/backup_v3` 与 `com.xuwudi.ochome/backup_v3/events`。执行合同的方法全部有实际 handler。

额外本地接口：

- `storageAtomicReplace {temporaryPath,destinationPath}`：无需账户/网络。路径限定 App `storage-control`，同目录临时文件 fsync 后 POSIX rename，再 fsync 父目录；没有 delete-first 窗口。
- `availableCapacity {}` → `{availableBytes?}`：本机可用于重要资料的可用容量。
- `availability` 额外返回 `writerId`：本地 excluded-from-backup marker 与 Keychain `AfterFirstUnlockThisDeviceOnly` 内容相符时复用 UUID；缺失/迁移/不一致则轮换。Keychain 不可读时明确提示，不能假装可用。
- `catalog` 额外含 `claims`；未完成删除可在任一设备以 `deleteAuthorized` 接续。`claimCleanup` 遇到已登记的未完成 claim 时返回其原 claimId，实际删除始终取已保存的确切路径。

## 云端数据合同

容器 `iCloud.com.xuwudi.ochome`；Documents 根 `Documents/ochome-backup-v3`；CloudKit `privateCloudDatabase` zone `OchomeBackupV3`。

CloudKit record types / fields（字段类型）：

| Record type | 确定 ID / 字段 |
|---|---|
| `OchomeBackupCatalog` | `catalog`；`payload` Bytes |
| `OchomeBackupClock` | `clock`；`nonce` String |
| `OchomeBackupReceipt` | `receipt-<SHA256(operationId)>`；`payload` Bytes |
| `OchomeBackupAbort` | `aborted-<SHA256(operationId)>`; `payload` Bytes |
| `OchomeBackupTombstone` | `deleted-<SHA256(relativePath)>`；`path` String |

无需全表查询或自定义查询索引。目录、回执和删除标记都在同一 custom zone；修改使用 `isAtomic=true`、`ifServerRecordUnchanged`。所有保存回调收齐之后再完成 Future。

目录只保留 3 份正常记录，按服务器协调分配的单调 `accountSequence` 排序；完成时间从发布回执的 CloudKit `creationDate` 读取，不使用设备时钟。保护期 24 小时，重复 reserve 可续期；过期判断基于新写入 clock 记录的服务器 `modificationDate`。CAS 冲突重取、重算，最多 8 次后报告可重试状态。

发布前核对所有对象来自本次实际已校验暂存记录或已登记保护的基底；确认全部文件为 ubiquitous 且 uploaded，再登记目录。响应丢失时查操作回执；已退休快照重试也不会重新占名额。

每个清理批次最多 256 个确切文件。先删不被 active/有效 reservation 引用的媒体，最后一起删 4 个快照元数据文件。许可与永久 tombstone 原子写入，旧路径不可复活。任何清单缺失、未知格式、摘要不一致、账户变化、过期/冲突或元数据发现未完成均停止删除。

文件进度来自实际流读写字节；上传等待仅报告已获确认文件数，不从 copy 100% 推算上传完成。原生每次等待上传/下载最多约 120 秒后报告 pending；后台 CloudDocuments 系统传输可能继续，应用不会将其冒充已撤销。

## 本机自动验证

独立测试命令（仅随机临时目录和内存记录仓库，不触及用户账户）：

```sh
swiftc ios/Runner/BackupV3Support.swift ios/Runner/BackupV3Catalog.swift test/native/backup_v3_test.swift -o /tmp/ochome-backup-v3-test
/tmp/ochome-backup-v3-test
```

结果：**72 项检查通过**。覆盖：零字节文档、多块完整复制、截断/错误摘要、超大元数据、不可变目标冲突、取消不生成最终文件/残留 part、原子替换失败保旧指针、路径遍历/符号链接、布尔/小数整数拒绝、跨客户端合计 3 份、设备时钟偏差、恢复引用保护、共享文件不删、跨设备接续中断清理、tombstone 拒绝复活、发布回执丢失/退休后幂等、reservation 过期、两客户端 CAS 交错、缺失目录/损坏清单不清理。

共享 Swift 全部文件使用真实 Flutter framework 分别完成 iOS 15 simulator、macOS 12 typecheck。Xcode project/entitlements `plutil -lint` 通过。完整 App 构建和 Flutter 回归由主会话统一执行，见其验证记录。

## 需要外部环境完成的验收

这些不是“已测试通过”的部分：

1. Apple Developer 中为相应 Bundle ID 配置同一个 CloudKit + CloudDocuments 容器；更新包含新能力的 provisioning profile。检查 Development / Production 环境与发布签名一致。
2. CloudKit Dashboard 验证上述 record types/fields，并在正式发布前部署 production schema。此实现和自动测试均未执行远程 schema 修改。
3. 两台已登录同账户的真机验证并行发布/跨设备发现、上传状态、Keychain 身份、退出/账户切换、iCloud 配额与断网恢复。
4. 数 GB 媒体测试真实吞吐、内存、耗电、系统后台暂停与 iCloud 本地缓存占用。
5. Known unpublished uploads now support receipt-first, account-fenced cleanup using native atomic-create ownership receipts. Unknown or interrupted ownership evidence stays cleanupPending; no deletion is inferred from directory enumeration, and immediate iCloud quota release is not promised.
6. CloudDocuments 物理删除和配额释放受系统同步影响；删除请求完成不等于云端容量已立即释放。

配置缺失或服务不可用会返回 `cloud_configuration` / `documents_unavailable` / `cloud_pending` 等明确错误；没有 fallback 到每设备 3 份，也不以本机拷贝完成代替成功备份。

## 核对的 Apple API 说明

- [kSecUseDataProtectionKeychain](https://developer.apple.com/documentation/security/ksecusedataprotectionkeychain)：macOS 启用与 iOS 一致的数据保护钥匙串语义，其他平台可安全忽略该选项；本实现同时指定 ThisDeviceOnly。
- [ubiquitousItemIsUploadedKey](https://developer.apple.com/documentation/foundation/urlresourcekey/ubiquitousitemisuploadedkey)：上传确认轮询在文件协调回调之外执行；每次清除 URL 资源值缓存，避免把首次 pending 状态永久复用。

## Integration refinements

- `availability.appVersion` now uses actual `CFBundleShortVersionString + "+" + CFBundleVersion`; absent build numbers are not invented.
- `legacy_manifest_missing` is returned only after completed NSMetadataQuery discovery finds no manifest in the operation's fixed legacy slot. Unknown discovery stays pending; another layout's manifest cannot fill this slot's gap. The slot is pinned before reporting its missing manifest.
- Added focused version/discovery/missing-manifest/layout-isolation tests: 48 native checks pass.

### Durability evidence boundary

`availableCapacity` only queries space. Streamed copies synchronize file contents before publishing the final name, then fsync the immediate parent directory. Atomic pointer replacement also synchronizes the temporary file and fsyncs its parent. These operations protect the written file and direct directory entry, but do not recursively fsync every newly created ancestor or request macOS F_FULLFSYNC. The fixture tests establish error/cancellation/process-recovery behavior, not a blanket hardware power-loss guarantee for all new directories and media.


## Abandoned upload reclamation

Wire: `abandonUpload {operationId: freshCleanupID, accountId, abandonedOperationId}` returns `{aborted, published?: descriptor, cleanupPending}`. The original operation token stays cancelled; cleanup uses its own token.

1. Read the idempotent publication receipt before any local-journal interpretation or abort mutation. Published means retain all files; an unknown receipt result throws and preserves evidence.
2. Atomically save an `OchomeBackupAbort` record and remove only that operation's reservation by catalog change-tag CAS. Reserve, stage and publish check the permanent abort fence; publication and abort cannot both win their catalog CAS.
3. Keep separate durable `attempts`, `paths` (verified staged), and `owned` journals. Only successful exclusive creation of a final target yields ownership; an already-existing identical file is never reclaimed as ours. The attempt journal and its ancestor entries are synchronized before cloud writes. A crash without a conclusive ownership receipt remains pending.
4. Read hash-bound manifests of all active/retired snapshots and verify reservation bases. Exclude every referenced path. Unknown references, unsupported manifests or account changes preserve files.
5. Authorize at most 256 exact paths per call with catalog CAS, tombstones and a persistent claim. Interrupted claims include `abandonedOperationId` and may be resumed by any device. Retry abandonUpload to process further batches using retained local ownership evidence.

`cleanupPending=false` means no provably owned, unreferenced paths remain to authorize. It does not mean retained shared objects were removed or iCloud physical space was released immediately. Unknown ownership evidence is intentionally not reclassified as clean.

Native tests now total 72 checks, adding exclusive-create ownership, normal cancel reclamation, retained/shared exclusions, reservation preservation, permanent late-reserve/publish fencing, repeated abandon, receipt-first published protection, publish-versus-abort CAS with lost publication response, interrupted cleanup continuation, 256-file batching and unknown/offline evidence preservation, lost abort-response recovery and a concurrent publisher changing cleanup reachability. No real CloudKit data or schema was mutated.
