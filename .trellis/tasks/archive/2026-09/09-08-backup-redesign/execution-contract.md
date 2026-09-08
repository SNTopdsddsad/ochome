# 实施接口与职责 · 2026-09-08

用户已明确批准建立/沿用 Trellis 任务并开始开发，无需再次确认产品规则。此文件将 design.md 的拟议接口收敛为协作边界；可在保持需求不变时由主会话协调细化。

## Ownership

- storage implementer：DataStorage、文件指纹/导入、SQLite 快照、repository 写入隔离及对应 tests；不修改 UI、app/main/router/providers、Apple 文件或 pubspec。
- core implementer：`lib/features/backup/` 中领域模型、严格协议、传输适配器、快照构建/校验、coordinator、账户目录 Dart API/清理及对应 tests；不修改 UI/provider/主入口、storage 所有文件或 Apple 文件。
- Apple implementer：iOS/macOS 新 backup_v3 传输/CloudKit 服务、共享 core、native tests、Xcode 引用、注册、entitlements；不修改 Dart。
- main：provider/启动/数据根 UI 注入、备份及详情页面、全链路可视化、依赖、集成/审查/最终验证与文档。

所有代理均不独占工作区，不得回退其他人的更改。不要提交、推送或操作真实用户备份。Flutter 构建/测试由主会话串行调度；各代理可做 formatter/独立 dart analyze，完成后通知主会话所需测试。

## Storage API（storage 拥有，实现完成前优先通知签名变动）

`lib/data/services/data_storage.dart`：

- `Future<DataStorage> initializeDataStorage({Future<Directory> Function()? supportDirectory})`：生产启动调用；设置已初始化的 `DataStorage.current`。测试可以构造隔离实例。
- `Future<Directory> getActiveDataDirectory()`：可替代既有 getApplicationSupportDirectory 的资料根读取，legacy 首次升级保持原目录。
- `DataStorage.supportDirectory / activeDirectory / epoch / changes`；`changes` 为 epoch stream。
- `Future<T> mutate<T>(Future<T> Function() action, {int? expectedEpoch})`，`Future<T> exclusively<T>(Future<T> Function() action)`：排队与跨 session 拒绝；生产 repository 捕获所属 epoch。
- `StoragePin pinFiles(Iterable<String> absolutePaths)`，`StoragePin.release()`：禁止被 pin 的物理文件删除/改名，DB 逻辑删除可进行，文件删除排队。
- `Future<void> deleteWhenUnpinned(File file)`。
- `Future<Directory> createStagingDataset()`。
- `Future<void> activate(Directory staging, {required Future<void> Function() closeDatabase, required Future<void> Function() reopenDatabase})`：受独占保护、持久日志/指针与健康检查；失败回退。
- `Future<bool> hasPrevious()`，`Future<void> restorePrevious({required ...closeDatabase, required ...reopenDatabase})`，`Future<void> discardPrevious()`。
- startup recover 不可直接创建空库覆盖未知损坏；同卷 stage，旧根仅清理确切数据路径。

指纹 API `lib/data/services/file_fingerprint_store.dart`：`FileFingerprint {String sha256; int bytes;}`；`FileFingerprintStore(Directory controlRoot)`；`Future<FileFingerprint> fingerprint(File file, {bool force = false})`；`Future<void> remember(File file, FileFingerprint fingerprint)`；`Future<void> close()`。缓存隔离由绝对根/不可变文件身份和 stat 检查保证，不把缓存当最新健康证明。文件导入同流 hash，失败不留有效记录。

`SqliteSnapshotter` 保留旧测试 API 兼容，新增一致 Online Backup API 路径（直接提供 `Future<File> createSnapshot({required File liveSqlite, required Directory destDir})`）；新核心使用该方法，不能只 checkpoint + copy。

## Core API（core 拥有）

`BackupCoordinator` 对 UI 暴露 stream / current job、availability、list/current contents、startBackup、prepareRestore(ref)、confirmRestore、cancel、retry、restorePrevious、discardPrevious 等强类型接口。构造注入 DataStorage、传输、close/reopenDatabase 回调，测试可使用隔离实例/fake transport。请先写出模型/API并告知主会话。

模型需覆盖：operationId / kind / phase / content time / started/completed time / current item / measured bytes? / file counters / reuse counts / error / cancellability / backup descriptor / contents；unknown=null。完成需账户发布确认；readyForReview 不自动激活。列表账户合计 3，损坏不部分恢复，无码全量 readAsBytes 媒体处理。

协议文件的 JSON 定义以 design.md + visual-experience.md 为准。上限、unknown format、精确字节/hash、DB schema/业务校验、旧格式只读兼容、持久 job、清理边界都必须落实。原生 transport JSON 统一如下。

## Apple wire protocol v3

MethodChannel `com.xuwudi.ochome/backup_v3`，EventChannel `com.xuwudi.ochome/backup_v3/events`。

统一方法参数含 operationId（涉及任务时）和 accountId（availability 返回的不透明值；执行前复核，禁止写入错误账号）。错误用稳定 code + 用户可理解的 message，禁止把所有异常报成未登录。

- `availability {}` → `{supported:bool, available:bool, accountId?:string, deviceName:string, appVersion:string, errorCode?:string, message?:string, availableBytes?:int}`。同时检查 Documents/CloudKit；native returns true only actual prerequisites work。
- `availableCapacity {}` → `{availableBytes?:int}`。只读本机可用容量，未知留空；旧格式恢复在下载 SQLite 并解析完整引用后、首个媒体前检查已知下限，并在每个媒体前复查；无历史大小的立绘保留 unknown，实际 ENOSPC 仍在独立准备区失败，不覆盖本机。
- `catalog {accountId}` → `{revision:string, snapshots:[descriptor], reservations:[reservation], retired:[descriptor]}`。初始目录安全创建；已存在内容但目录缺失时不盲目清理。
- `reserve {operationId,accountId,kind:'backup'|'restore',baseSnapshotIds:[string]}` → `{reservationId:string, expiresAtUtc:string}`。CAS 保护 active 的基底；过期后不允许迟到 publish。
- `publish {operationId,accountId,reservationId,snapshot:descriptor}` → descriptor with `accountSequence:int, completedAtUtc:string`。同区条件/原子更新+操作收据幂等，保留最新3并产生退休记录。
- `release {operationId,accountId,reservationId}` → null（幂等）。
- `stage {operationId,accountId,localPath,relativePath,bytes,sha256}` → null。v3 root下唯一目标，同流摘要/精确长度验证，原子发布，不覆盖不同内容。
- `awaitUploaded {operationId,accountId,relativePaths:[string]}` → null only every item uploaded=true and no conflict/error; progress events。未知/超时为可恢复 pending error。
- `download {operationId,accountId,relativePath,localPath,bytes?:int,sha256?:string,legacy?:bool}` → `{bytes:int,sha256:string}`。只读legacy root不自动迁移，zero bytes valid when expected=0；目标必须 App owned stage/control目录；安全路径。
- `legacyInfo {accountId}` → `{exists:bool, discoveryComplete:bool}`；不枚举结果空就断定不存在。
- `cancel {operationId}` → null only app-owned writers drained/isolate per-job stage cannot be reused while callbacks remain；system transfer不能保证撤销。
- `abandonUpload {operationId,accountId,abandonedOperationId}` → `{aborted:bool,published?:descriptor,cleanupPending:bool}`。调用前先 cancel/drain 旧任务，operationId 为新的清理 ID。native 先核对发布回执，再以不可逆账户 CAS abort fence 阻止旧任务晚到 reserve/publish；只清理持久 CREATED-path 账本证明由旧任务新建、且不被 active/reservation 引用的确切路径。未知状态返回待清理而不删除。Dart 保留旧任务日志及按账户过滤的 pending-abandons 标记，后续操作重试；每批最多 256 个，pending native claim 也可由 deleteAuthorized 接续。
- `claimCleanup {operationId,accountId,revision,relativePaths:[string]}` → `{claimId:string}`。CAS guard catalog revision/reservations；批次有界，unknown不授权。
- `deleteAuthorized {operationId,accountId,claimId}` → null；idempotent exact paths only；完成清理更新记录，可由不同设备接续。

Descriptor fields (wire names fixed): `snapshotId, writerId, basePath, createdAtUtc, appVersion, schemaVersion, roleCount, revisionCount, assetCount, fileCount, totalBytes, manifestSha256, commitSha256, deviceName, accountSequence?, completedAtUtc?`。basePath = `writers/<writerId>/snapshots/<snapshotId>`；object path = `writers/<writerId>/objects/<objectId>`。manifest/content模型可有额外字段但这些摘要必须映射。

Event envelope: `{operationId, sequence:int, phase:string, relativePath?:string, completedBytes?:int, totalBytes?:int, completedFiles?:int, totalFiles?:int}`。阶段只描述 native 工作（staging/uploading/downloading/waiting）；coordinator 负责整体任务状态，不发虚假速度或百分比。

Native provides `storageAtomicReplace` for durable control-file replacement and `availableCapacity` for read-only local space checks. App signing/schema not yet remotely configured must return actionable unavailable/pending, never falsely declare success.

## Execution acceptance

Production feature must use real native implementations, not a fake catalog; no real user iCloud mutation as a test. Run functional Dart tests and native typecheck/simulator tests with dedicated fixtures. New capabilities may require signing/CloudKit schema enablement; implement all reachable code and report exact external validation boundary without pretending physical double-device tests passed.
