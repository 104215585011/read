# StudyOS ReaderAdapter 技术桥接与坐标规范

- 规范版本：`v0.3-aligned-be-rev2`
- 对应阶段：`M0-UI`（依据 `docs/project/UI-V03-HANDOFF.md` 与 `0.1-draft / M0-BE-REV2` 契约修订）
- 责任角色：UI 总监与外部前端负责人（Claude2）
- 契约依据：`docs/backend/CONTRACT-v0.1-draft.md` (修订标识：`0.1-draft / M0-BE-REV2`)
- 目标平台：iPadOS 17.0+（技术候选，最低系统版本以工程验证和 PM 冻结为准）
- 涉及技术栈：SwiftUI / UIKit (`PDFView`, `PDFPage`) / PencilKit (`PKCanvasView`, `PKDrawing`, `PKToolPicker`)
- 关联验收用例：`docs/qa/ACCEPTANCE-MATRIX.md` (R02, R03, R04, R09, R17) 与 `docs/qa/UI-INTEGRATION-CASES.md` (UI-T01–UI-T07)

---

## 1. 概述与核心使命

`ReaderAdapter` 是 StudyOS 客户端架构中最核心的技术桥梁。它将 SwiftUI 响应式声明式状态，与底层命令式渲染框架（Apple `PDFKit` 和 `PencilKit`）及核心数据服务层（Core Service）做可靠解耦与严格同步。

核心职责：
1. **页码基准桥接 (UIREV-04, UI-T03)**：内部核心层统一使用 `0-based`（`pageIndex0`），UI 呈现渲染为物理页码 `pageIndex0 + 1`；所有对外接口严格校验非负与有效边界（`0 <= pageIndex0 < pageCount`），彻底杜绝 `-1` 或越界引发的崩溃；
2. **多层坐标系与 API 边界分离 (UIREV-04, UI-T04)**：明确区分 PDF 页面空间（用于数据持久化与 PDFView 页面级导航）与视口屏幕空间（仅用于 UIKit 浮动菜单与动画图层）；
3. **复杂几何变换支持**：严格应对 PDF 裁切框（非零 `cropBox.origin`）、页面内置旋转（0°、90°、180°、270°）及动态多级缩放；
4. **PencilKit 异步增量持久化生命周期 (UIREV-03, UI-T05)**：定义基于 `PageKey`、`readerSessionID` 与排队前不可变 `InkSaveSnapshot` 的保存机制；通过 `InkSaveReceipt` 推进 `persistedRevision`，杜绝跨会话/跨页脏写，明确 dirty 标记仅用于未保存指示而不作为笔划恢复数据；
5. **主执行域会话校验与安全导航 (UIREV-01, UIREV-04, UI-T04, UI-T07)**：必须调用 `resolveSource`；`await` 返回后必须在主执行域校验当前会话仍打开、当前文档与版本匹配、目标有效后在同一执行段导航；失配返回 `ignoredStaleSession`，绝不盲跳乱闪；全文重点跳转复用同一入口。

---

## 2. 坐标系统与转换契约 (Coordinate System Specification)

### 2.1 规范空间定义

在 StudyOS 中存在三套关键坐标空间，各空间拥有严格的职责边界：

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ 1. PDF 页面空间 (PDF Page Space)                                             │
│    - 单位：PDF Points (72 points = 1 inch)                                  │
│    - 原点与边界：由 page.bounds(for: .cropBox) 决定                          │
│    - 特点：原点 (x, y) 可能非零；Y 轴朝上（传统 PostScript/PDF 规范）         │
│    - 职责：数据持久化、SourceAnchor.regions、Annotation 存储、以及            │
│            Apple 原生导航 API pdfView.go(to: rect, on: page) 的入参          │
├─────────────────────────────────────────────────────────────────────────────┤
│ 2. 视图屏幕空间 (View Screen Space)                                          │
│    - 单位：UIKit Points                                                      │
│    - 原点：PDFView 视口左上角 (0, 0)，Y 轴朝下                               │
│    - 特点：受当前 contentOffset 与 scaleFactor 动态影响                      │
│    - 职责：仅用于 SelectionCalloutMenu 定位、SourceAnchorFocusRing 动画覆盖层 │
├─────────────────────────────────────────────────────────────────────────────┤
│ 3. PencilKit 画布空间 (Drawing Canvas Space)                                │
│    - 单位：UIKit Points (基于 PKDrawing 矢量内部矩阵)                        │
│    - 原点：挂载于对应单页容器的 PKCanvasView.bounds (0, 0)                   │
│    - 职责：矢量笔迹捕获、局部笔划重放与二进制序列化                          │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 官方 API 转换规则（严禁简单 Y 翻转推算）

根据 Apple 官方规范与后端契约，**严禁使用 `screenY = pageHeight - pdfY` 粗暴推算**，因为不同 PDF 页面往往具备非零裁切原点（`cropBox.origin != (0,0)`）及内置旋转角度（0°、90°、180°、270°）。

必须严格调用 Apple 原生几何变换接口：

```swift
// 1. PDF Page 坐标 -> 视图屏幕坐标 (仅用于 UI 覆盖层/动画框定位)
func convertToScreen(pdfRect: CGRect, from page: PDFPage) -> CGRect {
    return pdfView.convert(pdfRect, from: page)
}

// 2. 视图屏幕坐标 -> PDF Page 坐标 (供选区/手势几何转为持久化模型)
func convertToPdfPage(viewRect: CGRect, to page: PDFPage) -> CGRect {
    return pdfView.convert(viewRect, to: page)
}

// 3. 复杂旋转与裁切变换：
// 依据 page.transform(for: .cropBox) 与 page.rotation 建立仿射矩阵
```

---

## 3. PencilKit 手写图层与异步增量持久化 (UIREV-03, UI-T05)

### 3.1 覆盖层单页独立挂载与复用隔离

1. **单页独立绑定 (Per-Page PKCanvasView)**：每个可视 `PDFPage` 视图容器内独立挂载透明背景的 `PKCanvasView`；
2. **PageKey 严格标识**：`PageKey` 由 `documentID`、源文档 `documentRevision` 与物理页号 `pageIndex0` 唯一确定；
3. **复用隔离防护 (Canvas Reuse Isolation)**：在快速滑动、滚动列表重用或跨文档切换时，若某个 `PKCanvasView` 即将被解绑或回收：
   - 必须在排队前完整生成不可变的 `InkSaveSnapshot`，绑定该页当前的 `PageKey`、`readerSessionID`、`snapshotID`、`drawingBlob`、`canvasToPageTransform` 与 `expectedRevision`；
   - 严禁将解绑后的未保存快照写入随后被复用的新页面，彻底阻断跨页与跨文档脏写。

### 3.2 异步增量持久化状态机与 Receipt 机制 (Async Persistence Lifecycle)

删除任何“换页同步阻塞”或“系统挂起前必完成”的不实承诺，全面对齐 `0.1-draft / M0-BE-REV2` 契约：

- **数据结构约定**：
  ```swift
  struct PageKey: Hashable {
      let documentID: String
      let documentRevision: Int
      let pageIndex0: Int
  }

  struct InkSaveSnapshot {
      let pageKey: PageKey
      let readerSessionID: String
      let snapshotID: String
      let drawingBlob: Data
      let canvasToPageTransform: CGAffineTransform
      let expectedRevision: Int  // 该页手写 persistedRevision
  }

  struct InkSaveReceipt {
      let pageKey: PageKey
      let snapshotID: String
      let savedRevision: Int     // 服务端确认持久化后的新手写版本
      let readerSessionID: String
  }
  ```

- **笔迹生命周期状态**：
  - `clean`：内存笔迹与本地已持久化版本一致；
  - `dirty`：有新笔划产生，存在未提交快照；
  - `saving`：正在异步执行快照提交与磁盘写入；
  - `saved`：收到 `InkSaveReceipt` 确认，版本更新为 `savedRevision`；
  - `failed`：写盘失败（如存储满或 I/O 错误），保留内存快照并标红告警；
  - `conflict`：版本冲突（`expectedRevision` 不符），触发服务重载与冲突提示。

- **刷盘时机、防抖与会话隔离策略**：

| 触发场景 | 操作行为 | 容错与防乱序机制 |
|---|---|---|
| **手写抬笔 (Stroke Finished)** | 标记当前页 `dirty`，启动候选 2 秒防抖定时器（`debounceTimer`，为工程调优候选参数） | 若 2 秒内有新笔划产生，重置定时器；静默期结束后在排队前固化 `InkSaveSnapshot` 并发起异步持久化 |
| **翻页 / 页面滑出可视区** | 立即固化快照并提交 `flushInk(snapshot)` | 非阻塞翻页，不卡顿 UI；写盘任务入队后台串行队列执行 |
| **同页连续快速笔划** | 同一 `PageKey` 串行提交 | 仅合并**尚未开始排队**的旧快照；一旦已提交快照返回 `InkSaveReceipt`，必须推进对应页面的 `persistedRevision`，绝不能丢弃已确认版本导致后续 `expectedRevision` 冲突 |
| **收到 InkSaveReceipt** | 校验 `snapshotID` 与 `PageKey` | **仅清除该快照对应笔画的 dirty 状态**；若在提交期间产生了较新笔画，页面保持 `dirty`，并使用新确认的 `savedRevision` 作为下一次提交的 `expectedRevision` |
| **切换文档 / 关闭阅读器** | `readerSessionID` 发生变更 | 旧会话的迟到保存结果**仅更新底层服务账本，绝不反写或污染新会话的画布与保存状态**；文档已删则拒绝提交 |
| **应用切入后台 (sceneDidEnterBackground)** | 遍历所有 `dirty` 页面固化快照，调用系统 `beginBackgroundTask` 申请后台写入时间 | **容灾承诺**：若后台时间耗尽提前终止，系统保持上一版有效 `savedRevision`，并在本地记录 `dirty` 标志供下次冷启恢复。**明确声明：dirty 标记仅用于未保存修改指示，绝不宣称 dirty 标记本身能恢复未写盘墨水** |

---

## 4. 来源定位 (Source Navigation) 与视觉呈现 (UIREV-01, UIREV-04, UI-T04, UI-T07)

### 4.1 导航执行契约与主执行域会话核对

当用户在 AI 助学、自由问答或全文学习视图重点项中点击来源引用时，必须调用核心层 `resolveSource`，并在 `await` 返回后在主执行域进行严格的跨会话核对：

```swift
@MainActor
func navigateTo(sourceAnchor: SourceAnchor) async -> NavigationResult {
    guard let document = pdfView.document else { return .unavailable }
    
    // 1. 发起前捕获当前会话快照
    let capturedSessionID = self.readerSessionID
    let capturedDocID = self.currentDocumentID
    let capturedDocRevision = self.currentDocumentRevision
    
    // 2. 调用核心服务解析来源
    let resolution = await coreService.resolveSource(sourceAnchor)
    
    // 3. await 返回后，在主执行域进行严格会话与文档核对 (UIREV-04)
    guard self.readerSessionID == capturedSessionID else {
        // 会话已关闭或切换至其他文档
        return .ignoredStaleSession
    }
    
    switch resolution {
    case .navigationTarget(let target):
        // 核对目标文档与版本是否与当前一致
        guard target.documentID == capturedDocID,
              target.documentRevision == capturedDocRevision else {
            return .ignoredStaleSession
        }
        
        // 校验目标非负页码与有效边界
        guard target.pageIndex0 >= 0,
              target.pageIndex0 < document.pageCount,
              let page = document.page(at: target.pageIndex0) else {
            displayToast("目标页面越界或已被移除")
            return .invalidPageIndex
        }
        
        if target.precision == .page || target.regions.isEmpty {
            // 页级引用有效降级
            pdfView.go(to: page)
            displayToast("已导航至第 \(target.pageIndex0 + 1) 页 (页级来源)")
            return .success
        }
        
        // 区域级精准定位
        // 重点：Apple 原生 API pdfView.go(to:on:) 入参必须为 PDF Page 空间坐标！
        let targetPdfRect = target.regions[0]
        pdfView.go(to: targetPdfRect, on: page)
        
        // 触发覆盖层视觉高亮：转换为屏幕坐标后供 SourceAnchorFocusRing 绘制
        let screenRect = pdfView.convert(targetPdfRect, from: page)
        triggerFocusRingAnimation(screenRect: screenRect)
        return .success
        
    case .staleReference:
        // UIREV-01: 来源对应旧版本，绝对禁止跳转至旧页码！
        displayToast("引用基于旧版本文档（版本不一致），无法定位至当前内容")
        return .staleReference
        
    case .unavailable:
        // 目标失效或原文档已删除
        displayToast("引用目标已失效或原文档已被删除")
        return .unavailable
    }
}
```

### 4.2 动画聚焦规范与 Reduce Motion 适配
- **覆盖层**：在 `PDFView` 视口之上挂载 `SourceAnchorFocusRing`（`isUserInteractionEnabled = false`）；
- **常规动效**：高亮边框淡入（透明度 0.0 -> 0.8），执行 2 次微幅呼吸脉冲缩放（周期 0.6s，共 1.2s），随后衰减保留静态细实线框；
- **Reduce Motion 适配**：若系统无障碍设置开启了“减弱动态效果”，直接以静态半透明边框常驻 1.5 秒后平滑淡出，不产生任何脉冲缩放。

---

## 5. 跨模块接口与通信协议 (ReaderAdapterProtocol)

```swift
/// 笔迹保存错误类型 (UIREV-03, 契约对齐)
enum SaveInkError: Error {
    case conflict(currentRevision: Int)
    case storageFull
    case saveFailed(String)
    case staleReference
    case unavailable
    case timeout
    case cancelled
}

/// 工具态枚举 (UIREV-04)
enum ReaderToolMode {
    case reading          // 纯阅读模式 (手指滚动/翻页，Pencil 触碰默认书写)
    case textSelection    // 文本选择模式 (手指/Pencil 精准选词选句，抑制墨水)
    case annotation       // 显式批注模式 (PKToolPicker 处于激活态)
}

/// 导航执行结果 (UIREV-01, UIREV-04)
enum NavigationResult {
    case success
    case staleReference
    case unavailable
    case invalidPageIndex
    case ignoredStaleSession
}

/// ReaderAdapter 核心通信协议
protocol ReaderAdapterProtocol: AnyObject {
    // 状态与属性
    var readerSessionID: String { get }
    var currentDocumentID: String { get }
    var currentDocumentRevision: Int { get }
    var currentPageIndex0: Int { get }
    var currentSelectionAnchor: SourceAnchor? { get }
    var currentToolMode: ReaderToolMode { get set }
    
    // 页面安全跳转与来源导航 (UIREV-01, UIREV-04，全文重点项复用)
    func goToPage(index0: Int) -> Bool
    func navigateTo(source: SourceAnchor) async -> NavigationResult
    func zoom(to scale: CGFloat)
    
    // 工具态与 PencilKit 管理 (UIREV-04)
    func setToolMode(_ mode: ReaderToolMode)
    func setPencilTool(_ tool: PKTool)
    
    // 异步增量笔迹持久化 (UIREV-03, PageKey与Receipt对齐)
    func flushInk(snapshot: InkSaveSnapshot) async -> Result<InkSaveReceipt, SaveInkError>
    func flushAllDirtyInks() async -> [PageKey: Result<InkSaveReceipt, SaveInkError>]
    func clearCurrentSelection()
    
    // 搜索与目录
    func search(keyword: String, completion: @escaping ([SearchResultItem]) -> Void)
    func getOutlineTree() -> [OutlineNode]
}
```
