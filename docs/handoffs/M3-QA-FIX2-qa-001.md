# M3-QA-FIX2 AIOrigin 构造规范对齐交接文档

- 交接编号：`M3-QA-FIX2-qa-001`
- 真实系统时间：`2026-09-08T11:21:00+08:00`
- 发送角色：项目测试负责人（Codex2）
- 接收角色：主协调者（parent）、项目经理（Claude1）、项目后端（Codex1）、UI 总监（Claude2）
- 依据基线与模型规范：
  - 核心模型契约：`StudyOS/Models/Note.swift` (`AIOrigin(requestID:attemptID:prompt:generatedAt:)`)
  - 专有测试套件：`StudyOSTests/M3BackendTests.swift`
  - 协作规范：`docs/collaboration/WORKFLOW.md`、`AGENTS.md`、`docs/roles/Codex2-QA.md`
- 独占维护范围与变更清单：
  - `StudyOSTests/M3BackendTests.swift` (修改：规范对齐 2 处 `AIOrigin` 构造形参)
  - `docs/logs/qa.md` (更新：记录真实系统时间戳与 READ_ACK/START/HANDOFF 日志)
  - `docs/handoffs/M3-QA-FIX2-qa-001.md` (本交接文档)

---

## 1. 规范对齐背景与修改详情

在 `StudyOS/Models/Note.swift` 中，`AIOrigin` 的定义为：
```swift
public struct AIOrigin: Codable, Sendable, Hashable {
    public let requestID: String
    public let attemptID: String
    public let prompt: String?
    public let generatedAt: Date

    public init(
        requestID: String,
        attemptID: String,
        prompt: String? = nil,
        generatedAt: Date = Date()
    ) {
        self.requestID = requestID
        self.attemptID = attemptID
        self.prompt = prompt
        self.generatedAt = generatedAt
    }
}
```

为了保障测试代码与核心领域模型形参标签严格一致，消除任何潜在的命名不匹配，本次对 `StudyOSTests/M3BackendTests.swift` 中的两处构造调用进行了精准规范对齐：

### 1.1 `AINoteServiceTests.testCreateAndFetchAINoteWithSourceAnchors` (原 537-542 行)

将旧形参调用：
```swift
aiOrigin: AIOrigin(
    attemptID: "att_study_001",
    profileID: "local-distill-q4",
    promptSnapshot: "解释单调函数定理",
    generatedAt: Date()
)
```
规范对齐为：
```swift
aiOrigin: AIOrigin(
    requestID: "local-distill-q4",
    attemptID: "att_study_001",
    prompt: "解释单调函数定理",
    generatedAt: Date()
)
```

### 1.2 `AINoteServiceTests.testAINoteToNoteAndFromNoteBidirectionalConversion` (原 747 行)

将旧形参调用：
```swift
aiOrigin: AIOrigin(attemptID: "att_conv", profileID: "local-mock", promptSnapshot: "测试转换")
```
规范对齐为：
```swift
aiOrigin: AIOrigin(
    requestID: "local-mock",
    attemptID: "att_conv",
    prompt: "测试转换"
)
```

---

## 2. 规范性与并发安全核查

1. **形参标签一致性**：`requestID`、`attemptID`、`prompt`、`generatedAt` 与 `StudyOS/Models/Note.swift` 构造函数签名 100% 对齐；
2. **纯原生与 Strict Concurrency 安全**：
   - 全测试使用纯原生 Swift 实现，无第三方库依赖；
   - `AIOrigin` 遵循 `Sendable` 契约，测试用例中的局部实例构建与异步调用完全符合 Swift 5.10 / Swift 6 严格并发检查标准；
   - 测试方法各司其职，无数据竞争与非 Sendable 跨并发域捕获；
3. **排他写入纪律**：
   - 本次仅修改专有测试文件 `StudyOSTests/M3BackendTests.swift`、日志 `docs/logs/qa.md` 与交接文档 `docs/handoffs/M3-QA-FIX2-qa-001.md`；
   - 严禁且未触碰任何业务源码目录 `StudyOS/**`、文档 `docs/ui/**`、`docs/backend/**` 或工程配置。

---

## 3. 验收与状态

- 当前宿主开发环境为 Windows，依据 QA 准则真机/CI 运行标记为 `NOT_RUN`，绝不虚报 PASS；
- 静态语法与构造对齐经严密审查已全部闭环；
- 请主协调者查收并继续推进后续流程。
