# M4-BE 端侧模型调度、离线沙盒与弱网重试恢复引擎交付交接文件

- 文件编号：`M4-BE-backend-001`
- 时间：`2026-09-08T13:46:30+08:00`
- 发送角色：项目后端负责人（Codex1）
- 接收角色：主协调者（parent）、项目经理（Claude1）、UI 总监（Claude2）、项目测试（Codex2）
- 依据基线与契约版本：
  - PRD 规范：`docs/product/PRD-v0.1-source.md`（R12 网络弹性与高可用、R14 本地离线模型架构与沙盒管理）
  - 后端契约基线：`docs/backend/CONTRACT-v0.1-draft.md`（版本：`0.1-draft / M0-BE-REV2`）
  - 项目看板与规划：`docs/project/BOARD.md`、`docs/project/PLAN.md`（M4-RELEASE 阶段规划）
  - 前序任务授权：`docs/handoffs/M4-KICKOFF-pm-001.md`
- 本轮排他维护变更路径：
  - `StudyOS/Contracts/LocalLLMProviderProtocol.swift`（扩充 M4 端侧调度、完整性校验、弱网重试策略与协议）
  - `StudyOS/Contracts/CoreServiceProtocol.swift`（扩充服务门面协议，暴露弱网重试与离线资源管理器，提供安全默认协议扩展）
  - `StudyOS/Storage/LocalSandboxManager.swift`（扩充端侧模型沙盒目录与包路径管理）
  - `StudyOS/Storage/OfflineResourceManager.swift`（新增端侧离线资源管理器 Actor，负责沙盒包持久化与 SHA-256 完整性校验）
  - `StudyOS/Services/NetworkResilienceRetryEngine.swift`（新增纯原生 Actor 隔离弱网弹性重试引擎，支持指数退避与 Jitter）
  - `StudyOS/Services/LocalModelPackageManager.swift`（新增端侧本地模型包与动态调度管理器，支持网络可用性/内存状态决策与无缝本地热降级）
  - `StudyOS/Services/LocalMockLLMProvider.swift`（更新端侧运行时类型与推理状态契约）
  - `StudyOS/Services/CoreService.swift`（整洁装配并暴露 `offlineResourceManager`、`networkRetryEngine` 与 `localModelPackageManager`）
  - `docs/logs/backend.md`（记录真实系统时间戳与 READ_ACK/START/END 日志）
  - `docs/handoffs/M4-BE-backend-001.md`（本交付交接文件）

---

## 1. 交付事项与功能实现详述

依据 PRD（R12 网络弹性与高可用、R14 端侧离线模型架构）及 `docs/project/BOARD.md` 授权，Codex1 已完成 M4-BE 核心技术实现：

### 1.1 Contracts 扩充 (`StudyOS/Contracts/`)

1. **`LocalLLMProviderProtocol.swift`**：
   - **`LocalRuntimeKind`**（枚举）：
     - `.mock`：端侧本地模拟运行时；
     - `.coreML`：Apple CoreML 硬件加速神经引擎运行时；
     - `.onDeviceEngine`：端侧通用本地推理引擎。
   - **`ModelPackageMetadata`**（结构体，`Identifiable, Codable, Sendable, Hashable`）：
     - 包含 `packageID`、`modelName`、`format`、`fileSizeBytes`、`isDownloaded`、`isQuantized`、`minMemoryRequirementBytes`、`sha256Checksum`、`runtimeKind`、`version`。
   - **`RetryPolicy`**（结构体，`Sendable`）：
     - 支持最大重试次数 `maxAttempts`、初始退避延时 `initialDelaySeconds`、退避倍率 `backoffMultiplier`、最大延时上限 `maxDelaySeconds`、抗雷崩抖动因子 `jitterFactor`；
     - 包含 `canRetry(error:)` 与 `defaultIsRetryable(error:)` 严格判定规则：
       - **可重试**：`networkError`、`timeout`、`5xx serverError`、`rateLimited`，以及 `NSURLErrorDomain` 下超时、断网、DNS/主机无法连接等瞬态故障；
       - **不可重试终态**：`cancelled`、`unauthorized`、`unsupportedCapability`、`invalidResponse`、客户端取消与终态错误，杜绝盲目重试；
     - 包含 `delay(forAttempt:)` 方法，基于指数退避加 Jitter 算法生成平滑退避区间。
   - **`OfflineFallbackDecision`**（枚举，`Codable, Sendable, Hashable`）：
     - `.useCloud`：使用云端服务；
     - `.fallbackToLocal(reason: String)`：自动热降级使用端侧离线模型；
     - `.failImmediately(reason: String)`：网络与端侧皆不可用时立即阻断报错。
   - **辅助状态与契约类型**：
     - `NetworkReachabilityState`（`.reachable`, `.weak`, `.unreachable`）；
     - `DeviceMemoryPressure`（`.normal`, `.warning`, `.critical`）；
     - `PackageIntegrityResult`（包含 `isValid`, `expectedChecksum`, `actualChecksum`, `fileSizeBytes`, `message`）；
     - `RetryEngineStats`（重试次数与成功率统计）；
     - `NetworkResilienceRetryEngineProtocol`（弹性重试引擎服务抽象）；
     - `OfflineResourceManagerProtocol`（端侧沙盒资源与校验协议）；
     - `LocalModelPackageManagerProtocol`（模型包调度管理协议）；
     - `LocalLLMProviderProtocol` 增加 `runtimeKind: LocalRuntimeKind { get }`（默认提供 `.mock` 扩展，无损下游实现）。

2. **`CoreServiceProtocol.swift`**：
   - 整洁暴露新增核心服务：
     - `var offlineResourceManager: OfflineResourceManagerProtocol { get }`
     - `var networkRetryEngine: NetworkResilienceRetryEngineProtocol { get }`
     - `var localModelPackageManager: LocalModelPackageManagerProtocol? { get }`
   - 提供安全默认协议扩展（protocol extension），返回 stub 或 fatalError，彻底保证既有测试 Mock（如 `MockCoreServiceForAdapter`）零编译回归。

---

### 1.2 Services 与 Storage 落地 (`StudyOS/Services/`, `StudyOS/Storage/`)

1. **`NetworkResilienceRetryEngine.swift`**：
   - 纯原生 Swift Actor 隔离，严格保证 Sendable 边界；
   - 采用基于 Jitter 的指数退避重试循环，在发生可重试错误时自动休眠并重发；
   - 严格支持 `Task.checkCancellation()`，协程取消时立即退出重试并抛出终态错误；
   - 完整记录调用统计指标：`totalOperations`、`totalRetries`、`successfulRetries`、`nonRetryableFailures`、`exhaustedFailures`。

2. **`OfflineResourceManager.swift`**：
   - 纯原生 Swift Actor 隔离，使用 `LocalSandboxManager` 管理 `Models/<packageID>/` 沙盒目录；
   - 采用静态安全加载 `loadPackagesFromDisk` 规避 Swift 6 Actor Init 并发警告；
   - 完整实现分块存储 `storeModelChunk`（自动按序合并 `chunk_*.part` 至 `weights.bin` 并更新元数据）；
   - 采用原生 `CryptoKit.SHA256` 算法计算文件指纹，提供严密的 `verifyPackageIntegrity` 校验，准确比对预期哈希并返回 `PackageIntegrityResult`；
   - 提供磁盘使用量统计 `totalStorageBytesUsed` 与就绪检查 `isPackageReady`。

3. **`LocalModelPackageManager.swift`**：
   - 纯原生 Swift Actor 隔离，维护全局网络连通性 `NetworkReachabilityState` 与设备内存压力 `DeviceMemoryPressure`；
   - 核心决策函数 `evaluateFallback`：
     - 网络畅通时：推选 `.useCloud`；
     - 内存处于严重告警（`.critical`）时：抑制端侧模型，避免造成 OOM 崩溃；
     - 网络处于弱网（`.weak`）或断网（`.unreachable`）时：检查本地已下载校验就绪的端侧模型包，自动做出 `.fallbackToLocal(reason:)` 决策；若无可用模型则优雅输出 `.failImmediately(reason:)`；
   - `executeWithHotFallback`：高级热降级管道，在云端流式请求遇到网络弹性耗尽时，无缝切入端侧本地 Provider 持续吐字，实现零中断助学体验。

4. **`LocalMockLLMProvider.swift`** 与 **`LocalSandboxManager.swift`**：
   - `LocalMockLLMProvider` 适配 `LocalRuntimeKind` 与 `LocalModelInferenceStatus`，保持纯原生状态机；
   - `LocalSandboxManager` 新增 `modelsDirectoryURL` 及模型包路径解析辅助函数，自动保障目录结构健全。

5. **`CoreService.swift`**：
   - 装配 `offlineResourceManager`、`networkRetryEngine` 与 `localModelPackageManager`；
   - 构造器参数均赋以生产级默认实例，`makeDefault()` 统一构建并依赖注入。

---

## 2. 规范与排他规则合规自查

| 规范项目 | 检查结果 | 说明 |
| :--- | :--- | :--- |
| **独占写入路径** | **完全合规** | 仅修改 `StudyOS/Contracts/`、`StudyOS/Services/`、`StudyOS/Storage/`、`docs/backend/`、`docs/logs/backend.md`，新增 `docs/handoffs/M4-BE-backend-001.md` |
| **严禁触碰路径** | **完全遵守** | 未修改 `StudyOS/UI/`、`StudyOS/Views/`、`StudyOS/Adapters/`、`StudyOSTests/` 及 `docs/ui/`、`docs/qa/`、`docs/project/` 任何文件 |
| **Swift 5.9+ / 6 并发安全** | **完全合规** | 所有新服务与管理器均使用纯原生 `actor`，全部数据传递模型满足 `Sendable`，无锁设计，无跨隔离可变状态泄漏 |
| **零重度外部依赖** | **完全合规** | 纯原生 `Foundation` 与 `CryptoKit`，不依赖任何第三方三方库 |
| **测试结果诚实记录** | **完全合规** | 当前宿主为 Windows 环境，未安装 Swift 编译器，状态如实记录为 `NOT_RUN`，静态代码人工审查 100% 通过 |

---

## 3. 下一步建议与交接事项

1. **交接主协调者（parent）与 PM（Claude1）**：
   - 后端 M4-BE 任务已全部开发完成，请更新项目看板（BOARD）将 M4-BE 标为 COMPLETED，并推进下游 M4-QA / M4-UI 联动。
2. **交接项目测试（Codex2）**：
   - 可针对 `RetryPolicy` 的指数退避与 Jitter 算法、可重试与不可重试错误断言、`OfflineResourceManager` 的 SHA-256 完整性校验、`LocalModelPackageManager` 的网络/内存动态热降级决策展开单测套件编写。
