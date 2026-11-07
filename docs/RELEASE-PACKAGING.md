# 商店发布打包流程

面向 AppGallery 上传的 HarmonyOS 应用包（`.app`）打包步骤。
适用于 DSH Harmony 仓库的 `store` 产品变体。

## 前置条件

| 项 | 要求 |
| --- | --- |
| DevEco Studio | 26.0.0 或更高，含 HarmonyOS SDK API 26 |
| 签名材料 | `~/.ohos/config/` 下的 `dsh-harmony-release.cer` / `.p7b` / `.p12` |
| 构建配置 | `harmony/build-profile.json5` 中的 `store` signingConfig |
| 发布 Profile | 与 AppGallery 后台登记的证书一致，且权限清单覆盖 HAP 声明的权限 |

`harmony/build-profile.json5` 被 `.gitignore` 忽略，属于本机私有配置。
若文件缺失，`scripts/build-harmony.ps1` 会从
`harmony/build-profile.example.json5` 复制一份（不含签名材料），
此时需要手工补回 `store` 签名配置。

## 一条命令打包

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File scripts/build-harmony.ps1 `
  -DevEcoHome "$env:LOCALAPPDATA\Programs\Huawei\DevEcoStudio-26.0.0" `
  -Product store -BuildMode release -AssembleApp
```

产物：

```
harmony/build/outputs/store/harmony-store-signed.app     ← 上传 AppGallery
harmony/build/outputs/store/harmony-store-unsigned.app
```

`-AssembleApp` 走 hvigor 的 `assembleApp` 任务：打包全部模块、
生成 `pack.info` / `pac.json`，并用产品的 `signingConfig` 对整包签名。
构建成功后脚本会自动执行 `scripts/verify-store-bundle.mjs` 校验权限与版本，
失败则中止（防止 7014）。

## 脚本做了什么

`scripts/build-harmony.ps1` 在构建前后自动处理这些易错点：

1. **变体清单替换** —— `-Product store` 时把
   `harmony/variants/store/module.json5` 复制到
   `harmony/entry/src/main/module.json5`，构建结束再按字节还原。
   store 变体移除了 `ohos.permission.ACCESS_FIDO2_ONLINEAUTH`。
2. **应用名替换** —— 从 `entry/src/<capability>/ProductCapabilities.ets`
   读取 `appDisplayName`，写入 `AppScope/resources/base/element/string.json`，
   构建结束还原。
3. **环境准备** —— 设置 `NODE_HOME` / `JAVA_HOME` / `DEVECO_SDK_HOME` 与 `PATH`，
   执行 `ohpm install`。
4. **覆盖率门禁** —— 先跑 `scripts/verify-mock-coverage.mjs`，失败即中止。

## 上传前检查清单

### 1. 权限与 Profile 一致（错误码 7014）

自动校验（构建时已执行，可单独复跑）：

```powershell
node scripts/verify-store-bundle.mjs
```

期望输出：

```
Store bundle checks passed: 2 permission(s), version 0.4.10 (31)
  permissions: ohos.permission.INTERNET, ohos.permission.KEEP_BACKGROUND_RUNNING
```

脚本会拒绝：出现 `ACCESS_FIDO2_ONLINEAUTH`（变体清单未替换）、
出现 Profile 未批准的其它权限、缺少必需权限、`pack.info` 版本或 bundleType 异常。

手工核对方式：

AppGallery 上传时报 `7014 软件包内配置的权限与 Profile 申请的权限不一致`，
表示 HAP 声明的权限超出了发布 Profile 已批准的范围。

验证 HAP 实际权限：

```powershell
# .app 是 zip；取出其中的 HAP 再解压读 module.json
$tmp = Join-Path $env:TEMP 'release-check'
Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
Copy-Item harmony/build/outputs/store/harmony-store-signed.app (Join-Path $tmp 'a.zip')
Expand-Archive (Join-Path $tmp 'a.zip') -DestinationPath (Join-Path $tmp 'app')
Copy-Item (Join-Path $tmp 'app/entry-store.hap') (Join-Path $tmp 'h.zip')
Expand-Archive (Join-Path $tmp 'h.zip') -DestinationPath (Join-Path $tmp 'hap')
(Get-Content (Join-Path $tmp 'hap/module.json') -Raw | ConvertFrom-Json).module.requestPermissions.name
```

store 变体的期望输出**只有两项**：

```
ohos.permission.INTERNET
ohos.permission.KEEP_BACKGROUND_RUNNING
```

出现 `ohos.permission.ACCESS_FIDO2_ONLINEAUTH` 说明变体清单没有替换成功 ——
通常是因为绕过 `build-harmony.ps1` 直接调用了 hvigor。

### 2. 签名验证

```powershell
$ide = "$env:LOCALAPPDATA\Programs\Huawei\DevEcoStudio-26.0.0"
& "$ide/jbr/bin/java.exe" -jar "$ide/sdk/default/openharmony/toolchains/lib/hap-sign-tool.jar" `
  verify-app `
  -inFile harmony/build/outputs/store/harmony-store-signed.app `
  -outCertChain .artifacts/release-cert.cer `
  -outProfile .artifacts/release-profile.p7b
```

期望最后一行 `verify-app success`。

### 3. 版本号

`harmony/AppScope/app.json5`：

```json5
"versionCode": 31,      // 必须大于 AppGallery 上已有版本的 versionCode
"versionName": "0.4.10",
```

### 4. 包元数据

`pack.info` 应显示 `"releaseType": "Release"`、正确的 `bundleName`
与 `apiVersion`。

## 商店宣传图

AppGallery 详情页的截图必须显示**商店产品名 DSH Mobile**，而社区版显示名是
DSH Harmony。store 变体出于安全考虑关闭了确定性展示夹具
(`supportsMockFixtures = false`)，因此宣传图用 mock 变体渲染，但构建时把
显示名临时替换为商店名。

一条命令重新生成：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File scripts/capture-store-screenshots.ps1 `
  -DevEcoHome "$env:LOCALAPPDATA\Programs\Huawei\DevEcoStudio-26.0.0" `
  -Device <设备序列号>
```

脚本自动完成：

1. 从 `entry/src/store/ProductCapabilities.ets` 读取 `appDisplayName`；
2. 临时写入 `entry/src/mock/ProductCapabilities.ets`，构建 mock Release 包；
3. 构建结束按字节还原 mock 能力文件（构建失败也会还原）；
4. 安装并逐场景截图（hdc `uitest screenCap`，不依赖 devecocli）；
5. 合成 1080x1920 / 1920x1080 两套图，品牌名由 `--brand` 传入；
6. 写出 `manifest.json`，含 `displayName` 与 HAP 哈希。

产物目录（绝对路径）：

```
C:\Users\<user>\Documents\projects\dsh-harmony\artifacts\store-screenshots\final
```

- `final\appgallery-portrait\` —— 竖屏 1080x1920（AppGallery 上传用）
- `final\appgallery-landscape\` —— 横屏 1920x1080
- 根目录另含每张图的两种尺寸成品与配对图

`compose-store-screenshots.py` 的品牌名可用 `--brand` / `--tagline` 覆盖，
默认即 `DSH Mobile` / `DeepSeek Harness - HarmonyOS`。

## 归档发布包

```powershell
New-Item -ItemType Directory -Force -Path artifacts/release | Out-Null
Copy-Item harmony/build/outputs/store/harmony-store-signed.app `
  artifacts/release/dsh-mobile-<version>-store-release.app
Get-FileHash -Algorithm SHA256 artifacts/release/dsh-mobile-<version>-store-release.app
```

`artifacts/release/` 已在 `.gitignore` 中，发布包不入库。

## 常见问题

| 现象 | 原因 | 处理 |
| --- | --- | --- |
| `7014` 权限不一致 | HAP 含 Profile 未批准的权限 | 用 `build-harmony.ps1 -Product store` 构建；核对 `requestPermissions` |
| `9568322` 签名不受信任 | 用发布证书侧载到设备 | 发布包只能上传 AppGallery；本机测试改用调试签名构建 |
| `devecocli not recognized` | 旧版脚本依赖 `devecocli` | 已改为直接调用 hvigor `assembleApp` |
| 构建后主清单被改 | 脚本异常中断 | 检查 `git status harmony/entry/src/main/module.json5`，必要时 `git checkout` |
| 应用名不对 | 能力文件缺少 `appDisplayName` | 检查 `entry/src/store/ProductCapabilities.ets` |

## 相关文件

| 文件 | 作用 |
| --- | --- |
| `scripts/build-harmony.ps1` | 构建入口，处理变体替换与签名 |
| `scripts/verify-store-bundle.mjs` | 发布包权限/版本校验（构建时自动执行） |
| `harmony/build-profile.json5` | 产品与签名配置（本机私有） |
| `harmony/build-profile.example.json5` | 无签名材料的模板 |
| `harmony/variants/store/module.json5` | store 变体模块清单 |
| `harmony/entry/src/store/ProductCapabilities.ets` | 商店变体能力与显示名 |
| `harmony/AppScope/app.json5` | 版本号 |