# Mock 变体与前端覆盖 E2E

Date: 2026-11-01

状态：API 26 真机通过。当前 Mock HAP 完成 115/115 静态组合、12/12 screens、
76/76 states、39/39 registered features，并通过受影响的交互驱动。

## 覆盖契约

| ID | 场景 | 预期 | 状态 | 证据 |
| --- | --- | --- | --- | --- |
| MC-01 | 运行 `verify-mock-coverage.mjs` | 所有 screen/state 为 100%，无 missing | Passed | 12/12 screens、76/76 states、39/39 features；115 个静态组合 |
| MC-02 | 新增一个未登记 state | 检查明确失败并列出 state | Passed | Gateway 负向测试通过 |
| MC-03 | 构建三个 Release | default、store、mock 均成功 | Passed | 2026-11-01 三套 signed HAP 编译成功 |
| MC-04 | 安装 mock HAP | 默认进入 completed fixture，不访问网络 | Passed | 全量 suite 与多状态交互安装 |
| MC-05 | HDC 覆盖 state/theme | 参数仍可覆盖默认 fixture | Passed | dark/light fixture 覆盖 |
| MC-06 | 新增用户功能但未登记 | `verify-mock-coverage.mjs` 和任意产品构建均失败 | Passed | Manifest 负向契约测试通过；三个构建均先执行同一门禁 |

## 前端功能登记覆盖

机器可读登记表：
[`mock-feature-manifest.json`](mock-feature-manifest.json)。

| ID | 功能 | Screen / State | 驱动 | 状态 |
| --- | --- | --- | --- | --- |
| MF-01 | 完成回合与会话正文 | `conversation/completed` | static + turn-change | Passed |
| MF-02 | 运行中文件变更条 | `conversation/live-change` | static | Pending device |
| MF-03 | 发送附件托盘 | `conversation/attachments` | static | Pending device |
| MF-04 | 流式回答 | `conversation/streaming` | static | Pending device |
| MF-05 | 空运行回合 | `conversation/empty` | static | Pending device |
| MF-06 | 长历史与增量加载 | `conversation/long-history` | static + conversation chrome interaction | Pending device |
| MF-07 | 空闲发送 | `conversation/dock-send-idle` | dock interaction | Pending device |
| MF-08 | 待确认队列 | `conversation/dock-queue-pending` | dock interaction | Pending device |
| MF-09 | 权威队列消重 | `conversation/dock-queue-authoritative` | dock interaction | Pending device |
| MF-10 | 多队列折叠 | `conversation/dock-queue-many` | static | Pending device |
| MF-11 | 发送失败与草稿恢复 | `conversation/dock-send-error` | dock interaction | Pending device |
| MF-12 | Dock 静默材质 | `conversation/dock-material-quiet` | static | Pending device |
| MF-13 | Dock 抬升材质 | `conversation/dock-material-elevated` | static + dock interaction | Pending device |
| MF-14 | 审批卡提交 | `conversation/interaction-approval` | interaction | Passed |
| MF-15 | 问题卡选择与提交 | `conversation/interaction-question` | interaction | Passed |
| MF-16 | Plan 与子智能体谱系 | `conversation,lineage/plan-subagent,plan-subagent-long-count,plan-off-error` | mode interaction | Passed |
| MF-17 | 可继续子智能体 | `subagent/subagent-continuable` | mode interaction | Passed |
| MF-18 | 一次性与未知只读模式 | `subagent/subagent-one-shot,subagent-unknown` | mode interaction | Passed |
| MF-19 | 父会话离线 | `subagent/subagent-parent-offline` | mode interaction | Passed |
| MF-20 | 工作过程 | `process/completed` | static | Pending device |
| MF-21 | 侧边栏与工作区 | `sidebar/completed` | static | Pending device |
| MF-22 | 文件浏览器 | `browser/completed` | static | Pending device |
| MF-23 | 设置与二级页 | `settings/completed` | static + settings interaction | Passed |
| MF-24 | 插件管理原生页 | `plugins/plugins-*` | static | Pending device |
| MF-25 | 自动化任务列表与空态 | `automation/automation-list,automation-empty` | static | Pending device |
| MF-26 | 自动化详情、编辑、历史与冲突 | `automation/automation-detail,automation-editor,automation-history,automation-conflict` | static | Pending device |
| MF-27 | 更多锚定菜单 | `more/more-actions` | static | Pending device |

## Plan 与子智能体

| ID | 场景 | 预期 | 状态 | 证据 |
| --- | --- | --- | --- | --- |
| MPS-01 | `conversation/plan-subagent` | 标题区只显示子智能体入口；Plan 退出动作位于更多菜单 | Passed | `mode-subagent-clean/plan-lineage` |
| MPS-02 | 从更多菜单退出 Plan | 等待 projection 后菜单动作移除 | Passed | `plan-removed` |
| MPS-03 | `plan-off-error` 退出失败 | 显示短失败提示，更多菜单保留退出动作 | Passed | `plan-error-after` |
| MPS-04 | `lineage/plan-subagent` | 抽屉展示运行、一次性、可继续、未知、外部 | Passed | `lineage-open` |
| MPS-05 | 点击 external | 不打开且不伪造历史 | Passed | manifest |
| MPS-06 | `subagent/subagent-continuable` | 可继续输入，发送可用 | Passed | `continuable`、`subagent-sent` |
| MPS-07 | `subagent/subagent-one-shot` | 历史可读，composer 只读 | Passed | `one-shot` |
| MPS-08 | `subagent/subagent-unknown` | 历史可读，composer 只读 | Passed | `unknown` |
| MPS-09 | `subagent/subagent-parent-offline` | composer 只读并显示父会话不可用 | Passed | `parent-offline` |
| MPS-10 | 系统 Back | 返回直接父会话，再返回根会话 | Passed | `returned-parent` |
| MPS-11 | 亮暗模式与减少动效 | 无裁切、无安全区重叠，动效直达最终状态 | Pending | |
| SUB-19 | 长子智能体数量 | `128` 完整显示，入口向左扩展并压缩标题，不挤压更多操作 | Passed | `plan-visible-long-count` |
| SUB-20 | 子代理页面导航身份 | 子代理页只有返回父会话按钮，不显示侧边栏 | Passed | `workspace-subagent-back` |
| SUB-21 | 冷启动与子代理深链 | 冷启动及 `sessionId=child` 路由都落到一级会话，侧边栏可用 | Passed | `cold-root`、`requested-child-root` |
| CHROME-01 | 聊天滚动条物理边缘 | 滚动容器抵达屏幕右缘，正文保留右侧页面内边 | Passed | `conversation-chrome-clean/scrollbar-edge` |
| CHROME-02 | 聊天滚动交互 | 上滑移动正文并保留滚动中截图 | Passed | `scroll-live.jpeg` |

## 驱动

```powershell
node .\scripts\verify-mock-coverage.mjs
.\scripts\device-ui-mock-suite.ps1
.\scripts\device-ui-interaction-e2e.ps1
.\scripts\device-ui-mode-subagent-e2e.ps1
.\scripts\device-ui-settings-e2e.ps1
.\scripts\device-ui-turn-change-e2e.ps1
.\scripts\device-ui-dock-e2e.ps1
.\scripts\device-ui-conversation-chrome-e2e.ps1
```

静态覆盖完成不等于实机通过；上表在设备运行并保存截图、布局树和 manifest 前
必须保持 `Pending`。

本轮设备 `33Z0224801015621` API 26 已完成当前 Mock HAP 的安装、全量矩阵和
受影响的交互驱动。当前设备证据：

- `artifacts/device-e2e-final/mock-suite-clean/suite-summary.json`
- `artifacts/device-e2e-final/mode-subagent-clean/plan-lineage/manifest.json`
- `artifacts/device-e2e-final/settings-clean/appearance-persistence/manifest.json`
- `artifacts/device-e2e-final/interaction-clean/approval-question/manifest.json`

最终 Release 产物：

- `harmony/entry/build/default/outputs/default/entry-default-signed.hap`
- `harmony/entry/build/store/outputs/store/entry-store-signed.hap`
- `harmony/entry/build/mock/outputs/mock/entry-mock-signed.hap`
