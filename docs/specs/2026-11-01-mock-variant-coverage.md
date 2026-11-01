# Mock 变体与前端覆盖实现 SPEC

Date: 2026-11-01

Requirement:
[`2026-11-01-mock-variant-coverage.md`](../requirements/2026-11-01-mock-variant-coverage.md)

## 1. 产品变体

在 Harmony product 和 entry target 中新增：

```text
product: mock
target: mock
sourceRoot: ./src/mock
output: harmony/entry/build/mock/outputs/mock/entry-mock-signed.hap
```

`ProductCapabilities` 新增：

```ts
static readonly supportsMockFixtures: boolean
```

- `default`: `false`
- `store`: `false`
- `mock`: `true`

`EntryAbility` 仅在 `supportsMockFixtures=true` 时自动设置
`storeShowcase=true`。default/store 仍只在显式
`storeShowcase=true` 时读取 fixture，保持截图工具兼容。

Mock 产品使用现有 default source signing material；不新增或提交密钥。

## 2. Fixture 状态

`NativeUiFixture.screens` 增加：

- `lineage`: 根会话自动打开子智能体谱系抽屉。
- `subagent`: 直接打开一个子会话。

`NativeUiFixture.states` 增加：

- `plan-subagent`: Plan chip、子智能体计数和四种目录模式。
- `plan-off-error`: `/plan off` 返回可显示的本地错误。
- `subagent-continuable`: 可继续子会话，运行时可排队和停止。
- `subagent-one-shot`: 只读一次性子会话。
- `subagent-unknown`: 只读未知模式子会话。
- `subagent-parent-offline`: 父会话明确不可用且子会话空闲。

所有状态继续使用通用短文案，不出现真实服务或会话数据。

## 3. StoreShowcaseClient

根会话 projection 增加：

- `plan={active:true,pending:false}`；
- 3 个可打开成员和 1 个 `external` 成员；
- 运行成员的时间信息。

子会话由 `NativeShowcaseInteraction` 独立维护，返回确定性 history、
identity 和 composer 状态。`continuable` prompt 使用本地 interaction；
one-shot/unknown 拒绝发送。`cancel` 仅更新本地运行状态。

Mock `planOff` 成功后发送新的 inactive projection；失败 state 抛出短错误。

不修改生产 `NativeWorkspace` 的数据分支。`lineage`/`subagent` 只作为现有
fixture screen 导航钩子，在页面加载后执行与真实点击相同的打开路径。

## 4. 设备脚本

`device-ui-mock.ps1`：

- 默认 HAP 改为 mock signed HAP；
- 构建参数改为 `-Product mock`；
- 新增 screen/state ValidateSet；
- manifest 记录 `variant=mock`。

`device-ui-mock-suite.ps1` 增加 Plan、谱系和四类子会话的亮暗场景。

新增 `device-ui-mode-subagent-e2e.ps1`：

- 点击 Plan chip，验证成功后移除；
- 在错误 state 验证失败反馈；
- 从计数 chip 打开展示四种模式的谱系；
- 验证 external 不可打开；
- 验证 continuable 发送、一次性和未知只读、父会话离线和逐级 Back。

新增 `device-ui-interaction-e2e.ps1`：

- `interaction-approval` 验证审批文案、允许操作和卡片退出。
- `interaction-question` 验证问题文案、选项、提交和卡片退出。
- Mock `answer()` 只处理真实提交，`engage` 帧继续保留当前卡片，保证交互
  走与生产相同的提交入口且不访问网络。

## 5. 功能登记表

`docs/testing/mock-feature-manifest.json` 是用户可见功能的机器可读索引。
每项包含：

```json
{
  "id": "feature.id",
  "screens": ["conversation"],
  "states": ["fixture-state"],
  "drivers": ["device-ui-mock-suite.ps1", "device-ui-feature-e2e.ps1"],
  "e2eIds": ["MF-00"],
  "requiresInteraction": true
}
```

当前登记 conversation、流式、长历史、Dock、队列、发送失败、材质、审批、
问题、Plan、子智能体、过程、侧边栏、文件浏览器和设置共 23 项。

## 6. 自动覆盖检查

新增 `scripts/verify-mock-coverage.mjs`：

1. 从 `NativeUiFixture.ets` 提取 screen/state。
2. 从 `device-ui-mock-suite.ps1` 提取截图组合。
3. 从 `device-ui-*-e2e.ps1` 提取交互状态引用。
4. 要求每个 screen/state 至少被一个驱动引用。
5. 解析功能登记表，要求每个 fixture screen/state 至少被一个功能登记。
6. 要求功能引用的驱动存在、驱动确实引用对应 state、E2E ID 存在于测试表。
7. `requiresInteraction=true` 的功能必须绑定非静态交互驱动。
8. 校验 mock product、source root、默认 HAP 和 build 参数一致。
9. 输出 `screens N/N`、`states N/N`、`features N/N` 和覆盖率。

Gateway 增加对应测试，提取失败时 `npm test` 失败。`build-harmony.ps1` 在
调用 Hvigor 前执行同一检查，default、store、mock 任一构建都不能在功能登记
不完整时继续。

## 7. 验证

```powershell
node .\scripts\verify-mock-coverage.mjs
cd gateway
npm test
cd ..
.\scripts\build-harmony.ps1 -Product default -BuildMode release
.\scripts\build-harmony.ps1 -Product store -BuildMode release
.\scripts\build-harmony.ps1 -Product mock -BuildMode release
```

设备在线后再执行截图套件、审批/问题交互和模式/子智能体交互脚本。编译与
静态覆盖不能替代真机结果。
