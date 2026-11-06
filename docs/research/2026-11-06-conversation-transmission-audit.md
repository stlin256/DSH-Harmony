# 对话传输链路审计：Bug 清单与卡顿根因

日期：2026-11-06。

范围：对话实时传输全链路——Host WebSocket → 网关（`gateway/src/native-harness.mjs`、`gateway/src/native-protocol.mjs`）→ 手机 WebSocket 客户端（`NativeHarnessClient.ets`）→ 归并器（`NativeSessionModel.ets`）→ 发布与投影（`NativeWorkspace.ets`、`NativeTranscript.ets`、`NativeTurnChanges.ets`、`NativeListSource.ets`）→ 渲染（`NativeTextContent.ets` 等）→ 缓存（`NativeTranscriptCache.ets`、`NativeWorkspaceCache.ets` 等）。

方法：只读源码审计。主审传输客户端/归并器/发布路径，三个并行子审计分别深挖网关、渲染路径、缓存/状态层；所有 P0/P1 声明均经二次抽查核实。未修改任何源码；未做真机 profiling。

事实等级：**确认** = 当前源码可直接推导；**疑似** = 需真机 / 真 Host 证据。不能把疑似写成已确认的断连原因。

基线：工作树含未提交的 running-tail/鲸鱼改动；`092cf40`（当日）已包含 running-turn start O(1) 缓存修复。行号以当前工作树为准（`NativeWorkspace.ets` 4477 行、`NativeTurnChanges.ets` 374 行、`native-harness.mjs` 1209 行）。

## 1. 已核实为正确/已修复的历史问题

先记录正确项，避免重复修复：

- 发布节奏已按 [2026-11-01-stream-stability](2026-11-01-stream-stability.md) 修复：`NativeStreamPresentation.ets:3-4` `frameMs=32` / `scrollingFrameMs=64`（旧研究的 16ms 问题已消除）。
- 严格 revision/seq 合同已实现：durable `seq === cursor+1`（`NativeSessionModel.ets:604-612`）、assistant `revision === streamRevision+1` 与精确 `nextIndex`（:667-707）、重复事件冲突校验（:463-471）。2026-10-30 研究记录的“seq 不校验连续性”缺口已关闭。
- text-only 增量快路径已实现：`nativeUpdateLiveAssistant` 只补最后一行（`NativeTranscript.ets:127-139`），`source.setTail(visible, 2)` 只通知尾部（`NativeWorkspace.ets:2858-2859`、`NativeListSource.ets:67-77`），并有 `native-stream-fast-path.test.mjs` 覆盖。
- 增量 Markdown 缓冲已实现：stable blocks + 有界 tail（`NativeStreamingMarkdown.ets`），append 只扫新增部分，测试覆盖块数/tail 上限/不切 fence 与表格。
- 每帧双扫描 transcript 的 `runningTurnStartedAt` 已由 `syncRunningTurnStart` 按 cursor/running 缓存（`NativeWorkspace.ets:2658-2670`，commit `092cf40`）——该修复直接对应此前上报的卡顿。
- 重连防抖：单轮 6 次上限、250ms→30s 指数退避、连接存活 ≥30s 归零（`NativeStreamRecovery.ets:21-28`）；快照权威替换 + gap 检测 + 重复校验使重连不产生重复内容（子审计专项确认）。
- 流式 token 无入场动画（合规）；滚动跟随有 180ms 守卫、滚动中 64ms 退避、`markScrollActivity` 暂停尾滚。
- 网关：分块发送无逐块 await（`native-harness.mjs:928-931` 注释明确为刻意设计）；发送错误路径 `close(1011)` 后由 close 链 terminate upstream，不会漏 resume；监听器全挂各自 socket，无跨重连累积；手机→网关为只读通道（:1195），`maxPayload:16384` 正常路径不可触发。
- 缓存半写防护良好：事务包裹 + chunk 连续性/长度校验，损坏返回 null 保留原数据（`NativeTranscriptCache.ets:121-141, 202-227`）。

## 2. 确认 Bug（按层，含卡顿根因标注）

### 2.1 网关（`gateway/src/native-harness.mjs`）

| 编号 | 级别 | 位置 | 问题 |
| --- | --- | --- | --- |
| G-F1 | P1 确认 | :1114-1120, :1200 | wait 定时器覆盖未 `clearTimeout` 旧定时器；close 只清最新一个，且 close 不删除 `pending` 条目，旧定时器在连接关闭后仍可对已死连接执行 `ASK_TIMED_OUT` 拒绝 RPC。Host 对同一 eventId 续期（多帧 wait:item）时新期限被旧定时器吞掉。 |
| G-F2 | P1 确认·冻结根因 | :902, :913-958 | 背压暂停无看门狗：`upstreamPausedForDelivery` 为真时上游静默检测被完全豁免（:902），且无任何最长暂停时限。`resumeDelivery` 只在 `bufferedAmount` 回落到 32KiB 低水位时触发（:942-944, :953-957）。手机原生 socket 活着（自动回 pong）而 ArkTS 主线程被长任务占死、或中间反代持续读走数据时，流可以“连接活着但永久冻结”，无 1011/1012、无重连。 |
| G-F3 | P1 确认·重连放大器 | :1170-1180 | 每个无 `turnStartedAt` 的快照（空闲会话恒如此）都触发一次 `maxMessages:400` 的 `session/page` RPC 并在网关侧跑 normalize×400。每次连接/重连都执行，重连风暴时按次数线性放大 Host 与网关 CPU。 |
| G-F4 | P2 | :1150-1152, :1181-1187, :1189-1193 | 严格校验把任何良性异常帧（journal 修剪导致记录不连续、同批同 key、interactions item 缺 value 的 TypeError）升级为整条连接 `close(1011)` → 重连循环。Host 端协议演进/裁剪会变成 100% 复现的循环。 |
| G-F5 | P2 | :1002-1015, `native-protocol.mjs:520-530` | 去重边界：`seq < questionSeq` 才拒（相等重发 questions）；`asOfSeq` 缺失时 -1 恒通过（迟到的 control 基线可回放旧问题列表）；`projectionSeq<0` 不参与去重（无序投影可覆盖新值）；同批重复 key 抛错 → 走 G-F4 断连。陈旧 questions/plan/permissions 短暂回滚造成 UI 闪变。 |
| G-F6 | P2 | :1063, :516, :883, `app.mjs:119-120`, :485-487 | 无界/半无界入口：任意 streamId 的 error 帧都进 `retired` Set；engage 后 pending 条目滞留至连接结束；upstream `maxPayload:0`（收帧无上限）；`/pocket/api/native` 的 `express.json limit:Infinity` + prompt images base64 无长度上限。 |
| G-F7 | P2 | :933-935 | 32KiB 分块按字节切，UTF-8 多字节字符（中文/emoji）必然被切在字符中间。ws 侧 continuation 协议合法，风险完全取决于接收端是否先拼字节再解码（见 S2）。 |
| G-F8 | P2 | :976-978 | 前台 30s opening 超时对大历史会话+慢 Host 偏紧，可能稳定超时 → 1011 重连循环。 |

网关心跳策略修正（覆盖旧研究前提）：前台为 **5s 一次 ping、连续 20s 无 pong 即 terminate**（:39-43, :898-912），后台 15s/45s；不存在“30 秒 ping”。每连接一个 interval，close 统一清理，无定时器泄漏（唯一遗漏是 G-F1）。

### 2.2 App 传输客户端与归并器

| 编号 | 级别 | 位置 | 问题 |
| --- | --- | --- | --- |
| T-1 | P1 | `NativeHarnessClient.ets:692-696` + `NativeWorkspace.ets:2378-2379` | 归并器抛出的异常被折叠为少数 reason：`Stream gap`/`Stream attempt changed` → 重连（正确），但其余全部（`Invalid snapshot`、`Conflicting durable event`、`Committed event missing`、`Invalid stream end`、`Missing opening snapshot`）→ `frame_handler_error` → **永久停流**，需用户手动重试。边界场景（例如缓存恢复后 committed durable 行缺失）会表现为“流卡死且不自愈”。 |
| T-2 | P2·复杂度 | `NativeSessionModel.ets:653, 574-579, 586, 686-687, 598, 439, 428, 590` | 归并器二次复杂度：每 event `messages.concat` O(n)；`remember` 每 range 全 journal 扫描；`visible` 对每条消息线性扫 replacements；`streamText`/`tool.text`/`part.text` 每 delta `+=`（ArkTS VM 不保证 rope 优化，大参数工具流有 O(n²) 风险）；`appendStreamParts`/`updateTools` 对 streamParts/streamTools 线性 find。 |
| T-3 | P2 | `NativeStreamRecovery.ets:23` + `NativeWorkspace.ets:1158` | 连接存活 ≥30s 后失败将 attempts 归零 → 总重连次数无上限；每次重连伴随全 journal 重解析 + 全量缓存重写（见 C-2）。单轮 ≤6 次无死循环，但无全局预算。 |

### 2.3 发布与投影（UI 线程，每 32ms paint）

| 编号 | 级别 | 位置 | 问题 |
| --- | --- | --- | --- |
| R-1 | P0·卡顿根因 | `NativeTurnChanges.ets:234-242` + `NativeWorkspace.ets:2832` | `nativeLiveTurnChange` 在 running/waiting 时**无条件**全量重算 `nativeTurnChanges(rows)`（含 `nativeDiff` 对每个 write/edit 工具 JSON.parse×2 + 行级 LCS DP，`NativeDiff.ets:109-144`）。:2824-2828 精心做的签名缓存只保护 `this.turnChanges`，:2832 完全绕过它 → 每个 32ms paint 都全量重算，纯文本流也逃不掉。 |
| R-2 | P0·卡顿根因 | `NativeTurnChanges.ets:342-373` + `NativeWorkspace.ets:2824` | `nativeTurnChangeInputSignature` 对每个 tool 行的 args/metaRaw/output/errorRaw 逐字符 FNV 哈希 → O(全部工具内容字节) 每 paint。注释自称 cheap change detector，实际是全内容线性哈希。 |
| R-3 | P0·卡顿根因 | `NativeWorkspace.ets:2763-2784, 2336-2341` + `NativeTranscript.ets:73-96, 110-124, 48, 365-372` | reasoning delta 或工具参数 delta 不走尾部补丁（textOnly=false）→ hasLiveProcess 时每 32ms 完整 `nativeTranscript`：每行深拷贝（含 children 递归）、每工具行 `mergedStructuredMeta` JSON.parse×2+stringify、每 todo_write 重新解析 plan+diff、每 process 子行重跑 `nativeToolDetail`（JSON.parse args）。整个 reasoning/工具参数阶段全程全量。 |
| R-4 | P0/P1 | `NativeListSource.ets:33-59` | ① 稳定键路径对尾部 16 行逐行 `JSON.stringify`×2 对比；键变化/长度变化路径对**全表**每行 `JSON.stringify`×2，>4 行变化时 `onDataReloaded` 整列表重建（销毁全部增量 Markdown 缓冲，下个 tick 全文 O(n) 重扫描）。工具事件流频繁走此路径。② **稳定键 + 长度不变时，尾部 16 行窗口外的内容变化被静默丢弃**（:42 `if (!changed.length) return`）。已确认受害面：官方 turn-change 摘要到达后只调 `this.paint()`（`NativeWorkspace.ets:2747`），投影行未变 → 不通知 → 旧 turn 的文件变更卡片长期显示旧投影；会话列表（`sessionSource.set`，:512）中段行的标题/running 徽标同理可能陈旧。 |
| R-5 | P1 | `NativeWorkspace.ets:2370-2375, 2589-2608` | 双发布泵并发：`paintTimer`（每帧到达时调度，delta 32ms）与 `presentationTimer`（自续 32ms 游标推进循环）相位独立，错相时同一 32ms 窗口出现两次 renderTranscript+setTail+scrollEdge，等效 ~16ms 发布，部分重现历史主线程背压；非 delta 帧（event/state/end）以 0ms 立即 paint，事件突发无合并。 |
| R-6 | P1 | `NativeProcessView.ets:35-50` | process 组内嵌第二层 `NativeListSource.set`，子操作含完整工具文本，与外层 set 每 tick 各做一次尾部窗口序列化，成本叠加。 |

### 2.4 缓存与状态层

| 编号 | 级别 | 位置 | 问题 |
| --- | --- | --- | --- |
| C-1 | P0·卡顿根因 | `NativeTranscriptCache.ets:111-145` + `NativeWorkspace.ets:2360, 3142-3163` | `saveSession` 在调用线程（UI）同步 `JSON.stringify(model.capture())`（capture 含全部 messages + 全部 journal 原始事件 ≈ 2×transcript）；写入为整文件重写（一个事务 DELETE 全部旧 chunk → 逐个 INSERT）。非 delta 帧经 500ms 去抖触发 → 流式期间每个事件簇静默期一次全量重写，成本随会话线性增长，累计 O(n²)。会话切换（:2164）、退后台（:1165）、aboutToDisappear（:1007）同样在 UI 线程同步 stringify。 |
| C-2 | P0·卡顿根因 | `NativeWorkspace.ets:3183-3221, 2361, 2368` + `NativeTurnChanges.ets:252-277` | 历史泵每页（40ms 间隔）：`model.prepend` + `rememberTurnChangeReferences(Array.from(journal.values()))` **全 journal 重解析** + `paint()` 全量投影 + `saveSession` 全量缓存重写。turn 结束即自动启动 → 用户感知“传输完还卡”；打开长历史会话同理。每页成本随已加载行数增长 → 总 O(n²)。snapshot/重连同样全 journal 重解析（:2345）。 |
| C-3 | P1 确认 | `NativeTranscriptCache.ets:187, 384` | 写失败污染读路径：`loadSession` 在 try 内 `await writes` → 写链 reject 时读返回 null（**假 miss**，暖缓存变冷启动）；`loadRoute` 的 `await writes` 无保护 → 写失败后 loadRoute 抛异常，被 `NativeWorkspace.ets:1069` 当作连接失败进入 retrying。 |
| C-4 | P1 | `NativeWorkspaceCache.ets:432-466, 368-430`；`NativeAttachmentCache.ets:112-151`；`NativeMetadataCache.ets:79-84` | 主线程同步文件 IO：`saveBinary` 最多 64MB `bytes.slice()` + `writeSync` + `renameSync`；`loadBinary` 同步读 + 全量 byteHash；`enforceDefaultLimit`（每次缓存保存后触发，5s 节流）用 `listFileSync`+`statSync` 逐文件同步枚举；`applyLiveTitle` 在流式 title 帧触发 `putSync`+`JSON.stringify`。 |
| C-5 | P1 | `NativeSessionModel.ets:613, 479-523`；`NativeHarnessClient.ets:660-663` | journal 无界增长（唯一清理是 replacements 的 O(J) 扫描）；capture 把整个 journal 序列化进缓存（payload ≈ 2×transcript，双份持久化）；`client.models` 保留每个访问过会话的完整 model，仅登出清理，无 LRU。 |
| C-6 | P2 | `NativeTranscriptCache.ets:401-456`；`NativeHistoryPrefetch.ets:11-15`；`NativeSessionModel.ets:526-528` | `trimToQuota` 死代码（全仓库无调用，4GiB per-scope 配额从未生效）；历史重试 failures 无上限（Host 恒 hasMore=true 且不前进时 8s 一次 HTTP 轮询永续）；restore 仅接受 version===1，未来 v2 记录 throw → 当 miss，每次重读重抛直到下次保存自愈。 |

## 3. 卡顿根因链（综合结论）

用户报告的“对话传输过程中卡顿”由多层叠加造成，会话越长越明显：

1. **稳态流式（每 32ms paint，全在 UI 线程）**：R-1（live pill 全量 diff，含 LCS DP）+ R-2（全工具内容哈希）+ R-3（reasoning/工具阶段全量投影深拷贝+逐工具 JSON.parse）+ 全量 present + R-4（source.set 键比较；结构变化时整表 stringify×2 + onDataReloaded）。长会话（数百 turn）时单个 pass 即可达数十毫秒，32ms 节奏必然失守。
2. **事件簇边界**：C-1 的 500ms 去抖全量缓存重写（UI 线程 stringify 整模型+journal）造成周期性微冻结。
3. **turn 结束后**：C-2 历史泵每页 40ms 的全 journal 重解析 + 全量投影 + 全量缓存重写（O(n²)）——“传输完还卡”的直接来源。
4. **网关侧冻结/断连**：G-F2（暂停无看门狗 → 活着但永久不动）；S1（若 HarmonyOS 不自动回 pong：前台连接每 20s 被 terminate → 周期性断连重建，模式与“每 20 秒卡一下”精确吻合，**待 1 分钟真机验证**）；S2（>32KiB continuation 分片 vs 手机栈解码，中文长会话快照几乎必现 >32KiB）；S3（巨型单消息主线程秒级冻结）。
5. **重连放大器**：每次重连 = 快照重建 + G-F3 的 400 条 page RPC + 手机全量投影 + 全量缓存重写；T-1 的永久停流路径让部分异常表现为“卡死且不自愈”。

## 4. 疑似问题（需真机/真 Host 证据，不得写成已确认）

| 编号 | 优先级 | 内容 | 验证方法 |
| --- | --- | --- | --- |
| S1 | 最高（1 分钟量级） | HarmonyOS `@ohos.net.webSocket` 是否自动回 pong。App 全工程无 ping/pong 代码，API 无此面。若不自动回：每条前台流式连接在第 20s 被 terminate → 指数退避重连 → 快照重建 + 400 条 RPC → 周期性卡顿。 | 真机连真实 Host 开流 >25s 观察断连；网关 :899 terminate 处加计数日志。 |
| S2 | 高 | >32KiB 下行消息的 continuation 分片，手机栈是否 (a) 重组、(b) 先拼字节再 UTF-8 解码。若逐帧解码：每 32KiB 边界乱码 → `invalid_frame` → 重连 → 同一巨帧再来 → 死循环。 | 真机打开 >32KiB 历史会话观察断连/乱码；网关统计每连接分片数。 |
| S3 | 高 | 巨型单消息（MB 级）透传 → 手机端 JSON.parse + 渲染秒级主线程冻结；冻结期间若 pong 原生则事件洪泛二次卡顿，若 pong 依赖主线程则 20s 死线断连循环。 | 真机注入 2MB 级 assistant 消息。 |
| S4 | 中 | 前置 HTTPS 反代使网关 `bufferedAmount` 只度量网关→代理段，128KiB/32KiB 背压阈值失真（暂停过晚）；代理自行应答 ping 时 S1 死线进一步失真。 | 真实部署形态下测背压触发点。 |
| B1 | 中 | `@State livePresentationText/liveAuthorityText` 每 tick 重赋值且在 LazyForEach item builder 内读取（`NativeWorkspace.ets:290-291, 2786-2787, 3937-3938`）；若所用 ArkUI 版本对生成项注册父状态依赖，则每 tick 全部已物化行重渲染。 | DevEco Profiler / HiChecker 真机验证。 |
| B2 | 低 | 增长中的 process 组每新增操作重放一次组入场 transition（`NativeWorkspace.ets:2804-2812`）；token 无入场动画（合规），但结构动画在工具密集流中每步重放。 | 对照 live-process ordering spec 确认规格符合性。 |

## 5. 修复优先级建议

1. **真机验证 S1/S2**（各 1 分钟量级，网关加只计数不记数据的日志）——两者若属实即是“周期性断连卡顿”的完全解释。
2. **两行级修复**：R-1（live pill 改用签名门控后的 `this.turnChanges` 或只算当前 turn）+ R-2（签名改结构签名，不哈希内容）——消除最大 CPU 项。
3. G-F1（`clearTimeout` + close 清 pending 条目）。
4. G-F2（暂停加看门狗，超时 `close(1011)` 让客户端走快照重建）。
5. R-3 投影缓存复用（durable 部分复用 `transcriptBaseRows`，live process 行拼接其后；工具 args 解析按 callId 记忆化）。
6. C-1/C-2：`capture`+stringify 移入 TaskPool；增量持久化；历史泵只解析本页新 journal 条目。
7. R-4：行对象带内容版本号替代 stringify 对比；窗口外变化触发 reload 而非 return；官方 summary 到达时显式 onDataChange 受影响行。
8. R-5 合并双发布泵为单 32ms tick，非 delta 帧并入泵。
9. C-3 写失败与读失败解耦（`await writes.catch(()=>{})`）。
10. G-F3 加 running 前置条件；G-F5 统一去重比较符；G-F6 增大 upstream maxPayload 与 images 上限。

任何修复实施须走仓库既定流程（需求 → spec → 实现 → 模型/协议测试 → Mock 覆盖 → `verify-mock-coverage` → `qa.mjs pr` → 三变体构建 → 真机 E2E 台账更新）。

## 6. 测试盲区（当前自动化未覆盖）

- 网关：停 pong → 20s terminate 端到端；背压 pause→drain→resume 集成；`fin:false` 分片对非 ws 客户端；`maxPayload`→1009；upstream close→client 1012；多帧 wait 续期与 close 后旧定时器；空闲快照的 400 条 RPC 是否发出。
- App：`NativeListSource.set` 稳定键路径窗口外内容变化；官方 summary 到达后的卡片刷新；`loadSession`/`loadRoute` 在写链 reject 后的行为；`stopStream` 永久停流各 reason 的触发矩阵。

## 7. 结论

（2026-11-06 治理更新：R-1/R-2/R-4/R-5、C-2/C-3、G-F1/G-F2/G-F3/G-F6 已按
[2026-11-06-transmission-fluency-remediation.md](../specs/2026-11-06-transmission-fluency-remediation.md)
实施并通过 `qa.mjs pr` run `20261106T161121Z-35121de7`；R-3 增量投影、C-1
序列化出线程、T-1 停流分类、G-F5/G-F7/G-F8 与 S1/S2 真机取证为后续项。）

当前对话传输代码**没有发现会导致内容损坏或丢失的 P0 级正确性 Bug**——协议归并、重复防护、快照替换、缓存事务都经得起推敲。卡顿的根源是**性能型缺陷的叠加**：每 32ms paint 在 UI 线程执行多个 O(整个 transcript) 的 pass（其中 R-1/R-2 是“两行改动即可消除”的最大项），叠加事件边界的全量缓存重写、turn 结束后的 O(n²) 历史泵，以及网关侧两个待真机证实的断连/冻结机制（S1 心跳死线、S2 大帧分片）。会话越长、工具越密集，卡顿越严重，与用户描述吻合。
