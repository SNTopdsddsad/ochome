# Implement: iCloud 手动备份与恢复

按序做。前一步未验证不要开始后一步。未执行 `task.py start` 前不改产品代码。

## 0. Preconditions

- 开发者在 Xcode 为 iOS、macOS 打开 iCloud Documents，填 container id。
- 真机登录 iCloud，用于 AC1–AC3。单测不依赖真 iCloud。

## 1. 封面相对路径（无 iCloud 也可验）

- 改 `CoverImagePicker.savePickedFile`：返回 `covers/<file>`，不是 `dest.path`。
- 增加 `CoverPath.resolve(supportDir, coverImg)`：相对、绝对都处理。
- `role_list_page.dart`、`role_create_page.dart` 展示走 resolve。
- Drift `schemaVersion` 5 → 6：把已有绝对路径改写成相对（见 `design.md`）。
- 测试：选图返回相对路径；旧绝对路径仍能显示；migration 回写相对路径。

验证：`flutter test`；模拟器里选图后杀进程再进列表，封面仍在。

## 2. 本地快照器（无 iCloud）

- `SqliteSnapshotter`：checkpoint + 拷贝 sqlite 到临时文件；读/写 `PRAGMA user_version`。
- 版本闸：比较快照 `user_version` 与 `AppDatabase.schemaVersion`（含 `< 3` 拒绝）。
- 测试用 `NativeDatabase.memory()` 不够（要文件库）：用临时目录文件库测 checkpoint、版本比较、替换后 WAL 清理。

验证：`flutter test` 覆盖 AC5/AC6 的纯逻辑（用夹具 sqlite，不连 iCloud）。

## 3. 平台 iCloud 容器

- Swift MethodChannel：`isAvailable`、`backupRoot`、`upload`、`download`、`list`、`delete`、等待 ubiquity 下载完成。
- iOS / macOS entitlements + Info.plist ubiquity keys（按 Xcode 生成）。
- Dart `ICloudContainer` 接口；Android stub。
- 测试：Android stub；iOS 通道用假实现测 Dart 编排。

验证：真机「备份」能在 Files / 容器里看到 `ochome-backup/`。

## 4. 备份 / 恢复编排 + UI

- `ICloudBackupService.backup()` / `restore()` 按 `design.md` 流程。
- `BackupRestorePage`：备份、恢复、上次备份时间、进度、错误。
- `RoleListPage` AppBar 入口。恢复用墨色确认框（R5）。
- 备份中禁用重复点击；失败 SnackBar + 可再点。

验证：真机 AC1–AC3、AC7；Android AC9。

## 5. 版本夹具与回归

- schema 4 夹具库（无 `role_desc_revision`）走恢复逻辑 + 打开 AppDatabase → AC4。
- schema 7（伪造高于当前）→ AC5。
- schema 2 → AC6。
- 相对路径 + 列表/编辑回归（现有 widget 测试仍过）。

验证：`flutter analyze`、`flutter test`；真机再走一遍备份→删库或换机→恢复。

## Validation commands

```bash
flutter analyze
flutter test
```

真机（登录 iCloud）：备份 → 改一个角色设定 → 恢复 → 设定回到备份点；封面为原图像素。

## Risky files / rollback

| 点 | 风险 | 回滚 |
|----|------|------|
| `app_database.dart` migration v6 | 路径改写错导致封面全丢 | 解析层同时接受绝对/相对 |
| 恢复替换 sqlite | 活库 WAL 混用损坏 | 关连接、删 `-wal`/`-shm`、先写临时再替换 |
| ubiquity 未下载完成 | 恢复到 0 字节图 | 等待下载；失败不替换 |
| entitlements | 真机 `isAvailable=false` | 检查 container id 与 bundle id |

## Commit split（实现阶段，规范见 git-commit.md）

1. `应用: 将立绘路径改为相对路径`
2. `测试: 补充立绘相对路径与升级用例`
3. `应用: 增加 iCloud 手动备份与恢复`（含 Dart 编排与页面）
4. `iOS: 增加 iCloud 文档容器与备份通道`
5. `桌面: 增加 macOS iCloud 文档容器与备份通道`
6. `测试: 补充 iCloud 备份版本闸与恢复用例`

不要把 `lib/` 和 `ios/` 打进同一个 commit。

## Before `task.py start`

- 用户已批准本任务最新规划摘要。
- 不要在本文件写完的同一轮里 `start` 或改产品代码。
