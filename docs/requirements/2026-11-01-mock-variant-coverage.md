# Mock 变体与前端覆盖需求

Date: 2026-11-01

## 用户目标

提供一个可独立构建、安装和识别的 `mock` 产品变体，用确定性的本地前端数据
覆盖所有原生 UI 功能。以后每次新增面向用户的功能，都必须同时增加对应 Mock、
设备驱动和 E2E 表项目；没有覆盖的功能不能算前端完成。

## 覆盖定义

本仓库中的“Mock E2E 覆盖率 100%”指：

1. `NativeUiFixture.screens` 中每个顶层界面至少有一个设备场景。
2. `NativeUiFixture.states` 中每个状态至少被截图套件或交互驱动引用。
3. 新增 Plan、子智能体、Dock、交互卡、文件预览等用户功能都有可复现状态。
4. 需要点击、发送、返回或状态切换的功能有交互驱动，不能只靠静态截图。
5. 自动检查发现未覆盖的声明时必须失败，报告缺口的 screen/state。
6. `docs/testing/mock-feature-manifest.json` 必须登记每个用户可见功能、
   对应 screen/state、驱动脚本和 E2E 表项目。
7. Manifest 中的每个 state 至少被所选驱动实际引用；标记为交互的功能还
   必须包含非静态截图驱动。

这里的 100% 是“Mock 映射覆盖”，不代表所有设备场景已经执行通过。设备未运行
的项目仍必须在 E2E 表中保持 `Pending`。

“100%”不能由程序推断任意新控件的业务语义。新增用户可见功能时，开发者必须
先登记功能并要求一个确定性的 Mock 分支；漏登记会通过仓库规则和覆盖门禁阻止
交付。真实网络、Passkey、系统选择器和推送投递等外部依赖仍保留独立 E2E。

## Mock 产品变体

- 产品名固定为 `mock`，输出独立的 signed HAP。
- 使用与社区版相同的 bundle identity，以便现有 HDC 和签名 Profile 可直接安装。
- Mock 产品默认进入本地 fixture；显式启动参数仍可覆盖 screen、state 和 theme。
- 社区版与商店版不得在正常启动时自动进入 fixture。
- Mock 不使用网络、真实账号、Passkey、真实服务地址或真实会话内容。

## 当前新增功能

- Plan 模式 chip、退出成功和退出失败。
- 根会话的子智能体计数、运行点和谱系抽屉。
- `continuable`、`one-shot`、`unknown`、`external` 四种模式。
- 子会话只读原因、可继续输入、逐级 Back 和父会话不可用状态。

## 自动门槛

- `node scripts/verify-mock-coverage.mjs` 必须输出 100%。
- `harmony/entry/build-profile.json5` 必须声明 `mock` target。
- `scripts/build-harmony.ps1 -Product mock` 必须可用。
- `scripts/device-ui-mock.ps1` 默认构建、安装和检查 `mock` HAP。
- `scripts/build-harmony.ps1` 在编译前运行 Mock 覆盖检查，任何产品构建都不能
  绕过未登记的 Mock 功能。
- Gateway tests 必须包含 Mock 覆盖契约。
- 共享 ArkUI 代码变化后仍构建 default、store 和 mock 三个 Release。
