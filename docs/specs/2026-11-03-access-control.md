# DSH 权限预设与单次升权审批 SPEC

日期：2026-11-03

状态：implemented / device-verified

## 1. 数据合同

### 1.1 Session 投影

`permissions` 只接受 Host 提供的 `currentValue`：

```text
permissions: {
  currentValue: string
}
```

- 字符限制为 `[A-Za-z0-9][A-Za-z0-9._-]{0,63}`。
- 缺失、空值、非对象、多余状态或非法字符表示能力不可用。
- Session 列表、一次性 `projections` 读取和实时 projection 帧使用同一归一化
  规则。
- 实时帧使用 `permission` 类型，携带 `selection` 和 `projectionSeq`。

### 1.2 权限目录

Gateway operation：

```text
permissionCatalog -> {
  options: [{ value, name, description? }],
  defaultOptions: [{ value, name, description? }],
  defaultPreset: string
}
```

- 只代理 Host 的 `permissionPresets/catalog` Remote。
- 最多 32 个选项；`value` 使用与投影相同的字符集。
- `name` 最多 120 字符，`description` 最多 320 字符；控制字符被移除。
- `options` 可包含 `auto`，但不得包含 `custom`。
- `defaultOptions` 不得包含 `auto`、`custom`。
- `defaultPreset` 必须存在于 `defaultOptions`。
- 目录读取失败返回 `502`，不回退到本地硬编码目录。

### 1.3 当前会话切换

Gateway operation：

```text
setPermissionPreset(sessionId, preset)
```

- `preset` 必须存在于本次读取的 Host `options`，且不能是 `custom`。
- Gateway 只构造 `/permission <preset>`，不接受完整命令行。
- 写入通过 Host `commands/execute`。
- HTTP 成功只代表命令已接受。原生端继续保持 busy，直到收到匹配的
  `permissions.currentValue` projection。

### 1.4 新会话默认权限

- 设置页从同一个 Host 目录读取 `defaultOptions` 和 `defaultPreset`。
- 新会话默认值写入 `permission` 命名空间的 `defaultPreset` 字段。
- 沿用 `settingsDescribe` 的 revision 和 `settingsSet` 的
  `expectedRevision`。
- 写入失败后只刷新权威设置，不自动重放。
- 修改默认值不改变任何当前会话。

## 2. 原生模型与状态

### 2.1 模型

新增纯模型 `NativePermissions.ets`：

- `NativePermissionOption`
- `NativePermissionCatalog`
- `NativePermissionSelection`
- `nativePermissionLabel()`
- `nativePermissionShortLabel()`
- `nativePermissionIcon()`
- `nativePermissionRequiresRisk()`
- `nativePermissionCanSelect()`
- `nativePermissionCatalogFromJson()`
- `nativePermissionSelectionFromValue()`

`custom` 可以显示为当前值，但不能出现在可选目录或成为写入目标。

### 2.2 Composer chip

- 只有当前 `permissions` 和完整 catalog 都存在时才显示。
- 子智能体会话不显示当前权限入口。
- 入口只显示一个业务 SVG，不显示短标签、展开箭头或固定胶囊背景。
- 入口使用 32vp 圆形命中区，按压时才显示圆形状态高光。
- 入口放在 composer 工具栏左侧；有附件快捷键时不挤压附件和发送。
- 同一工具行使用 2vp 间距，附件、停止和发送使用 32vp 圆形控件。
- 打开菜单后保留当前选中项，使用勾选、业务 glyph 和短标签。

### 2.3 完全权限确认

- 选择 `danger-full-access` 不立即写入，先打开局部确认层。
- 确认层包含风险说明和“我已了解风险”复选框。
- 未勾选时确认按钮禁用。
- 取消、点遮罩和系统 Back 只关闭确认层。
- `auto` 显示 `EXP` 标记和单独风险确认。
- 提交后关闭菜单并保持 busy；只有投影到达目标值后释放。
- 目录失效、连接代际变化、请求失败或投影冲突时关闭确认层，回到最近一次
  权威值。

### 2.3.1 原生 Popup 外观

- 权限菜单与风险确认共用锚定 composer 的原生 `bindPopup`。
- API 26 的 `CustomPopupOptions` 默认会绘制 1vp 内外描边；这是系统 Popup
  容器装饰，不属于卡片设计，会表现为弹层出现时窗口四周出现白色细框。
- Popup 容器必须显式设置 `outlineWidth: 0` 和 `borderWidth: 0`。
- 卡片自身的 0.5vp 语义色边框继续保留，避免把系统装饰和业务层级混在一起。
- 遮罩使用暗色 `NativeDesign.mask()` 对应的半透明颜色，并保持点击外部、
  Back 与取消动作只关闭当前层。

### 2.4 设置行

- DSH 设置页在目录可用时显示“新会话默认权限”。
- 选项来自 `defaultOptions`，不包含 `auto`/`custom`。
- 行说明必须明确“只影响之后创建的会话”。
- 写入期间只锁该行；冲突后刷新目录和设置。

## 3. 审批卡

- 保持现有 `NativeInteraction` 两按钮合同：
  `rejected` 和 `allowed-once`。
- 卡片保留工具名、目标权限、具体原因和剩余时间，不再显示额外的单次授权说明行。
- Host 提供目标权限时显示目标范围；高风险目标使用 warning 语义。
- submitting 状态保持卡片可见，两个按钮禁用并显示进度。
- `interaction-ended` 移除卡片；迟到响应不能重新提交。
- 断线或请求取消直接移除 pending interaction，失败关闭。
- `cancelled` / `unavailable` 是 Host 最终结果状态，不伪装成用户拒绝。

## 4. Gateway 安全规则

- 权限操作使用现有认证、Origin、owner 和固定 endpoint 边界。
- catalog 和写入均设置超时。
- 不接受任意 Remote method、完整 slash command、任意 ns/field 或未知 preset。
- `permissionCatalog`、`setPermissionPreset` 加入 operation allowlist。
- `permissions` 加入 projection allowlist。
- 旧连接或迟到 projection 继续由 `projectionSeq` 拒绝。

## 5. Mock 与测试

至少覆盖：

- read-only、workspace-write、danger-full-access、custom 当前 chip。
- 权限菜单加载、错误、目录撤回。
- 完全权限确认未勾选、已勾选、取消。
- workspace/full 单次审批、长原因、submitting、disconnect。
- 新会话默认权限设置。

Gateway 合同测试覆盖归一化、目录恶意字段、非法 preset、settings allowlist
和投影透传。

纯模型测试覆盖标签、图标、风险项、custom 不可选、目录/投影归一化。

## 6. 验收

- `node scripts/verify-mock-coverage.mjs`
- `node scripts/qa.mjs pr`
- community、store、mock 三变体 Release 构建
- 最新 Mock HAP 真机截图和交互 manifest
- 暗色为默认，亮色补充风险确认与审批卡
- 键盘弹起时 composer chip 不遮挡，底部安全区保持
