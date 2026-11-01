# Mock 变体与前端覆盖 E2E

Date: 2026-11-01

状态：设备当前离线；以下实机项目均为 `Pending`。

## 覆盖契约

| ID | 场景 | 预期 | 状态 | 证据 |
| --- | --- | --- | --- | --- |
| MC-01 | 运行 `verify-mock-coverage.mjs` | 所有 screen/state 为 100%，无 missing | Passed | 7/7 screens、21/21 states、23/23 features；50 个静态组合 |
| MC-02 | 新增一个未登记 state | 检查明确失败并列出 state | Passed | Gateway 负向测试通过 |
| MC-03 | 构建三个 Release | default、store、mock 均成功 | Passed | 2026-11-01 三套 signed HAP 编译成功 |
| MC-04 | 安装 mock HAP | 默认进入 completed fixture，不访问网络 | Pending | |
| MC-05 | HDC 覆盖 state/theme | 参数仍可覆盖默认 fixture | Pending | |
| MC-06 | 新增用户功能但未登记 | `verify-mock-coverage.mjs` 和任意产品构建均失败 | Passed | Manifest 负向契约测试通过；三个构建均先执行同一门禁 |

## 前端功能登记覆盖

机器可读登记表：
[`mock-feature-manifest.json`](mock-feature-manifest.json)。

| ID | 功能 | Screen / State | 驱动 | 状态 |
| --- | --- | --- | --- | --- |
| MF-01 | 完成回合与会话正文 | `conversation/completed` | static + turn-change | Pending device |
| MF-02 | 运行中文件变更条 | `conversation/live-change` | static | Pending device |
| MF-03 | 发送附件托盘 | `conversation/attachments` | static | Pending device |
| MF-04 | 流式回答 | `conversation/streaming` | static | Pending device |
| MF-05 | 空运行回合 | `conversation/empty` | static | Pending device |
| MF-06 | 长历史与增量加载 | `conversation/long-history` | static | Pending device |
| MF-07 | 空闲发送 | `conversation/dock-send-idle` | dock interaction | Pending device |
| MF-08 | 待确认队列 | `conversation/dock-queue-pending` | dock interaction | Pending device |
| MF-09 | 权威队列消重 | `conversation/dock-queue-authoritative` | dock interaction | Pending device |
| MF-10 | 多队列折叠 | `conversation/dock-queue-many` | static | Pending device |
| MF-11 | 发送失败与草稿恢复 | `conversation/dock-send-error` | dock interaction | Pending device |
| MF-12 | Dock 静默材质 | `conversation/dock-material-quiet` | static | Pending device |
| MF-13 | Dock 抬升材质 | `conversation/dock-material-elevated` | static + dock interaction | Pending device |
| MF-14 | 审批卡提交 | `conversation/interaction-approval` | interaction | Pending device |
| MF-15 | 问题卡选择与提交 | `conversation/interaction-question` | interaction | Pending device |
| MF-16 | Plan 与子智能体谱系 | `conversation,lineage/plan-subagent,plan-off-error` | mode interaction | Pending device |
| MF-17 | 可继续子智能体 | `subagent/subagent-continuable` | mode interaction | Pending device |
| MF-18 | 一次性与未知只读模式 | `subagent/subagent-one-shot,subagent-unknown` | mode interaction | Pending device |
| MF-19 | 父会话离线 | `subagent/subagent-parent-offline` | mode interaction | Pending device |
| MF-20 | 工作过程 | `process/completed` | static | Pending device |
| MF-21 | 侧边栏与工作区 | `sidebar/completed` | static | Pending device |
| MF-22 | 文件浏览器 | `browser/completed` | static | Pending device |
| MF-23 | 设置与二级页 | `settings/completed` | static + settings interaction | Pending device |

## Plan 与子智能体

| ID | 场景 | 预期 | 状态 | 证据 |
| --- | --- | --- | --- | --- |
| MPS-01 | `conversation/plan-subagent` | 显示“计划”和子智能体计数 | Pending | |
| MPS-02 | 点击 Plan chip | 等待 projection 后 chip 移除 | Pending | |
| MPS-03 | `plan-off-error` 点击 Plan chip | 显示短失败提示，chip 保留 | Pending | |
| MPS-04 | `lineage/plan-subagent` | 抽屉展示运行、一次性、可继续、未知、外部 | Pending | |
| MPS-05 | 点击 external | 不打开且不伪造历史 | Pending | |
| MPS-06 | `subagent/subagent-continuable` | 可继续输入，显示排队/接管和 Stop | Pending | |
| MPS-07 | `subagent/subagent-one-shot` | 历史可读，composer 只读 | Pending | |
| MPS-08 | `subagent/subagent-unknown` | 历史可读，composer 只读 | Pending | |
| MPS-09 | `subagent/subagent-parent-offline` | composer 只读并显示父会话不可用 | Pending | |
| MPS-10 | 系统 Back | 返回直接父会话，再返回根会话 | Pending | |
| MPS-11 | 亮暗模式与减少动效 | 无裁切、无安全区重叠，动效直达最终状态 | Pending | |

## 驱动

```powershell
node .\scripts\verify-mock-coverage.mjs
.\scripts\device-ui-mock-suite.ps1
.\scripts\device-ui-interaction-e2e.ps1
.\scripts\device-ui-mode-subagent-e2e.ps1
.\scripts\device-ui-settings-e2e.ps1
.\scripts\device-ui-turn-change-e2e.ps1
.\scripts\device-ui-dock-e2e.ps1
```

静态覆盖完成不等于实机通过；上表在设备运行并保存截图、布局树和 manifest 前
必须保持 `Pending`。

本轮设备 `33Z0224801015621` 为 `Offline`，因此 MC-04、MC-05 和全部
`Pending device` 功能没有安装或执行。Release 产物：

- `harmony/entry/build/default/outputs/default/entry-default-signed.hap`
- `harmony/entry/build/store/outputs/store/entry-store-signed.hap`
- `harmony/entry/build/mock/outputs/mock/entry-mock-signed.hap`
