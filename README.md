# 崽档 · ochome

本地优先的 OC 角色档案应用，使用 Flutter、Riverpod 和 Drift/SQLite。支持角色资料、自定义属性、设定历史、立绘、混合资产及角色卡导出。

## 开发

使用满足 `pubspec.yaml` 中 Dart `^3.13.2` 约束的 Flutter SDK：

```sh
flutter pub get
flutter analyze
flutter test
flutter run -d <设备ID>
```

表定义或带注解的 provider 发生变化后，更新对应生成代码：

```sh
dart run build_runner build --delete-conflicting-outputs
```

当前主要开发和验证 iOS/macOS。iCloud 备份仅用于 Apple 平台；其他平台不提供云备份入口操作。

## 数据保存

角色文字、属性和历史保存在 `ochome.sqlite`；立绘原图在 `covers/`，资产原文件在 `role_assets/`。导入会复制文件到 App 私有空间，数据库记录相对路径与显示信息。

启动先检查 `storage-control/active.json`，再打开对应数据集。已有数据可以继续使用原 Application Support 根；恢复后使用 `datasets/<id>`。请勿手动删除或混合这些目录。

文件导入时流式计算 SHA-256，摘要缓存在本地可重建的 `storage-control/file-fingerprints.sqlite`。后续备份优先复用有效摘要；实际上传和恢复仍核验读取的字节。摘要缓存不等于实时健康检查。

## iCloud 备份与恢复

从档案页右上角云图标进入：

1. 查看本机已保存资料和备份范围，点击“备份到 iCloud”。
2. 进度区展示当前阶段、文件/项目进度和复用量；文件写入或阶段 100% 不代表云端已确认。
3. 同一个 iCloud 账户合计保留最近 **3 份完成备份**，不同设备共享名额。新备份确认后才退休最旧记录，共享原文件只有无引用时才清理。
4. 点开某份历史备份，可浏览备份时的角色/文件目录和时间。历史名称不会跟随本机后续改名变化。
5. 恢复先下载到隔离准备区，检查完整性并升级兼容的旧数据库；用户确认后才切换整套数据。
6. 本机保留最近 **1 份恢复前副本**，可以切回或明确确认后清理。损坏/缺失文件不会被静默跳过；首版不做部分恢复。

首版不提供独立备份文件导出/导入，也不做资料实时同步。返回页面不会创建第二个备份任务；中断后可查看状态并重试。准备完成的恢复不会在重启后自动覆盖本机。

恢复需要容纳新数据集、下载缓存和迁移空间。旧备份退休、系统同步删除、未知归属暂存及异常恢复保留的目录可能暂时额外占用空间；界面提供待清理提示和安全重试。

## Apple 配置与上线前验证

v3 使用同一容器 `iCloud.com.xuwudi.ochome`：Documents 存储大文件，CloudKit **私有数据库**保存账户目录与并发状态。Xcode 目标需要匹配的签名/provisioning，并启用 CloudDocuments、CloudKit；macOS 还需要网络权限。

CloudKit custom zone 为 `OchomeBackupV3`。开发/生产环境需具备：

| Record type | 字段 |
|---|---|
| OchomeBackupCatalog | payload: Bytes |
| OchomeBackupClock | nonce: String |
| OchomeBackupReceipt | payload: Bytes |
| OchomeBackupTombstone | path: String |
| OchomeBackupAbort | payload: Bytes |

不需要自定义查询索引。开发环境可按正常开发流程建立这些类型；面向用户的构建需要部署匹配的 production schema。目录条件更新、回执和保护租约负责多设备一致性，不能用三个互相覆盖的文件代替。

本次代码开发未自动修改远程 schema 或用户真实云端数据。发布前需要真实签名设备、正确 schema、同账户两台设备的备份/恢复，以及断网、配额不足、账号变化和大文件验收。单元测试或无签名构建不能替代这些验证。

## 兼容与安全边界

- 原单槽备份通过只读兼容入口读取，不在查询时自动移动/删除原目录。
- 支持的旧数据库 schema 为 3–8；未知或过新版本明确拒绝。旧备份缺少历史摘要时，不能承诺发现所有同大小内容变化。
- 原文件损坏时先重试，仍失败则选择其他有效备份；复用同一原文件的多个快照不等于多份独立原件。
- 资料控制或当前数据库损坏时进入只恢复模式，保留文件并允许有效云端恢复，不自动创建空库掩盖错误。
- 正常取消可以回收可证明属于该未发布操作的上传文件；已发布或归属不明确的内容不会冒险删除，状态会保留待清理。

项目开发流程、实现合同和测试矩阵见 `.trellis/workflow.md`、`.trellis/spec/backend/backup-restore.md`、`.trellis/spec/frontend/backup-restore.md`。
