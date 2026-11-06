# 对话传输流畅度治理需求

日期：2026-11-06。

## 用户报告

对话传输过程中出现卡顿；要求检查传输代码 Bug 并对整个流畅度与传输流进行治理。

## 事实依据

全链路只读审计（[2026-11-06-conversation-transmission-audit.md](../research/2026-11-06-conversation-transmission-audit.md)）确认：协议正确性无 P0 缺陷，卡顿来自多层性能缺陷叠加——每 32ms paint 在 UI 线程执行多个 O(整个 transcript) 的 pass（live pill 全量 diff、全工具内容哈希、live-process 全量投影、数据源 JSON.stringify 对比）、事件边界的全量缓存重写、turn 结束后历史泵的 O(n²) 级联，以及网关侧 wait 定时器泄漏、背压暂停无看门狗、空闲快照 400 条 RPC 放大器。

## 需求

REMEDY-01 消除每 paint 的 O(transcript) 热路径：live pill 复用签名门控后的 turn-change 缓存；turn-change 输入签名改为 O(1) 字段签名（长度替代逐字符内容哈希）；列表数据源以字段级等值比较替代 JSON.stringify，且稳定键路径不得静默丢弃窗口外变化。

REMEDY-02 统一发布泵：delta 帧在呈现节奏器已接管时不再另起 32ms paint 定时器，消除错相双泵；非 delta 结构帧保持 0ms 立即发布。

REMEDY-03 缓存层治理：历史泵每页只解析本页新 journal 条目（不再全 journal 重解析）；每页的整文件缓存重写改为去抖调度；缓存写链失败不得污染读路径（loadSession 假 miss、loadRoute 抛异常）。

REMEDY-04 网关治理：wait 定时器续期必须清理旧定时器，连接关闭必须删除 pending 条目；背压暂停加看门狗（超时断代重建而非无限冻结）；空闲会话快照不再触发 400 条 page RPC；upstream 收帧设 64MiB 上限。

REMEDY-05 官方 turn-change 摘要到达后，受影响的 turn-footer 行必须收到显式数据源通知，卡片不得停留在旧投影。

## 非目标（本轮不做，另行立项）

- live-process 阶段的增量投影（durable 前缀缓存复用）——R-3 大项。
- 缓存序列化移出 UI 线程（TaskPool 可行性待研）——C-1 大项。
- `frame_handler_error` 永久停流语义的重新分类——T-1，涉及流恢复 spec 合同。
- 网关去重比较符统一（G-F5）、分块码点对齐（G-F7）、opening 超时（G-F8）。
- S1（HarmonyOS pong）/S2（>32KiB 分片）真机取证——需真实 Host，单独执行。

## 验收标准

- 全部既有自动化测试保持通过；新增行为有模型/协议级测试。
- `node scripts/verify-mock-coverage.mjs` 通过。
- `node scripts/qa.mjs pr` 通过并记录报告路径。
- 共享 ArkUI 代码变更后 default/store/mock 三变体 Release 构建通过。
- 设备台账如实记录受影响表面与证据状态；未取证项保持 Pending，不得以静态测试冒充。
