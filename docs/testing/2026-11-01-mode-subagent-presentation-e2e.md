# Plan 模式与子智能体设备 E2E

状态：设备当前离线；以下项目在真实设备执行前均为 `Pending`。

| ID | 场景 | 预期 | 状态 | 证据 |
| --- | --- | --- | --- | --- |
| PMS-01 | 普通会话无 `plan` projection | 不显示 Plan chip | Pending | |
| PMS-02 | `plan={active:false,pending:true}` | 显示“计划” | Pending | |
| PMS-03 | `plan={active:true,pending:true}` | 目标为 inactive，不显示 chip | Pending | |
| PMS-04 | 点击 Plan chip 后 Host 回写 inactive | chip 在确认后淡出，不提前消失 | Pending | |
| PMS-05 | `/plan off` command 失败 | 显示“退出计划模式失败”，模式保持不变 | Pending | |
| SUB-01 | 根会话 catalog 空 | 不显示子智能体入口 | Pending | |
| SUB-02 | 根会话 2 个直接成员，其中 1 个运行 | 显示运行点和“2 个子智能体” | Pending | |
| SUB-03 | 打开谱系抽屉 | 抽屉最大 60% 视口，实色、紧凑、底部安全区 | Pending | |
| SUB-04 | 当前子会话位于目录中 | 当前行高亮，模式与运行状态可读 | Pending | |
| SUB-05 | 点击 external | 不打开，不伪造 transcript | Pending | |
| SUB-06 | 打开 one-shot | 历史可读，composer 只读 | Pending | |
| SUB-07 | 打开 unknown | 历史可读，composer 只读 | Pending | |
| SUB-08 | 打开 continuable 并发送 queue | `subagents/prompt` 被受理，消息只出现一次 | Pending | |
| SUB-09 | continuable 运行中 Stop | 使用 `interruptByParent`，不完全走 session/cancel | Pending | |
| SUB-10 | 子会话系统 Back | 回到直接父会话，不退出聊天 | Pending | |
| SUB-11 | 嵌套 child Back 多次 | 按地址栈逐级返回 | Pending | |
| SUB-12 | 抽屉打开时 Back | 只关闭抽屉 | Pending | |
| SUB-13 | 减少动效 | chip/抽屉直接到最终状态 | Pending | |
| SUB-14 | 暗色模式/大字体/横屏 | 无裁切、无不可读文本、无安全区重叠 | Pending | |
| SUB-15 | 断线重连 | projection baseline 恢复模式与目录，无旧状态残留 | Pending | |

## 自动前置验证

- Gateway protocol/model tests
- default/store Release builds
- 源码契约检查

这些自动结果不能替代上表的真机结论。
