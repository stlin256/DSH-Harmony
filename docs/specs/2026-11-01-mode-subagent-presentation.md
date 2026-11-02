# Plan 模式与子智能体呈现实现 SPEC

状态：协议、模型与原生表面已实现；自动验证已通过，设备 E2E pending

## 1. 数据契约

### 1.1 Gateway 归一化

新增纯函数：

- `normalizePlanProjection(value)`
- `normalizeSubagentCatalog(value)`
- `normalizeSubagentIdentity(value)`
- `normalizeSubagentTiming(value)`
- `normalizeSubagentAddress(value)`

规则：

- session/member id 使用现有 `sessionIdValid`，长度 1..160。
- label 去除控制字符、压缩空白、截断 160 字符。
- `mode` 只接受白名单。
- `continuable` 目录成员和身份必须带 label。
- seq、时间戳、耗时均为非负安全整数。
- catalogue 最多 100 个直接成员；重复 id 只保留第一项。
- malformed catalogue item 不进入结果；整体类型错误返回 `null`。
- `subagent` 显式 `null` 是有效权威值。
- Session summary 的 `agentAvailable` 仅在 Host 提供布尔值时转发；缺字段保持 unknown，不折叠成 `false`。

### 1.2 Live frame

后续帧使用类型化 key，避免把任意 projection 透传：

```ts
{ type: 'plan', plan: { active, pending }, projectionSeq }
{ type: 'subagent-catalog', catalog: [...], projectionSeq }
{ type: 'subagent-identity', identity: {...} | null, projectionSeq }
{ type: 'subagent-timing', timing: {...}, projectionSeq }
```

每个 key 独立按 `projectionSeq` 递增。客户端忽略旧 seq。

### 1.3 Snapshot

`operation: projections` 返回白名单快照：

```ts
{
  kind: 'sequenced',
  asOfSeq,
  values: {
    plan?: { active, pending },
    subagentCatalog?: [...],
    subagent?: {...} | null,
    subagentTiming?: {...}
  }
}
```

## 2. 传输与操作

### 2.1 Follow 与分页

客户端地址：

```ts
{ kind: 'session', sessionId }
{ kind: 'subagent', parentSessionId, childSessionId, mode }
```

- WebSocket query 增加受验证的 `parentSessionId`、`parentMode`。
- `session/follow` 使用 Address。只有普通 `session` 用户主动打开时传
  `activate: true`；`subagent` 子历史使用同一 address 非激活读取。
- `session/page` 使用同一 Address。
- state/projection subscription 仍点名 child session id。

### 2.2 子代理操作

- `subagents/prompt` 请求：

```ts
{
  requestId,
  parentSessionId,
  childSessionId,
  mode: 'continuable',
  delivery: 'queue' | 'steer',
  content: [{ type: 'text', text }]
}
```

- Stop 使用 positional wire args：

```ts
[childSessionId, parentSessionId, 'continuable']
```

- Plan off 使用 positional wire args：

```ts
[sessionId, '/plan off', []]
```

## 3. ArkTS 模型

新增 `NativeModeSubagent.ets`：

- Plan projection 与目标状态计算。
- 子智能体 mode/identity/timing/entry。
- projection per-key seq 校验。
- catalogue duplicate/cycle/depth guard。
- address validation 与 stack pop。
- `canOpen`、`readOnlyReason`、时长格式。

`NativeSession` 增加展示所需的基础 parent/identity 字段。

`NativeFrame` 增加类型化 projection 字段和 `projectionSeq`。

## 4. UI

### 4.1 Plan 退出动作

- 标题区、标题下方和任务计划 Dock 前方都不显示 Plan chip。
- 仅 authoritative target active 时，在右上角“更多操作”菜单中显示“退出计划模式”。
- 选择后调用 `/plan off`；菜单关闭，收到权威 inactive projection 前保留本地
  Plan 状态。
- 成功后再次打开菜单不再显示该动作；失败在标题下方显示
  “退出计划模式失败”，2 秒后自动清理。

### 4.2 子代理 chip

- 根/当前父会话的直接目录成功且非空时显示，并进入会话标题主行，位于标题列
  与“更多操作”之间。
- 视觉只显示 `branch-outline` 与 `N`，不显示“个子智能体”长文案、运行圆点或
  下拉箭头。运行成员存在时，图标和数字使用 accent 色；否则使用 secondary 色。
- 视觉高度 28vp、圆角 `radiusChip`，左右 padding 合计不超过 14vp；完整语义
  `N 个子智能体[，正在运行]` 写入 accessibility text。
- 长标题先截断，chip、行内 loading 和 44vp 图标触控区不得被压缩或移出标题行。
- 目录非空本身不创建标题下方状态行；标题下方只允许出现短暂 Plan 错误文本。
- 子会话额外显示父级返回入口，不使用永久第二顶栏。

### 4.3 谱系抽屉

- 最大高度 `min(60% viewport, 520vp)`，底部安全区。
- 实色 `raised` surface；无额外教学文本。
- 44vp 行、12vp 圆角、树形缩进与 1px 连接线。
- 当前子会话高亮；运行、完成、未运行用短标签。
- one-shot/continuable/unknown/external 显示官方短模式名。
- 副标题模式名不得重复标题；外部成员的副标题固定为“外部”，
  右侧不可用状态与无障碍说明负责表达“不可打开”。
- 外部成员禁用打开；加载与失败使用紧凑状态行。
- disclosure/toggle 使用 `NativeMotion.disclosure`，减少动效直接完成。

### 4.4 子会话 composer

- `continuable` 可发送文本；当前运行时支持 queue/steer 与 Stop。
- `one-shot`：显示“一次性子智能体记录”，只读。
- `unknown`：显示“此子智能体暂时只读”，只读。
- `external`：不可进入。
- 子代理 composer 不展示普通文件的附件入口；避免发送 Host 明确拒绝的 file receipt。
- 父可用性为 `false` 且子会话空闲时显示只读；可用性未知时保持正常 composer，等待 Host summary。

## 5. 导航

- `NativeNavigationState` 增加 `lineage` 与 `subagentHistory`。
- 打开 child 前保存 current root id、parent id、mode 和 title。
- child Back 返回 direct parent；嵌套地址逐级弹出。
- 抽屉打开时 Back 只关闭抽屉。
- 普通根会话列表点击仍只打开 `origin !== 'subagent'` 的会话。
- 从通知/外部路由打开 child 时只接受合法 address，否则回根会话入口。

## 6. 性能与恢复

- projection cache 按 session id 保存，只保留最近 24 个目录快照。
- 目录展开按需加载；当前实现只加载所打开父级的直接目录。
- 切会话取消旧 follow，不复用旧 identity/timing。
- 重连以 projection baseline 替换本地状态。
- 登出清空所有子代理缓存。

## 7. 测试

- Gateway normalization 的 malformed、duplicate、null identity、limits。
- Plan target 与 pending。
- catalogue/identity/timing baseline 与 live frame。
- 旧 seq 不覆盖新值。
- follow/page 的普通与子代理 address wire。
- 普通根会话 Follow 保持 `activate:true`；子智能体 Follow 对同一 address 使用
  `activate:false`，并有真实 WebSocket 集成断言。
- `/plan off`、subagent prompt、interrupt 的准确 args。
- 子代理发送必须携带实际 `childSessionId`，不能依赖未定义变量或隐式字段。
- ArkTS capability：external 不可打开、one-shot/unknown 只读、continuable 可发送。
- 显式 null identity、父会话离线、运行中 Stop、address stack、深度/cycle guard、duration format。
- 源码契约：普通列表过滤 child；chip 不消费任务清单；子智能体计数位于标题行，
  标题下方的模式状态行只承载 Plan。

## 8. 验证门槛

- `gateway: npm test`
- default Release 构建
- store Release 构建
- 设备在线后再执行 E2E 表中的实机项

## 9. 全局底部安全区

- `NativeDesign.navigationBarMinInset` 固定为 20vp，是原生底部安全区的权威下限。
- `WindowAppearance.refreshSafeArea()` 发布
  `nativeSafeBottom = max(20, systemGestureBottom)`；窗口尚未就绪和读取异常时同样
  发布 20vp，禁止回退为 0。
- 所有已有 `@StorageLink('nativeSafeBottom')` 的页面、抽屉、浮层、预览、灯箱和
  Dock 自动继承该下限。任何新增底部表面必须消费同一 token，不得自行写 0 或
  小于 20vp 的安全区。
- `NativeBottomConversationDock` 在未弹出输入法时直接使用 20vp 页面安全区；
  输入法可见时改用 12vp 紧凑间隙，使发送控件更贴近输入法。
