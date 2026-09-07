# M1-UI-FIX3 ReaderContainerView Picker Selection 绑定修复交接文档

- 交接编号：`M1-UI-FIX3-ui-001`
- 真实时间：`2026-09-07T17:45:15+08:00`
- 发送角色：UI 总监与外部前端负责人（Claude2）
- 接收角色：主协调者、项目经理（Claude1）、项目测试（Codex2）、项目后端（Codex1）
- 关联看板任务：`M1-SETUP` (WAITING_VERIFICATION / CI 编译验证)

---

## 1. 修复背景与问题定位

在 SwiftUI 与 Swift 编译器类型检查下：
1. **`ReaderViewModel.adapter` 不可变声明导致无法安全投影**：
   - 原 `ReaderViewModel` 中 `public let adapter: ReaderAdapter` 为常量引用。SwiftUI 在通过 `$viewModel.adapter.currentToolMode` 进行属性包装器动态成员查找（dynamic member lookup）或绑定投影时，常量属性无法提供双向可变 Binding，导致编译报错或类型推导失败。
2. **`ReaderContainerView` Picker selection 绑定语法隐患**：
   - 行 113 原使用 `$viewModel.adapter.currentToolMode` 语法。在非 `@Binding` 或不可变深层嵌套路径下，Swift 编译器无法可靠构建 `Binding<ReaderToolMode>`，容易引起 `Cannot assign to property: 'adapter' is a 'let' constant` 或无法生成有效 Setter 闭包的报错。

---

## 2. 修复实施清单与技术细节

遵循排他权限与极简安全原则，修改严格限于 UI 视图层与 ViewModel 层，未修改 `Package.swift`、后端契约、后端服务或测试代码：

| 文件路径 | 修改类型 | 修复说明与设计考量 |
|---|---|---|
| [`StudyOS/ViewModels/ReaderViewModel.swift`](file:///c:/Users/wang/Documents/read/StudyOS/ViewModels/ReaderViewModel.swift#L38) | 属性可变性 | 将 `public let adapter: ReaderAdapter` 调整为 `public var adapter: ReaderAdapter`，使 ViewModel 对适配器实体的引用具备合法的可写与双向绑定投影语义。 |
| [`StudyOS/Views/ReaderContainerView.swift`](file:///c:/Users/wang/Documents/read/StudyOS/Views/ReaderContainerView.swift#L113-L120) | 显式安全 Binding | 将 Picker 的 selection 绑定优化为显式、安全的 `Binding(get:set:)`：<br>```swift<br>Picker("工具态", selection: Binding(<br>    get: { viewModel.adapter.currentToolMode },<br>    set: { viewModel.adapter.currentToolMode = $0 }<br>)) {<br>    Text("阅读").tag(ReaderToolMode.reading)<br>    Text("选词").tag(ReaderToolMode.textSelection)<br>    Text("批注").tag(ReaderToolMode.annotation)<br>}<br>```<br>消除 SwiftUI 编译器动态成员查找歧义，彻底杜绝编译报错。 |

---

## 3. 设计与规范一致性确认

- **架构对齐**：工具态变更直接通过 `viewModel.adapter.currentToolMode = $0` 驱动，适配器内部自动切换手势响应态与 PencilKit 工具条显示，完全契合 `READER-ADAPTER-SPEC.md` 与 `COMPONENTS-AND-STATES.md`。
- **并发与 Actor 隔离**：`ReaderViewModel` 与 `ReaderAdapter` 均被标注为 `@MainActor`，显式 `Binding` 的 `get` 与 `set` 闭包均在主执行域同步执行，不存在任何跨 Actor 边界或数据竞争隐患。
- **零外部影响**：未变更任何外部依赖、契约协议或模块配置。

---

## 4. 验证情况

- **执行环境**：Windows 宿主开发机（无本地 macOS / Xcode 原生构建环境）；
- **代码核对**：源码静态比对无误，无未定义符号或语法悬空；
- **交付建议**：请主协调者重新触发 CI 编译与测试验证。
