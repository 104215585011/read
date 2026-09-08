# Model Hub & UI Polish 测试套件与测试桩兼容性交付交接文件

- 文件编号：`MODEL-HUB-QA-qa-001`
- 真实系统时间：`2026-09-08T14:55:00+08:00`
- 发送角色：项目测试负责人（Codex2）
- 接收角色：主协调者（parent）、项目经理（Claude1）、项目后端（Codex1）、UI 总监（Claude2）
- 依据基线与契约版本：
  - PRD 规范：`docs/product/PRD-v0.1-source.md`（R06 选区助学、R12 网络弹性、R14 本地离线模型架构、R17 离线研读）
  - 后端契约基线：`docs/backend/CONTRACT-v0.1-draft.md`（CoreServiceProtocol 扩展 `modelProviderRegistry: ModelProviderRegistryProtocol`）
  - 前序任务交接：后端 Codex1 & 前端 Claude2 关于 App UI Polish & Model Hub Sprint 的交付成果
- 独占维护范围与变更清单：
  - `StudyOSTests/ReaderAdapterFlowTests.swift`（更新：在 MockCoreServiceForAdapter 中实现 `var modelProviderRegistry: ModelProviderRegistryProtocol`）
  - `StudyOSTests/ModelConfigurationTests.swift`（新增：全新的自动化测试套件，涵盖 4 大测试类，共 21 项细分测试方法）
  - `docs/logs/qa.md`（更新：记录真实时间戳与 READ_ACK/START/HANDOFF 完整日志）
  - `docs/handoffs/MODEL-HUB-QA-qa-001.md`（本交付交接文档）

---

## 1. 交付内容详述

依据主协调者授权与后端/UI 交付代码，Codex2 已完成测试桩兼容性补齐与专有测试套件编写：

### 1.1 测试桩契约补全 (`StudyOSTests/ReaderAdapterFlowTests.swift`)
在 `MockCoreServiceForAdapter` 中显式添加 `CoreServiceProtocol` 新增属性：
```swift
var modelProviderRegistry: ModelProviderRegistryProtocol {
    fatalError("ModelProviderRegistry not accessed in ReaderAdapter unit tests")
}
```
- 彻底对齐协议定义，杜绝任何下游测试因契约新增导致的编译阻断。

---

### 1.2 Model Hub 自动化测试套件落地 (`StudyOSTests/ModelConfigurationTests.swift`)

交付 4 大测试类共 21 项细分测试用例：

#### 1. ModelProfileTests (5 项)
- `testDefaultProfilesCountAndUniqueness`：验证预设模型严格为 6 款，ID 唯一无碰撞，仅且唯有 DeepSeek-R1 默认激活；
- `testDefaultProfilesAttributesIntegrity`：逐项验证 6 款模型预设（DeepSeek-R1、OpenAI GPT-4o、Claude 3.5 Sonnet、Gemini 1.5 Pro、ChatGPT Plus Web、iPad 本地 CoreML）的 `providerKind`、`authMethod`、`contextWindowTokens`、`modelIdentifier` 等属性配置；
- `testCodableRoundtrip`：测试完整字段的 JSON 序列化与反序列化保真度；
- `testHashableAndEquatable`：测试数据实体的 Hashable 散列与 Equatable 判等契约；
- `testEnumCasesCompleteness`：验证 `ProviderKind` (8 种) 与 `AuthMethod` (3 种) 的 CaseIterable 完备性。

#### 2. KeychainStorageTests (5 项)
- `testSaveAndRetrieveSecret`：测试安全凭据的保存与精确获取，验证未存 Key 返回 nil；
- `testOverwriteExistingSecret`：测试同 Key 凭据覆盖更新；
- `testDeleteSecret`：测试安全凭据的删除与状态清除；
- `testClearAllSecrets`：测试清空所有凭据缓存；
- `testConcurrentAccessSafety`：使用 `withThrowingTaskGroup` 启动 20 个并发协程执行读写操作，验证 Actor 隔离下的严格并发安全性与零死锁。

#### 3. ModelProviderRegistryTests (7 项)
- `testRegistryInitializationWithDefaults`：验证注册表冷启动预载入 6 款预设模型，默认激活 DeepSeek-R1；
- `testSetActiveProfile`：测试切换激活模型（如切至 GPT-4o），原默认模型 `isDefault` 自动降为 false，未注册 ID 拦截抛错；
- `testSaveCustomProfileAndSandboxPersistence`：测试自定义模型（如 Ollama 7B）保存，并在新 Registry 实例冷启动下通过沙盒持久化恢复；
- `testDeleteProfileValidations`：测试删除自定义模型、禁止删除当前默认激活模型的安全阻断保护；
- `testDynamicProviderInstantiation`：验证 Provider 工厂的多态动态拉起逻辑：
  - `.onDeviceCoreML` -> `LocalMockLLMProvider`
  - `.chatgptWeb` -> `ChatGPTWebStreamingProvider`
  - `.openai` / `.deepseek` / `.anthropic` -> `OpenAICompatibleProvider`
  - 验证 Provider 实例缓存机制；
- `testGetActiveProviderLinkage`：验证 `getActiveProvider()` 随激活模型切换自动联动；
- `testChatGPTWebStreamingProviderExecution`：验证免 Key 网页模拟 Provider 的异步流式逐 chunk 吐字与正常完成。

#### 4. ConnectionHandshakeTests (4 项)
- `testConnectionOnDeviceCoreML`：验证离线 CoreML 神经引擎握手零网络直接成功，延迟 ≤ 10ms；
- `testConnectionChatGPTWebSession`：验证 ChatGPT Plus Web 会话探测正常连通；
- `testConnectionMissingApiKeyGracefulMessage`：验证需要 API Key 的模型在未配置密钥时，优雅返回 `success: false` 并明确提示“未配置 API Key”；
- `testConnectionInvalidEndpointURL`：验证非法 URL 端点握手时的防御拦截。

---

## 2. 规范与排他规则合规自查

| 规范项目 | 检查结果 | 说明 |
|:---|:---:|:---|
| **独占修改路径** | **完全合规** | 仅修改 `StudyOSTests/`、`docs/logs/qa.md` 与新增 `docs/handoffs/MODEL-HUB-QA-qa-001.md` |
| **严禁触碰路径** | **完全遵守** | 未修改 `StudyOS/**` 业务代码、`Package.swift` 及其他角色专有文档 |
| **Swift 6 严格并发安全** | **完全合规** | 测试类继承 `XCTestCase`，使用纯原生 Actor 隔离与 Sendable 边界，并发多任务安全 |
| **纯原生零外部依赖** | **完全合规** | 仅依赖 `Foundation`, `Security`, `XCTest` 原生库 |
| **测试结果客观真实** | **完全合规** | 当前开发宿主为 Windows 环境，按规程客观标注为 **`NOT_RUN`**，绝不虚报 PASS |

---

## 3. 下一步建议与交接流转

1. **交接主协调者（parent）**：
   - 测试桩兼容性已补全，Model Hub 自动化测试套件（21 项用例）已就绪；
   - 请安排统一提交至 GitHub Actions CI 真实云端流水线进行编译与自动化测试验证。
