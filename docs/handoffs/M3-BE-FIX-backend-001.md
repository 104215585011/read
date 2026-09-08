# M3-BE-FIX AINoteService 与 FullDocumentStudyService Swift 6 并发警告修复交接文件

- 文件编号：`M3-BE-FIX-backend-001`
- 时间：`2026-09-08T11:06:23+08:00`
- 发送角色：项目后端负责人（Codex1）
- 接收角色：主协调者（parent）、项目经理（Claude1）、外部 UI 总监（Claude2）、项目测试（Codex2）
- 依据规范与原则：
  - Swift 5.9+ / Swift 6 Complete Concurrency 规范 (Actor Isolation)
  - 协作规范：`docs/collaboration/WORKFLOW.md`
  - 角色排他规则：Codex1 独占维护 `StudyOS/Contracts/**`、`StudyOS/Services/**`、`StudyOS/Models/**`、`StudyOS/Storage/**`、`docs/backend/**`、`docs/logs/backend.md`，严禁修改 UI/Views 目录与测试目录
- 变更路径：
  - `StudyOS/Services/AINoteService.swift`
  - `StudyOS/Services/FullDocumentStudyService.swift`
  - `docs/logs/backend.md`
  - `docs/handoffs/M3-BE-FIX-backend-001.md`

---

## 1. 修复事项说明

### 1.1 背景与警告
在 Swift 6 严格并发检查模式下，编译抛出如下警告：
`warning: actor-isolated instance method 'loadFromDisk()' can not be referenced from a non-isolated context; this is an error in Swift 6`

### 1.2 根因分析
在 `AINoteService` 与 `FullDocumentStudyService` 两个 `actor` 的同步构造函数 `public init(...)` 中：
- `init` 尚未完全初始化对象自身上下文，在同步上下文中调用 actor-isolated 实例方法 `self.loadFromDisk()` 违反了 Swift 6 的 Actor 隔离原则（非隔离上下文中无法同步引用 actor-isolated 方法，Swift 6 模式下将作为编译错误升级阻断）。

### 1.3 修复方案与代码变更

#### 1.3.1 StudyOS/Services/AINoteService.swift
1. 提取私有静态方法：
   ```swift
   private static func loadCardsFromDisk(sandbox: LocalSandboxManager, decoder: JSONDecoder) -> [String: AINoteCard] {
       let fileURL = sandbox.metadataFileURL(fileName: "ai_notes")
       guard let data = try? Data(contentsOf: fileURL),
             let loaded = try? decoder.decode([String: AINoteCard].self, from: data) else {
           return [:]
       }
       return loaded
   }
   ```
2. 在 `public init(sandbox: LocalSandboxManager = .shared)` 中直接通过静态函数对实例属性赋值：
   `self.cards = Self.loadCardsFromDisk(sandbox: sandbox, decoder: decoder)`
   消除了在 `init` 中调用 actor-isolated 实例方法的问题。
3. 保留实例方法 `private func loadFromDisk()` 供后续刷新调用，复用静态加载逻辑：
   `self.cards = Self.loadCardsFromDisk(sandbox: sandbox, decoder: decoder)`

#### 1.3.2 StudyOS/Services/FullDocumentStudyService.swift
1. 提取私有静态方法：
   ```swift
   private static func loadAnalysesFromDisk(sandbox: LocalSandboxManager, decoder: JSONDecoder) -> [String: FullDocumentAnalysis] {
       let fileURL = sandbox.metadataFileURL(fileName: "full_doc_analysis")
       guard let data = try? Data(contentsOf: fileURL),
             let loaded = try? decoder.decode([String: FullDocumentAnalysis].self, from: data) else {
           return [:]
       }
       return loaded
   }
   ```
2. 在 `public init(...)` 中直接通过静态函数对属性赋值：
   `self.cachedAnalyses = Self.loadAnalysesFromDisk(sandbox: sandbox, decoder: decoder)`
   消除了在 `init` 中调用 actor-isolated 实例方法的问题。
3. 保留实例方法 `private func loadFromDisk()` 供内部刷新复用：
   `self.cachedAnalyses = Self.loadAnalysesFromDisk(sandbox: sandbox, decoder: decoder)`

---

## 2. 纯原生与并发合规检查

- **Swift 6 Concurrency**：所有涉及的载入逻辑使用纯不可变参数（`sandbox: LocalSandboxManager` 为 `@unchecked Sendable`，`decoder: JSONDecoder` 为值或局部实例），完全不穿越非隔离执行上下文；
- **纯原生零外部依赖**：仅使用 Foundation 原生 `Data`, `JSONDecoder` 等能力；
- **排他隔离边界**：本次变更完全局限于 `StudyOS/Services/` 目录下受影响的服务文件，严禁触碰的 UI 目录（`StudyOS/UI/**`、`StudyOS/Views/**`、`StudyOS/Adapters/**`）与测试目录（`Tests/**`）均未做任何更改。

---

## 3. 验证状态说明 (Windows 宿主真实状态)

依据 `WORKFLOW.md` 规范：
- 当前运行环境：Windows 宿主
- 验证方式：人工静态代码语法审查与 Swift 6 Actor 并发隔离边界走查（Manual Static Review Pass）
- 构建命令执行状态：**NOT_RUN**（当前环境缺少 Apple Swift/iOS SDK）

---

## 4. 后续交接
1. 代码修改与交接文件已落地并已更新 `docs/logs/backend.md`；
2. 建议协调者或下游环境重跑编译验证 Swift 6 警告已彻底消除；
3. 向主协调者（parent）、项目经理（Claude1）、UI 总监（Claude2）与项目测试（Codex2）汇报。
