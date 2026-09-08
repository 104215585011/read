# M2 收口检查表与任务编排

审计基线：`c429470`（GitHub Actions CI 真实云端流水线已在 `macos-14` + `iPad Pro 11-inch (M4) / iOS 17.5` 模拟器通过，47/47 项测试 100% PASS）。
核心交付与修复全量闭环：真实正文传输、全量 CryptoKit SHA-256 摘要、流式终态互斥防御（`failed` / `cancelled` / `alreadyTerminal`）、握手前防并发重入、SSE 协议鲁棒性断言全部达成。

## 已交付与证据边界

| 范围 | 现有证据 | 结论 |
|---|---|---|
| 后端 | `5e7c72f` 服务/协议、`b051da9` 并发捕获修复、`4f7b9a9` 上下文覆盖与取消修复、`c429470` 最终闭环；后端交接齐全 | 已交付，核心缺陷闭环，经 CI 验证通过 |
| UI | ReaderViewModel、AISidebarView、SelectionCalloutMenu、`c429470` 真实正文提取与不可变 AggregatedContext 迁移闭环 | 已交付，经模拟器流测试与 CI 验证通过 |
| 测试源码 | 7 大测试套件共 47 个测试方法全部交付并在 CI 运行（含 `M2RegressionTests` 8 项专项回归） | 自动化测试套件全量执行 PASS (47/47) |
| 最新CI | GitHub Actions CI（macos-14 runner, Xcode 15.4 / Swift 5.10, iPadOS 17.5 模拟器, xcodebuild test, xcresult 上传） | Commit `c429470` 真实绿灯，47/47 PASS，0 失败，0 告警 |
| 真机/真实Provider | 物理 Pencil 压感/防误触、外部公网商业大模型端到端走查 | 客观标定为 D 层（Device Level）边界，规划在 M3/M4 真机环境走查 |

## 阶段关闭必须检查（全量闭环）

- [x] **M2-FIX-CONTEXT**：真实发送消息包含已确认的选区/单页/跨页章节上下文，杜绝只传占位清单；未勾选相邻页严格物理隔离（`PAGE_ZERO_SENTINEL` vs `PRIVATE_OTHER_PAGE`）。`M2RegressionTests` 专项用例通过。
- [x] **M2-FIX-DIGEST**：使用全量 UTF-8 数据字节通过 `CryptoKit.SHA256.hash(data: Data(utf8))` 计算真实摘要，杜绝前缀/长度伪哈希；单字符差异产生雪崩效应。`testDigestHashesAllUTF8BytesNotOnlyPrefixAndLength` 断言通过。
- [x] **M2-CI**：记录最终 commit `c429470`，GitHub Actions `macos-14` runner，Xcode 15.4 / Swift 5.10，`iPad Pro 11-inch (M4) / iOS 17.5` 模拟器，`xcodebuild test` 生成 xcresult，47/47 PASS，0 失败，0 告警。
- [x] **M2-QA-REGRESSION**：重跑上下文覆盖、流取消、Task 取消、失败互斥、重复 attempt 预占拦截、来源过滤、存储 Actor 隔离、跨会话核对等全部 47 项测试，在新基线 `c429470` 上 100% 复测通过。
- [x] **M2-SCOPE-AUDIT**：逐项核对 R01–R09、R14、R16、R17 契约与功能，自动化测试覆盖 U 层与 S 层；客观标定 D 层真机手写走查边界。
- [x] **M2-PROVIDER**：`OpenAICompatibleProvider` 具备流式 SSE 协议解析、增量 delta 累加、畸形 JSON 阻断、EOF 非正常截断拦截；Mock/Fixture 与参数配置闭环。
- [x] **M2-AI-QUALITY**：六段助学结构、当前章节真实起止边界覆盖、资料不足明确拒绝等通过单元与流式测试校验。
- [x] **M2-DEVICE**：客观区分 U/S/D 边界，明确记录 Apple Pencil 物理压感/低延迟、手掌防误触及外部公网网络为 D 层待走查项，不以模拟器冒充真机。
- [x] **M2-PM-CLOSE**：核心缺陷全量闭环，差异与处置方案清晰，BOARD.md 更新为 DONE，输出收口交接 `docs/handoffs/M2-CLOSE-pm-002.md`。

## 全文范围阻塞与临时 UI 路由闭环

- [x] **M2-FULL-SCOPE**：针对 `.document` 全文学习范围的阶段处置已明确：在 M2 中已落地安全限制与友好提示（`invalidResponse` / 明确未支持长文档一次性外发，杜绝以目录伪造全文正文）；独立的全文分批长文档研读与大纲结构分析任务作为 **R10 P0** 核心需求正式排入 **M3** 阶段实施，不静默删除。
- [x] **M2-UI-CONTEXT-MIGRATION**：主协调者依据授权在 `ReaderViewModel.swift` 完成真实物理页正文提取与不可变 `AggregatedContext` 强校验透传迁移，已合入 Commit `c429470` 并经 CI 验证通过，临时文件锁定已解除。

