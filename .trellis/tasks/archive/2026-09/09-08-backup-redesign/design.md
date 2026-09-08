# 备份与恢复 v3 技术设计

2026-09-08 · 产品规则已确认；账户级技术方案修订稿。用户确认按数 GB 数据量设计。所有签名为拟议合同，不代表已实现。

## 1. 决策与边界

采用独立完整逻辑快照、按整文件复用的不可变媒体对象、应用级任务协调和本地数据代际切换。iCloud Documents 作为最终一致的文件传输层，不能提供多文件分布式事务。客户端用发布标记、账户目录登记和完整校验决定是否可恢复；CloudKit 私有目录条件更新协调账户合计 3 份的保留集合，详见 `research/account-retention.md`。

保留现有角色/设定历史/属性/资产领域结构，SQLite schema 8 不因单纯备份格式升级而递增。新格式版本 3 与数据库版本分别管理。继续由用户手动触发 iCloud 备份、整份恢复。用户已明确不需要手动导出完整备份文件或从文件恢复，本轮不实现这两项；不加实时同步、后台定时、部分合并、未受管理的旧目录自动清理或自定义密码加密。

替代方案及用户流程见 `review.md`。本设计优于持续修补三个可变目录，但会影响文件根目录解析和应用启动，必须分阶段验证。

## 2. 不变量

1. 已发布快照、数据库对象和媒体对象不原地修改；一个对象 ID 永不复用为不同内容。
2. 每份 manifest 都是完整逻辑快照；其恢复不依赖先恢复旧数据库或重放补丁。
3. manifest 中数据库摘要、文件摘要、引用路径与 snapshotId 绑定；只使用快照内引用，不拼接云端其他快照文件。
4. 不存在成功发布的新快照时，不因本次任务删除旧快照所需内容。
5. staged/local-written、cloud-confirmed、download-verified 是不同证据，不混用成功状态。
6. 恢复前完成下载、摘要校验、数据库结构/业务校验和迁移。准备失败不改变当前数据。
7. 可写业务层在一个 epoch 中只访问一个数据根；切换期间不运行旧 repository 写入。
8. 所有完成、失败、取消由 coordinator 唯一裁决。页面销毁不释放运行锁，不授权后台覆盖。
9. 取消先停止/隔离写入者，后清理工作目录。不能仅 timeout Future 后删除仍被使用的目录。
10. 清理是独立可重试动作；不能把清理失败解释成已成功的数据切换失败。

## 3. 目录与身份

### 3.1 云端

在原容器 `iCloud.com.xuwudi.ochome` 的 `Documents/ochome-backup-v3/` 下：

```text
writers/<writerId>/
  objects/<objectId>             # 不可变原始媒体字节
  snapshots/<snapshotId>/
    database.sqlite             # 此快照专属
    manifest.json               # 此快照专属
    contents.json               # 与该快照绑定的可读内容目录
    commit.json                 # 最后发布，小文件
  receipts/<snapshotId>/completed.json # 可选：创建者观察到完成后的时间回执
```

- writerId 是一次本地写入者身份；随机生成，不包含个人身份信息；来源 ID 可在 manifest 中保留，但本地写入资格材料和账本不纳入云端角色备份。文件仍分写入路径，但所有设备共享一个账户保留集合，writerId 不分配备份名额。
- 正常 App 更新保留身份；卸载重装、迁移后无法证明自己仍拥有完整本地写入账本时，生成新 writerId；旧快照仍由账户目录统一保留和退休，不能因原设备离线而永远免于清理。设备还原不得复制出两个拥有相同写入资格的客户端；实现时用不随设备迁移的本地身份材料核验，无法证明则轮换。
- snapshotId/objectId 为随机 UUID。writerSequence 只用于本地诊断；账户成功发布时由目录条件更新分配 accountSequence，决定全账户保留顺序。设备时钟只影响内容时间展示。
- 内容复用索引是 `(sha256, bytes) → objectId`，不是用户文件名。删除退休对象后重新出现同样内容时用新 objectId，避免延迟删除命中重新上传的同名对象。
- 不以 Documents 中共同覆盖的 `latest.json` 协调并发。正常备份列表来自 CloudKit 私有账户目录，最多 3 项；元数据查询只辅助定位内容/兼容发现。初版仍可只做同 writer 对象复用，但清理和引用保护必须是账户级。
- 存储对象可能被多个保留快照引用；损坏一个共享对象可能影响这些快照，因此恢复前必须完整校验，并在有损坏时明确指出受影响文件。

### 3.2 本地

```text
Application Support/
  ochome.sqlite, covers/, role_assets/     # legacy 当前数据，可继续使用
  datasets/<datasetId>/
    ochome.sqlite, covers/, role_assets/   # 每次恢复产生完整新数据集
  storage-control/
    active.json                           # 小型原子切换指针
    restore-intent.json                   # 恢复切换日志
    writer-ledger.sqlite                  # 仅本安装使用，不进用户备份
    jobs/<operationId>/                    # 持久化任务状态、清单、暂存文件
```

`active.json` 的拟议结构：`{format:1, current:{kind:"legacy"}|{kind:"dataset",id:UUID}, previous:DatasetRef?, epoch:int}`。存储根不能由任意用户路径指定，dataset id 严格校验。

首次升级不批量搬动资料：无控制文件且旧库存在时初始化 legacy 指针；全新安装创建新 dataset。备份仍可读取 legacy；第一次恢复切换到新 dataset。旧路径在退休 legacy 时只清理明确的旧数据文件，禁止删除整个 Application Support。

## 4. Manifest / Commit 合同

`manifest.json` 必需字段：

| 字段 | 类型/规则 |
|---|---|
| format | 严格整数 3；未知值拒绝，不默认成当前版本 |
| snapshotId / writerId | UUID；必须匹配发现路径和 commit |
| writerSequence | 正整数 |
| createdAtUtc | 合法 UTC ISO-8601；只作展示 |
| appVersion | 实际运行 build version；消除 `kAppVersion` 手工双写来源 |
| schemaVersion | 源快照 `PRAGMA user_version`，必须与数据库一致 |
| requiredFeatures | 已知协议特性集合；遇到未知必需特性拒绝 |
| deviceLabel | 用户可见来源标签，不用于权限或路径 |
| database | `{file:"database.sqlite", bytes:int>0, sha256:64位小写hex}` |
| contents | `{file:"contents.json", bytes:int>0, sha256:64位小写hex}`，备份时派生的可读目录 |
| files | 完整数组，见下 |
| summary | `{roleCount, revisionCount, assetCount, fileCount, totalBytes}`；恢复前重算核对 |

每个 file：`{kind:"cover"|"asset", relativePath:string, objectId:UUID, bytes:int>=0, sha256:hex}`。

- relativePath 仅可为 `covers/<安全文件名>` 或 `role_assets/<安全文件名>`，与数据库中实际引用对应；拒绝绝对路径、`..`、隐藏路径、反斜线、嵌套目录和重复逻辑路径。同一 objectId 的摘要/大小必须一致。
- 路径和大小不能从目录占位文件反推；零字节资产合法，空路径封面表示不需要文件。非空封面引用指向零字节图片则为损坏。
- 同一路径被多个角色引用时只保存一项；引用映射不能按显示名称去重。重复属性名称与属性顺序保持原有数据库语义。
- 快照必须覆盖全部非空封面引用和资产引用；不允许跳过缺失必需文件后标记完整。
- legacy 绝对封面若确实落在旧 covers 目录内，规范化到相对路径。其他绝对封面在本机有文件时，只在待上传快照副本内重新映射为安全 covers 路径并纳入清单；无法读取则报错，不产生残缺成功备份。

`commit.json` 必需字段：`{format:3, snapshotId, writerId, writerSequence, manifestBytes, manifestSha256}`。

摘要基于最终写入的准确字节，不基于重新编码的 JSON。SHA-256 用于完整性检测，不代表来源签名或抵抗拥有整个备份写权限者的伪造。

解析边界拟定为 manifest ≤16 MiB、files ≤100,000、整数不得越界；这些是资源保护上限，不是预期容量。超过时明确失败，不截断清单。媒体按流读取，不把数 GB 文件整体载入内存。具体边界作为实施测试参数，不依赖 UI 中硬编码。

## 5. 应用内模块与拟议接口

| 模块 | 责任 |
|---|---|
| BackupCoordinator | 单任务锁、状态机、持久化进度、取消、账号变化、重启恢复 |
| AccountBackupCatalog | 账户发布顺序、合计 3 份保留、跨设备引用保护与清理许可 |
| DataSession / DataMutationGate | 当前根与 epoch，业务写入租约，排空事务，短时独占切换 |
| SnapshotBuilder | SQLite 快照、引用枚举、文件固定、摘要与 manifest |
| BackupTransport | 云发现、原子暂存、上传确认、下载、取消；不认识角色字段 |
| SnapshotValidator / LegacyBackupReader | 格式/内容/数据库/迁移验证；旧格式转换到统一准备计划 |
| DatasetActivator | 本地切换指针、提交日志、启动恢复、本地恢复前副本 |
| Backup page/controller | 订阅状态和触发意图，不直接 close 数据库或操作目录 |

```dart
abstract interface class BackupCoordinator {
  Stream<BackupJobState> watchJob();
  Future<OperationId> startBackup();
  Future<OperationId> prepareRestore(BackupSource source);
  Future<void> confirmRestore(OperationId id, ReviewedLocalState expected);
  Future<void> cancel(OperationId id);
  Future<void> resume(OperationId id);
  Future<void> recoverOnStartup();
}
abstract interface class BackupTransport {
  Stream<BackupDiscoveryState> watchSnapshots();
  Future<CloudWriteReceipt> stageImmutable(TransferRequest request);
  Future<CloudConfirmation> waitUntilUploaded(UploadSet request);
  Future<VerifiedLocalFile> download(DownloadRequest request);
  Future<void> cancelAndDrain(OperationId id);
}
```

`BackupJobState` 至少包含 `{operationId, kind, phase, datasetEpoch, completedBytes?, totalBytes?, processedFiles?, totalFiles?, canCancel, canLeave, error?, result?}`；结果区分 cloudConfirmed、restoreActivated，不用一个含义模糊的 success。进度中未知值为 null，不转换成零或伪造百分比。`BackupSource` 为固定的 cloudSnapshot、legacySlot 或 previousDataset；prepareRestore 不追随可变 latest。

所有 request 带 operationId、账号会话标识、writerId、snapshotId（适用时）、取消 token。接收目录由 coordinator 授权，不接受任意 native 写入路径。允许相同 operationId 重试同一不可变字节；发现同 ID 不同摘要必须拒绝。

同一 App 同时最多一个备份/恢复/清理任务；业务阅读通常可继续。启动时还需对本安装的控制目录持有进程级 OS 文件锁，第二个 macOS 进程不能只靠各自的内存锁同时写入；锁不可获得时显示已有实例正在使用数据。进程退出释放锁，重启先处理持久化任务。写入锁由所有 repository、历史恢复、选图落盘、资产导入/删除及未来文件清理共同遵守，不能只禁用按钮。

## 6. 备份算法

1. **建立任务**：检查支持平台/指定容器/账号、读取当前 dataset 和空间；写入本地 job 日志。账号 token 变化停止后续发布，不退回默认其他容器。
2. **一致快照**：短时禁止业务写入并排空正在进行的事务；用当前安装 sqlite3 的 Online Backup API 在后台 isolate 创建独立 SQLite。等待完成并关闭目标连接；做完整性及版本检查。取消/异常输出不可使用。
3. **固定引用**：从独立 SQLite 查询封面/资产全部引用；在解除写入锁前登记文件 pin。之后业务可继续写逻辑数据，物理删除/替换已 pin 文件必须延期；pin 的文件保持字节不可变。无法覆盖全部写入入口前，不能开放这一并发阶段。
4. **准备对象**：优先读取导入时已计算的本地摘要缓存，对受控不可变文件检查缓存身份、存在性、大小与版本线索；未知/失效缓存后台补算。需要新上传的内容在复制到持久化 job stage 的同一字节流中重算并核对预期摘要。同卷克隆仅为可选优化，不能绕过需要实际内容校验的边界，普通流复制是正确性基线。进程重启后，stage 已完成对象重新校验，未完成且无法证明 pin 连续有效的任务放弃重建，不沿用可能变化的 live 文件。
5. **增量复用**：候选摘要先经本地索引定位，但必须从账户当前保留/有效保护集合取得复用许可，且对象未退休、摘要/长度匹配、云端状态可确认；不是仅比较目录长度。若复用对象的版本/内容状态无法与已验证记录对应，下载重新校验，或生成新 objectId 上传，不能猜测成功。
6. **新路径写入**：新媒体、database.sqlite、contents.json、manifest.json 都先写临时文件，校验/flush 后同卷原子发布到唯一最终路径。对 iCloud 做 NSFileCoordinator 协调，永不 remove 一个已发布旧快照来腾位置。
7. **等待传输**：观察文件真实上传状态/错误；不确定则 pending。全部引用内容、数据库、可读目录和清单确认上传后，生成并发布 commit，再等待 commit 自身上传确认。
8. **账户发布与完成**：所有内容与 commit 确认后，用条件更新登记到账户目录、分配 accountSequence 并维持 active 最多 3 项；冲突则重取重算，响应不确定按 operationId 查询回执。成功后持久化 completed/receipt，更新 UI。随后才可独立调度退休清理；清理失败显示已完成并附空间清理提示，不改成备份失败。

因为 iCloud 可乱序传播，另一设备即使先看到 commit，没有有效账户登记也不能把它列入正常备份列表。必须取到匹配的 manifest/数据库/媒体并校验后，才有恢复资格。一次元数据上传确认也不等于永久耐久性或所有设备立刻可见。

## 7. 原生传输层

新 MethodChannel 名称建议 `com.xuwudi.ochome/backup_v3`，EventChannel 为 `.../backup_v3/events`。Apple 共用 Foundation 传输核心，各平台壳只负责通道注册、能力和系统生命周期；首版不引入备份文档选择器，避免复制两套下载判断。

| 方法 | 输入 | 完成/错误语义 |
|---|---|---|
| getAvailability | 无 | available/unavailable/unsupported + 不透明账号会话值；禁止泄露 token |
| startDiscovery / stopDiscovery | operationId | NSMetadataQuery 初始发现/后续更新；空初始集不等于已证明无备份 |
| stageImmutable | operationId, scoped target, owned local source, expected bytes/hash | 本地校验及原子写完成；明确尚未保证 cloud-confirmed |
| observeUploads | operationId, exact item refs | 每项 uploaded/error/unknown，返回集合确认结果；nil 不是 true |
| download | operationId, item ref, authorized stage path, expected bytes/hash | 发起下载、判断状态后流复制到独立 .partial，精确校验后改名；空文档支持 |
| cancelAndDrain | operationId | 停止 app 自己的队列和复制，等待活动写入结束；系统 iCloud daemon 已接收的传输不承诺可撤销 |
| deleteAuthorized | operationId, account GC claim, exact retired refs | 仅账户协议证明无保留/活动引用的内容；可清理其他来源设备的受管文件，禁止广泛 prefix 删除 |

- 观察 `ubiquitousItemIsUploaded`、上传/下载错误、下载状态和冲突状态；刷新元数据，区分「不存在」「尚未发现」「尚未下载」。旧版备份目录读取不触发移动或删除。
- 废弃用 `Thread.sleep` 长时间独占串行队列的轮询；采用可取消异步观察/有上限退避。初始建议 3 次指数退避（1/3/10 秒），网络等待用可恢复 pending 状态，不把固定 20 分钟当总文件大小上限。
- 大文件传输有进展时不因固定每文件 120 秒就判损坏；无进展超过 2 分钟提示暂停/重试，用户可停止等待。参数可配置，需真机验证。
- 错误码至少区分 unsupported、accountUnavailable、accountChanged、notFound、notDiscovered、quotaExceeded、localNoSpace、transferFailed、contentMismatch、conflict、cancelled、unknown。保留原生错误到内部日志，不直接把堆栈/绝对路径吐到界面。
- 路径标准化后验证在确切容器/授权 stage 内，拒绝符号链接、穿越和 symlink 父目录；安全检查不能只用字符串前缀。

## 8. 恢复算法与本地切换

### 8.1 下载与验证

1. 用户选定账户目录内快照，固定 source writer/snapshot/commit 摘要并取得恢复保护；不在过程中追随另一个「最新」快照，保护失效后须重新核验。
2. 读取并验证 commit/manifest，判格式和数据库版本；计算空间，下载到 `datasets/<newId>` 暂存。
3. 每项精确字节数 + SHA-256 校验，验证 DB 文件摘要后只读打开。完整性检查（`PRAGMA integrity_check`）、外键检查、表/列/索引结构、字段解码、资产 kind/path/bytes、属性 JSON/顺序/重复名合同全部验证。
4. 数据库和文件引用必须吻合；拒绝未知或不允许的 schema 对象（含额外触发器/视图），拒绝重复/冲突路径。不执行备份提供的任意 SQL。资源限额防止异常云端清单或文件耗尽内存/磁盘。
5. 若 schema 比当前旧且支持，在该 dataset 内打开 Drift 执行迁移；完成 checkpoint/close 并重验业务内容。绝不先覆盖活库再试迁移。
6. readyForReview：显示快照信息、本地将被替换的信息和空间；等待用户确认。离开页面、App 重启、取消都不自动执行覆盖。

### 8.2 切换协议

1. `confirmRestore` 获取短时独占 mutation gate，检查当前 epoch 和本地 revision 与审核摘要一致；有新编辑则刷新摘要重新确认。
2. 让旧页面退出数据会话，排空 repository 调用、导入、预览文件租约和事务，关闭旧数据库。销毁/重建数据范围 ProviderScope，禁止旧闭包在关闭后继续写入。
3. 保留当前 dataset，不删除其 DB/WAL/SHM。旧库干净关闭后，完整旧数据就是本地回退点，无需另复制一份旧媒体。
4. 将新 dataset 及其迁移完成证明 flush，写入 `restore-intent.json {operationId, oldRef, newRef, phase:prepared}` 并持久化。
5. 使用同卷原子小文件替换，把 `active.json` 的 current 改为 new、previous 改为 old、epoch 递增；持久化目录元数据。要求 native durable-replace 合同与真机 crash tests，不把普通多次 rename 当跨文件事务。
6. 在独占门内打开新库执行短时健康检查，持久化 healthy；重建全部数据 provider、缓存和导航状态后放开写入。旧图片根目录静态缓存必须移除或以 epoch 为 key。
7. 新库打开失败时，只在用户写入尚未放开时，把指针切回 old 并重开旧库。健康检查后开始的新业务写入不得因迟到清理异常而回退。
8. 清理旧 job/上上份恢复副本为后续动作。失败只标 cleanupPending，不能回滚已经健康并开放写入的新数据。

### 8.3 启动恢复矩阵

在 `runApp` 建立业务 provider 之前执行 storage bootstrap / journal recovery：

| 日志/指针状态 | 启动行为 |
|---|---|
| 无 intent，指针正常 | 打开当前 dataset |
| prepared，指针仍 old | 继续用 old；new 保留待用户重新审核或清理，不自动切换 |
| 指针已 new、未 healthy | 验证准备记录并尝试打开 new；失败切回完整 old；成功持久化 healthy 后开放 |
| healthy、cleanupPending | 使用 new；仅重试无引用临时数据清理 |
| 指针损坏、intent 可验证 | 根据已持久化阶段恢复明确指针；无法判定时进入恢复界面，不创建空库掩盖错误 |
| 当前和 previous 都不可读 | 明确故障并保留目录，允许选择云端备份；禁止清空目录自动重建 |

终止进程测试须覆盖每个边界；文件系统原子性不能替代设备上的实际验证。正常系统/文件系统工作的条件下，目标是进程崩溃后完整旧或完整新；不宣称抵抗设备硬件损坏。

## 9. 取消、离开页面与恢复任务

| 阶段 | 返回/取消 | 业务写入 |
|---|---|---|
| snapshotting | 可离开；取消等待快照 API 释放资源 | 短时排队 |
| preparing/transferring backup | 可离开；取消 app 任务并 drain，已发布旧快照不动 | pin 建立后可继续 |
| publishing/waiting commit confirmation | 可离开；标「等待云端确认」，发布边界以后不能宣称撤销云端对象 | 可继续；其他备份/恢复仍串行 |
| restore downloading/validating | 可离开和取消，绝不自动覆盖 | 可继续 |
| readyForReview | 用户确认才切换；重启后重新审核 | 可继续，确认时核对 revision |
| activating | 短时禁止返回/取消；后台终止由日志恢复 | 全部暂停 |
| completed/failed/paused | 可关闭、重试或清理；迟到回调由 operationId 隔离 | 正常 |

前台协调器/原生传输不保证 iOS 无限后台执行；已排入 iCloud 的同步可能继续，但 App 下次启动仍要验证进度。恢复/备份任务日志只保存必要路径摘要和状态，不保存额外角色文本。取消完成前不删除仍有写入租约的 stage；无法中止系统行为时保留隔离目录，等待安全清理。

## 10. 账户级历史保留与垃圾清理

**用户已确认：同一 iCloud 账户合计最近 3 份完成备份，所有设备共享名额。** 原来的每 writer 独立保留/清理规则撤销。

账户目录采用小型 CloudKit 私有 custom zone 记录，通过服务器 change tag 条件修改维护 active 集合和账户发布顺序。所有内容/commit 上传确认后才登记新快照、淘汰最旧项；更新冲突必须重取重算，不能按设备时钟或本地缓存覆盖目录。

任务复用对象前登记保护；恢复时也固定并保护所选快照。退休文件只有在账户 active、有效发布/恢复保护均无引用时，才由获得 GC claim 的设备删除。原设备离线不阻止其他设备处理合法清理；未知/过期/冲突状态不能授权删除。退休 objectId 不允许复活引用，重现同样内容须使用新 ID。

正常列表最多 3 项；待传输、受保护退休内容、删除延迟和旧版迁移残留可能暂时额外占空间。清理失败保持 cleanupPending，不倒退已完成发布。详见 `research/account-retention.md` 的发布、保护、重试、兼容和 G01–G08 验证合同。

此技术方案依赖当前尚未配置的 CloudKit 元数据能力；实施前须验证同容器 privateCloudDatabase、custom zone 条件/原子写入、幂等回执及账号变化。文件内容校验和 Documents 与 CloudKit 间的故障补偿仍由 App 保证，不能将两者当作自动跨系统事务。

## 11. 空间、性能与文件操作边界

### 空间

- 备份新增空间：SQLite 快照 + 尚未复用媒体 stage + iCloud 本地缓存可能占用的拷贝 + 余量。旧资料已占空间不再重复计入「剩余空间需求」，UI 同时说明总占用。
- 恢复额外空闲空间：完整新数据集 + 尚未在本机物化的 iCloud 下载缓存增量 + SQLite 迁移工作空间 + 余量。当前数据保留在原地成为 previous；不能假定 APFS 克隆一定省空间。
- 初始余量建议 `max(256 MiB, 预计新增字节的 10%)`；实际复制仍需捕获 ENOSPC 并保留旧数据，估算不作为成功保证。大文件空间持续检查。
- 最近一份 previous 不自动按时间删除；下一次恢复成功后可清理上上份，或用户明确清理。空间不足时不偷偷删掉当前唯一回退点。

### 性能

SHA-256/SQLite 快照处理在后台 isolate 或 native worker，I/O 按流；初始一条大文件传输管线、有限元数据并发，不无限并发解码/读入。逻辑元数据变化不要求重新上传未变视频。进度分阶段报告已处理/待处理字节，不把文件数量百分比包装成真实传输百分比。

### 首版文件操作边界

不引入可携带备份包、ZIP64 打包/解包、备份文件类型关联、导出备份或从文件恢复的接口。新备份界面移除现有「保存到文件」入口；后续实施删除仅供该入口使用的原生方法与相关测试，避免遗留不可达功能。

此决定不影响角色资产的日常文件导入、角色卡导出、云端文件下载、恢复暂存目录及内部恢复前副本。这些仍按各自现有或拟议合同工作。

## 12. 旧备份兼容

LegacyBackupReader 只读探测原 `Documents/ochome-backup` 及已知历史位置；不触发旧 native backupRoot 的移动删除。优先当前已知旧槽，多个槽存在时列成不同候选，不能合并。

| 输入 | 处理 |
|---|---|
| format 1/2、schema 3–8、文件齐全 | 校验已知大小/结构；迁移 staging 后允许审核 |
| 真正无 manifest 的已知旧布局 | 从 SQLite 查询实际引用，按确定映射下载；齐全才允许，标有限完整性保障 |
| manifest 存在但 JSON/结构损坏 | 明确损坏，不降级为无清单成功 |
| 网络错误 / 未发现 manifest | pending/retry；不能把未知误判为不存在 |
| SQLite / manifest schema 不一致 | 明确不一致，拒绝覆盖，不能只检查范围 |
| schema <3 / 比当前新 | 仍拒绝；不能修改 user_version 来绕过 |
| 旧文件缺少摘要 | 用原有大小和数据库/文件结构验证；新计算的摘要只保护本次迁移后的内容，不证明历史原文件未被更改 |
| 丢失必需封面/资产 | 拒绝完整恢复；部分救援工具留作单独设计 |

新备份不会更新或删除旧槽。App 降级不保证自动识别 datasets 新布局，应避免降级写入；本次功能上线需明确版本切换与回滚方式，不能只回退 Dart 文件。开发回滚必须保留新旧数据，使用用户选择的受支持备份迁移。

## 13. 测试与落地限制

详细矩阵在 `implement.md`。关键实现前验证项：Online Backup API 的 isolate/取消行为、同卷 durable replace、NSMetadataQuery/上传状态刷新、身份材料的设备迁移行为。这些有明确验收结果才推进对应阶段；若平台证据不足，保持 pending/禁用清理，不以乐观假设代替数据安全。

方案已对照当前代码与官方合同；尚未实施、未运行 v3 真机流程，不应把设计不变量当成已经验证的产品保证。


## 14. 全链路可视化合同（用户追加需求）

完整定义见 `visual-experience.md`，其内容目录、时间和进度合同是本设计的组成部分。v3 尚未实施，直接增补必需的 contents.json，不另造已发布版本。SnapshotBuilder 从同一 DB 快照派生内容索引；manifest 绑定摘要，上传确认集合包含索引。恢复前重算比对，不能只信 UI 目录。

新增 SnapshotContentsReader 与 JobEventStore 责任：前者按快照返回角色、属性名称/顺序、历史数量、文件显示名/所属/大小，支持分页；后者持久化 operationId、事件 sequence、阶段和时间。旧备份用隔离读取的旧 DB 派生目录，不读取当前本机资料补齐。

进度分别描述逻辑完整量、需传量、复用量、本阶段已测量量。unknown 为 null，不把文件数量百分比冒充字节进度，也不将阶段 100% 当成任务完成。完成回执只补充时间展示，不改变 commit 的可恢复性定义。


## 15. 摘要预计算与缓存（性能方案增补）

采用用户提出的导入时计算、落库保存、备份优先比较摘要的方向；算法继续使用 SHA-256。完整合同在 `research/digest-caching.md`，H01–H10 纳入实施验证。

摘要是可重建索引，推荐放在现有本地控制账本 SQLite 的 file_fingerprints 表，统一覆盖 covers 与 role_assets，并用 datasetId + 相对路径 + 不可变内容身份隔离。角色 schema 8 不为此单独变动；导入中断或缓存缺失必须安全退化成重新计算。

导入计算与复制共用一次源读取；已知未变化媒体的后续备份不重复全量哈希。真正上传所需的读取、恢复写入准备区所需的读取仍计算并核对实际摘要；缓存一致不能代替当前内容验证。重命名不重算，替换内容失效重算，历史文件惰性补算，数据库/manifest/contents 每次新生成后计算。

元数据 fast path 不声称排除静默磁盘损坏，UI 分别显示“复用”与“本次实际校验”。实际耗时与设备、数据总量有关，实施阶段用真机验证；后台 worker 降低 UI 阻塞，不承诺零 CPU/I/O/耗电成本。


## 16. 产品规则确认

用户已同意损坏数据先重试、仍失败由用户换选有效备份、校验失败不覆盖本机，首版不做部分恢复；同意本机保留 1 份恢复前副本并提供清理入口。云端明确按账户合计 3 份。相关产品问题已关闭，账户级技术验证仍属后续实施工作。
