# 实施交付与验证记录

2026-09-08。代码已实现并通过下列本机检查；任务仍为 `in_progress`，等待真实 Apple 环境和用户验收。本轮已按用户要求提交本地；未推送、部署 schema 或操作用户云端备份。

后续首页回归修复：原生路径检查错误拒绝尚不存在的 `/private/var/.../active.json`，现已修复并在连接的 iPhone 上重新安装启动，确认显示角色首页。最新全量 Flutter **326 项**、Swift **76 项**及静态分析通过；详见 `research/home-backup-routing.md`。这次启动真机验证不代表双设备 iCloud 备份/恢复验收通过。

## 已实现

- iCloud v3 不可变快照、共享媒体复用；CloudKit 私有账户目录 CAS、发布回执和引用保护，账户合计保留最近 3 份完成备份。
- 导入原文件时流式计算 SHA-256，本地派生 SQLite 缓存；未变化文件复用摘要，实际上传和恢复校验内容字节。
- 独立恢复准备区、完整性和业务数据校验、准备完成后的明确确认；持久数据根指针、连接切换、失败回退、恢复前本机副本与清理。
- 损坏本机数据库/指针进入恢复入口，保留故障证据，不通过创建空数据库掩盖错误。
- 备份范围与历史角色/文件目录、来源设备、真实阶段/文件进度、时间、等待/失败/重试及结果；离开页面后任务由应用持续持有。
- 旧格式只读恢复兼容；移除生产界面的手动备份文件导出/导入。
- backend/frontend 规格、导航/文件管理约定、README 和原生配置说明同步。

## 自动验证

| 检查 | 结果与边界 |
|---|---|
| `flutter analyze --no-pub` | 最终检查通过，0 issues |
| `flutter test --no-pub --reporter expanded` | 全量 318 项通过；包含真实 SQLite、数据根切换、真实 Riverpod provider 集成、核心 fake-cloud 故障测试和 widget 测试 |
| 原生独立 Swift 检查 | 72 项通过，临时目录和内存 CloudKit 记录仓库；见 `native-validation.md` |
| iOS/macOS Swift typecheck | 使用实际平台框架通过；不能替代签名及云端运行 |
| iOS unsigned debug build | 最终增量构建通过（9.8 s），`flutter build ios --debug --no-codesign --no-pub` |
| macOS unsigned debug build | 通过；先运行 `flutter build macos --debug --no-pub --config-only` 补齐生成配置，再以 `xcodebuild` 关闭签名构建 |
| `git diff --check` | 通过；Trellis implement/check 上下文验证也通过 |

重点回归包括：旧快照不被失败上传破坏、等待云同步不显示完成、同长度损坏拒绝、空文件恢复、未变化媒体复用、取消排空、发布响应丢失幂等、当前终态仍在落盘时下一操作排队、恢复确认不能越过取消、准备后编辑要求重新确认、旧 repository 拒绝写入新会话、损坏库仍能准备并确认有效恢复、清理未知状态保留证据。

独立审查发现的原生进度计数丢失、等待阶段时间线提前完成、旧备份恢复空间预检查、真实 provider 切换覆盖、恢复来源设备和 README 缺失均已修正并纳入最终验证。

macOS 构建命令：`xcodebuild -quiet -workspace macos/Runner.xcworkspace -scheme Runner -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath build/macos-unsigned CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build`，退出码 0。首次缺少 Flutter 生成 file-list 的构建失败，补齐 config-only 后重跑通过；构建生成的 macOS CocoaPods 版本标记变动已撤回。构建产物为 `build/macos-unsigned/Build/Products/Debug/ochome.app` 与 `build/ios/iphoneos/Runner.app`，均非发布签名包。

## 1 GiB 主机性能探针

可复现脚本保存在 `research/streaming-performance-test.dart.txt`，原始输出见 `research/streaming-performance-result.txt`。以 Flutter test 主机执行，生成 64 KiB 分块数据，测试后删除临时文件；没有读取用户资料或执行云传输。

| 指标 | 本次观测 |
|---|---:|
| 原文件体积 | 1,073,741,824 bytes（1 GiB） |
| 流式复制并计算 SHA-256 | 9,383 ms |
| 缓存摘要查询 | 4,921 μs（约 4.9 ms） |
| 强制重新读取并校验 | 6,977 ms |
| 主测试进程采样 RSS | 176,324,608 → 202,817,536 bytes（增加约 25.3 MiB） |
| 20 ms 定时器最大观测间隔 | 1,119 ms |

单次主机结果只验证该样本的处理路径，不能证明多种体积下内存增长曲线、真机帧率、耗电或 iCloud 吞吐。定时器出现长间隔，不据此宣称 UI 无卡顿；还需 profile/release 真机测量。

## 尚未完成的发布验收

1. Apple Developer 容器能力与 provisioning profile，CloudKit Development/Production schema 的真实配置检查。
2. 两台同账户设备的并发备份、交叉发现/恢复、合计 3 份与清理、账号变化、配额不足和断网恢复。
3. iPhone/Mac 上数 GB 资料的内存/帧率/耗电/低磁盘/后台暂停测试，以及实际 kill/relaunch 覆盖全部提交边界。自动故障夹具不等于每个真实进程边界均已验证。
4. 用户界面和旧真实备份兼容验收。

上述检查属于发布门槛，当前交付为开发实现。新入口使用真实 native 服务；配置不可用/状态未知时返回错误或等待，不能改用 fake 服务、按设备 3 份或虚假成功。实际 Apple 配置、双设备结果与签名均未被本次自动测试替代。

## 工作区

本轮功能改动已提交本地，提交记录见下文。保留原先存在的 `ios/Podfile.lock` 修改与 `devtools_options.yaml`，不将其冒认为本轮功能变更。Trellis 任务不归档，后续验收结果追加至本记录。


## 本地提交记录

用户明确要求代码 commit 到本地；按仓库模块规范拆分，未推送远程。

- `6cadb13` 依赖: 增加文件摘要计算依赖
- `0901183` 应用: 增加可视化云备份与完整恢复
- `358343e` iOS: 增加安全云备份与本机资料切换
- `83d7982` 桌面: 接入云备份与资料恢复能力
- `98daeac` 测试: 验证备份恢复与正常首页启动
- `a780262` 测试: 修复缩略图失败用例的并发不稳定
- `8cd645d` 文档: 说明云备份使用与平台验收要求

规格与本任务记录随最后一笔 Trellis 提交保存。任务继续保留 in_progress，等待真实双设备 iCloud 验收；本地提交不代表已完成发布验收。原有 ios/Podfile.lock 修改和 devtools_options.yaml 未纳入。
