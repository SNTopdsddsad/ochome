# 实施计划与验收矩阵

状态：开发实现已完成，本机全量测试通过；实际证据及尚未完成的发布门槛见 `verification.md`。以下清单保留原阶段粒度：混合真机要求的条目不会仅凭自动测试勾选。接口以 `execution-contract.md` 为准。

## 阶段 1：合同与最小技术验证

- [ ] 将 F01/F04 已复现实验转为正式回归测试，补原生空文件测试；先证实旧实现会失败。
- [x] 定义快照绑定的 contents.json、目录计数/名称合同和时间回执；固化 V01–V12 可视化验收。
- [x] 定义严格的 manifest/commit v3、业务错误、任务状态和传输 request/result 合同；准备有效/无效 fixture。
- [ ] 用现有 sqlite3 Online Backup API 在独立 isolate 验证 WAL 活库快照、取消/异常资源释放；选定一条正式快照路径。
- [ ] 验证 Foundation 同卷 durable replace、小文件指针及进程中断恢复，不能只写 mock 测试。
- [ ] 在 iPhone/Mac 验证元数据发现、占位文件、零字节文件、上传状态刷新和账号变化；确认不随设备迁移的写入资格身份行为。
- [ ] 验证 CloudKit 私有目录 custom zone、ifServerRecordUnchanged、原子回执/退休记录、账号状态与能力配置；执行 G01–G08 双设备验证。未通过时不启用新发布/清理，不回退到按设备保留。
- [x] 原生上传/账户登记状态无法证实时保持 pending；未知状态不授权清理。

退出条件：核心原生合同可执行，有测试及真实平台证据；没有把未验证平台行为写成保证。

## 阶段 2：备份主流程

- [x] 引入 DataSession / MutationGate / 本地持久化 job 与 writer 账本，覆盖所有写入入口。
- [x] SnapshotBuilder 从一致 SQLite 查询引用；封面与资产统一纳入完整性规则。
- [ ] 在资产/立绘导入流中计算摘要，建立本地派生缓存、失效策略和旧文件惰性回填；执行 H01–H10 性能与正确性验证。
- [x] 引用 pin + 不可变原件 + stage 流复制/摘要；pin 不可证连续有效时放弃旧准备任务并重新建快照。
- [x] 新的 Apple 传输核心与小型平台壳；旧云槽只读，不再在 status 查询中迁移旧目录。
- [x] 独立快照、同 writer 对象复用、上传观察、commit 最后发布，支持重试/pending/账号变化。
- [x] 账户统一历史与最多 3 项 active；实施跨设备 reservation/恢复保护、CAS 发布和经授权退休清理。
- [x] 验证 source 文件删改、失败上传、重入、重启和中途取消，旧完成快照始终可恢复。

退出条件：同设备完整往返准备和双设备发现可验证，备份成功文案只由完成状态驱动。

## 阶段 3：恢复与启动切换

- [x] 引入 legacy / datasets 根解析，启动先恢复控制日志再初始化业务 provider。
- [x] 下载/严格校验/业务引用检查/迁移全部在新 dataset 中完成。
- [x] 确认摘要绑定 epoch/revision；有新编辑则重新审核，不沿用旧确认。
- [x] 实现指针切换日志、短时写入门、旧连接关闭、新连接健康检查、数据 ProviderScope 重建。
- [x] 清理 cover 静态根缓存；预览、角色卡导出、picker、repository 同时改为注入当前 DataSession 根。
- [x] 最近一次恢复前副本及切回入口；下一次恢复成功后才允许清理上上份。
- [x] 只读 LegacyBackupReader 覆盖格式 1/2、明确无 manifest、schema 3–8 和历史路径布局。
- [ ] 每个磁盘边界执行 kill/relaunch 故障注入；清理失败与激活失败分离。

退出条件：任何已定义故障点都不会将混合数据开放给业务层；旧数据恢复路径明确。

## 阶段 4：全链路可视化界面与发布验收

- [x] 实现可分页内容目录与角色文件明细，固定历史名称；完成可回访进度、时间记录与结果报告。
- [x] 备份列表、来源设备、完成/等待/损坏状态、阶段进度和错误操作；页面只订阅 coordinator。
- [ ] 下载完成后再确认覆盖；返回/重进/取消/系统挂起交互验证。
- [x] 按用户决定不提供备份文件导出/导入；移除旧「保存到文件」界面及仅供该入口使用的原生方法和测试。
- [ ] 数 GB 媒体低内存/低磁盘实验；记录峰值内存、准备/传输时间和空间增量。门槛：媒体大小增加时不能使内存按媒体总量线性增长；具体可接受时延由设备实验确定。
- [ ] 在两台独立 iCloud 会话设备完成备份→发现→恢复，包括一台本地目录尚无内容的情况；不能以 fake 云替代。
- [x] 更新备份专用 backend spec、frontend 状态/导航约定、README 使用和恢复限制。

退出条件：通过下列矩阵，完成代码审查和用户验收，再讨论发布；本轮不含发布授权。

## 文件影响范围

| 区域 | 现有文件 / 拟新增责任 |
|---|---|
| SQLite | `lib/data/database/app_database.dart`、`lib/data/providers/app_database_provider.dart`、`sqlite_snapshotter.dart` |
| 核心备份 | `icloud_backup_service.dart`、`icloud_container.dart`、`backup_manifest.dart`、`restore_version_gate.dart`、`backup_exceptions.dart`；拆出 coordinator / builder / validator |
| 数据根与文件 | `local_file_store.dart`、`cover_store.dart`、`cover_image_picker.dart`、`role_asset_store.dart`、两个 repository、相关 providers；新增 DataSession、mutation gate、activator |
| UI / 预览 | `backup_restore_page.dart`、`cover_file_view.dart`、`cover_preview_page.dart`、角色卡导出读取根、`role_create_page.dart` 注入；重建数据会话导航 |
| 启动 | `lib/main.dart`、`lib/app.dart`；先 storage recovery 后开放业务 |
| Apple | `ios/Runner/ICloudChannelHandler.swift`、`macos/Runner/ICloudChannelHandler.swift`；拟共用 Foundation backup core，平台 picker 壳分离 |
| 配置 | 同容器 CloudDocuments + CloudKit 元数据能力、私有 custom zone/schema；不引入归档依赖或文件类型关联，业务 schema 不因目录协议单独变化 |
| 规格 | 新建 `.trellis/spec/backend/backup-restore.md`，更新前后端索引和现有 role-assets/role-custom-attributes 合同引用 |

代码变更须按 before-dev 阅读实际相关规格，不能直接把设计文档当成已经落地的 repo 标准。

## 验收矩阵

| ID | 场景与故障注入 | 必须观察到的结果 | 层级 |
|---|---|---|---|
| T01 | 上传任意媒体/DB/manifest/commit 时失败 | 原完成快照所需内容逐字节不变，新记录不冒充完成 | 服务 + native |
| T02 | 本地 stage 成功、uploaded=false/nil、离线/配额错误 | pending/明确错误；无虚假 completed | native + UI + 真机 |
| T03 | 接收端先看见 commit，媒体/manifest 未发现 | 尚未就绪，等待/重试，不能恢复空数据 | transport + 双设备 |
| T04 | 截断文件、同长度不同字节、错误摘要 | staging 校验失败，本机数据不变 | 服务 |
| T05 | 空文档、Unicode/重复显示名、多个格式原文件 | DB 和文件往返一致；空文档不等待到超时 | 服务 + native |
| T06 | 源引用缺文件、封面指向旧绝对路径 | 可确定合法旧路径重映射；无法读取则明确失败 | builder |
| T07 | 备份期间删除/替换被引用资产或封面 | 已 pin 字节保持；逻辑删除可完成，物理清理延后 | repository + gate |
| T08 | 本地源库 WAL 有提交、连续业务写入 | 快照是一个一致时间点，引用与文件符合 snapshot | SQLite |
| T09 | 只改角色文字、重命名资产 | 新 DB/manifest；不重传已确认未变媒体 | 服务 |
| T10 | 点击两次、返回再进入、旧回调晚到 | 同一 operationId 持续显示，禁止竞争任务；旧 epoch 回调无副作用 | UI + coordinator |
| T11 | 下载取消/超时，native 随后才完成写入 | drain 或隔离后清理；不会重建已取消工作区或改 live | native + 服务 |
| T12 | 上传进程退出并重启，stage 完整/不完整 | 完整对象重验续传；不完整 pin 任务安全重建；不重复发布矛盾快照 | coordinator |
| T13 | 恢复准备后又编辑本机角色 | 确认检查 revision，重新展示影响；不得无提示覆盖新编辑 | UI + gate |
| T14 | 恢复下载完成但用户离开/重启 | ready/待审核，不自动激活 | UI + startup |
| T15 | manifest 是错误类型/未知 format/未知必需特性/重复路径 | fail closed，本机不动，不吞错当无清单 | parser |
| T16 | SQLite 损坏/外键错误/错误属性 JSON/非法 asset kind | 准备期拒绝，不等 UI 加载才失败 | validator |
| T17 | schema 3、4、5、6、7、8 升级，v1/v2/无清单 | staging 迁移成功且各字段/历史/属性顺序/文件不丢 | migrations |
| T18 | schema 2、新版 schema、manifest/schema 不一致 | 明确拒绝，本机及旧云槽不动 | validator |
| T19 | intent 写前/写后、active 切换前/后、healthy 前/后 kill | 重启只开放完整旧或完整新；不能静默新建空库 | native + process |
| T20 | 新库健康检查失败 | 写入门内切回完整 old；未开放混合状态 | activator |
| T21 | 激活成功后清理失败 | completed + cleanupPending，不回滚新数据库/媒体 | activator |
| T22 | 带旧 root 的预览/导出/repository 仍持有引用 | 切换先排空或关闭旧会话；新请求一律用新 epoch | cross-layer |
| T23 | 两设备离线各自备份后联网，时钟相差一天 | 两份快照并存、来源清楚，无共同 latest 竞争 | 双设备 |
| T24 | 账户目录/保护信息不完整、未知快照或账号变化 | 停止 GC；不基于本机目录缺项删除共享文件 | retention |
| T25 | 老快照退休但文件被 retained/pending 引用 | 文件不删除；已退休 ID 不重新引用 | retention |
| T26 | 启动、复制中途、迁移中途空间不足 | 清晰错误，current/previous 保持，不自动删回退点 | 文件系统 |
| T27 | 恢复前副本切回，期间发生新编辑 | 确认替换范围后同协议切回；旧副本无需 iCloud | UI + activator |
| T30 | 换 iCloud 账号 / 指定容器不可用 / 冲突版本 | 任务暂停/失败，不自动退回其他容器或混写 | native + coordinator |

## 检查命令与证据

- `flutter analyze --no-pub`。
- `flutter test --no-pub`；平台构建与 Flutter 测试串行运行，避免共享 native-assets 产物竞争。
- 按模块运行有针对性的 Flutter/native 测试；iOS/macOS 构建分别进行。
- `git diff --check`，核对源代码生成文件、规格索引和配置。
- 原生进程故障测试只使用专用模拟器/测试数据目录；真机验收使用明确的测试快照，不覆盖用户日常数据来验证故障。
- 验证记录须区分 mock、源码路径检查、模拟器、真实双设备结果；性能数据记录设备、数据体积和资产种类。

## 实施中回退

新 writer/新目录与旧云槽隔离，未审核/未验证不打开新写入入口。各阶段可通过功能开关退回旧 UI，但不能把已切到新 dataset 的数据交给只懂旧路径的代码写入。若需要回滚版本，必须先验证数据布局兼容并保留两个完整数据根；没有经验证的迁移路径时保留数据、停用不兼容写入，通过修复版继续访问。不能依赖已取消的文件导出功能，也不能删除新根假装回滚成功。


## 用户追加的可视化验收

执行 `visual-experience.md` 的 V01–V12，特别验证同一快照的目录/实际数据一致、百分比来源真实、历史名称不随本机改动、未知时间与完成回执缺失、恢复确认返回路径，以及离开重进的任务连续性。示例原型不替代这些正式 Flutter/native 测试。


用户已取消手动文件备份：原归档验收 T28/T29 撤销，编号不复用。数 GB 原文件的云端传输、内容校验与空间测试仍保留。


## 摘要缓存增补验证

执行 `research/digest-caching.md` 的 H01–H10。通过读取字节计数器验证无变化第二次备份的快路径，同时验证实际上传/恢复摘要不匹配仍会失败。业务缓存、云对象状态和真正内容健康检查必须分开记录，不能把缓存命中当作本次全量文件校验。


## 账户合计 3 份增补

执行 `research/account-retention.md` 的 G01–G08。只有账户目录 CAS、上传/恢复引用保护、幂等发布以及跨设备清理在真实 Apple 环境验证通过，才打开相应写入功能。修订已有“每设备 3 份”“其他设备永不清理”的 fixture 与断言；设备名称只作来源，不决定数量。


## 2026-09-08 实施结点

自动验证通过：318 项 Flutter 测试、72 项原生检查和最终静态分析。流式处理/缓存已实现，1 GiB 主机测量已记录；原阶段中 H/G 全矩阵、双设备、低磁盘与实际进程故障要求仍需真机验收。生产发布门槛保持不变，开发入口按 execution-contract.md 接入实际 native 能力。详见 `verification.md`。
