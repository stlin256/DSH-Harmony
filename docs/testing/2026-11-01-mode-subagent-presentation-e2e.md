# Plan 模式与子智能体设备 E2E

日期：2026-11-02

设备：`HBN-AL80`，HarmonyOS `7.0.0.111` SP10C10，API `26`。

Mock HAP SHA-256：
`893177598199A3DA33BFF36BDFFF0BD64ED808D9C56D79F9C5818D3DAAAD250B`。

当前 Mock 交互证据：
`artifacts/device-e2e/20261102-device-mode-subagent-final/plan-lineage/manifest.json`。

| ID | 场景 | 预期 | 状态 | 证据 |
| --- | --- | --- | --- | --- |
| PMS-01 | 普通会话无 `plan` projection | 不显示 Plan chip | Passed | `completed` 暗色/亮色最终截图与布局树 |
| PMS-02 | `plan={active:false,pending:true}` | 显示“计划” | Passed | `plan-subagent` 暗色/亮色截图 |
| PMS-03 | `plan={active:true,pending:true}` | 目标为 inactive，不显示 chip | Pending | 需要 provider-target 专用 fixture；纯模型测试不算真机证据 |
| PMS-04 | 点击 Plan chip 后 Host 回写 inactive | chip 在确认后消失，不提前消失 | Passed | `plan-visible`、`plan-removed` 与 manifest |
| PMS-05 | `/plan off` command 失败 | 显示“退出计划模式失败”，模式保持不变 | Passed | `plan-error-after` 截图与 manifest |
| SUB-01 | 根会话 catalog 空 | 不显示子智能体入口 | Passed | `completed` 最终截图无子智能体入口 |
| SUB-02 | 根会话 2 个直接成员，其中 1 个运行 | 显示运行点和“2 个子智能体” | Pending | 当前 fixture 为 4 个子智能体，未伪造 2 个成员的精确证据 |
| SUB-03 | 打开谱系抽屉 | 抽屉最大 60% 视口，实色、紧凑、底部安全区 | Passed | `lineage-open` 截图、布局和最大字号复测 |
| SUB-04 | 当前子会话位于目录中 | 当前行高亮，模式与运行状态可读 | Pending | 当前根会话打开的抽屉不包含“当前子会话”行 |
| SUB-05 | 点击 external | 不打开，不伪造 transcript | Passed | 外部任务行显示“外部 / 不可打开” |
| SUB-06 | 打开 one-shot | 历史可读，composer 只读 | Passed | `one-shot` 截图与 manifest |
| SUB-07 | 打开 unknown | 历史可读，composer 只读 | Passed | `unknown` 截图与 manifest |
| SUB-08 | 打开 continuable 并发送 queue | `subagents/prompt` 被受理，消息只出现一次 | Passed | `subagent_probe` 只出现一次 |
| SUB-09 | continuable 运行中 Stop | 使用 `interruptByParent`，不完全走 session/cancel | Pending | 当前 fixture 为已完成的 continuable，没有运行中 Stop 状态 |
| SUB-10 | 子会话系统 Back | 回到直接父会话，不退出聊天 | Passed | `Return-To-ParentConversation` |
| SUB-11 | 嵌套 child Back 多次 | 按地址栈逐级返回 | Pending | 当前只验证一层 child 到 parent |
| SUB-12 | 抽屉打开时 Back | 只关闭抽屉 | Passed | `lineage-closed` |
| SUB-13 | 减少动效 | chip/抽屉直接到最终状态 | Passed | `artifacts/device-e2e/20261102-reduced-motion-1` |
| SUB-14 | 暗色模式/大字体/横屏 | 无裁切、无不可读文本、无安全区重叠 | Partial；暗色和最大 `超大` 竖屏通过，横屏 Pending | `20261102-large-text-2/large-text-contact.jpg`（含 `20261102-large-text-1` 完成态会话） |
| SUB-15 | 断线重连 | projection baseline 恢复模式与目录，无旧状态残留 | Pending | 需要实时 Host 断线与重连条件 |

## 自动前置验证

- Gateway 协议、模型和源码契约通过。
- PR QA `20261101T192208Z-eefbe49f` 通过。
- default、store、mock Release HAP 均构建成功。
- Mock 全量视觉套件 68/68 通过。

自动结果只用于前置检查，不替代上表仍为 `Pending` 的真机场景。
