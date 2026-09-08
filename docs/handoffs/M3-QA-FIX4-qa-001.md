# M3-QA-FIX4 M3BackendTests 形参顺序编译修复交接文档

- 交接编号：`M3-QA-FIX4-qa-001`
- 真实系统时间：`2026-09-08T13:15:30+08:00`
- 发送角色：项目测试负责人（Codex2）
- 接收角色：主协调者（parent）、项目经理（Claude1）、项目后端（Codex1）、UI 总监（Claude2）
- 依据基线与模型规范：
  - 核心模型契约：[SourceAnchor.swift](file:///c:/Users/wang/Documents/read/StudyOS/Models/SourceAnchor.swift) (`SourceAnchor` 初始化方法签名)
  - 专有测试套件：[M3BackendTests.swift](file:///c:/Users/wang/Documents/read/StudyOSTests/M3BackendTests.swift)
  - 协作规范：[WORKFLOW.md](file:///c:/Users/wang/Documents/read/docs/collaboration/WORKFLOW.md)、[AGENTS.md](file:///c:/Users/wang/Documents/read/AGENTS.md)、[Codex2-QA.md](file:///c:/Users/wang/Documents/read/docs/roles/Codex2-QA.md)
- 独占维护范围与变更清单：
  - [M3BackendTests.swift](file:///c:/Users/wang/Documents/read/StudyOSTests/M3BackendTests.swift) (调整行 524-533 `SourceAnchor` 构造实参顺序)
  - [qa.md](file:///c:/Users/wang/Documents/read/docs/logs/qa.md) (记录系统时间戳、READ_ACK/START/HANDOFF)
  - [M3-QA-FIX4-qa-001.md](file:///c:/Users/wang/Documents/read/docs/handoffs/M3-QA-FIX4-qa-001.md) (本交接文档)

---

## 1. 修复背景与报错根因

在针对测试用例编译构建时，[M3BackendTests.swift](file:///c:/Users/wang/Documents/read/StudyOSTests/M3BackendTests.swift) 行 530 报出如下编译错误：
```
error: argument 'regions' must precede argument 'paragraphID'
```

### 根因分析
在 [SourceAnchor.swift](file:///c:/Users/wang/Documents/read/StudyOS/Models/SourceAnchor.swift) 中，`SourceAnchor` 初始化构造器的形参声明顺序为：
```swift
public init(
    documentID: String,
    documentRevision: Int,
    pageIndex0: Int,
    regions: [CodableRect] = [],
    paragraphID: String? = nil,
    quote: String? = nil,
    textRevision: Int? = nil,
    precision: AnchorPrecision = .region,
    availability: AnchorAvailability = .active
)
```
其中 `regions:` 作为第 4 个形参，严格位于 `paragraphID:`（第 5 个形参）之前。原测试代码在行 524-533 调用时将 `regions` 实参置于 `paragraphID` 与 `quote` 之后，违反了 Swift 调用时实参标签必须与函数签名形参声明顺序完全一致的规则。

---

## 2. 精准修复与代码变更

在 [M3BackendTests.swift](file:///c:/Users/wang/Documents/read/StudyOSTests/M3BackendTests.swift) 中，将行 524-533 `testCreateAndGetAINoteCardPreservingSourceAnchor()` 的 `SourceAnchor` 初始化实参顺序重排：

```swift
// 修复前：
let anchor = SourceAnchor(
    documentID: "doc_math_analysis",
    documentRevision: 2,
    pageIndex0: 15,
    paragraphID: "para_math_15_2",
    quote: "设函数 f 在区间 [a, b] 上连续且单调递增...",
    regions: [CodableRect(x: 100, y: 200, width: 350, height: 45)],
    precision: .region,
    availability: .active
)

// 修复后：
let anchor = SourceAnchor(
    documentID: "doc_math_analysis",
    documentRevision: 2,
    pageIndex0: 15,
    regions: [CodableRect(x: 100, y: 200, width: 350, height: 45)],
    paragraphID: "para_math_15_2",
    quote: "设函数 f 在区间 [a, b] 上连续且单调递增...",
    precision: .region,
    availability: .active
)
```

重排后参数完全吻合：
1. `documentID: "doc_math_analysis"`
2. `documentRevision: 2`
3. `pageIndex0: 15`
4. `regions: [CodableRect(...)]`
5. `paragraphID: "para_math_15_2"`
6. `quote: "设函数 f 在区间 [a, b] 上连续且单调递增..."`
7. `textRevision:` (缺省 nil)
8. `precision: .region`
9. `availability: .active`

---

## 3. 规范审查与并发安全

1. **纯原生与规范遵守**：严格使用原生 Swift 5.9+ / XCTest 标准库与类型，零外部第三方依赖；
2. **Swift Concurrency 严格并发安全**：保持异步方法调用与测试环境数据隔离，无数据竞争与非 Sendable 闭包逃逸；
3. **排他写入原则落实**：严格杜绝修改 `StudyOS/**` 业务源码或工程配置文件，所有变更仅收敛于测试文件 `StudyOSTests/M3BackendTests.swift`、QA 日志 `docs/logs/qa.md` 及本交接文档。

---

## 4. 运行状态与后续建议

- **当前运行环境**：Windows 本地宿主环境无 macOS/Xcode/swiftc 原生编译器，按照 QA 客观严谨守则，真实测试执行状态标识为 **NOT_RUN**，绝不虚报 PASS。
- **后续验证建议**：主协调者或 macOS CI 流水线可重新拉起 Xcode 构建与运行 `StudyOSTests/M3BackendTests.swift`，验证编译及全量 27 项用例执行情况。
