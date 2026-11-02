# 会话顶栏、设置密度与聊天滚动条 SPEC

状态：implemented, API 26 真机通过

## 1. 当前结构

- `NativeWorkspace.conversation()` 同时按 `activeAddress` 渲染父级返回与移动侧栏
  图标，导致子代理页出现两个左置图标。
- 子智能体数量入口以常驻 `fieldSurface` 绘制 28vp 胶囊，并提供独立按压背景。
- 会话标题行统一使用 6vp 间距，入口外圈左右 padding 放大与“更多操作”的距离。
- 聊天 `List` 位于整页 16vp 水平 padding 内，因此系统滚动条落在正文内边。
- `NativeSettings` 根页仍挂载 `settingsSearch`、结果列表和搜索状态。
- 存储管理卡片硬编码“上限 X · 当前账户 Y”。
- 会话任务计划 Dock 覆盖列表顶部，但列表没有对应 inset；底部附加 Dock 增高
  后也没有对应尾部 inset。
- 结构化读取使用通用 `NativeCodeViewer` 的最小 44vp 内容高度并在外层再抬到
  64vp，单行文件因此出现大块空白。
- 终端命令复用 `fieldRow` 的 52vp 标签列，命令正文被推到内容区中部；终端输出
  继续使用普通文本密度。

## 2. 会话顶栏

### 2.1 导航身份

- `activeAddress.kind === 'subagent'` 时只渲染返回父会话按钮。
- 移动侧栏按钮条件为 `!wide && activeAddress.kind === 'session'`。
- 根会话恢复只接受 `origin !== 'subagent'`、非空白、非归档会话。
- `requestedSession` 指向子代理时不得构造子代理地址，直接进入一级会话入口。

### 2.2 数量入口

- 外层命中区高度 44vp，宽度由内容决定并有 44vp 下限，背景透明。
- 内层视觉高度 28vp、`radiusChip`、无默认背景和边框；仅在按下时绘制
  `selectionSurface`，按压结束后恢复透明。
- 内层与“更多操作”之间使用 4vp 标题行间距。入口宽度由图标和完整数量决定，
  不使用固定宽度、数字截断或小数点缩写。
- 标题列使用剩余宽度并先省略；数量增长时左边界自然向左移动。
- 点击命中区仍覆盖 44vp，视觉高亮和裁切只作用于内层胶囊。

## 3. 设置

- 删除 `NativeSettings` 对 `NativeSettingsIndex` 的依赖、搜索状态、搜索 builder、
  搜索结果 builder 和根页条件分支。
- 设置根页直接显示分组导航；不保留空搜索栏占位。
- 存储管理卡片仅显示缓存池占用值；不显示上限和当前账户摘要。
- 保留缓存分类、刷新、清空与错误恢复。
- Mock `settings-search` 状态从产品、脚本和覆盖清单移除，搜索索引不再属于
  用户可见前端功能。

## 4. 聊天滚动条

- 会话正文列表滚动容器使用 `calc(100% + 24vp)` 向右扩展，并以等量右侧
  content padding 抵消，使系统滚动条轨道抵达窗口物理右边缘。
- 每个聊天 `ListItem` 继续保留 `NativeDesign.pageInset` 右 padding；列表级
  offset 与行级 padding 相加后，文字和卡片的视觉边界不改变。
- 列表显式启用 `BarState.Auto`，滚动条颜色使用主题中性色，不增加常驻自定义
  滚动条控件。
- 窄屏、宽屏和 IME 场景继续使用同一列表几何。

## 5. 浮动 Dock 首尾空白

- 顶部任务计划 Dock 外层用 `onAreaChange` 上报实测高度到
  `NativeWorkspace.taskDockHeight`。
- 任务计划存在时，在 `LazyForEach` 前插入零交互的 `ListItem` 空白，高度等于
  实测 Dock 高度；Dock 展开和收起时高度采用同一数值动画。
- 底部 Dock 的额外内容（错误、实时变更、队列、附件）单独包装并上报
  `bottomDockExtraHeight`，不包含固定 composer 高度。
- 额外内容存在时，在 `LazyForEach` 后插入尾部空白；内容消失时空白同步收起。
- 首尾空白 ListItem 不进入消息 identity，不改变工具/消息的行点击热区，减少
  动态效果时直接到最终高度。
- 高度变化后若处于跟尾状态，继续复用现有尾部滚动调度；离开尾部时不强制跳转。

## 6. 读取与命令密度

- `NativeCodeViewer` 增加 `compact` 模式；结构化工具读取传 `compact: true`。
- compact 单行内容高度为 22vp 加 8vp 垂直 padding，常规文档预览继续保留原
  最小高度。
- 结构化读取外层高度按 `lines * 22 + 8` 计算，不再强制 64vp 下限。
- `命令` 字段使用独立全宽命令行：不再渲染 52vp 标签列，命令文本从内容容器
  padding 后开始。
- 命令字段字号使用 `fontMicro`，等宽字体，最多两行后省略。
- 终端工具原始输出使用 `fontMicro + 16fp` 等宽文本，不再进入普通 Markdown
  正文密度分支。

## 7. 测试

- Gateway 源码契约：
  - 子代理页侧栏按钮受根会话条件保护；
  - 子智能体视觉入口默认透明，按压态使用圆角胶囊；
  - 设置不引用搜索索引或搜索文案；
  - 存储管理不输出上限/当前账户摘要；
  - 会话 List 使用右侧外扩和 ListItem 内容 padding；
  - 首尾 Dock 空白由实测高度驱动并带过渡；
  - 结构化读取使用 compact viewer；
  - 终端命令字段全宽且使用较小等宽字体。
- Mock：
  - 保持 `plan-subagent` 覆盖 4 个成员；
  - 增加长数量状态，验证数字完整、入口左扩和标题压缩；
  - 移除 `settings-search` 场景。
- 设备 E2E：
  - 子代理页无侧栏图标，一级页有侧栏图标；
  - kill/relaunch 后只进入一级会话；
  - 长数量入口和“更多操作”保持同一标题行；
  - 设置根页无搜索框；
  - 存储管理无上限/当前账户行；
  - 聊天滚动条轨道贴近屏幕右边缘。

## 8. 设备证据

- 设备：`HBN-AL80` / HUAWEI Pura 70 Pro+，HarmonyOS `7.0.0.111` SP10C10，
  API `26`，序列号 `33Z0224801015621`。
- 设备验收 Mock HAP SHA-256：
  `F23693248955498EC90306DC2D1942D2DC30F440FE449D73DDB9592FE59412CD`。
- 标题、子代理导航、长计数、冷启动与子代理发送：
  `artifacts/device-e2e-final/mode-subagent-clean/plan-lineage/manifest.json`。
- 设置密度、通知紧凑度、存储摘要移除与偏好持久化：
  `artifacts/device-e2e-final/settings-clean/appearance-persistence/manifest.json`。
- 聊天滚动条抵达物理右边缘：
  `artifacts/device-e2e-final/conversation-chrome-clean/scrollbar-edge/manifest.json`。
- 浮动任务 Dock 与首尾 transcript spacer：
  `artifacts/device-e2e-final/task-dock-clean/floating-overlay/manifest.json`。
- 最终 Release 重建产物：
  default `43E3466D0C878A07C673899B2B213E6348A0DC0424BA032E16C080D31D880E08`，
  store `2BC7E88367F6CAD626954CDA7F9FC72FB6324702E9C6EE9AAFEFD0168DB9A6E6`，
  mock `EED9CAB2AC4ACC6B81AAF715B5D76D5E0A1D178557A9EF03BB337805052980F3`。
- 最终 default Release 已安装并启动，烟测证据：
  `artifacts/device-e2e-final/release-smoke/manifest.json`。该烟测不得替代上表
  Mock 交互证据。
