# 首页进入备份页：定向检查

用户要求启动 subagent 检查，本轮只读检查代码，未修改业务实现，也未读取真实用户数据库或操作 iCloud。

## 已确认触发链

1. `initializeDataStorage()` 使用 `allowRecovery: true`。
2. `DataStorage.open()` 将 `_recover()` 抛出的异常转为 `isRecoveryOnly = true`，仍返回 storage 对象。
3. `MyApp` 在该状态下使用 `/backup` 初始路由；router redirect 持续限制进入其他页面。
4. 健康冷启动的默认路由仍为 `/archive`。目前没有用户运行时的 `recoveryError` 证据，不能断言具体是数据库损坏。

## 已纠正的初步判断

初步 subagent 只看到 AppDatabase 存在 from < 3 分支，误认为可以安全迁移。复核发现该分支实际删除 role 表后重建，会丢失角色，不能据此放开启动检查。继续保护 schema < 3；schema 3–8 可正常进入既有迁移。

## 测试缺口

首页 widget 测试直接挂载 MyApp 并使用 fake repository，没有经过真实 AppStorageBootstrap；真实存储/provider 集成测试没有挂载 MyApp/router。需补“启动→存储状态→路由”的联合测试，覆盖健康冷启动、受支持旧库、故障恢复入口与切换后路由。

## 下一步

截图后已开始实施：明确完整性错误才进入 recovery-only，一般原生/文件系统/SQLite I/O 错误交给启动错误页并提供错误详情。25 项存储和完整 bootstrap→router 回归通过。

真机只读目录证据：现有 ochome.sqlite 约 28 KB，storage-control 有正常 legacy epoch0 的 active.json.pending，但无 active.json。这说明本次数据库健康检查已通过，失败发生在原生指针原子替换完成之前；schema 版本不是此次首要原因。继续取得具体原生异常并修复，不能以仅更换错误页作为完成。

## 最终根因与真机验证

原始错误是 `PlatformException(unsafe_path, 恢复文件必须写入 App 的准备区)`。真机 Foundation 根路径为 `/var/mobile/Containers/Data/Application/<id>/Library/Application Support`；Dart 传入 `/private/var/mobile/.../storage-control/active.json`。目标尚不存在，Foundation 的 resolvingSymlinksInPath 保留了 `/private`，导致 contained 的字符串前缀检查拒绝目标；已存在的 pending 则能正常解析。这是首次原子写指针的路径规范化错误，与 schema 版本和 iCloud 配置错误无关。

`canonicalFileURL` 现在回退到最近存在的祖先解析物理路径，再逐级拼回缺失组件；根、输入与父目录使用同一规范。仍拒绝越界和应用目录内的符号链接。移除了诊断过程中添加的原生路径打印。

已重新构建、安装并通过 Flutter tooling 启动连接的 iPhone 开发版。只读 VM/Widget Inspector 验证：`_recoveryOnly=false`，`_recoveryError=null`；`ArchivePage`、`RoleListPage`、`NavigationBar` 存在，`BackupRestorePage` 不存在。未清空数据库或媒体，未执行云备份/恢复。

最终验证：326 项 Flutter 全量测试通过、76 项 Swift 原生检查通过、静态分析通过。原生 helper 经独立 subagent 复核，未发现路径安全回归。iCloud 配置错误仍是单独的后续验收事项。
