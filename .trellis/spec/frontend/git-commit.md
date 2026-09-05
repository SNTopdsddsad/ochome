# Git Commit Convention

> 本仓库所有人工 / AI 提交必须使用中文，并按「模块 + 功能声明」拆分。

---

## Format

```
模块: 功能声明
```

- 标题只用一行，不用英文 Conventional Commits 前缀（不要 `feat:` / `fix:` / `chore:` / `docs:`）。
- `模块` 是变更所属目录或能力边界，不是文件名。
- `功能声明` 用中文说明「做了什么」，不写「怎么做」、不堆文件列表。
- 一个 commit 只覆盖 **一个模块里的一项功能**。跨模块必须拆成多次提交。
- 需要补充说明时，空一行后写中文正文（条目化）。标题已经能说清的，不要正文。

---

## Module Names

按变更落点选模块。没有对应项时，先新增模块名再提交，不要塞进「其他」。

| 模块 | 适用范围 |
|------|----------|
| 应用 | `lib/` 业务代码、页面、状态、主题 |
| iOS | `ios/` 原生工程、签名、权限、启动图 |
| Android | `android/` 原生工程、Gradle、权限、图标 |
| 桌面 | `macos/` `linux/` `windows/` |
| Web | `web/` |
| 测试 | `test/` 以及各平台测试目录 |
| 依赖 | `pubspec.yaml` `pubspec.lock` |
| 资源 | `assets/` 字体、静态资源及其授权说明 |
| Trellis | `.trellis/` `.grok/` `AGENTS.md` `.gitattributes` |
| 技能 | `.agents/skills/` 项目级技能及配套资源 |
| 文档 | `README.md` 及其他给人看的说明 |

同一批改动同时碰到 `lib/` 和 `test/`：先提交 `应用`，再提交 `测试`。  
只为某个功能补测试、没有应用代码：只提交 `测试`。

---

## Feature Statement

功能声明必须能单独读懂，遵循：

1. 用动词开头：增加 / 修复 / 调整 / 移除 / 初始化 / 拆分
2. 写结果，不写过程（不要「改了几个文件」「更新代码」）
3. 修复类写清「修了什么现象」，不要只写「修复 bug」
4. 不超过 40 个汉字

---

## Split Rules

提交前先按模块分组，再按功能分组：

1. **先按模块拆**：`lib/` 与 `.trellis/` 不能进同一个 commit。
2. **再按功能拆**：同一模块里互不依赖的两件事，拆成两次提交。
3. **一次功能一个 commit**：同一功能的实现、配套资源和必要的配置可以在一起；无关重构单独提交。
4. **不要按文件拆**：一个功能改了 5 个文件，仍然是 1 个 commit。

配合 Trellis Phase 3.4：先给出提交计划（每条 = `模块: 功能声明` + 文件列表），确认后再执行。本规范覆盖「跟 git log 学风格」——即使历史里还有英文提交，新提交也必须用本格式。

---

## Good / Bad

### Good

```
应用: 增加首页下拉刷新
认证: 修复登录过期后无法回到登录页
测试: 补充计数器点击用例
Trellis: 增加中文按模块提交规范
依赖: 升级 flutter_riverpod 到 2.6
```

### Bad

```
feat: add pull to refresh
update files
fix bug
首页和认证: 刷新加登录修复
应用: 改了 main.dart 和几个 widget
```

| 反例 | 原因 |
|------|------|
| `feat: add pull to refresh` | 英文 + Conventional Commits 前缀 |
| `update files` | 没有模块，没有功能 |
| `fix bug` | 没说修了什么 |
| `首页和认证: …` | 两个模块混在一次提交 |
| `应用: 改了 main.dart` | 写了文件，没写功能 |

---

## Trellis Auto-Commits

脚本自动提交也尽量贴近本格式：

| 来源 | 文案 |
|------|------|
| `add_session.py` | 使用 `.trellis/config.yaml` 的 `session_commit_message`：`Trellis: 记录会话日志` |
| `task.py archive` | 脚本当前写死 `chore(task): archive <task>`。不要为了改文案去改 Trellis 脚本；若本次是手动归档，用 `Trellis: 归档任务 <任务名>` |

---

## Wrong vs Correct

#### Wrong

```bash
git add -A
git commit -m "feat: init trellis and update app"
```

一次提交混了 Trellis 和应用，而且是英文。

#### Correct

```bash
git add .trellis/spec/frontend/git-commit.md .trellis/spec/frontend/index.md
git commit -m "Trellis: 增加中文按模块提交规范"

git add lib/main.dart
git commit -m "应用: 初始化默认计数器页面"
```
