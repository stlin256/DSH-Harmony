# DSH Harmony 移动端

![DSH Harmony](AppScope/resources/base/media/app_icon.svg)

[English](README.en.md)

HarmonyOS 原生工程位于本目录。仓库根目录 README 提供产品、登录、插件和通知说明；本页聚焦构建与签名。

## 构建产品

| 产品 | Push Kit | 后台通知 | 用途 |
| --- | --- | --- | --- |
| `community` | 包含 | 由 Push Kit 送达 | 社区签名版；服务器插件使用项目服务帐号推送 |
| `store` | 不包含 Push Kit SDK | 可选监测运行中任务 | 应用商店及普通开发者构建 |
| `mock` | 不包含 | 不适用 | 仅供前端开发与设备自动化；默认加载确定性本地数据，不访问网络 |

`community` 和 `mock` 的展示名为 **DSH Harmony**，`store` 的展示名为
**DSH Mobile**。展示名由各产品的 `ProductCapabilities.appDisplayName`
控制，构建脚本会同步桌面 `app_name` 并在构建结束后恢复源资源。bundle name
保持为 `io.github.stlin256.dshharmony`。需要在 Huawei 开发者中心登记这个应用后，才能为该应用申请应用签名和 Push Kit 能力。此仓库不保存应用签名、服务帐号或开发者凭据。

社区版在 HarmonyOS 工程内继续复用 `default` target，以保持既有签名资料和
升级路径兼容；产品脚本对外统一使用 `community`。

## 本机构建

1. 使用包含 SDK 26 的 DevEco Studio。
2. 将 `build-profile.example.json5` 复制为本机忽略的 `build-profile.json5`，填入开发者中心签名配置；保留个人密钥在 Git 之外。
3. 在仓库根目录使用产品构建脚本；它会同步桌面名称、检查 Mock 覆盖并恢复
   构建期间的临时资源修改：

```powershell
.\scripts\build-harmony.ps1 -Product community -BuildMode release
.\scripts\build-harmony.ps1 -Product store -BuildMode release
.\scripts\build-harmony.ps1 -Product mock -BuildMode release
```

直接使用 DevEco CLI 时，命令如下：

社区版的底层 target 仍为 `default`；下面的 `devecocli` 命令是绕过产品脚本时的
直接构建方式。

```sh
devecocli signature generate --product default
devecocli signature generate --product store
devecocli signature generate --product mock
devecocli build --product default --build-mode release
devecocli build --product store --build-mode release
devecocli build --product mock --build-mode release
```

安装到当前设备可执行 `devecocli run --module entry@default --product default --build-mode release --skip-build`。Mock 产物位于 `entry/build/mock/outputs/mock/entry-mock-signed.hap`。

构建前必须通过：

```sh
node ../scripts/verify-mock-coverage.mjs
```

新增用户可见前端功能时，必须同时加入确定性 Mock 状态、截图或交互驱动、`docs/testing/mock-feature-manifest.json` 登记和 E2E 表项目。只加入生产界面而不补 Mock 会被覆盖门禁拒绝。

## 通知

服务端 DSH 插件保存任务名与匿名状态投影。`community` 版以 Push Kit 分别发送任务完成、失败和待确认提醒。`store` 版不获取 Push Kit token；用户开启“任务运行时后台监测”后，应用只在检测到运行中任务时申请系统可见的长时任务，轮询状态，任务完成后停止。通知点击会打开对应会话。

不要将真实服务地址、凭据、签名 Profile 或 Push Kit 服务帐号提交到仓库。
