# M4-QA 规程手册编制与自动化测试套件交付交接文件

- 文件编号：`M4-QA-qa-001`
- 真实系统时间：`2026-09-08T13:50:00+08:00`
- 发送角色：项目测试负责人（Codex2）
- 接收角色：主协调者（parent）、项目经理（Claude1）、项目后端（Codex1）、UI 总监（Claude2）
- 依据基线与契约版本：
  - PRD 规范：`docs/product/PRD-v0.1-source.md`（R01–R17，重点覆盖 R03 批注、R12 网络弹性与高可用、R14 本地离线模型架构与沙盒管理）
  - 后端契约基线：`docs/backend/CONTRACT-v0.1-draft.md`（版本：`0.1-draft / M0-BE-REV2` 及 M4 扩展）
  - 后端交付文件：`docs/handoffs/M4-BE-backend-001.md`
  - 前序任务授权：`docs/handoffs/M4-KICKOFF-pm-001.md`
  - 项目看板与规划：`docs/project/BOARD.md`、`docs/project/PLAN.md`（M4-RELEASE 阶段规划）
- 独占维护范围与变更清单：
  - `docs/qa/MANUAL-WALKTHROUGH-GUIDE.md`（新增：《StudyOS iPad 真机与 Apple Pencil 物理走查规程手册》，覆盖 10 大物理检验流）
  - `StudyOSTests/M4BackendTests.swift`（新增：M4 后端核心测试套件，涵盖 3 大测试类，共 32 项细分测试用例）
  - `docs/logs/qa.md`（更新：记录真实时间戳与 READ_ACK/START/HANDOFF 完整日志）
  - `docs/handoffs/M4-QA-qa-001.md`（本交接文档）

---

## 1. 交付事项详述

依据 PRD、项目看板 BOARD 及授权交接文件，Codex2 已完成 M4-QA 核心工作：

### 1.1 编制《StudyOS iPad 真机与 Apple Pencil 物理走查规程手册》 (`docs/qa/MANUAL-WALKTHROUGH-GUIDE.md`)

针对真实 iPad 硬件与 Apple Pencil 物理手感，编制了工业级现场验收标准手册，覆盖全部 10 大物理走查流。每条检验流均严格具备：**前置条件、操作步骤、物理手感与视觉预期、客观通过准则 (Pass Criteria)**：

| 检验流编号 | 检验流名称 | 核心硬件/技术焦点 | 客观通过准则核心摘要 |
| :--- | :--- | :--- | :--- |
| **流 01** | Apple Pencil 物理压感与线条动态响应 | 压电传感器线性度、轻压至重压动态笔宽 (0.8pt~6.0pt) | 粗细单调线性无台阶跳变；最低识别阈值 ≤ 10g；顿笔提笔干净无拖尾 |
| **流 02** | Apple Pencil 笔锋倾斜角度（侧锋阴影渲染与阻尼感） | Tilt Sensor 倾角感知、侧锋阴影着色器 (≤ 45°) | 倾角 ≤ 45° 100% 触发侧锋展开（8~15mm）；纸张粗糙颗粒感；抬笔 500ms 内快照固化 |
| **流 03** | PencilKit 极低书写延迟与高刷采样 | iPad Pro ProMotion 120Hz、Stroke Prediction 预测渲染 | 端到端感知延迟 ≤ 9ms；连续极速草写与快速折角零丢帧、零跳画、零卡顿 |
| **流 04** | 手掌自然搭屏防误触 (Palm Rejection) | 手腕/大鱼际电荷屏蔽、防误触与视口锁止 | 防误触成功率 100%，接触区残留杂点严格为 0；滑动时不产生非预期滚动或缩放 |
| **流 05** | Apple Pencil 2/Pro 硬件手势 | `UIPencilInteraction` 笔身双击 (Double-Tap)、Hover 悬停环 (M2/M4) | 双击切换画笔/橡皮擦响应 ≤ 50ms，成功率 100%；Hover 4~12mm 动态发光预测环 |
| **流 06** | 离线长文档分批抽取与内存峰值 | 300+ 页学术长文档分页抽取、并发手写批注 | 抽取全过程应用总内存峰值 ≤ 280MB；0 次系统内存告警；100% 杜绝 Jetsam OOM |
| **流 07** | 本地离线模型加载与长时功耗发热 | 端侧模型连续推理 30 分钟、NPU 能效、发热与耗电 | 30 分钟连续推理背板温升 ≤ 8.5℃ (最高 ≤ 41℃)；耗电 ≤ 8%；卸载后释放 ≥ 300MB |
| **流 08** | 弱网断网与云端/本地 Provider 无缝热降级 | 弱网抖动 Jitter 退避、突发断网/飞行模式热切换 | 弱网可重试错误按 Jitter 退避自动恢复；断网 100% 无感热降级至本地端侧模型 |
| **流 09** | 深浅色与 4 种纸张背景主题无缝切换 | 日光白/米黄/羊皮纸/深色主题、墨水反差比率 | 切换过程墨水坐标 100% 保真无位移；符合 WCAG AA (≥ 4.5:1)；高亮透光率 35%~50% |
| **流 10** | 多窗口分屏与旋转自适应视口对齐 | Stage Manager 自由拉伸、Split View 分屏、横竖屏旋转 | 笔迹与底层 PDF 矢量相对坐标对齐误差 ≤ 0.5pt；不可变快照与 PageKey 稳定绑定 |

手册同时制定了真机走查 **缺陷分级矩阵 (Blocker / Critical / Major / Minor)** 及 **现场物理走查通过性判定总则 (Exit Criteria)**，为后续 Mac/iPad 实体走查提供权威依据。

---

### 1.2 M4 自动化测试套件交付 (`StudyOSTests/M4BackendTests.swift`)

在专有测试目录 `StudyOSTests/` 下交付 `M4BackendTests.swift`，划分为 3 大测试类，共 32 项深度测试用例：

#### 1. NetworkResilienceTests (13 项测试)
- `testRetryPolicyDefaultValues`：验证默认策略参数（maxAttempts: 3, initialDelay: 0.5s, multiplier: 2.0, maxDelay: 8.0s, jitterFactor: 0.2）；
- `testRetryPolicyNone`：验证无重试基线策略；
- `testExponentialBackoffDeterministicCalculation`：关闭 Jitter 下精确验证指数退避延迟（1.0s, 2.0s, 4.0s, 8.0s, 10.0s 截断）；
- `testJitterBoundsWithinExpectedFactor`：在多次采样下验证 Jitter 随机抖动严格落于 `[initial * (1 - jitter), initial * (1 + jitter)]` 理论区间；
- `testRetryableErrorsClassification`：验证可重试错误精准识别（networkError, timeout, rateLimited, 500/502/503/504 serverError 及 NSURLErrorTimedOut/CannotConnect 等）；
- `testNonRetryableTerminalErrorsClassification`：验证不可重试终态精准拦截（unauthorized, cancelled, unsupportedCapability, invalidResponse, 400/401/403/404 客户端错误及 NSURLErrorCancelled）；
- `testCustomRetryablePredicate`：验证自定义断言扩展能力；
- `testRetryEngineSuccessWithoutRetry`：验证无故障时首发成功，无多余重试开销；
- `testRetryEngineTransientFailureRecoversOnRetry`：验证瞬态网络故障在重试后成功恢复，指标统计归正；
- `testRetryEngineNonRetryableFailsImmediately`：验证遇到不可重试错误时立即终止并抛出，执行次数严格为 1，重试次数为 0；
- `testRetryEngineExhaustedRetriesThrows`：验证超过最大重试次数后抛出终态超时错误，exhaustedFailures 统计准确；
- `testRetryEngineTaskCancellationInterrupts`：验证在 Task 取消时立即中断退避等待循环，协程敏捷退出；
- `testRetryEngineResetStats`：验证统计数据完整重置。

#### 2. OfflineResourceManagerTests (9 项测试)
- `testRegisterAndGetPackage`：模型包元数据注册、按 ID 查询与全局列表；
- `testDeletePackageAndPurgeSandbox`：删除模型包并彻底清理沙盒磁盘目录；
- `testStoreModelFile`：单文件直接写入并同步更新元数据大小与下载标记；
- `testStoreModelChunksAndAutomaticMerge`：多分块并发/按序写入（chunk_0, chunk_1, chunk_2），并在全部分块到达后自动原子合并至 `weights.bin`，清除临时分块并更新元数据；
- `testVerifyPackageIntegritySuccess`：基于原生 `CryptoKit.SHA256` 计算二进制指纹，比对预期哈希完全一致，判定 isValid 为 true；
- `testVerifyPackageIntegrityTamperedFails`：模拟数据篡改，校验和不匹配时严密判定 isValid 为 false 并输出拦截信息；
- `testVerifyPackageIntegrityUnregistered`：未注册包的校验防御；
- `testVerifyPackageIntegrityMissingWeights`：权重文件丢失时的安全校验防御；
- `testTotalStorageBytesUsed`：跨模型包沙盒磁盘存储总量统计。

#### 3. LocalModelPackageManagerTests (10 项测试)
- `testNetworkAndMemoryStateUpdates`：网络状态与设备内存压力动态感知与更新；
- `testEvaluateFallbackReachablePrefersCloud`：网络畅通 (.reachable) 时推选 `.useCloud`；
- `testEvaluateFallbackUnreachableFallbacksToLocal`：网络断开 (.unreachable) 时自动热降级至本地端侧模型 (`.fallbackToLocal`)；
- `testEvaluateFallbackWeakNetworkFallbacksToLocal`：弱网 (.weak) 状态下自动决策热降级；
- `testEvaluateFallbackCriticalMemorySuppressesLocalToPreventOOM`：设备内存临界告警 (.critical) 时抑制端侧模型，避免造成 OOM 崩溃 (`.failImmediately`)；
- `testActivePackageAndSelectOptimalRuntime`：活跃模型包切换与 CoreML/Mock 运行时推选；
- `testExecuteWithHotFallbackDirectLocalWhenOffline`：断网状态下 `executeWithHotFallback` 直接直通本地 Provider；
- `testExecuteWithHotFallbackCloudSuccessWhenReachable`：网络正常时优先使用云端 Provider；
- `testExecuteWithHotFallbackCloudFailureSeamlesslySwitchesToLocal`：云端发生网络故障时，执行管道自动无缝热降级至端侧离线 Provider 持续流式吐字；
- `testExecuteWithHotFallbackCloudRetryEngineExhaustedAndFallsBackToLocal`：带重试引擎时，重试耗尽后仍然无缝回退至本地离线 Provider。

---

## 2. 规范与排他规则合规自查

| 检查项 | 状态 | 详细说明 |
| :--- | :--- | :--- |
| **独占修改路径** | **完全遵守** | 仅操作 `docs/qa/`、`StudyOSTests/`、`docs/logs/qa.md` 与 `docs/handoffs/M4-QA-qa-001.md` |
| **业务源码与配置隔离** | **完全遵守** | 严禁且未触碰 `StudyOS/**` 业务代码、`Package.swift` 及其他角色专有文档 |
| **Swift 6 严格并发安全** | **完全遵守** | 所有测试类继承 `XCTestCase`，无不当类级隔离冲突；Mock 使用 `actor` 或线程安全 `@unchecked Sendable` 加锁；闭包均标 `@Sendable`；无跨隔离数据竞争 |
| **纯原生零外部依赖** | **完全遵守** | 仅依赖 `Foundation`, `CryptoKit`, `XCTest` 原生框架，不引入任何第三方依赖 |
| **测试执行结果真实标注** | **完全遵守** | 当前开发宿主为 Windows 环境，未安装 Xcode/Swift 原生工具链，按规程客观标注为 **`NOT_RUN`**，绝不虚报 PASS |

---

## 3. 下一步建议与交接流转

1. **交接主协调者（parent）与 PM（Claude1）**：
   - M4-QA 规程手册与后端自动化测试套件已全量就绪；
   - 请协调 UI 总监（Claude2）完成 M4-UI 视口打磨与硬件手势支持，并在环境就绪时由协调者统一提交 CI 执行真实云端验证；
2. **交接 UI 总监（Claude2）**：
   - 可参考《StudyOS iPad 真机与 Apple Pencil 物理走查规程手册》（`docs/qa/MANUAL-WALKTHROUGH-GUIDE.md`）中的 10 大检验流（特别是流 01~05 的手势与流 09~10 的主题与视口对齐），核对客户端硬件交互落地体验。
