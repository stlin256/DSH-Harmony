<p align="center">
  <img src="docs/assets/dsh-harmony.svg" width="96" height="96" alt="DSH Harmony">
</p>

<h1 align="center">DSH Harmony</h1>

<p align="center">
  <strong>把 DeepSeek Harness 装进 HarmonyOS</strong><br>
  为手机重新设计的原生工作空间，让想法、执行与结果留在同一条工作线上。
</p>

<p align="center">
  <a href="https://github.com/deepseek-ai/deepseek-harness">
    <img src="docs/assets/deepseek.svg" width="22" height="22" alt="DeepSeek">
  </a>
  <a href="https://github.com/deepseek-ai/deepseek-harness"><strong>DeepSeek Harness</strong></a>
  &nbsp;·&nbsp;
  <img src="https://img.shields.io/badge/HarmonyOS-7-4D6BFE?style=flat-square" alt="HarmonyOS 7">
  <img src="https://img.shields.io/badge/API-23%2B-2EA44F?style=flat-square" alt="HarmonyOS API 23+">
  <img src="https://img.shields.io/badge/license-AGPL--3.0-6E7781?style=flat-square" alt="AGPL 3.0">
</p>

<p align="center">
  <a href="README.en.md">English</a> · <strong>简体中文</strong>
</p>

---

## 为手机而生的 Harness

DSH Harmony 将 DeepSeek Harness 的工作空间、会话、工具调用和实时输出带到 HarmonyOS，并以 ArkUI 构建为触控、键盘、安全区与系统返回重新设计的原生界面。

它关心的不只是“能不能用”。从冷启动到长对话滚动，从一次工具调用到一条后台通知，DSH Harmony 都围绕更少的等待、更清楚的状态和更自然的操作展开。

## 从想法到交付，在同一条工作线上

把需求交给 DSH Harmony，接着看它读取文件、运行命令、整理差异并给出结果。过程可以展开，结果保持直接；浮动任务计划和实时状态始终贴着当前工作。

<p align="center">
  <img src="artifacts/readme-screenshots/final/appgallery-landscape/01-conversation-1920x1080.png" width="100%" alt="DSH Harmony 原生会话与浮动任务计划">
</p>

<p align="center">
  <img src="artifacts/readme-screenshots/final/appgallery-portrait/02-process-1080x1920.png" width="250" alt="结构化工作过程">
  <img src="artifacts/readme-screenshots/final/appgallery-portrait/03-plan-subagent-1080x1920.png" width="250" alt="计划与子代理谱系">
  <img src="artifacts/readme-screenshots/final/appgallery-portrait/04-file-preview-1080x1920.png" width="250" alt="工作区文件预览">
</p>

**过程清楚，结果直接。** 读取、执行与改动按真实顺序展开，需要细看的时候再展开。

**并行推进，上下文相连。** 计划、子代理和父子会话保持清楚，继续检查也不丢失上下文。

**文件就在工作区里。** 配置、表格、Markdown、代码和图片都可以直接阅读，全程只读。

## 该确认时，只确认一次

会话权限、单次审批、提问和附件都贴着输入栏工作。高风险操作会明确展示范围与影响；单次授权只放行当前工具调用，不会改变会话权限。

<p align="center">
  <img src="artifacts/readme-screenshots/final/appgallery-portrait/05-approval-1080x1920.png" width="250" alt="单次审批与风险确认">
  <img src="artifacts/readme-screenshots/final/appgallery-portrait/07-automation-1080x1920.png" width="250" alt="自动化任务与运行状态">
  <img src="artifacts/readme-screenshots/final/appgallery-portrait/08-plugins-1080x1920.png" width="250" alt="插件与运行组件">
</p>

**清楚的审批边界。** 允许一次、拒绝、风险确认和提交中的状态都有明确的视觉归宿。

**让重复工作按时发生。** 每日巡检、每周整理和发布同步都在自动化任务中集中管理。

**工具随需扩展。** 浏览已安装能力、确认运行状态，并在同一处完成启用与管理。

## 原生界面，完整工作流

DSH Harmony 以 ArkUI 构建单一原生工作空间：会话、工作过程、模型选择、权限、文件预览、插件和自动化都使用 DSH 的视觉语言。它会记住上次会话、工作区、滚动位置和展开状态。

登录保持灵活：

- **Harness 原生登录**是默认选项，可连接局域网或公网地址。
- **Pocket ID · Passkey**是可选选项，在 HTTPS 环境中使用系统 Passkey。

## 清晰，但不打断思路

| **顺滑** | **简洁** |
| --- | --- |
| 缓存先行、增量同步，历史内容提前预取；稳定列表与虚拟化渲染让长对话保持轻盈，页面切换和展开状态遵循 HarmonyOS 的节奏。 | 沿用 DSH 的紧凑信息层级与视觉语义。工具、思考、文件和消息保持清楚，但不让界面替内容抢戏。 |
| 触控反馈、抽屉、页面动线、安全区和系统 Back 都为 HarmonyOS 重新实现，并尊重系统的减少动态效果设置。 | 覆盖会话、模型、工具、审批、提问、图片、Markdown、代码、文件浏览与分级通知，让移动端真正完成工作流。 |

<p align="center">
  <img src="artifacts/readme-screenshots/final/appgallery-landscape/06-appearance-light-dark-1920x1080.png" width="49%" alt="DSH Harmony 亮暗模式">
  <img src="artifacts/readme-screenshots/final/appgallery-landscape/09-desktop-cards-1920x1080.png" width="49%" alt="DSH Harmony 桌面卡片">
</p>

## 开始使用

把下面这一句发给 DSH，支持 `plugin_manager` 的 Agent 会完成插件安装并核对版本：

```text
请按 https://github.com/stlin256/DSH-Harmony/blob/main/docs/PLUGIN-INSTALL.md 安装并启用 DSH Harmony 插件，使用与 App 匹配的 plugin-v0.4.0 Release 中的 dsh-harmony-plugin-0.4.0.tgz，安装后确认 @dsh-harmony/plugin 正常运行并报告版本。
```

也可以打开 DSH 的 **插件 → Add plugin**，粘贴同一版本化 tarball 地址。随后打开 DSH Harmony，填写服务地址并选择原生登录或 Passkey。

[插件安装](docs/PLUGIN-INSTALL.md) · [部署](docs/DEPLOYMENT.md) · [Passkey](docs/OIDC-DEPLOYMENT.md)

## 连接状态，随时知道

任务完成、失败或等待确认时，DSH Harmony 可以按级别发送 HarmonyOS 通知。点击通知会回到对应会话；桌面服务卡片则以紧凑方式呈现工作区与任务状态。

社区构建支持使用 Push Kit 的即时推送。面向 AppGallery 的构建会按应用商店能力单独配置，并在受系统约束的场景下提供后台状态监测。

## 面向 AppGallery

<p align="left">
  <a href="https://developer.huawei.com/consumer/cn/appgallery/">
    <img src="docs/assets/huawei-appgallery.svg" width="34" height="34" alt="Huawei AppGallery">
  </a>
  <strong>HarmonyOS AppGallery · 准备中</strong>
</p>

DSH Harmony 正在完成面向所有 HarmonyOS 用户的商店发布准备。商店版本保留同样流畅的界面、完整的会话体验与 DSH 原生设计，并按照 AppGallery 的分发与通知规范发布。

## 参与共建

DSH Harmony 是开源项目。欢迎提交问题、改进建议和代码；开始开发前，请阅读 [验证说明](docs/VALIDATION.md) 与仓库中的实现规格。

[报告问题](https://github.com/stlin256/DSH-Harmony/issues) · [查看源码](https://github.com/stlin256/DSH-Harmony) · [作者主页](https://github.com/stlin256)

<p align="center">
  <sub>Built for HarmonyOS with care. AGPL-3.0.</sub>
</p>
