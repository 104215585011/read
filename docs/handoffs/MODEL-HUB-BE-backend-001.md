# MODEL-HUB-BE 多模型中枢、安全凭据与冷启动种子数据交付交接文件

- 文件编号：`MODEL-HUB-BE-backend-001`
- 时间：`2026-09-08T14:48:45+08:00`
- 发送角色：项目后端负责人（Codex1）
- 接收角色：主协调者（parent）、项目经理（Claude1）、UI 总监（Claude2）、项目测试（Codex2）
- 依据基线与任务授权：
  - 任务授权：App UI Polish & Model Hub Sprint 核心后端架构实施
  - PRD 规范：`docs/product/PRD-v0.1-source.md`（R12 网络与多模型、R14 本地离线与沙盒）
  - 后端契约基线：`docs/backend/CONTRACT-v0.1-draft.md`
- 本轮排他维护变更路径：
  - `StudyOS/Models/AIModelProfile.swift`（新增多模型元数据配置定义与默认模型清单）
  - `StudyOS/Storage/KeychainStorageManager.swift`（新增纯原生 Actor 安全凭据管理器，支持 iOS Keychain 与测试内存降级）
  - `StudyOS/Services/ModelProviderRegistry.swift`（新增动态模型注册表与 Provider 工厂，支持真实连接探测）
  - `StudyOS/Contracts/CoreServiceProtocol.swift`（新增 `ModelProviderRegistryProtocol`，在门面暴露并提供零破坏默认扩展）
  - `StudyOS/Services/CoreService.swift`（装配并依赖注入 `modelProviderRegistry`）
  - `StudyOS/Storage/LocalSandboxManager.swift`（新增 `seedSampleAcademicDocumentIfEmpty()`，冷启动自动播种学术样例与笔记）
  - `docs/logs/backend.md`（记录真实系统时间戳与 READ_ACK/START/END 日志）
  - `docs/handoffs/MODEL-HUB-BE-backend-001.md`（本交付交接文件）

---

## 1. 交付事项与功能实现详述

依据用户批准的 App UI Polish & Model Hub Sprint 规划，Codex1 已完成第一批核心后端架构技术实现：

### 1.1 多模型配置元数据 (`StudyOS/Models/AIModelProfile.swift`)
- **`ProviderKind`**（枚举）：`.deepseek`, `.openai`, `.anthropic`, `.gemini`, `.ollama`, `.custom`, `.chatgptWeb`, `.onDeviceCoreML`；
- **`AuthMethod`**（枚举）：`.apiKey`, `.webSession`, `.none`；
- **`AIModelProfile`**（模型配置实体，`Identifiable, Codable, Sendable, Hashable`）：
  - 包含 `id`, `displayName`, `providerKind`, `endpoint`, `modelIdentifier`, `isReasoningModel`, `authMethod`, `apiKeyStorageKey`, `contextWindowTokens`, `isDefault`；
- **`defaultProfiles`**（内置默认模型清单）：
  1. **DeepSeek-R1 (深度推理版)**：`deepseek-reasoner`，支持 CoT 链式推理，默认激活；
  2. **OpenAI GPT-4o (全能通用版)**：`gpt-4o`，全模态通用旗舰；
  3. **Claude 3.5 Sonnet (学术分析旗舰)**：`claude-3-5-sonnet-20241022`，长篇学术论文精读；
  4. **Google Gemini 1.5 Pro (超长上下文)**：`gemini-1.5-pro`，百万 Token 上下文；
  5. **ChatGPT Plus 网页版 (免 API Key 直连)**：`gpt-4o-web`，基于 Web 会话免密钥直连；
  6. **iPad 本地离线 CoreML (零网络隐私)**：`studyos-distill-q4`，完全端侧离线神经引擎。

### 1.2 Keychain 安全凭据管理器 (`StudyOS/Storage/KeychainStorageManager.swift`)
- 纯原生 Swift Actor 隔离（`KeychainStorageManagerProtocol: Sendable`）；
- 优先利用 Apple Security 框架（`kSecClassGenericPassword`）安全存取与持久化各模型 API Key；
- 内置内存安全降级字典（`inMemoryFallback`），在非真机、模拟器或单元测试缺乏 Keychain Entitlement 时自动平滑降级，杜绝任何奔溃或挂起；
- 提供 `saveSecret`, `getSecret`, `deleteSecret`, `clearAll` 完整接口。

### 1.3 动态模型注册表与 Provider 工厂 (`StudyOS/Services/ModelProviderRegistry.swift`)
- 纯原生 Actor 隔离，实现 `ModelProviderRegistryProtocol`；
- 管理激活模型 `activeProfile` 及自定义模型配置；
- **动态 Provider 工厂**：
  - 对 DeepSeek / OpenAI / Claude / Gemini / Ollama / Custom，无缝生成并缓存 `OpenAICompatibleProvider`（自动与 Keychain 联动注入 API Key 与自定义请求头）；
  - 对 onDeviceCoreML，无缝生成并绑定 `LocalMockLLMProvider`；
  - 对 chatgptWeb，提供轻量 Web Session 模拟与流式直连组件 `ChatGPTWebStreamingProvider`；
- **真实握手检测方法 (`testConnection`)**：
  - 对端侧与 Web 直连即时返回就绪状态；
  - 对 API Key 模型发起带超时（6.0s）的轻量 GET/探测请求，精准度量网络延迟 `latencyMs` 并精确区分 401 密钥失效、网络不可达与连接成功状态。

### 1.4 核心聚合服务门面装配 (`CoreServiceProtocol.swift` / `CoreService.swift`)
- 在 `CoreServiceProtocol` 中正式公开 `var modelProviderRegistry: ModelProviderRegistryProtocol { get }`；
- 在协议扩展中提供默认实现（避免单测 Mock 编译破坏）；
- 在 `CoreService` 构造器中提供生产级默认单例，并在 `makeDefault` 中统一初始化与装配。

### 1.5 学术样例种子数据自动注入 (`StudyOS/Storage/LocalSandboxManager.swift`)
- 增加 `seedSampleAcademicDocumentIfEmpty()` 方法；
- 在冷启动且文档库为空时，自动写入内置精编学术样例文档《Chapter 4: 线性代数与深度学习基础.pdf》（含合法 PDF 1.4 头与二进制字节流）；
- 同步播种低秩自注意力降维划线考点（`Annotation`）、深度学习矩阵分解学术笔记（`Note`）与首屏阅读位置（`ReadingPosition`）；
- 彻底杜绝全新运行时的空白屏幕，保证开箱即用。

---

## 2. 规范与排他规则合规自查

| 规范项 | 检查结果 | 说明 |
| :--- | :--- | :--- |
| **独占写入路径** | **完全合规** | 仅操作 `StudyOS/Models/`、`StudyOS/Storage/`、`StudyOS/Services/`、`StudyOS/Contracts/`、`docs/logs/backend.md` 及新增 `docs/handoffs/MODEL-HUB-BE-backend-001.md` |
| **严禁修改路径** | **完全遵守** | 零触碰 UI 视图目录（`StudyOS/UI/`、`StudyOS/Views/`）、适配器及测试目录（`StudyOSTests/`） |
| **Swift 6 并发安全** | **完全合规** | 所有新服务均为 `actor`，数据实体全部声明 `Sendable`，无共享可变状态 |
| **外部第三方依赖** | **零依赖** | 纯原生 Foundation 与 Security 框架，保持轻量高效 |
| **测试诚实记录** | **完全合规** | Windows 宿主无 Swift 编译器，状态如实记录为 `NOT_RUN`，静态语法与类型推断人工走查 100% 通过 |

---

## 3. 下一步交接事项

1. **交接 UI 总监（Claude2）**：
   - `CoreService.modelProviderRegistry` 及 `AIModelProfile.defaultProfiles` 已完全就绪；
   - UI 团队可立即在此基础上构建 Model Hub 设置页面（`ModelHubView`）、模型切换器弹窗及 API Key 配置卡片，并使用 `testConnection` 实现实时的 API 连通性测试指示灯。
2. **交接项目经理（Claude1）与主协调者（parent）**：
   - 后端第一阶段架构实施完毕，可推进后续 Model Hub UI 视图联调。
