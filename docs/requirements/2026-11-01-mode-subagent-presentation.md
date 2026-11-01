# Plan 模式与子智能体呈现需求

状态：已确认，进入实现

## 用户目标

DSH Harmony 需要把新版 DSH 的 Plan 模式和子智能体谱系原生化，并保持官方的状态语义、操作边界、视觉密度与移动端导航习惯。

## 功能要求

1. Plan 模式只在权威 `plan` projection 可用时显示紧凑状态 chip，不从文字、任务清单或本地意图推断。
2. Plan chip 文案为“计划”。模式处于待切换状态时，按官方目标状态 `pending ? !active : active` 决定显示。
3. 点击 Plan chip 使用官方 `/plan off` command。收到新的权威 projection 前不得乐观隐藏；失败只显示短错误。
4. `todo_write` 任务计划 Dock 继续独立工作，不能和 Plan 模式共用状态或入口。
5. 根会话说存在直接子智能体时显示紧凑计数 chip；成功加载的空目录不显示入口。
6. 子代理使用受限高度抽屉呈现，支持当前子会话高亮、运行状态、可继续/一次性/未知/外部模式、加载、失败和重试。
7. 普通侧栏会话列表继续隐藏子会话。
8. 子会话可以打开只读或可继续的历史。`one-shot`、`unknown` 和 `external` 不提供发送；`external` 不能打开。
9. `continuable` 以精确父会话地址继续；Host 明确报告父会话 `agentAvailable: false` 且子会话空闲时退化为只读，可用性未知时保持正常输入。发送和停止分别使用官方 `subagents/prompt` 与 `subagents/interruptByParent`。
10. 子会话返回父会话，嵌套子代理按栈逐级返回；系统 Back 与界面 Back 使用同一路径。
11. 动效遵循 Quiet Precision。状态 chip 和抽屉使用现有语义 token；减少动效时直接到最终状态。
12. 不在 UI 中加入实现说明、教程或原始协议 JSON。

## 非目标

- 不在本次实现 Plan 模式进入按钮；进入仍使用官方命令或 Agent 流程。
- 不把 `subagentCatalog` 成员混入普通工作区列表。
- 不为 `external` 子代理伪造本地 transcript。
- 不在设备未在线时宣称实机 E2E 通过。

## 验收原则

- 协议数据必须经过 allowlist 归一化，非法值不得产生假状态或假成员。
- 结构、权限和导航先完成，再完善动效。
- 本地与商店 Release 变体必须共同编译。
- 设备项目写入 E2E 表，实际执行前保持 `Pending`。
