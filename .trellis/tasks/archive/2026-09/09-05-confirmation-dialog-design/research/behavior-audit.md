# 二次确认弹窗：行为与文案审计

日期：2026-09-05。范围：只读核实 3 个确认弹窗、对应持久化边界和已有测试；未修改业务代码、测试或 spec。本文件是 planning 研究，不表示已实现。

审计基线：实现前提交 `319a38c`。以下代码行号与旧文案属于该基线；当前实现与验证结果见 `../design.md`、`../implement.md`。

## 1. 设计应遵守的主题边界

- 弹窗是 `surface + border`；标题、正文用 `ink`。页面底色 `bg` 与弹窗底色 `surface` 是不同语义，不要把浅色弹窗全部改成页面暖纸色。来源：`.trellis/spec/frontend/theming.md:117-129`，`lib/theme/zaidang_tokens.dart:41-60`。
- 删除、危险操作用墨色按钮、二次确认和明确文案；不能把火漆红作为危险红。红色占 5–10%，金色只用于买断/会员。来源：`.trellis/spec/frontend/theming.md:79-88,110-129`。
- 当前主题已使用手写 token，`ColorScheme.error = ink`，`TextButton` 全局前景是 `accent`；主题中没有 `dialogTheme`。3 个确认均仍直接使用 `AlertDialog`。因此具体取消/确认层级需要在统一组件中明确，不能依赖全局文本按钮颜色。来源：`lib/theme/zaidang_theme.dart:6-99`，`lib/pages/role_create_page.dart:501-517`，`lib/pages/role_desc_history_page.dart:100-118`，`lib/pages/backup_restore_page.dart:214-232`。
- spec 中“app.dart 仍然使用紫色 seed”的叙述已过时，不应据此推断现状；已读主题代码手写 `ColorScheme`。来源：`.trellis/spec/frontend/theming.md:17` 对比 `lib/theme/zaidang_theme.dart:8-24`。

## 2. 建议文案

以下文案对应当前实际实现，不额外承诺撤销或备份能力。标记“建议”的部分是本次设计建议。

| 场景 | 建议标题 | 建议正文 | 取消 / 主操作 |
| --- | --- | --- | --- |
| 删除属性 | 删除这条属性？ | 将从编辑中的角色移除“{名称}”及其内容，保存角色后生效。 | 取消 / 删除属性 |
| 删除未命名属性 | 删除这条属性？ | 将从编辑中的角色移除这条未命名属性及其内容，保存角色后生效。 | 取消 / 删除属性 |
| 恢复设定历史 | 恢复这版设定？ | 恢复后立即替换设定，未保存的设定修改不会保留。已有修改历史仍会保留。 | 取消 / 恢复此版 |
| iCloud 覆盖 | 用备份覆盖本机数据？ | 本机角色（含自定义属性）、设定历史和立绘将被 iCloud 备份替换。完成后无法撤销。 | 取消 / 覆盖并恢复 |

建议将属性名、历史版本时间、备份时间放在独立对象摘要中；长名称必须换行或滚动，不能挤压按钮。历史版本时间目前已能从 `revision.createdAt` 得到，见 `lib/pages/role_desc_history_page.dart:64,174-178`；iCloud 确认目前没有接收 inspection 或 manifest 参数，设计里若展示备份时间，实施时需显式传入且缺失时不能编造，见 `lib/pages/backup_restore_page.dart:123-132,212`、`lib/data/services/icloud_backup_service.dart:193-212`。

## 3. 三个确认的真实影响

### 删除属性：编辑草稿 → 保存角色后落库

- 确认前检查保存中/条目存在；确认后再检查 `mounted`、保存中、条目仍存在。只有 `true` 才从 `_attributes` 移除目标草稿。先移除并取消拖拽，再在下一帧释放控制器。来源：`lib/pages/role_create_page.dart:497-530`。
- 属性名称和内容作为整份角色保存的一部分传给 repository；仅点击删除不会写库。保存失败显示提示并保持编辑页。来源：`lib/pages/role_create_page.dart:164-247`，`lib/data/repositories/drift_role_repository.dart:69-98`。
- 没有就地撤销入口；未保存时退出可以保留原已存数据，但这也会放弃同页其他草稿，因此不应承诺“随时撤销”或“一键恢复”。新建时被删除的属性更没有历史副本。来源：移除/释放控制器 `lib/pages/role_create_page.dart:528-530`，保存边界 `:197-231`；已有离页未保存测试 `test/pages/role_create_page_custom_attributes_test.dart:165`。
- 简洁提示“保存角色后生效”需要保留，不能为了统一外观改成“立即删除 / 无法恢复”。现有文案已经包含此边界，见 `lib/pages/role_create_page.dart:504-506`。

### 恢复设定：立即写库，并覆盖当前设定草稿

- 从详情预览点“恢复此版”会先关闭预览，再打开确认。当前版本没有恢复入口；确认后直接调用 `restoreDescRevision`，成功才退出历史页并返回恢复后的设定文本，失败显示 SnackBar、保留历史页。来源：`lib/pages/role_desc_history_page.dart:79-86,121-135`。
- 数据层只替换该角色的 `desc`，保留已保存的固定字段、立绘和自定义属性；重复内容直接返回，真正改动时同事务更新角色并追加恢复后的版本。来源：`lib/data/repositories/drift_role_repository.dart:69-98,133-165,177-196`。
- 编辑页只将返回值写入 `_descController`，自定义属性等其他草稿不受影响；但是打开历史前的未保存设定内容会被覆盖。来源：`lib/pages/role_create_page.dart:250-263`。现有测试验证自定义属性草稿保留：`test/pages/role_create_page_custom_attributes_test.dart:285-315`。
- 当前正文“现在的内容会留在修改历史里”范围过宽：repository 只追加 `next`，并不读取编辑页未保存文本；初次创建的空设定也不建修订。可保证的是已有历史保留，不能保证未保存设定可恢复。来源：`lib/pages/role_desc_history_page.dart:106`，`lib/data/repositories/drift_role_repository.dart:177-196`。
- 可通过已有修改历史再次恢复已有版本，但没有单步撤销动作；不要文案化为“随时撤回所有更改”。来源：`lib/pages/role_desc_history_page.dart:79-86,125-129`，历史只插入不清空 `lib/data/repositories/drift_role_repository.dart:177-196`。

### iCloud 覆盖：确认后下载，成功提交时整体替换

- 先 inspect 下载快照和检查版本，再询问覆盖；取消或页面卸载时清理 inspection。用户确认后才准备下载立绘，最后关闭活库、commit，再刷新数据库/provider/图片缓存。不是点确认即刻完成覆盖。来源：`lib/pages/backup_restore_page.dart:123-180`；版本门禁 `lib/data/services/icloud_backup_service.dart:182-205`。
- 范围是完整 SQLite 快照 + covers，包括角色及其自定义属性、设定修订；并非只恢复某个角色，也不是合并。服务分别替换 covers 和 SQLite。来源：`lib/data/services/icloud_backup_service.dart:272-301`；含完整属性恢复的真实快照测试 `test/data/icloud_backup_service_test.dart:128-170`；持久化契约 `.trellis/spec/backend/role-custom-attributes.md:36`。
- 成功后没有应用内撤销入口；替换过程中旧 covers 仅临时用于失败回滚，成功后丢弃。不要把底层失败回滚当成用户可撤销。来源：`lib/data/services/icloud_backup_service.dart:277-301`。
- 版本不支持/下载失败不应改本机数据；SQLite 替换失败时尝试回滚 covers。页面显示失败信息并解除 busy。不能承诺所有异常均绝对无损（回滚本身也可能失败），更不能称为“已自动为你保留完整备份”。来源：`lib/data/services/icloud_backup_service.dart:195-221,261-301`，`lib/pages/backup_restore_page.dart:168-194`；已验证的具体失败场景 `test/data/icloud_backup_service_test.dart:292-431`。

## 4. 组件改版必须保留的行为/测试边界

1. **确认值契约**：取消返回 false，非确认关闭不进入动作；只有 `== true` 执行。三个调用点均如此，见 `lib/pages/role_create_page.dart:521`、`lib/pages/role_desc_history_page.dart:121`、`lib/pages/backup_restore_page.dart:133`。改成统一 helper 后，仍应保留安全的空值/返回键/遮罩关闭处理。
2. **不吞业务时机**：共享弹窗只负责采集确认，调用方仍负责草稿修改、repository 写入、inspection 释放和恢复进度；不要为了显示 loading 将三种动作误做同一事务。来源：以上三个行为分节。
3. **删除保护**：保存期间控件及陈旧回调均禁用；条目按对象身份删除；控制器下一帧释放。已覆盖取消、失败草稿、删除保存和陈旧回调：`test/pages/role_create_page_custom_attributes_test.dart:123-161,241-279`。
4. **历史范围**：已有 repository 测试覆盖恢复会追加版本且保留属性，已有 widget 测试覆盖属性草稿保留：`test/data/drift_role_repository_test.dart:185-217,347-368`；`test/pages/role_create_page_custom_attributes_test.dart:285-315`。设计新增的“未保存设定不保留”文案应有相应 widget 场景核实；既有测试没有覆盖该草稿丢失场景。
5. **恢复失败**：保留版本门禁、准备失败不写入、取消清理和 SQLite 替换失败回滚测试：`test/data/icloud_backup_service_test.dart:292-431`。现有备份页测试只验证平台可用性及墨色 outline 入口，尚未测试确认弹窗本身：`test/pages/backup_restore_page_test.dart:12-61`。
6. **改测试选择器而非行为断言**：当前属性/历史测试将 `TextButton` 与“删除”“恢复”文字绑定。若按钮类型或文案变化，应改为稳定 key 或可访问标签，保留最终数据断言。来源：`test/pages/role_create_page_custom_attributes_test.dart:148,304`。
7. **视觉/可访问性实施验收建议**：两种主题、窄屏、长属性名、文本放大、键盘/返回键、真实按钮语义与焦点；标题与危险动作仍用 `ink`，金色不入危险确认。依据 token 对比度和危险动作契约 `.trellis/spec/frontend/theming.md:141-175`，按钮语义要求 `.trellis/spec/frontend/component-guidelines.md:56-72`。这是实施验收建议，本次未运行测试。
