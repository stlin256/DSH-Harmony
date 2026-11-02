# Plan 模式与子智能体设备 E2E

日期：2026-11-02

设备：`HBN-AL80`，HarmonyOS `7.0.0.111` SP10C10，API `26`。

上一轮 Mock HAP SHA-256：
`893177598199A3DA33BFF36BDFFF0BD64ED808D9C56D79F9C5818D3DAAAD250B`。

当前设备验收 Mock HAP SHA-256：
`F23693248955498EC90306DC2D1942D2DC30F440FE449D73DDB9592FE59412CD`。

Current-HAP status: Partial。标题行、导航身份、冷启动、长计数、按压胶囊与
可继续子代理发送已通过 API 26 真机；其他尚未构造的独立 provider/实时重连
fixture 仍按行保留 Pending。

当前 Mock 交互证据：
`artifacts/device-e2e-final/mode-subagent-clean/plan-lineage/manifest.json`。

| ID | 场景 | 预期 | 状态 | 证据 |
| --- | --- | --- | --- | --- |
| PMS-01 | 普通会话无 `plan` projection | 不显示 Plan chip | Passed | `completed` 暗色/亮色最终截图与布局树 |
| PMS-02 | `plan={active:false,pending:true}` | 显示“计划” | Passed | `plan-subagent` 暗色/亮色截图 |
| PMS-03 | `plan={active:true,pending:true}` | 目标为 inactive，不显示 chip | Pending | 需要 provider-target 专用 fixture；纯模型测试不算真机证据 |
| PMS-04 | 点击 Plan chip 后 Host 回写 inactive | chip 在确认后消失，不提前消失 | Passed | `plan-visible`、`plan-removed` 与 manifest |
| PMS-05 | `/plan off` command 失败 | 显示“退出计划模式失败”，模式保持不变 | Passed | `plan-error-after` 截图与 manifest |
| SUB-01 | 根会话 catalog 空 | 不显示子智能体入口 | Passed | `completed` 最终截图无子智能体入口 |
| SUB-02 | 根会话 2 个直接成员，其中 1 个运行 | 只显示分支图标和 accent 数字 `2`；无障碍文本为“2 个子智能体，正在运行” | Pending | 当前 fixture 为 4 个子智能体，未伪造 2 个成员的精确证据 |
| SUB-03 | 打开谱系抽屉 | 抽屉最大 60% 视口，实色、紧凑、底部安全区 | Passed | `lineage-open` 截图、布局和最大字号复测 |
| SUB-04 | 当前子会话位于目录中 | 当前行高亮，模式与运行状态可读 | Pending | 当前根会话打开的抽屉不包含“当前子会话”行 |
| SUB-05 | 点击 external | 不打开，不伪造 transcript | Passed | 外部任务行显示“外部 / 不可打开” |
| SUB-06 | 打开 one-shot | 历史可读，composer 只读 | Passed | `one-shot` 截图与 manifest |
| SUB-07 | 打开 unknown | 历史可读，composer 只读 | Passed | `unknown` 截图与 manifest |
| SUB-08 | 打开 continuable 并发送 queue | `subagents/prompt` 被受理，消息只出现一次 | Passed | `continuable`、`subagent-sent` 截图、布局与 manifest |
| SUB-09 | continuable 运行中 Stop | 使用 `interruptByParent`，不完全走 session/cancel | Pending | 当前 fixture 为已完成的 continuable，没有运行中 Stop 状态 |
| SUB-10 | 子会话系统 Back | 回到直接父会话，不退出聊天 | Passed | `Return-To-ParentConversation` |
| SUB-11 | 嵌套 child Back 多次 | 按地址栈逐级返回 | Pending | 当前只验证一层 child 到 parent |
| SUB-12 | 抽屉打开时 Back | 只关闭抽屉 | Passed | `lineage-closed` |
| SUB-13 | 减少动效 | chip/抽屉直接到最终状态 | Passed | `artifacts/device-e2e/20261102-reduced-motion-1` |
| SUB-14 | 暗色模式/大字体/横屏 | 无裁切、无不可读文本、无安全区重叠 | Partial；暗色和最大 `超大` 竖屏通过，横屏 Pending | `20261102-large-text-2/large-text-contact.jpg`（含 `20261102-large-text-1` 完成态会话） |
| SUB-15 | 断线重连 | projection baseline 恢复模式与目录，无旧状态残留 | Pending | 需要实时 Host 断线与重连条件 |
| SUB-16 | 根会话标题与 4 个子智能体计数 | 标题行只显示分支图标和 `4`，不显示长文案或下拉箭头；长标题先省略，chip、加载和更多操作不溢出 | Passed | `plan-visible`、`plan-visible-long-count` 截图与布局 bounds |
| SUB-17 | 从谱系打开 continuable 子会话 | 子会话使用非激活 Follow 加载历史，不出现“连接断开”，Back 返回直接父会话 | Passed | `continuable`、`subagent-sent`、`returned-parent` 与 manifest |
| SUB-18 | 全界面底部导航避让 | 会话、抽屉、设置、浏览器、预览、灯箱、自动化、插件、谱系和各状态浮层的可操作控件均不进入屏幕底部 20vp | Passed for API 26 default text | 115/115 全量 Mock 视觉矩阵、截图审查与当前交互布局断言 |
| SUB-19 | 长子智能体数量与按压态 | `128` 完整显示，入口向左扩展、标题先压缩、更多操作不移动；按压高亮仅为内层圆角胶囊 | Passed | `plan-visible-long-count`、`subagent-entry-pressed` 截图与布局树 |
| SUB-20 | 子代理页面导航身份 | 子代理页不显示侧边栏；一级会话页显示侧边栏 | Passed | `workspace-sidebar` / `workspace-subagent-back` 布局断言 |
| SUB-21 | 冷启动与子代理深链 | 最后停留在子代理后冷启动仍进入一级会话；显式子代理 `sessionId` 路由也回退一级会话 | Passed | `cold-root.jpeg`、`requested-child-root.jpeg` 与布局树 |

## 自动前置验证

- Gateway 协议、模型和源码契约通过。
- 当前 PR QA 在最终收尾阶段重跑并记录到交付摘要。
- default、store、mock Release HAP 均构建成功。
- 当前设备 Mock HAP 全量视觉套件 115/115 通过。

自动结果只用于前置检查，不替代上表仍为 `Pending` 的真机场景。
