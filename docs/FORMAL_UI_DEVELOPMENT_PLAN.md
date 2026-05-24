# 正式版界面开发计划

本文档用于跟踪 Dice Fight UI 从 demo 级操作界面升级为准正式版奇幻像素战斗界面的全部工作。目标方向参考用户提供的效果图：暗色奇幻像素风、金色装饰边框、蓝色地下城竞技场、左右大型玩家 HUD、骰子区、嵌入式战斗日志、横向技能卡。

## 信息源

- 玩法规则来源：`docs/GAME_DESIGN.md`
- 架构与 UI 要求来源：`docs/TECH_DESIGN.md`
- 项目协作与进度规则：`AGENTS.md`
- 目标视觉方向：暗黑奇幻像素对战 UI，包含金色装饰框、蓝色地下城竞技场、大型玩家 HUD、骰子托盘、嵌入式战斗日志、横向技能卡。

UI 工作必须保持在表现层。UI 可以渲染 battle snapshot、提交 command、播放 presentation events，但规则结算仍属于 `scripts/rules/`，LAN 主机权威逻辑仍属于 `scripts/network/`。

## 当前基线

最后检查日期：2026-05-24。

- Milestone 1 本地热座规则 demo 已实现。
- Milestone 2 LAN Host/Join 基础已实现。
- Milestone 3 第一版 UI 正在推进中。
- 主流程已存在：主菜单、角色选择、强化选择、战斗、交互判定、游戏结束、再战。
- 现有 UI 场景位于 `scenes/ui/`，脚本位于 `scripts/ui/`。
- 战斗界面已经有可复用的高层结构：顶部 HUD 区、中部竞技场区、底部行动/日志区。
- 占位角色头像、技能图标、状态图标和部分角色动画路径已经存在。
- 战斗界面样式仍然主要依赖 `BattleScreen._apply_placeholder_styles()` 中的运行时 `StyleBoxFlat` 占位颜色。
- 骰子目前仍是简单 Label 风格控件，不是正式骰子美术。
- 主菜单、角色选择、强化选择和结算界面仍然像 demo/控制台界面。
- 创建本计划时工作区干净，但本地 `main` 比 `origin/main` 落后 1 个提交。

## 目标结果

正式版战斗界面需要在结构和意图上接近目标效果图：

- 顶部左侧和右侧是玩家 HUD 面板，显示头像、先后手、HP、MP、护盾、状态、被动和强化。
- 顶部中间是网络/房间状态面板，包含房间状态与主题化返回/断开按钮。
- 中部是完整横向竞技场，包含像素地下城背景、蓝色魔法地面、回合标题、左右角色站位。
- 底部左侧是骰子与战斗日志面板，包含骰子面、重掷/改点操作和紧凑可滚动日志。
- 底部右侧是技能选择面板，包含大型横向技能卡、图标区、骰子需求标记、MP 消耗、可用/禁用状态。
- 全局统一暗黑奇幻像素风：深色面板、金色描边、装饰角、可读中文文本、清晰信息层级。
- 玩家不看战斗日志也能理解主要战斗变化。

## 状态标记

- `[todo]` 尚未开始。
- `[doing]` 正在进行。
- `[blocked]` 被美术资源、设计决策或实现依赖阻塞。
- `[done]` 已实现并通过验证。

## 工作流 1：视觉规格冻结

状态：`[todo]`

### 需要结果

- 冻结第一版正式 UI 美术方向。
- 确定 UI 缩放目标，首版以 16:9 桌面视口、1920x1080 构图为参考。
- 确定 UI 美术资源命名规则。
- 确定共享色板与边框语言：深色面板、金色描边、蓝色竞技场强调色、危险红、法力蓝、护盾灰、中毒绿/紫、灼烧橙。
- 决定当前 playable slice 之外的数据角色是否显示、隐藏或标注为开发中。

### 实施过程

1. 在本文档中明确视觉关键词。
2. 决定目标视口和最低支持分辨率。
3. 在导入资源前创建资产命名规则。
4. 决定 UI 当前只支持 Swordsman、Archer、Witch Doctor、Pyromancer，还是同时显示 Arcanist、Stormcaller、Vampire 等数据角色。

### 验收标准

- 美术方向足够具体，后续开发者新增面板或按钮时不需要重新发明风格。
- 角色显示范围决策已记录。
- 不需要更改规则或网络代码。

## 工作流 2：资产与 Theme 基础

状态：`[todo]`

### 需要结果

创建或填充以下目录：

```text
assets/ui/backgrounds/
assets/ui/frames/
assets/ui/panels/
assets/ui/buttons/
assets/ui/dice/
assets/ui/icons/
assets/ui/fonts/
assets/ui/theme/
assets/ui/theme/dice_fight_theme.tres
```

Theme 至少覆盖：

- `Button`
- `PanelContainer`
- `Label`
- `LineEdit`
- `TextEdit`
- `ProgressBar`
- `ScrollBar`
- Tooltip/Popup 样式，在可行范围内覆盖

### 实施过程

1. 添加 UI 资产目录结构。
2. 导入或生成第一版正式 UI 资产。
3. 创建 `dice_fight_theme.tres`。
4. 将 Theme 应用到主 UI 根节点或各个屏幕根节点。
5. 保持 `UIAssets.texture_from_path()` 的 fallback 行为，确保 JSON 里的可选资源路径为空时仍然安全。

### 验收标准

- 可选美术路径为空时，项目不会出现缺失资源错误。
- 应用 Theme 后，现有 UI smoke tests 通过。
- 不提交 `.godot/` 生成缓存。

## 工作流 3：战斗界面布局重构

状态：`[todo]`

主要文件：

- `scenes/ui/screens/battle_screen.tscn`
- `scripts/ui/screens/battle_screen.gd`

### 需要结果

- 用目标效果图布局替代当前占位三段式视觉。
- 顶部区域包含左侧 HUD、中间网络状态面板、右侧 HUD。
- 中央竞技场使用真实背景图或分层场景美术，不再显示 `"场景"` 占位 Label。
- 底部区域像目标图一样分为骰子/日志区与技能卡区。
- LAN 隐私规则保持不变：客户端看不到对手骰子、待提交行动和私密日志。

### 实施过程

1. 先重排 `battle_screen.tscn` 的布局。
2. 用 Theme 和正式组件替换 `_apply_placeholder_styles()`。
3. 保持 `_render_*` 方法专注于 snapshot 到 UI 的渲染。
4. 保留现有 signal 和 command 提交流程。
5. 布局变更后检查本地热座与 LAN 显示假设。

### 验收标准

- 战斗界面在 16:9 下接近目标效果图构图。
- UI 回调中不新增规则逻辑。
- 行动提交与交互判定流程仍然可用。
- UI smoke tests 和 Godot 启动/debug 检查通过。

## 工作流 4：角色 HUD 组件

状态：`[todo]`

当前主要组件：

- `scenes/ui/components/player_state_panel.tscn`
- `scripts/ui/components/player_state_panel.gd`

建议新增或替换为：

```text
scenes/ui/components/character_hud.tscn
scripts/ui/components/character_hud.gd
```

### 需要结果

- 带角色美术的头像框。
- 玩家编号、角色名、先手/后手标记。
- 符合目标图风格的 HP、MP、护盾条。
- 状态徽章行，显示层数/回合数。
- 被动区与强化摘要区。
- LAN 客户端隐藏对手私密行动。

### 实施过程

1. 决定是演进 `PlayerStatePanel`，还是替换为 `CharacterHud`。
2. 如果布局需要，抽取可复用 `resource_bar`。
3. 保持 `set_player(player_id, battle, animate, hide_private_info)` 或等价 snapshot 渲染 API。
4. 使用现有状态和角色数据，不在 HUD 里复制规则。

### 验收标准

- HUD 展示的信息不低于当前面板，但视觉层级更清楚。
- 多个状态同时存在时仍然可读。
- 被动和强化文本在目标分辨率下不溢出。

## 工作流 5：骰子托盘与骰子面

状态：`[todo]`

当前主要组件：

- `scenes/ui/components/dice_view.tscn`
- `scripts/ui/components/dice_view.gd`

建议新增组件：

```text
scenes/ui/components/dice_tray.tscn
scripts/ui/components/dice_tray.gd
scenes/ui/components/die_face.tscn
scripts/ui/components/die_face.gd
```

### 需要结果

- 1 到 6 点的正式骰子贴图。
- 类似目标图中 `P2` 的玩家标签。
- LAN 隐私用的空/隐藏骰子状态。
- 重掷反馈动画。
- 为后续改点 UX 预留选中态。

### 实施过程

1. 在 `assets/ui/dice/` 添加骰子面美术。
2. 用 die face 实例替代 Label 骰子渲染。
3. 保持现有重掷和改点命令提交。
4. 增加视觉状态，不改变骰子规则。

### 验收标准

- 骰子一眼可读。
- LAN 模式下隐藏的敌方骰子看起来是有意设计，而不是坏掉。
- 重掷动画不会和 snapshot 中的实际骰值脱节。

## 工作流 6：技能卡组件

状态：`[todo]`

当前主要组件：

- `scenes/ui/components/skill_button.tscn`
- `scripts/ui/components/skill_button.gd`

建议替换为：

```text
scenes/ui/components/skill_card.tscn
scripts/ui/components/skill_card.gd
```

### 需要结果

- 符合目标图的横向技能卡。
- 图标区、技能名、骰子需求标记、MP 消耗、模式标签。
- 清晰的可用、悬停、按下、选中和禁用视觉。
- 禁用原因继续通过 tooltip 或卡内提示可见。
- 可选技能图标路径继续安全 fallback。

### 实施过程

1. 保留现有 `configure(skill, selected_modes, cost, block_reason, theme_color)` 合约，或谨慎迁移调用点。
2. 将骰子需求渲染为徽章，而不是只放在 tooltip 文本里。
3. 保持现有 `use_skill` command payload。
4. 测试基础技能与强化施法、锁定攻击等 mode 变体。

### 验收标准

- 不打开 tooltip 也能读懂技能的基本信息。
- 禁用技能能清楚说明为什么不可用。
- 新增普通伤害/护盾类技能仍然主要依赖数据配置，不需要改 UI 规则。

## 工作流 7：战斗日志面板

状态：`[todo]`

当前主要组件：

- `scenes/ui/components/battle_log_view.tscn`
- `scripts/ui/components/battle_log_view.gd`

### 需要结果

- 符合目标图左下角的紧凑嵌入式日志。
- 金色标题栏。
- 自动滚动到最新条目。
- 玩家前缀和重要事件清晰可读。
- LAN 私密日志隐藏逻辑保持不变。

### 实施过程

1. 先重做现有组件样式，不优先改日志生成逻辑。
2. 保持 `set_logs(logs)` 作为主要 API。
3. 布局稳定后，可增加轻量事件着色。

### 验收标准

- 日志仍然对调试有用。
- 日志不再承担玩家理解战斗的主要责任。
- LAN 客户端不会泄露敌方私密行动日志。

## 工作流 8：状态徽章与反馈效果

状态：`[todo]`

当前主要组件：

- `scenes/ui/components/status_icon.tscn`
- `scripts/ui/components/status_icon.gd`

### 需要结果

- guard、immune、sure evasion、poison、burn、fire shield、eagle eye、flame tide、soul bind、static cage，以及需要展示时的 Pyromancer rebirth，都有正式徽章美术。
- 支持层数/回合数显示。
- tooltip 文本保持清楚。
- 重要状态变化除了写入日志，也要有可见反馈。

### 实施过程

1. 在保持 `configure(status, status_data)` 的前提下升级状态图标视觉。
2. 审查来自 `battle.status_effects` 和 player flags 的全部状态。
3. 基础徽章稳定后，再扩展 presentation event 的消费方式。

### 验收标准

- 关键状态视觉上彼此不同。
- 状态层数和持续时间不只藏在 tooltip 中。
- 玩家可以一眼识别中毒、灼烧、免疫、闪避。

## 工作流 9：竞技场角色与表现事件

状态：`[todo]`

当前相关脚本：

- `scripts/ui/components/animated_sprite_texture_rect.gd`
- `scripts/ui/screens/battle_screen.gd`

### 需要结果

- 竞技场中有左右角色站位。
- 角色有阴影或底座。
- 在资源存在时，支持 idle、attack、dodge/backstep、hit、shield、heal/status、defeat 等表现。
- HP、MP、护盾、状态变化有浮字或短提示。

### 实施过程

1. 保持现有 character animation manifest / SpriteFrames 支持。
2. 为没有完整动画行的角色添加 fallback。
3. 在 UI 中扩展 `battle.presentation_events` 的消费方式，不改变规则。
4. 分阶段增加视觉反馈：先做伤害/治疗/护盾，再做状态事件，最后做高级动画。

### 验收标准

- 不看日志也能跟上战斗变化。
- 缺少动画资源时能安全 fallback。
- 缺少资源时 presentation event 不会导致脚本错误。

## 工作流 10：主菜单、角色选择、强化选择、结算界面

状态：`[todo]`

主要文件：

- `scenes/ui/screens/menu_screen.tscn`
- `scripts/ui/screens/menu_screen.gd`
- `scenes/ui/screens/character_select_screen.tscn`
- `scripts/ui/screens/character_select_screen.gd`
- `scenes/ui/screens/augment_select_screen.tscn`
- `scripts/ui/screens/augment_select_screen.gd`
- `scenes/ui/screens/game_over_screen.tscn`
- `scripts/ui/screens/game_over_screen.gd`

建议新增组件：

```text
scenes/ui/components/character_card.tscn
scripts/ui/components/character_card.gd
scenes/ui/components/augment_card.tscn
scripts/ui/components/augment_card.gd
```

### 需要结果

- 主菜单不再显示 `Dice Fight Demo`。
- 主菜单使用正式标题、背景、模式按钮和 LAN 输入面板。
- 角色选择改为卡片式，包含头像、属性、被动和技能预览。
- 强化选择改为卡片式，区分通用强化与角色专属强化。
- 结算界面显示胜者、败者、再战/重新选角操作和紧凑对局摘要。

### 实施过程

1. 将共享 Theme 应用于所有流程界面。
2. 在有助于维护的地方，把动态 Button 构造拆成复用卡片组件。
3. 保留现有 command signal。
4. 保持 LAN 控制限制的可见和可读。

### 验收标准

- 所有界面都像同一个游戏，不再是 demo 与正式 UI 混杂。
- 现有流程保持不变。
- UI 同时支持热座和 LAN 模式。

## 工作流 11：交互判定弹窗

状态：`[todo]`

主要文件：

- `scenes/ui/dialogs/interactive_dialog.tscn`
- `scripts/ui/dialogs/interactive_dialog.gd`

### 需要结果

- 弹窗边框与正式 UI 风格一致。
- 射击闪避/后跳判定用视觉骰子显示判定结果。
- 缚魂选技使用正式小型技能按钮。
- 灼烧判定当前限制继续记录，直到设计交互实现完成。

### 实施过程

1. 先重做当前弹窗样式。
2. 在可行时用 die face 组件替代纯数字判定骰。
3. 保持当前 interactive command payload。

### 验收标准

- 交互判定看起来属于战斗界面的一部分。
- 禁用控件能清楚体现无权限或 MP 不足。
- 现有交互相关测试继续通过。

## 工作流 12：音频反馈

状态：`[todo]`

当前主要脚本：

- `scripts/ui/components/audio_feedback.gd`

### 需要结果

- 当最终或占位音频资源存在时，为 click、dice、skill、hit、shield、heal、status、win、lose 填充可编辑 stream slot。
- 音量和重复播放频率舒适。
- 缺少 stream 时仍然安全。

### 实施过程

1. 在 `assets/audio/` 添加第一版音效资源。
2. 通过现有 exported stream slot 连接音效。
3. 检查重复 UI 操作不会造成声音过于嘈杂。

### 验收标准

- 音频增强反馈，但不阻塞游玩。
- 部分 stream 缺失时项目仍然可运行。

## 工作流 13：验证与回归检查

状态：`[todo]`

### 需要结果

- 正式 UI 工作拥有可重复的验证流程。
- 重大视觉变更后有关键界面截图或人工检查记录。
- 不提交 `.godot/` 生成缓存。

### 实施过程

每次重要 UI 改动后运行最小相关验证：

```powershell
godot --path . --headless --check-only
godot --path . --headless --script res://tests/ui/presentation_screens_smoke_test.gd
godot --path . --headless --script res://tests/ui/main_network_lifetime_test.gd
```

如果 UI 改动涉及 command payload、snapshot shape、网络行为或 presentation event shape，还要运行：

```powershell
godot --path . --headless --script res://tests/rules/rule_smoke_test.gd
godot --path . --headless --script res://tests/rules/status_and_new_characters_test.gd
godot --path . --headless --script res://tests/network/network_controller_smoke_test.gd
```

### 验收标准

- Godot 启动/debug 检查通过。
- 相关 smoke tests 通过；若失败，记录具体阻塞原因。
- 停止前检查并总结 `git status --short --branch`。

## 进度追踪表

| 工作流 | 状态 | 负责人 | 最后更新 | 备注 |
| --- | --- | --- | --- | --- |
| 1. 视觉规格冻结 | `[todo]` | 未分配 | 2026-05-24 | 需要最终风格与角色显示范围决策。 |
| 2. 资产与 Theme 基础 | `[todo]` | 未分配 | 2026-05-24 | 添加 `assets/ui/` 和 Theme 资源。 |
| 3. 战斗界面布局重构 | `[todo]` | 未分配 | 2026-05-24 | 目标效果图的主要落地点。 |
| 4. 角色 HUD 组件 | `[todo]` | 未分配 | 2026-05-24 | 替换或演进 `PlayerStatePanel`。 |
| 5. 骰子托盘与骰子面 | `[todo]` | 未分配 | 2026-05-24 | 替换 Label 风格骰子。 |
| 6. 技能卡组件 | `[todo]` | 未分配 | 2026-05-24 | 替换 demo 按钮视觉。 |
| 7. 战斗日志面板 | `[todo]` | 未分配 | 2026-05-24 | 重做样式并保留隐私过滤。 |
| 8. 状态徽章与反馈效果 | `[todo]` | 未分配 | 2026-05-24 | 让关键状态一眼可读。 |
| 9. 竞技场角色与表现事件 | `[todo]` | 未分配 | 2026-05-24 | 扩展视觉反馈，不改变规则。 |
| 10. 全流程界面正式化 | `[todo]` | 未分配 | 2026-05-24 | 主菜单、选角、强化选择、结算。 |
| 11. 交互判定弹窗 | `[todo]` | 未分配 | 2026-05-24 | 主题化判定弹窗。 |
| 12. 音频反馈 | `[todo]` | 未分配 | 2026-05-24 | 填充现有音频 stream slot。 |
| 13. 验证与回归检查 | `[todo]` | 未分配 | 2026-05-24 | 每次重要改动后运行。 |

## 近期下一步

1. 冻结第一版视觉规格和角色显示范围决策。
2. 添加 `assets/ui/` 目录和 `dice_fight_theme.tres`。
3. 围绕目标效果图重构战斗界面布局。
4. 实现正式 `character_hud`、`skill_card` 和 `dice_tray` 组件。
5. 使用 Godot 启动检查和 UI smoke tests 验证。

## 协作规则

- 正式 UI 工作流开始或完成时，更新本文档的进度追踪表。
- 被美术资源或设计决策阻塞时，在备注中写明。
- UI 改动优先使用 scene/component。
- 不要在 UI 回调里写伤害、MP、护盾、骰子或状态结算。
- 保留 UTF-8 中文显示文本。
- 从 JSON、Dictionary、snapshot 或其他 `Variant` 来源取值时，避免使用 `:=`。
