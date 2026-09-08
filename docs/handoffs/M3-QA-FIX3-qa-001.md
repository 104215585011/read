# M3-QA-FIX3 M3BackendTests 编译错误修复交接文档

- 交接编号：`M3-QA-FIX3-qa-001`
- 真实系统时间：`2026-09-08T11:29:00+08:00`
- 发送角色：项目测试负责人（Codex2）
- 接收角色：主协调者（parent）、项目经理（Claude1）、项目后端（Codex1）、UI 总监（Claude2）
- 依据基线与模型规范：
  - 核心模型契约：`StudyOS/Models/SourceAnchor.swift` (`SourceAnchor`, `AnchorPrecision`, `AnchorAvailability`)
  - 专有测试套件：`StudyOSTests/M3BackendTests.swift`
  - 协作规范：`docs/collaboration/WORKFLOW.md`、`AGENTS.md`、`docs/roles/Codex2-QA.md`
- 独占维护范围与变更清单：
  - `StudyOSTests/M3BackendTests.swift` (修复 4 处编译错误)
  - `docs/logs/qa.md` (更新：记录真实系统时间戳与 READ_ACK/START/HANDOFF 日志)
  - `docs/handoffs/M3-QA-FIX3-qa-001.md` (本交接文档)

---

## 1. 修复背景与错误根因分析

在 `StudyOSTests/M3BackendTests.swift` 中存在 4 处编译报错隐患：
1. **错误 1（async in autoclosure）**：`XCTAssertTrue` / `XCTAssertFalse` 的表达式形参为 `@autoclosure () throws -> Bool`，属于同步闭包上下文，直接传入 `await provider.isReady()` 会触发编译器报错 `'async' call in an autoclosure that does not support concurrency`；
2. **错误 2（SourceAnchor 属性与契约参数命名/类型不符）**：`SourceAnchor` 结构体定义的矩形区域属性为 `public var regions: [CodableRect]`（而非 `rects`），精度枚举为 `AnchorPrecision`（成员为 `.page` 与 `.region`，无 `.exact`）；
3. **错误 3（SourceAnchor 缺少必填参数与非法枚举）**：`SourceAnchor` 初始化器必填参数包括 `documentRevision: Int`，测试中漏传导致签名不匹配；且 `precision` 传入了不存在的 `.exact`；
4. **错误 4（SourceAnchor 缺少必填参数）**：测试双向互转用例中的 `SourceAnchor` 同样漏传必填参数 `documentRevision: 1`。

---

## 2. 精准修复清单与代码变更

### 2.1 修复 1：XCTest autoclosure 内 await 展开（行 451, 465, 487）

在断言前将异步调用提升至当前 `async` 测试函数作用域内并赋值给局部变量，再传入同步断言：

```swift
// testLocalLLMProviderAutoReloadWhenStreamingWhileUnloaded
await provider.unloadModel()
let isReadyBefore = await provider.isReady()
XCTAssertFalse(isReadyBefore)

...
let isReadyAfter = await provider.isReady()
XCTAssertTrue(isReadyAfter, "流式推理发起后应自动将模型拉回 ready 状态")

// testLocalLLMProviderStreamEarlyCancellation
let isReadyEnd = await provider.isReady()
XCTAssertTrue(isReadyEnd)
```

### 2.2 修复 2：SourceAnchor 属性与契约参数（行 527, 528, 574, 576, 577）

- 将构造形参 `rects:` 修改为 `regions:`；
- 将精度参数 `precision: .exact` 修改为 `precision: .region`；
- 将断言 `XCTAssertEqual(fetchedAnchor.precision, .exact)` 修改为 `XCTAssertEqual(fetchedAnchor.precision, .region)`；
- 将断言中 `fetchedAnchor.rects` 修改为 `fetchedAnchor.regions`。

```swift
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

...
XCTAssertEqual(fetchedAnchor.precision, .region)
XCTAssertEqual(fetchedAnchor.availability, .active)
XCTAssertEqual(fetchedAnchor.regions.count, 1)
XCTAssertEqual(fetchedAnchor.regions[0], CodableRect(x: 100, y: 200, width: 350, height: 45))
```

### 2.3 修复 3：SourceAnchor 补充必填参数与合法枚举（行 674-681）

补充必填参数 `documentRevision: 1`，将 `precision: .exact` 修正为 `.region`：

```swift
let anchor = SourceAnchor(
    documentID: docID,
    documentRevision: 1,
    pageIndex0: 3,
    quote: "重要推论内容",
    precision: .region,
    availability: .active
)
```

### 2.4 修复 4：SourceAnchor 补充必填参数（行 749）

补充必填参数 `documentRevision: 1`：

```swift
sourceAnchors: [SourceAnchor(documentID: "doc_conv_01", documentRevision: 1, pageIndex0: 2)],
```

---

## 3. 架构一致性与并发安全审查

1. **纯原生与规范遵守**：严格使用原生 Swift 5.9+ / XCTest 宏与类型，无第三方依赖；
2. **Swift Concurrency 严格安全**：消除同步 autoclosure 内跨异步边界调用隐患，所有局部变量于 `async` 测试上下文内线性声明，无数据竞争与非 Sendable 闭包逃逸；
3. **排他写入与业务代码保护**：严禁并切实杜绝修改 `StudyOS/**` 业务源码或工程配置文件，所有修复严格收敛于测试文件 `StudyOSTests/M3BackendTests.swift`、QA 日志 `docs/logs/qa.md` 与本交接文件。

---

## 4. 运行状态与后续建议

- **当前运行环境**：Windows 本地环境无 macOS/Xcode/swiftc 原生编译器，根据 QA 客观严谨守则，真实测试执行状态标识为 **NOT_RUN**，绝不虚报 PASS。
- **后续流水线建议**：主协调者或 CI 可触发 macOS-14 / Xcode 15.4 / iPadOS 模拟器流水线，全量构建并运行 `StudyOSTests/M3BackendTests.swift` 进行双重验证。
