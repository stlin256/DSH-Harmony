# Plan 模式与子智能体呈现调研

## 上游基线

- DSH revision：`f3803c96974ad4a94195fb97e5c637e9c2a3afe3`
- 版本：`0.2.2-alpha.2`
- Plan 源码：`packages/plan/plan-mode`
- Plan UI：`packages/client/ui-plan`
- 子智能体源码：`packages/subagent/subagent`
- 子智能体 UI：`packages/client/ui-subagent`
- Session Controller：`packages/api/session-controller`

## Plan 模式

`plan` projection 的 wire value 只有：

```ts
{ active: boolean, pending: boolean }
```

官方显示目标为：

```ts
const target = pending ? !active : active
```

chip 只在目标为 `true` 时出现。点击调用 `commands.execute(sessionId, '/plan off', [])`；在新 projection 到达前保持原状态。失败文案为“退出计划模式失败”。

`todo_write` 是会话内容里的任务清单投影；Plan 是协作模式投影。两者生命周期、持久化和操作均不同。

## 子智能体投影

直接子成员目录：

```ts
{
  id: string
  createdAt: number
  mode: 'one-shot' | 'continuable' | 'external' | 'unknown'
  label?: string
}
```

`continuable` 必须有 label。子会话身份 `subagent` 是
`one-shot | continuable + label? + seq`，无有效 descriptor 时必须为 `null`。计时投影为：

```ts
{
  settledMs: number
  active?: { since: number, through: number }
  lastTurnCompleted?: boolean
}
```

目录按父日志中的事件顺序返回。普通会话列表仍按 `origin === 'subagent'` 过滤。根会话只在直接目录确认为空时不显示入口；加载空白不能当作空目录。

## 官方交互

- 根会话 header 显示直接子代理数量；子会话 header 显示父级 switcher。
- 谱系按需展开，不从成员 id 猜测后代。`external` 是叶子，不能打开或继续。
- `one-shot` 可查看历史，但不能继续。
- `unknown` 在读取历史确认身份前只读。
- `continuable` 通过 `subagents/prompt` 继续，`delivery` 为 `queue` 或 `steer`。
- 停止通过 `subagents/interruptByParent(child, parent, 'continuable')`。
- `SessionSummary.agentAvailable` 是明确布尔值；其摘要未到达或不可读时，可用性保持未知。官方在未知状态仍使用正常 composer，只在明确 `false` 且子会话空闲时退化为只读。
- 子历史 Follow 地址为：

```ts
{
  kind: 'subagent',
  parentSessionId,
  childSessionId,
  mode
}
```

上游 Web 在打开子会话时使用非激活的 subagent address；历史页也使用相同地址。

## 当前 HarmonyOS 差距

- Gateway list 只转发标题、工作区、运行状态等基础字段。
- live projection 只处理 `userQuestions`、`title`、`inbox`。
- follow、page、prompt、cancel 目前只路由普通 session。
- ArkTS `NativeSession` 和 `NativeFrame` 没有 Plan、目录、身份和计时字段。
- 根列表过滤子代理是正确的，但没有子代理导航入口。
- `NativeTaskDock` 已正确处理任务清单，不能复用于 Plan 模式 chip。

## 移动端映射

- 模式使用 28vp 高紧凑 chip，放在会话标题行下方；不新增常驻大栏。
- 子代理目录使用最大 60% 视口的实色浮层。行高 44vp，树形缩进配细连接线。
- 当前会话、运行状态和模式以文本及语义圆点表达；不依赖仅有颜色。
- 子会话继续使用同一个聊天页面和 transcript，只替换地址与 composer 能力。
- 返回路径由 address 栈驱动。根会话直接 Back 行为保持不变。

## 风险

- projection 可能早于 session 列表到达。状态按 session id 缓存，不依赖当前选中先后。
- `subagent` 的显式 `null` 必须保留，不能被当作“缺字段”。
- 旧 seq 不能覆盖新状态；同一 catalogue 的重复 id 只保留第一项。
- 父会话明确离线时 continuable 空闲输入必须退化为只读；可用性未知不能提前误判。Host 错误不能显示为成功。
- 页面重连后需要从权威 baseline 恢复，不能用本地 chip 假设状态。

## 结论

实现分为四层：Gateway allowlist 归一化、ArkTS 纯模式模型、地址感知的会话传输、ArkUI 状态 chip 与谱系抽屉。先用自动测试锁定非法值、模式能力、地址和导航，再完成共享 UI。
