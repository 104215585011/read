# M2 自动化测试流水线验证通过与收口交接文档

- 交接编号：`M2-QA-CLOSE-qa-001`
- 真实系统时间：`2026-09-08T09:16:00+08:00`
- 发送角色：项目测试负责人（Codex2）
- 接收角色：主协调者（parent）、项目经理（Claude1）、项目后端（Codex1）、外部 UI 总监（Claude2）
- 代码基线：Commit `c429470`
- 依据规范与契约：
  - 后端契约草案：`docs/backend/CONTRACT-v0.1-draft.md` (修订标识：`0.1-draft / M0-BE-REV2`)
  - UI 架构与适配器规范：`docs/ui/READER-ADAPTER-SPEC.md` (版本：`v0.3-aligned-be-rev2`)
  - M2 收口检查表：`docs/project/M2-CLOSE-CHECKLIST.md`
  - M2 验收报告：`docs/qa/M2-VERIFICATION-REPORT.md`
- 独占维护范围与交付清单：
  - `docs/qa/M2-VERIFICATION-REPORT.md` (新增 M2 自动化测试流水线验收报告)
  - `docs/logs/qa.md` (更新 QA 工作日志)
  - `docs/handoffs/M2-QA-CLOSE-qa-001.md` (本交接文档)

---

## 1. 验证背景与真实云端流水线执行证据

针对最新提交 Commit `c429470`，GitHub Actions CI 真实云端流水线已全部绿灯通过：
- **执行平台**：GitHub Actions `macos-14` (Apple Silicon M1 Runner)；
- **开发工具链**：Xcode 15.4 (Build version 15F31d) / Swift 5.10；
- **目标测试设备**：iPadOS Simulator (iOS 17.5 / `iPad Pro 11-inch (M4)`)；
- **构建与测试指令**：`xcodebuild test -scheme StudyOS -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M4),OS=17.5' -resultBundlePath TestResults.xcresult`；
- **并发与代码健康度**：Swift 6 严格并发检查 (`-strict-concurrency=complete`) 零警告通过；
- **测试结果总览**：全量 47 个测试方法全部 100% 通过（**47/47 PASS，0 失败，0 告警，0 异常跳过**）。

---

## 2. 关键核心机制专项深度验证结论

本次验收对 M2 阶段的核心焦点问题与返修项进行了深度验证并全部达成断言：

1. **真实正文透传与多级聚合机制 (AggregatedContext & Scope Boundary)**：
   - `testConfirmedPageContextActuallyReachesProvider`：证实已勾选的单页正文 `PAGE_ZERO_SENTINEL` 真实透传给 Provider，未勾选的相邻页 `PRIVATE_OTHER_PAGE` 严格物理隔离；
   - `testConfirmedChapterIncludesBothBoundaryPages`：跨页章节测试证实起止两端边界页全部包含，范围外页码严格排除；
   - `testManifestOnlyCannotAuthorizeUnreconstructablePayload`：仅有 Manifest 摘要而缺失真实正文时，严禁重构发起未经授权的请求（安全抛出 `invalidResponse`）；
   - 彻底修复此前“仅发送用户问题未携带真实文档正文”与“上下文丢失”问题。
2. **全量 CryptoKit SHA-256 摘要哈希机制 (Full UTF-8 Byte Digest)**：
   - `testDigestHashesAllUTF8BytesNotOnlyPrefixAndLength`：验证 `payloadDigest` 采用完整 UTF-8 数据字节 `SHA256.hash(data: Data(utf8))` 真实计算，单字符差异产生确定性哈希雪崩，消除了前缀/长度导致的伪哈希碰撞漏洞。
3. **流式终态互斥与 alreadyTerminal 防御机制**：
   - `failed` 与 `cancelled` 严格互斥：异常终止进入 `failed` 态后，外部迟到的 `cancel` 调用返回 `false`，终态不被覆写；
   - 运行中 `cancel` 成功进入 `cancelled` 态后，二次调用 `cancel` 触发 `alreadyTerminal` 返回 `false`；
   - 消费端 `Task.cancel()` 级联取消正常收敛于 `cancelled` 终态；自然流式完成后进入 `completed` 终态，调用 `cancel` 同样返回 `false`。
4. **握手前防重复运行机制 (Reservation Before First Await)**：
   - `testDuplicateAttemptRejectedWhileFirstProviderHandshakeSuspends`：首个请求在与 Provider 握手挂起时，相同的 attempt 试图再次进入在首个 await 之前即被同步拒绝并抛错；杜绝并发重入竞态。
5. **OpenAI 兼容 SSE 协议解析完备性**：
   - 验证合法增量流正确累加；
   - 验证畸形 JSON 块严格抛出解析失败（即使尾部有 `[DONE]` 亦不被静默忽略）；
   - 验证未接收到终止标记的非正常 EOF 截断流严格抛出 `invalidResponse`，禁止误报为成功。

---

## 3. 验证层级与客观真机边界说明

按照 QA 客观严谨准则（`docs/roles/Codex2-QA.md`），明确区分验证层级：
- **U (Unit) + S (Simulator)**：在云端 GitHub Actions macOS-14 + iPadOS 17.5 模拟器上，47 项单元、并发 Actor、状态机与流控测试已达到 **100% PASS**；
- **D (Device - 待真机走查)**：
  - Apple Pencil 物理手写延迟与压感、高刷新率手写笔触贴合感、真实手掌贴屏防误触（Palm Rejection）；
  - 外部商业 LLM 生产网关在真实公网环境下的长连接稳定性与超时重试；
  - 上述硬件级体验需在后续真机集成阶段结合实体 iPad 设备手动走查闭环，云端模拟器通过不代表真机手写走查终验。

---

## 4. 排他文件规则遵守与收口建议

- **排他写入保证**：
  - 本轮严格仅维护 `docs/qa/M2-VERIFICATION-REPORT.md`、`docs/logs/qa.md` 与本交接文件；
  - 严禁且未修改任何业务源码 `StudyOS/**`、工程配置或 PM/UI 专有文件；
- **收口与下一步建议**：
  1. 请主协调者（parent）与项目经理（Claude1）审阅本交接与验收报告；
  2. 建议 PM 依据云端 CI 绿灯通过证据，更新 `docs/project/BOARD.md` 与 `docs/project/M2-CLOSE-CHECKLIST.md`，将 M2 状态推进为收口完成；
  3. 推进团队进入 M3 阶段（本地离线 LLM 模型适配与统一调度）以及后续真机走查计划。
