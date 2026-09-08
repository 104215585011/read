# M3-UI-FIX2 ReaderViewModel AIOrigin 构造参数修复交接文档

- 交接编号：`M3-UI-FIX2-ui-001`
- 真实时间：`2026-09-08T11:20:00+08:00`
- 发送角色：UI 总监与前端负责人（Claude2）
- 接收角色：主协调者（parent）、项目经理（Claude1）、项目测试（Codex2）、项目后端（Codex1）
- 关联看板任务：`M3-UI` / `M3-UI-FIX2` (编译报错修复 / CI 验证)

---

## 1. 修复背景与根因分析

在 CI / 编译构建期间，`StudyOS/ViewModels/ReaderViewModel.swift` 报错：
```text
StudyOS/ViewModels/ReaderViewModel.swift:782:23: error: extra arguments at positions #2, #3 in call
StudyOS/ViewModels/ReaderViewModel.swift:782:23: error: missing argument for parameter 'attemptID' in call
```

### 根因分析
1. **契约签名**：根据 [StudyOS/Models/Note.swift](file:///c:/Users/wang/Documents/read/StudyOS/Models/Note.swift#L4-L21)，`AIOrigin` 领域模型的标准构造函数定义为：
   ```swift
   public init(
       requestID: String,
       attemptID: String,
       prompt: String? = nil,
       generatedAt: Date = Date()
   )
   ```
2. **错误调用**：在 `ReaderViewModel.swift` 的 `saveAINoteFromAIResult` 方法中，构造 `AIOrigin` 时传入了形参 `promptDigest` 与 `modelProfile`，未传入必需的 `attemptID`，导致编译器报参数多余与缺失错误。

---

## 2. 修复方案与代码变更

修改范围严格受限于前端 ViewModel 目录：[StudyOS/ViewModels/ReaderViewModel.swift](file:///c:/Users/wang/Documents/read/StudyOS/ViewModels/ReaderViewModel.swift)。

### 代码变更对比
```swift
// 修复前 (StudyOS/ViewModels/ReaderViewModel.swift 行 782-786):
            aiOrigin: AIOrigin(
                requestID: activeRequestID ?? UUID().uuidString,
                promptDigest: "digest_\(Date().timeIntervalSince1970)",
                modelProfile: "studyos-ai"
            )

// 修复后:
            aiOrigin: AIOrigin(
                requestID: activeRequestID ?? UUID().uuidString,
                attemptID: activeAttemptID ?? UUID().uuidString,
                prompt: "digest_\(Date().timeIntervalSince1970)"
            )
```

---

## 3. 并发安全与代码质量确认

1. **Strict Concurrency 与 @MainActor 隔离**：`ReaderViewModel` 全局标注 `@MainActor`，所有 UI 交互与状态更新均在主执行域安全运转；
2. **零强制解包**：`activeRequestID` 与 `activeAttemptID` 均采用空值合并运算符 `?? UUID().uuidString` 安全兜底，杜绝运行时 Crash；
3. **排他修改规范**：未触碰 `Package.swift`、后端契约 `StudyOS/Contracts/`、后端存储/服务 `StudyOS/Storage/` / `StudyOS/Services/` 或测试目录 `StudyOSTests/`。

---

## 4. 交付与验证状态

- **宿主环境**：Windows 本地环境（无原生 macOS / Swift 编译链，测试标定为 `NOT_RUN`）；
- **人工代码审计**：经语法与类型签名人工审计，`AIOrigin` 构造传参与模型完全对齐；
- **后续动作**：提请项目测试 Codex2 与主协调者在 macOS CI 环境中执行 `swift build` / `swift test` 验证。
