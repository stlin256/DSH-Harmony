# Mock 变体与前端覆盖调研

Date: 2026-11-01

## 现状

- `StoreShowcaseClient` 通过 `NativeHarnessClient` 接口提供确定性会话，不访问网络。
- 现有 `NativeUiFixture` 声明 7 个 screen 和 21 个 state。
- `device-ui-mock-suite.ps1` 覆盖大部分静态截图状态。
- `dock-queue-pending` 等动态状态由 `device-ui-dock-e2e.ps1` 交互驱动覆盖。
- 审批与问题卡由 `device-ui-interaction-e2e.ps1` 驱动。
- `device-ui-settings-e2e.ps1` 和 `device-ui-turn-change-e2e.ps1` 覆盖设置与文件变更。
- Plan、谱系和四种子智能体模式由 `device-ui-mode-subagent-e2e.ps1` 驱动。
- `build-profile` 已有独立 `mock` product，默认构建专用 signed HAP。
- personal/store 不自动选择 fixture，避免普通用户进入测试状态。

## 设计判断

继续把 fixture 只作为生产包的启动参数，容易让普通安装误入测试状态，也无法
清楚区分测试包。新增 `mock` product 可以在保留已有签名工具链的同时，让 CI、
HDC 和设备脚本明确使用一个测试产物。

使用相同 bundle identity 的原因是本机签名 Profile 与 AppGallery 应用身份已绑定。
另建 bundle 会导致个人 Profile 无法直接签名。独立 product 的 HAP 路径、源码
target、默认 fixture 行为和脚本参数已经能避免产物混淆。

## 覆盖检查

只用 screen/state 列表仍会遗漏“新功能复用旧 state”的情况。因此增加
`docs/testing/mock-feature-manifest.json`，把用户功能显式映射到 screen/state、
截图或交互驱动以及 E2E ID。自动检查同时验证 fixture、manifest、脚本和测试表；
任一环节缺失即失败。

静态截图只证明确定性视觉状态。发送、提交、导航和状态变化功能必须同时登记
非静态交互驱动。`build-harmony.ps1` 在 Hvigor 编译前执行覆盖门禁，避免仅运行
DevEco 构建时绕过检查。

程序无法自动理解任意新 ArkUI 控件的业务语义。仓库要求新增用户可见功能时先
添加 Mock 分支和 manifest 项；这属于开发契约，自动检查负责防止遗漏已经声明的
新 state，并阻止登记不完整的交付。

## 测试边界

Mock 可以证明前端状态、导航、模块权限和控件行为，不能证明真实 Push、Passkey、
网络恢复、服务端 Host 行为或系统 Picker。这些仍属于真实环境 E2E。
