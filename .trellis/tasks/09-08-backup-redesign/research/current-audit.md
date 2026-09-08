# 现有备份审计与研究证据

2026-09-08；基线 `ba39fb5`；原有工作区改动为 `ios/Podfile.lock` 和未跟踪的 `devtools_options.yaml`，未触碰。业务代码未修改。

## 当前调用链

`BackupRestorePage → ICloudBackupService → SqliteSnapshotter / CoverStore / RoleAssetStore → MethodChannelICloudContainer → iOS/macOS ICloudChannelHandler`。

备份：checkpoint → 复制活库主文件 → 枚举本地立绘并按长度上传 → 删除云端多余立绘 → 按快照引用上传资产 → 覆盖 SQLite → 覆盖 manifest → 删除云端多余资产。

恢复：下载 manifest / SQLite → 版本范围判断 → 下载立绘与资产 → 关闭活库 → 依次替换 covers、role_assets、SQLite → 删除备份目录 → invalidate providers。

## 问题定位

| ID | 优先级 | 证据与触发条件 | 位置 |
|---|---|---|---|
| F01 | P1 | 另一设备具有不同本地立绘集，新备份在 SQLite 上传处失败；旧云端清单所引用的立绘已被删除。假云环境、实际服务复现。 | `lib/data/services/icloud_backup_service.dart:125` |
| F02 | P1 | `coordinatedCopy` 先 remove 旧目标再 copy；copy 失败旧文件已丢失。单文件协调不能补偿此前的多文件改动。源码确认。 | `ios/Runner/ICloudChannelHandler.swift:310`，macOS 同实现 |
| F03 | P1 | `upload` 在本机复制结束返回，没有上传状态/错误观察；Dart 随即显示「已备份到 iCloud」。源码确认，未用真实账号断网复现。 | iOS handler `:149`；`lib/pages/backup_restore_page.dart:95` |
| F04 | P1 | manifest 预期 4 字节的立绘下载为 1 字节仍通过；`minBytes` 只用于决定是否检查等于零。实际服务复现。 | `icloud_backup_service.dart:276,383` |
| F05 | P1 | 服务/规范允许零字节文档；原生 `isMaterialized` 各分支都要求 size > 0，且 download 末尾拒绝零字节。提取原函数对本地空文件得到 false，1 字节得到 true。 | iOS handler `:159,282`，macOS 同实现 |
| F06 | P1 | 备份页 `canPop: true`；`_busy` 局限页面；恢复下载后仅更新 UI 时检查 mounted，随后依然 close/commit。旧页面异步任务与新页面任务可以重叠。源码路径确认，尚未跑专门导航竞态测试。 | `lib/pages/backup_restore_page.dart:28,146,170,243` |
| F07 | P1 | 20 分钟 `Future.timeout` 只停止等待，底层下载继续；catch 会删除 staging，旧异步工作可能继续写同一目录。源码与官方 API 合同确认。 | `backup_restore_page.dart:158,186` |
| F08 | P1 | 多目录/数据库没有持久化提交记录；进程退出后没有自动恢复入口。SQLite 新文件换入之后删除 .bak 异常会外抛，外层又回滚媒体，可能变成新库配旧媒体。源码路径确认，未做故障注入。 | `sqlite_snapshotter.dart:104,119`；`icloud_backup_service.dart:328,335`；`lib/main.dart` |
| F09 | P1 | 缺少文件摘要、SQLite 完整性/业务数据验证和在切换前演练 migration；现存 manifest 解析错误被吞成 null。未来格式号也未成为明确门禁。 | `backup_manifest.dart`、`restore_version_gate.dart`、`icloud_backup_service.dart:439` |
| F10 | P2 | FULL checkpoint 的 busy 返回未验证，checkpoint 与主文件复制间没有保护并发写。当前 UI 可以返回并写入，不能把这种复制普遍视为一致快照。未复现数据库撕裂。 | `sqlite_snapshotter.dart:13,18` |
| F11 | P2 | covers 取全目录，资产取 DB 引用；弃用封面也上传。两类引用规则不统一。 | `icloud_backup_service.dart:112,132` |
| F12 | P2 | 只枚举本机目录，无法完整描述云端未发现/占位文件；把 .icloud 文件长度当原始内容长度不可靠。发现空、等待、下载错误和无备份混用。 | 原生 `list`；`icloud_backup_service.dart:366,455` |
| F13 | P2 | backupRoot 查询会搬迁旧文件，甚至移除 legacy 目录；不是纯读取。迁移集合还未包含 loose-documents role_assets。新设计不复用这一隐式迁移行为。 | 原生 `backupRoot / migrateLegacyBackup / migrateLooseDocuments` |
| F14 | P2 | 「保存到文件」是云端散文件的系统导出，无反向导入，macOS 只是 Finder 定位；跨平台语义不同。 | 两端 `exportToDrive`；`backup_restore_page.dart:305` |

## 验证记录

同会话上一轮已运行 `flutter analyze --no-pub`：通过。全量 `flutter test --no-pub`：234 通过、1 失败，失败为缩略图测试对并发顺序的假定；相关 7 项单独重跑通过。它不是本次备份重设计的缺陷证明。

备份临时实验使用实际 `ICloudBackupService`、临时 SQLite/媒体与 `FakeICloudContainer`，不访问真实 iCloud。两个针对期望安全行为的断言均失败：

- `restore rejects nonempty truncated cover`：预期拒绝，实际返回了恢复计划。
- `failed next backup preserves previous cloud snapshot`：预期保留旧立绘，实际该键已不存在。

保留源代码文本与输出：`backup-failure-probe.dart.txt`、`backup-failure-probe.log.txt`。可复制为临时 `.dart` 后在项目根目录运行 `flutter test --no-pub /tmp/ochome-audit-backup_test.dart`。其中假对象使用当前工作区绝对路径，移机后需调整。

原生函数实验 `empty-file-probe.swift.txt` 提取当前 iOS 的 `isMaterialized`，只对临时本地文件调用。输出 `zero-byte ... false`、`one-byte ... true`。这证明错误判断条件，不替代 iCloud 真机测试；下载末尾的零字节拒绝另由源码证明。

## 官方资料与设计依据

1. [SQLite Online Backup API](https://www.sqlite.org/backup.html)：正式接口能生成一致快照，支持分步执行。项目已经安装的 sqlite3 3.5.2 提供 `Stream<double> Database.backup(Database toDatabase, {int nPage = 5})`，首选复用，无需为快照新引入整套数据库库。
2. [SQLite VACUUM INTO](https://www.sqlite.org/lang_vacuum.html)：另一种一致快照方式，可紧缩数据库；更耗 CPU、不能位于已开启事务内，中断后的输出不能发布。作为替代而非同时维护两条主路径。
3. [Apple iCloud File Management](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/iCloud/iCloud.html)：使用元数据查询发现云端文件，并考虑多设备版本冲突。不能把本机一次目录枚举作为完整云端视图。
4. [Apple 上传完成状态](https://developer.apple.com/documentation/foundation/nsmetadataubiquitousitemisuploadedkey)：该状态表示上传到云端；本机 copy 完成不等于此状态。设计额外要求相关文件及提交标记都被确认。
5. [Apple replaceItemAt](https://developer.apple.com/documentation/foundation/filemanager/replaceitemat(_:withitemat:backupitemname:options:))：支持同卷文件替换和备份选项；不能因此推断整个 iCloud 文件夹具备跨设备原子事务。
6. [Dart Future.timeout](https://api.dart.dev/dart-async/Future/timeout.html)：源 Future 在超时后仍能完成，因此需要真正的任务取消和写入隔离。
7. [restic 存储设计](https://github.com/restic/restic/blob/master/doc/design.rst)、[Borg Quick Start](https://borgbackup.readthedocs.io/en/stable/quickstart.html)：完整逻辑快照与底层内容复用可以分离。这里只借鉴这种结构；不引入这些程序、不照搬其仓库锁，也不宣称实现分块去重或其加密能力。

设计中的分写入者空间、3 份保留、恢复前副本、状态机和提交记录均为本项目建议，不是 Apple/SQLite 文档规定。


## 后续范围决定

用户明确不需要手动导出完整备份文件和从文件恢复。F14 保留为现有代码的事实记录，不再作为补齐文件导入功能的依据；新界面将移除旧「保存到文件」入口。
