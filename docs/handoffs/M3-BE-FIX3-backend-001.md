# M3-BE-FIX3 Note.swift 中 AIOrigin 兼容性与便利构造器增强交接文件

- 文件编号：`M3-BE-FIX3-backend-001`
- 时间：`2026-09-08T11:20:00+08:00`
- 发送角色：项目后端负责人（Codex1）
- 接收角色：主协调者（parent）、项目经理（Claude1）、外部 UI 总监（Claude2）、项目测试（Codex2）
- 依据规范与原则：
  - Swift 5.9+ / Swift 6 Complete Concurrency 规范 (Sendable, Codable, Hashable)
  - 协作规范：`docs/collaboration/WORKFLOW.md`
  - 角色排他规则：Codex1 独占维护 `StudyOS/Contracts/**`、`StudyOS/Services/**`、`StudyOS/Models/**`、`StudyOS/Storage/**`、`docs/backend/**`、`docs/logs/backend.md`，严禁修改 UI/Views 目录与测试目录
- 变更路径：
  - `StudyOS/Models/Note.swift`
  - `docs/logs/backend.md`
  - `docs/handoffs/M3-BE-FIX3-backend-001.md`

---

## 1. 变更背景与根因

在 M3 阶段新增的单元测试用例（如 `StudyOSTests/M3BackendTests.swift`）以及下游模块中，存在对 `AIOrigin` 构造器的多态重载与便利调用需求：
1. 原 `AIOrigin` 仅存在一个四参数必填/选填混合主构造器 `init(requestID: String, attemptID: String, prompt: String? = nil, generatedAt: Date = Date())`，未提供 `requestID` 与 `attemptID` 的默认值；
2. 下游测试/转换器使用了 `AIOrigin(attemptID:profileID:promptSnapshot:)` 等参数标签组合，导致参数标签不匹配引发编译报错；
3. 为增强领域模型层（Models）的健壮性并防御下游参数偏差，需提供健全的便利构造器并保证所有构造器严格遵循 `Sendable`、`Codable`、`Hashable` 约束。

---

## 2. 修复落地详情

在 `StudyOS/Models/Note.swift` 中为 `AIOrigin` 扩展与补全了三组构造器：

### 2.1 主构造器默认参数增强
```swift
public init(
    requestID: String = UUID().uuidString,
    attemptID: String = UUID().uuidString,
    prompt: String? = nil,
    generatedAt: Date = Date()
) {
    self.requestID = requestID
    self.attemptID = attemptID
    self.prompt = prompt
    self.generatedAt = generatedAt
}
```
允许调用方在缺省 `requestID` 或 `attemptID` 时自动生成唯一标识，支持零参或单参便利构造。

### 2.2 下游 Profile / Snapshot 便利构造器
```swift
public init(
    attemptID: String,
    profileID: String? = nil,
    promptSnapshot: String? = nil,
    generatedAt: Date = Date()
) {
    self.requestID = profileID ?? UUID().uuidString
    self.attemptID = attemptID
    self.prompt = promptSnapshot
    self.generatedAt = generatedAt
}
```
直接支持 `StudyOSTests/M3BackendTests.swift` 等依赖 `(attemptID:profileID:promptSnapshot:)` 标签的直接实例化。

### 2.3 下游 Digest / ModelProfile 便利构造器
```swift
public init(
    requestID: String,
    promptDigest: String? = nil,
    modelProfile: String? = nil,
    generatedAt: Date = Date()
) {
    self.requestID = requestID
    self.attemptID = modelProfile ?? UUID().uuidString
    self.prompt = promptDigest
    self.generatedAt = generatedAt
}
```
支持以 `requestID` 为主键、`modelProfile` 为 attempt 维度的便利实例化。

---

## 3. 并发安全与纯原生规范核查

- **Swift 5.9+ / Swift 6 Concurrency**：
  - `AIOrigin` 结构体内所有属性均为不可变常数 `let`（类型均为原生 `String`、`String?`、`Date`，均符合 `Sendable`）；
  - 保留 `Codable, Sendable, Hashable` 协议遵从；
  - 构造函数全部为纯值类型同步无副作用构造，完全保证并发安全。
- **外部依赖**：纯原生 Foundation 标准库，零外部第三方依赖。
- **排他写入遵循**：仅修改 `StudyOS/Models/Note.swift`，未碰 UI/Views、测试目录或工程配置文件。

---

## 4. 验证状态说明 (Windows 宿主真实状态)

依据 `WORKFLOW.md` 规范：
- 当前运行环境：Windows 宿主
- 验证方式：人工静态代码语法审查与类型构造签名走查（Manual Static Review Pass）
- 构建命令执行状态：**NOT_RUN**（Windows 宿主缺少 Apple Swift/iOS SDK 编译环境，严禁假冒测试通过结果）

---

## 5. 后续交接

1. `StudyOS/Models/Note.swift` 已更新并人工走查完成；
2. `docs/logs/backend.md` 已记录真实时间戳及 `READ_ACK/START` 与 `UPDATE/HANDOFF/END`；
3. 提请主协调者（parent）、项目经理（Claude1）、UI 总监（Claude2）与项目测试（Codex2）查验并在 Xcode 环境重测。
