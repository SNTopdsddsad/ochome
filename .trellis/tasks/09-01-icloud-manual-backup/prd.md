# iCloud 手动备份与恢复

## Goal

用户在 iOS / macOS 上手动把本机崽档数据备份到自己的 iCloud，换机或重装后能整份恢复。备份包含 Drift 库（角色 + 设定修订）和立绘 **原图**。

## Background

本机数据现在分两处，都在 Application Support 沙盒：

- Drift 库 `ochome`（`lib/data/database/app_database.dart`，`schemaVersion` 5）：表 `role`、`role_desc_revision`
- 立绘文件：`covers/`，`Role.coverImg` 当前写入 **绝对路径**（`lib/data/services/cover_image_picker.dart` 的 `dest.path`；列表/编辑页用 `File(path)` 读）

不能把正在打开的 sqlite 丢进 iCloud Drive 做实时同步。本任务做 **手动快照备份**，不是 CloudKit 实时同步。

已拍板（会话 2026-09-01）：

- 手动备份 / 手动恢复，不自动后台传
- 立绘必须原图，不压成缩略图当备份
- 封面按文件增量上传；库只保留一份最新快照
- 恢复前比 Drift `schemaVersion`；备份更新则拒绝并提示升级 App
- 恢复经二次确认后 **整份覆盖** 本机（库 + 立绘）
- 只做 iOS / macOS；Android 无 iCloud
- 入口：角色列表进入「备份与恢复」页（不做完整设置系统）

## Requirements

- **R1** 角色列表可进入「备份与恢复」。Android 与其它非 Apple 平台展示不可用说明，不提供备份按钮。
- **R2** 「备份到 iCloud」生成一份最新快照：checkpoint 后的 sqlite + `manifest` + 立绘原图。未改动的立绘文件不重复上传。
- **R3** 「从 iCloud 恢复」先读备份版本，再决定是否覆盖本机。
  - 备份 `schemaVersion` == 当前 App：覆盖后打开
  - 备份更旧：覆盖后由 Drift `onUpgrade` 升级；升级必须保住用户数据
  - 备份更新：拒绝恢复，本机不动，提示升级 App
  - 未登录 iCloud / 容器不可用 / 没有备份：明确错误，本机不动
- **R4** `coverImg` 改为相对路径（相对 Application Support，形如 `covers/<file>`）。选图、展示、备份、恢复都走同一套解析。已有绝对路径在 migration 里改写。
- **R5** 恢复是破坏性覆盖：确认文案说清会替换本机角色、设定历史和立绘；按钮用墨色 + 确认，不用火漆红填充（见主题规范 destructive 合同）。
- **R6** 不把活库文件直接映射到 iCloud。备份时关闭或 checkpoint 后再拷快照。
- **R7** 面向备份的后续 Drift 升级只允许加表/加列/回填，或「拷数据到新表再删旧表」。禁止用删表重建清空还要用的数据。v3 的 `deleteTable('role')` 路径不支持：schema 低于 3 的备份拒绝恢复。

## Acceptance Criteria

- [ ] **AC1** 在已登录 iCloud 的 iOS 或 macOS 上备份成功后，iCloud 容器里能看到一份 sqlite 快照、manifest，以及与本机一致的立绘原图文件（字节级原图，非压缩预览）。
- [ ] **AC2** 第二次备份只上传有变化的立绘；未改动的文件不再全量重传。
- [ ] **AC3** 同版本备份恢复后，角色字段、设定修订、立绘原图与备份时一致。
- [ ] **AC4** 用 schema 4 的备份在 schema 5 App 上恢复：角色仍在，且设定修订表按现有 v5 migration 补上。
- [ ] **AC5** 用比当前 App 更新的 `schemaVersion` 备份恢复：失败提示升级 App，本机角色一行不丢。
- [ ] **AC6** schema 低于 3 的备份拒绝恢复。
- [ ] **AC7** 未确认恢复或恢复失败时，本机库和 `covers/` 与操作前相同。
- [ ] **AC8** 换用相对 `coverImg` 后，列表和编辑页仍能显示本机立绘；绝对路径旧数据升级后也能显示。
- [ ] **AC9** Android 打开该入口只看到不可用说明，不调用 iCloud API。

## Out of Scope

- CloudKit 实时多设备同步
- 自动 / 后台备份
- 多代版本备份（按日期保留多份完整包）
- 备份到非 iCloud 的网盘或自建服务器
- Android / Web / Windows / Linux 云备份
- 分享给其他 iCloud 用户
- 导出设定卡、水印、买断

## Risks

- iCloud Documents 大文件可能处于「未本地下载」状态，恢复时要显式下载。
- 真机 + 登录 iCloud 才能验 AC1–AC3；模拟器不可靠。
- 当前 bundle id 仍是 `com.example.ochome`，上架前必须换成正式 id 并配置对应 iCloud container。
- 首次备份若立绘很多，会耗时、占用户 iCloud 配额；UI 要有进度和失败可重试。
