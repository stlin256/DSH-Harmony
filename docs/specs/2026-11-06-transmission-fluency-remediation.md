# 对话传输流畅度治理实现 Spec

日期：2026-11-06。

需求：[2026-11-06-transmission-fluency-remediation.md](../requirements/2026-11-06-transmission-fluency-remediation.md)

审计依据：[2026-11-06-conversation-transmission-audit.md](../research/2026-11-06-conversation-transmission-audit.md)

## 1. 发布与投影热路径（REMEDY-01/02/05）

### 1.1 live pill 复用签名缓存（R-1）

新增纯函数 `nativeLiveTurnChangeFrom(summaries, active)`（`NativeTurnChanges.ets`）：active 为真时从既有 summaries 反向找第一个 running 项。`NativeWorkspace.renderTranscript` 改用它读取签名门控后的 `this.turnChanges`，不再每 paint 全量重算 `nativeTurnChanges(rows)`。原 `nativeLiveTurnChange(rows, active)` 保留（rows 语义不变，供测试与兼容）。

### 1.2 输入签名 O(1) 化（R-2）

在 `appendSignature` 中，args/metaRaw/output/error/errorRaw 以 `.length` 参与签名，替代逐字符 FNV 哈希；结构字段（role/turnKey/callId/id/renderKey/toolName/phase/status/outcome/footerOutcome/failed）保持参与。工具参数流式追加单调增长，长度覆盖常规失效；同长度内容替换属理论边界，由最终 durable 行（新 id/seq）兜底失效。新增 error 长度修复旧签名未覆盖 `tool.error` 的潜在缺口。

### 1.3 数据源等值比较（R-4/R-6）

在 `NativeSessionModel.ets` 新增 `nativeMessageEqual(a, b)`：逐字段指针级比较（投影行由同一 record 复制而来，未变字段共享字符串实例），children 递归，blocks/images/segments 按长度+字段比较。

`NativeListSource.set(rows, keyOf?, equals?)`：
- 注入 equals 时以字段级比较替代 JSON.stringify（transcript 与 process 子列表均注入）；未注入保持既有 stringify 行为（会话列表行数小，不在热路径）。
- 稳定键路径尾部 16 行窗口未发现变化时**不再提前 return**，落入全量 diff：中段内容变化不得被静默丢弃。
- 全量 diff 将"键不同的同位行"也计为变化（旧实现漏计，替换行可能不刷新）。
- 新增 `notifyChanged(index)`：官方 turn-change 摘要到达后，对全部 turn-footer 行显式通知（REMEDY-05）。

### 1.4 单发布泵（R-5）

delta 帧仅在呈现节奏器未接管（`presentationTimer < 0`）时才调度 paintTimer；节奏器已运行时由其统一的 32/64ms tick 负责发布。非 delta 结构帧保持 0ms 立即发布。节奏器 offer 后 pending 必然为真（immediate 重置路径由 paintTimer 兜底），无丢帧路径。

## 2. 缓存与状态（REMEDY-03）

- 快照/历史页只把**本帧/本页** journal 传给 `rememberTurnChangeReferences`（旧条目已被 officialTurnChangeSequences 记录，重复解析为无谓 O(journal)）。恢复路径保持全量（首次必经）。
- 历史泵每页不再直接 `saveSession` 整文件重写，改走 500ms 去抖 `scheduleCache`；连续翻页只在静默后落盘一次。
- `loadSession` 与 `loadRoute` 对 `await writes` 加 catch：写链失败与读失败解耦，读路径按存储现状继续。

## 3. 网关（REMEDY-04）

- wait 续期前 `clearTimeout` 旧定时器；client close 清理时删除 `connection.pending` 条目。
- 背压暂停看门狗：新增纯函数 `nativeDeliveryStallReady(pausedForDelivery, pausedSinceMs, now, limitMs)`（默认 60s），在 250ms drain 轮询中检查；超限 `client.close(1011, "Delivery stalled")`，客户端走快照重建。
- 快照补取 turn-start 的 page RPC 仅在 running 已知为真（或未知）时发出；空闲会话不再每次连接发 400 条请求。
- upstream WebSocket `maxPayload` 由 0（无限制）改为 64MiB。

## 4. 自动化测试

- `nativeLiveTurnChangeFrom` 与签名长度化：更新 `native-models.test.mjs` 既有断言（1894-1896 的源码正则改为新调用形式），新增 summaries 变体单测。
- `nativeMessageEqual`：等值/不等值/children 递归/长度差异单测。
- `NativeListSource`：注入 equals 后稳定键窗口外变化触发通知；同位换键行计入变化；notifyChanged 生效；既有 2000 行有界尾部测试保持通过。
- 网关：wait 续期清旧定时器、close 清 pending、`nativeDeliveryStallReady` 纯函数、空闲快照不发 page RPC、upstream maxPayload 源断言。

## 5. 构建与证据门槛

共享 ArkUI 代码变更：default/store/mock 三变体构建；`verify-mock-coverage` 与 `qa.mjs pr` 必须通过。设备台账新增受影响表面（流式发布节奏、turn-change 卡片刷新、历史翻页），证据未取证前保持 Pending。
