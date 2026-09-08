# 同一 iCloud 账户合计最近 3 份

2026-09-08 · 用户明确确认：损坏数据按重试/换选有效备份处理；本机保留 1 份恢复前副本并提供清理入口；云端保留数量按账户合计，不按设备分别计算。

产品规则已确定。以下是为满足该规则提出的技术修订，尚未实现/验证，也未改变 Apple 能力配置。

## 1. 用户可见语义

- 一个 iCloud 账户维护一个正常备份列表，所有设备合计最多 3 份完成并登记的快照。设备名称只是来源标签。
- 新备份完整上传并登记成功后，才淘汰最旧的一份。失败、等待上传/登记的任务不挤掉旧的完成备份。
- 「最近」按账户级成功发布顺序定义，不按可能错误的设备时钟排序。内容时间仍单独显示。
- 不增加绕过上限的“永久固定第 4 份”功能。
- 正常保留列表为 3 份；传输暂存、退休对象等待删除、正在恢复所需保护和旧版迁移残留可能暂时额外占空间。不能承诺 iCloud 任意瞬间都只有 3 组物理文件。
- 清理原文件前检查所有保留快照及活动任务的引用。多个快照共享的文件不会随其中一条历史记录被删除。

## 2. 为什么不能只改 UI 数字

iCloud Documents 的本地目录发现是最终一致的，设备内的锁不约束其他设备。两台设备各自读一个不完整列表后删除旧文件，可能误删另一台正在上传/恢复的数据。旧的“每 writer 自己保留 3 份、只清理本空间”规则因此撤销。

保留文件按 writer 分路径有助于避免重名覆盖，但路径分区不再决定保留数量或删除权。

## 3. 推荐技术方向：账户目录协调

保留大文件在现有 iCloud Documents 容器；使用同一容器的 CloudKit privateCloudDatabase 管理小型账户目录和发布/清理记录。无需自建服务器或新的用户登录系统。CloudKit 元数据协调与资料实时同步是不同功能，本轮仍不做实时资料同步。

当前工程仅声明 CloudDocuments。实现前需验证 CloudKit 能力、私有 custom zone、开发/生产 schema、账号可用性与错误处理。这里尚未配置或部署任何能力。若验证不通过，新流程不能悄悄退回“每设备 3 份”。

关键合同：

初始化时两设备可能同时创建同一目录，必须使用确定记录 ID 并在创建冲突后读取现有记录。CloudKit 对象非空不代表账号可用，仍检查 accountStatus。若目录缺失但已有 v3 内容，进入目录恢复/待检查状态，禁止把它当全新空账户直接清理旧内容。

- 单一 `BackupCatalog` 记录维护 `format`、单调 `nextSequence`、`activeSnapshots[最多3]`、有界活动任务/保护引用。
- 每条 snapshot ref 绑定 snapshotId、writerId、commitSha256、manifestSha256 和账户发布 sequence；内容仍由文件清单校验。
- 更新从服务器获取的记录，使用 `ifServerRecordUnchanged`。发生 `serverRecordChanged` 后重新取数、重新计算、重试，不能直接覆盖服务器记录。
- 发布收据、退休记录和目录更新在同一私有 custom zone 中通过原子记录修改关联。高体积文件引用留在不可变 manifest，不塞入单条 CloudKit 记录。
- 新的 native `AccountBackupCatalog` 接口负责 reserve / publish / list / claimCleanup / finishCleanup。云目录写入完成不替代媒体校验。

这是推荐方案，需要阶段 1 的真实双设备技术验证；不把 SDK 的单区记录原子性扩大为 CloudKit 与 Documents 跨系统事务。

## 4. 并发发布协议

1. 构建一致本地快照，取得期望摘要和不可变对象引用。
2. 复用现有云对象前，读取账户目录并条件登记 reservation，固定本次使用的基底快照引用。已经退休、无法再登记保护的对象不允许从旧本地缓存“复活”；改用新 objectId 上传本机完整原件。
3. 将新增内容、DB、contents、manifest 和 commit 上传到新路径，等待必要上传确认；reservation 持久化，保护被本次复用的基底文件。
4. CAS 发布到账户目录：分配账户 sequence，将新快照加入 active，保留 sequence 最新的 3 项，并产生旧快照退休记录。发布回执以 operationId/snapshotId 去重，网络响应不确定时先查询回执，不能重复占用名额或把已退休快照重新当作新发布。
5. 成功后才向 UI 返回任务完成。文件已上传但目录登记失败时显示“等待备份完成确认”，保留旧 active 列表。
6. 一个设备发布成功、另一个同时发布遇到冲突时，后者重取目录计算，最终所有设备收敛到同一 3 项集合。

reservation 使用有期限的服务器可确认租约/代次，持续运行时续期；过期或取消后旧任务必须重新获取许可并检查所有引用。迟到的 iCloud 文件传输不能仅凭出现一个旧 commit 文件就重新进入 active 列表。时间不可靠时停止清理，不擅自判保护已过期。

## 5. 安全清理与恢复保护

- 任何当前登录该账户的新版本设备都可以执行已登记的退休清理；不要求原备份设备仍在线。
- 清理先读取权威 active 和有效 reservations，再读取受摘要绑定的清单，计算可达对象。读取不完整、清单未知、账号变化或索引冲突时不删。
- GC claim 必须通过条件更新登记。允许新任务引用的对象只能来自 active 或它已登记保护的集合；进入不可逆退休状态的 objectId 不允许被重新引用。重现相同字节时使用新 objectId，避免旧删除传播。
- 清理任务记录是独立、幂等、可重试的；失败不会把已经成功的新备份改成失败，也不会回滚目录到更旧版本。
- 账户目录可将老快照从正常列表退休，但它的文件若被有效恢复/上传租约引用，继续保留。恢复本身完成/取消后释放保护。
- 恢复先固定账户 snapshot ref 并取得保护；下载、完整校验、用户确认和本地切换沿用现有方案。保护过期后必须重新核验，不自动覆盖本机。
- 单纯删除 manifest 不能证明其对象可删；禁止根据一次本机目录枚举跨设备清理文件。

初版可继续仅在同 writer 的对象中查找复用候选，但保留与引用保护是账户级；不因此变回按设备分配名额。跨设备内容去重不是此次规则变更额外承诺的能力。

## 6. 旧备份与故障边界

原旧槽仍按只读兼容处理。验证并迁移成 v3 的旧备份可登记到账户列表，受同一 3 份规则约束；不能在新副本确认之前删旧槽。旧格式残留不作为额外正常历史记录长期展示，应明确列出兼容/待清理状态及额外占用。

旧版 App 不理解账户目录，不能靠新协议阻止它继续写旧槽；因此不能承诺跨旧版本的物理文件硬上限。不得把其可变目录直接交给新 GC 盲删。迁移和残留清理需独立验证，不影响已确认的账户级正常备份上限。

目录离线时可查看带缓存时间的历史列表；不得基于缓存执行全局退休或清理。CloudKit 账户目录不可用时新发布保持待确认，已存在的完整文件不因此删除。

## 7. 技术验证门槛

- G01 两台设备都从相同 catalog revision 开始发布，最终 active 合计恰为最近 3 份，不是各自 3 份。
- G02 两设备时钟相差一天，保留顺序仍由账户发布 sequence 决定；内容时间各自如实显示。
- G03 上传失败、目录 CAS 失败、响应丢失和重复请求不会误淘汰旧备份、产生重复名额或复活过期快照。
- G04 新备份使用的共享对象、另一设备正在恢复的对象不会被并发 GC 删除。
- G05 原创建设备离线/卸载后，当前设备仍能根据账户退休记录安全清理；未知状态不删。
- G06 任务 reservation 过期后迟到回调、后台传输和旧缓存不能重新引用已退休对象。
- G07 开发/生产 schema、CloudKit 与 Documents 双能力、账号切换、限流/配额错误、native 生命周期均在真实 Apple 环境验证。
- G08 物理删除延迟、保护中的退休文件及旧版残留在 UI 中不冒充额外正常备份，也不把尚未释放的空间说成已释放。

## 参考与证据范围

[Apple savePolicy](https://developer.apple.com/documentation/cloudkit/ckmodifyrecordsoperation/savepolicy) 说明按 record change tag 条件保存；[recordChangeTag](https://developer.apple.com/documentation/cloudkit/ckrecord/recordchangetag) 描述服务端修改版本标识。条件目录、reservation/保护及跨 Documents 清理协议是本项目设计，不是 SDK 自动完成的保证。

[Apple privateCloudDatabase](https://developer.apple.com/documentation/cloudkit/ckcontainer/privateclouddatabase) 说明该数据库属于当前 iCloud 用户，数据计入其 iCloud 配额；[Apple isAtomic](https://developer.apple.com/documentation/cloudkit/ckmodifyrecordsoperation/isatomic) 将原子修改限定于支持 atomic 的同一 record zone。

此次只核对文档和本地配置，未执行 CloudKit 写入、schema 部署或多设备实验。
