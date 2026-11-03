# DSH 权限预设与单次升权审批研究

日期：2026-11-03

状态：研究报告。本文描述现有契约、UI 方案和未来实现顺序，不代表已经实施。

## 结论

DSH 里有两层经常被混淆的权限：

1. **会话权限预设**：当前会话整体使用只读、工作区写入还是完全访问。
2. **单次升权审批**：某个受限工具调用只针对当前调用请求更宽权限。

二者不是同一个按钮：

- 选择 `danger-full-access` 是持久改变当前会话的权限预设，必须经过可见风险
  确认；
- 工具被沙箱拒绝后弹出的“允许一次”只放行当前调用，不能改变会话预设，也不
  等价于永久完全访问；
- `approval/request` 是 Host 的审批 seam，原生端必须消费它，而不是在聊天里
  临时拼接一段“是否允许”的文本。

## 当前 DSH 契约

固定上游版本：
`deepseek-ai/deepseek-harness@ce7073d51254c26cd63b22a60835b8f948deb447`。

### 预设与目录

权限预设由 Host 配置，绑定：

- 沙箱模式；
- 审批策略；
- 可选显示名称和说明。

默认配置中常见组合是：

```text
workspace-write   = workspace-write + ask
danger-full-access = danger-full-access + never
```

客户端只能把目录和当前值组合起来展示。`custom` 是推导值，不是可选目标。

参考：

- [docs/subsystems/permission-presets.zh.md](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/docs/subsystems/permission-presets.zh.md)
- [packages/interaction/permission-presets/README.zh.md](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/interaction/permission-presets/README.zh.md)

### 沙箱拒绝与升权

沙箱只描述文件系统效果：

```text
read-only             拒绝写入
workspace-write       工作区、显式额外根目录和临时区域可写
danger-full-access    绕过沙箱
```

被拒绝的调用会带一行提示，模型可以用“最窄的更高模式 + justification”重试
完全相同的调用。这个重试在真正执行前通过 `ctx.approval` 请求用户批准：

```text
受限调用
  -> 沙箱拒绝
  -> 模型请求更宽 sandbox_permissions
  -> approval/request
  -> 用户允许一次 / 拒绝
  -> 仅当前调用使用获批模式
```

参考：

- [packages/sandbox/sandbox/README.zh.md](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/sandbox/sandbox/README.zh.md)
- [packages/shell/tool-bash/README.zh.md](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/shell/tool-bash/README.zh.md)

### 审批结果

审批结果是闭合集合：

```text
allowed-once   仅当前调用
rejected       用户拒绝
cancelled      请求撤回
unavailable    没有可用审批通道
```

只有 `allowed-once` 放行，其他结果失败关闭。请求与结果写入审计日志，但不进入
模型 transcript；模型只看到工具调用的最终结果。

参考：

- [docs/subsystems/approval.zh.md](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/docs/subsystems/approval.zh.md)
- [packages/interaction/user-approval/README.zh.md](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/interaction/user-approval/README.zh.md)

### 上游 UI

Web 端审批卡是 composer 的接管状态，不是普通消息：

```text
等待审批
工具: bash
允许此操作使用 workspace-write 权限：
Need to write the requested file.

[拒绝] [允许一次]
```

工具审批只有单次批准/拒绝；`始终允许`不是沙箱工具审批的默认动作。浏览器用
Enter 允许、Esc 拒绝，并避免在输入框中截获这些按键。

参考：

- [packages/client/ui-approval/README.zh.md](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/client/ui-approval/README.zh.md)
- [ApprovalCard.tsx](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/packages/client/ui-approval/src/client/ApprovalCard.tsx)
- [approval-composer 快照](https://github.com/deepseek-ai/deepseek-harness/blob/ce7073d51254c26cd63b22a60835b8f948deb447/snapshots/web/approval-composer/ui.expected.md)

## 当前 Harmony 实现

### 已经存在的部分

- [NativeWorkspace.ets](../../harmony/entry/src/main/ets/components/NativeWorkspace.ets)
  接收 `interaction` 和 `interaction-ended` 帧，把待处理审批放到 composer 上方。
- [NativeInteraction.ets](../../harmony/entry/src/main/ets/components/NativeInteraction.ets)
  已绘制审批卡：warning 状态条、工具名、原因、目标范围、倒计时、拒绝和允许一次。
- [native-harness.mjs](../../gateway/src/native-harness.mjs) 已持有审批 pending
  interaction，校验 `allowed-once` / `rejected`，并把结果写回
  `$events/result`。
- [NativeHarnessClient.ets](../../harmony/entry/src/main/ets/services/NativeHarnessClient.ets)
  已有 `/pocket/api/native/answer` 请求。

所以“完全访问请求批准”的审批卡基础已经存在，不应该重复实现另一套。

### 仍然缺失的部分

1. Gateway 没有把 `permissions` 作为 Session projection 透传给原生端。
2. Gateway 没有权限目录读取接口。
3. Gateway 没有受控的 `setPermissionPreset` 或 `/permission <preset>` 调用路径。
4. `NativeHostSettings` 没有读取 `permission.defaultPreset`。
5. 当前审批卡虽然能显示 Host `displayReason`，但没有权限预设入口来让用户预先
   选择“只读/工作区/完全访问”。
6. 审批卡的 `cancelled` / `unavailable` / 请求已被替换等结果尚未形成完整的 UI
   状态矩阵。

### 当前审批卡逻辑

现有 `NativeInteraction` 对 approval 的提交值只有：

```text
rejected
allowed-once
```

这与上游工具审批的两种动作一致。允许一次只提交当前 `eventId`；不会提交新的
Session 权限事件。审批结束后，客户端移除 interaction，等待工具执行结果。

需要保留的约束：

- 一个 interaction 对应一个 `eventId`；
- 提交后立即锁定按钮；
- `interaction-ended` 到达后移除卡片；
- 迟到响应不能重新打开或重复提交；
- 连接断开时待处理审批失败关闭。

## UI 设计

### 当前会话权限 chip

放在 composer 底部工具栏：

```text
[权限 chip] [图片] [文件]                         [发送]
```

视觉：

- 28vp chip，44vp 触控区；
- 业务 glyph + 短标签；
- `只读`、`工作区`、`完全`、`自定义`；
- chip 最大宽度约 88vp，长 Host 标签省略，完整名称进入 accessibility text；
- 当前项不能挤压发送和附件。

打开菜单后的内容：

```text
会话权限
只影响当前会话

[✓] 仅可查看
    浏览和查询，不修改工作区
[ ] 工作区内修改
    可修改当前工作区
[ ] 完全权限
    可直接执行更多操作
```

选择完全权限后，使用单独的局部确认层：

```text
确认启用完全权限？

这会减少确认步骤，并允许智能体直接执行
敏感操作、文件修改或外部命令。

[ ] 我已了解风险，并愿意继续

[取消] [启用完全权限]
```

确认层不是审批请求本身；它是“切换持久会话预设”的用户操作。

### 单次升权审批卡

审批卡继续使用现有组件，不把它做成普通消息。建议保留并收紧：

```text
● 等待审批                              12s

工具：bash
允许此操作使用 workspace-write 权限：
Need to write the requested file.

[拒绝]                         [允许一次]
```

视觉规则：

- warning 状态条保持 28vp；
- 工具 badge 使用紧凑控件，不单独占一整行；
- 原因区域允许 Markdown/纯文本格式化，但设置最大高度和内部滚动；
- 主操作使用 accent，拒绝使用中性描边；
- 高风险的目标模式（`danger-full-access`）用 warning/danger 文案，不用普通
  accent 偷换严重性；
- 审批进行中禁用两个按钮；
- 审批成功到 interaction-ended 之间显示处理中，不提前宣称工具成功；
- 拒绝后不保留可重复提交的按钮；
- 取消/不可用状态显示具体情况，不能显示成“已拒绝”。

### 当前值和审批的关系

```text
当前会话预设
├─ read-only
├─ workspace-write
└─ danger-full-access

工具调用被拒绝
└─ 可请求一次更宽权限
   ├─ allowed-once：仅当前调用
   ├─ rejected：当前调用失败
   ├─ cancelled：请求撤回
   └─ unavailable：通道不可用
```

审批卡上“允许一次”不改变上面的三档 chip。若用户想永久切换，必须回到 chip
菜单并经过完全权限确认；这可以避免把一次危险操作误认为会话配置已改变。

## Gateway 改造方案

以下为实施前协议，不是本轮已完成的接口。

### 1. `permissions` projection

在 `normalizedProjectionSnapshot()` 和实时 projection 分发中加入：

```text
permissions: {
  currentValue: string
}
```

只接受 Host 的 `currentValue`，限制长度和字符集，不接受任意嵌套对象。当前值
为空或未知时隐藏可操作控件，不能默认成只读。

### 2. 权限目录

建议增加受控 operation：

```text
permissionCatalog
  -> [{ value, name, description?, experimental? }]
```

服务端必须：

- 读取 Host 的进程级目录；
- 拒绝任意客户端提交的预设值；
- 限制选项数量、字符串长度和字符集；
- 区分空目录和读取失败；
- 在目录撤回时使旧目录缓存失效。

### 3. 当前会话切换

建议增加：

```text
setPermissionPreset(sessionId, preset)
```

它由 Gateway 内部调用 Host 的 `commands/execute`：

```text
/permission <preset>
```

`preset` 必须由当前目录校验，不能把客户端传来的完整命令行直接执行。写入成功
后仍以 `permissions` projection 为权威确认，不以 HTTP 200 作为最终 UI 状态。

### 4. 审批结果

审批链路已经存在，实施时只做合同收紧：

- 只允许 `allowed-once` 和 `rejected` 作为工具审批回答；
- 一个 pending event 只能被回答一次；
- `engage`、超时、取消和连接断开都要有明确状态；
- `interaction-ended` 与 `approval/decided` 不冲突；
- 不把审批 request 的未知字段直接透传到 UI；
- `displayReason.zh/en` 需要长度限制和类型校验。

### 5. 新会话默认值

只有当前上游确实暴露 `permission.defaultPreset` 时，Gateway 才允许：

```text
settingsDescribe -> permission.defaultPreset
settingsSet      -> permission.defaultPreset
```

其值必须是目录中允许的未来默认项。`custom` 和 `auto` 不允许作为默认；写入
使用 revision/CAS，失败不自动重试。

## 参考 DSH Go

DSH Go 的设置页把权限明确分成：

- “当前对话”；
- “新对话默认”；
- 选择完全权限前显示风险确认；
- 说明新默认值只影响后来创建的会话。

可以借鉴的是信息范围和确认时机，不是它的六组设置结构、搜索框或大页面。DSH
Harmony 应保持 composer chip + DSH 设置行的紧凑布局。

## 分阶段实现建议

### Phase 1：只读状态和审批矩阵

- 将 `permissions` projection 暴露给原生端；
- 接入权限目录；
- 显示当前权限 chip 的只读状态；
- 完善现有审批卡的 pending / allowed-once / rejected / cancelled /
  unavailable / stale 状态。

这一阶段不改变任何 Host 权限。

### Phase 2：当前会话切换

- 增加权限菜单；
- 增加完全权限风险确认；
- 通过受控 `setPermissionPreset` 切换；
- 以 projection 确认结果；
- 覆盖目录撤回、断线和迟到响应。

### Phase 3：新会话默认值

- 在 DSH 设置页增加“新会话默认权限”；
- 接入 Host 设置 descriptor、revision/CAS；
- 验证修改不会影响当前会话。

### Phase 4：实验性 Auto

- 仅显示 Host 当前值；
- 单独评审实验确认、额外 token 和自动审查边界；
- 不将 `auto` 作为未来默认值。

## Mock 与 E2E 清单

本轮不新增 Mock fixture。未来实现时必须登记到
`docs/testing/mock-feature-manifest.json`，至少覆盖：

| 场景 | 类型 | 关键状态 |
| --- | --- | --- |
| `permission-current-read-only` | Composer | 只读当前值 |
| `permission-current-workspace` | Composer | 工作区当前值 |
| `permission-current-full` | Composer | 完全权限当前值 |
| `permission-current-custom` | Composer | custom 只读展示 |
| `permission-catalog-loading` | 浮层 | 目录加载中 |
| `permission-catalog-error` | 浮层 | 保留当前值并重试 |
| `permission-catalog-stale` | 浮层 | 目录撤回，关闭菜单 |
| `permission-full-confirm` | 浮层 | 勾选风险确认 |
| `permission-full-cancel` | 浮层 | 取消后不写 Host |
| `approval-workspace-once` | 审批卡 | 工作区单次升权 |
| `approval-full-once` | 审批卡 | 完全权限单次升权 |
| `approval-long-reason` | 审批卡 | 长原因滚动 |
| `approval-submitting` | 审批卡 | 按钮锁定 |
| `approval-ended` | 审批卡 | 请求被移除 |
| `approval-disconnected` | 审批卡 | 断线失败关闭 |
| `permission-default-setting` | 设置 | 新会话默认权限 |

每个动作、选择、审批和状态转移必须有 interaction driver，并加入设备 E2E 表。
静态截图不足以证明单次批准、拒绝、过期和断线行为。

## 未决问题

1. 当前会话权限入口是否固定放在 composer 底部工具栏，还是也提供 `/permission`
   命令菜单作为高级入口。
2. 首期是否显示当前 `auto` 状态但仍禁止从默认设置中选择。
3. 完全权限确认采用当前设计系统的局部确认层，还是复用设置页的确认样式。
4. 是否需要在后续支持硬件键盘 Enter/Esc；本轮移动端按钮和触控路径必须完整。
