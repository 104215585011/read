import SwiftUI

#if canImport(PencilKit) && canImport(UIKit)
import PencilKit
import UIKit

/// PencilKit 手写图层包装器 (按 PageKey 独立挂载与生命周期管理)
/// 严格满足 READER-ADAPTER-SPEC.md 规范、UIREV-03 与 M4-RELEASE 硬件手势交互要求
///
/// ### 真机防误触与触控隔离说明 (Palm Rejection & Touch Isolation Architecture):
/// 1. **真机防误触 (Palm Rejection)**:
///    - 利用 iPad 物理数字化仪（Digitizer）对 Apple Pencil 主动式笔尖信号的硬件隔离特性；
///    - 通过将 `drawingPolicy` 设为 `.pencilOnly`，彻底屏蔽手掌大面积接触（Palm Contact）与指腹擦碰产生的多余笔迹，保证手腕贴屏书写如同物理纸张般自然；
/// 2. **三模态触控隔离 (Touch Event Routing)**:
///    - `.reading` (纯阅读模式): `drawingPolicy = .pencilOnly`，手指导电手势穿透并交由底层 PDFView 翻页与平移，Pencil 笔尖随时可书写标注；
///    - `.textSelection` (文本选择模式): `canvas.isUserInteractionEnabled = false`，画布透明穿透所有事件，使 PDFKit 能精准捕获长按取词与拖动光标；
///    - `.annotation` (专注批注模式): 激活 PencilKit 画布与硬件手势，Apple Pencil 与触控各司其职；
/// 3. **Apple Pencil 硬件手势 (Hardware Double-Tap)**:
///    - 接入 `UIPencilInteraction` 硬件感应器，毫秒级响应笔身双击手势，依据系统偏好无缝切换笔/橡皮擦并同步 `adapter.currentToolMode`。
public struct PencilKitOverlayCanvas: UIViewRepresentable {
    @ObservedObject public var adapter: ReaderAdapter
    public let pageIndex0: Int
    
    public init(adapter: ReaderAdapter, pageIndex0: Int) {
        self.adapter = adapter
        self.pageIndex0 = pageIndex0
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(adapter: adapter, pageIndex0: pageIndex0)
    }
    
    public func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        // 遵循防误触规范：默认仅允许 Apple Pencil 书写
        canvas.drawingPolicy = .pencilOnly
        canvas.delegate = context.coordinator
        
        // 挂载 Apple Pencil 物理硬件双击交互手势
        let pencilInteraction = UIPencilInteraction()
        pencilInteraction.delegate = context.coordinator
        canvas.addInteraction(pencilInteraction)
        
        context.coordinator.canvasView = canvas
        context.coordinator.pencilInteraction = pencilInteraction
        context.coordinator.updateInteraction(toolMode: adapter.currentToolMode)
        
        return canvas
    }
    
    public func updateUIView(_ uiView: PKCanvasView, context: Context) {
        context.coordinator.pageIndex0 = pageIndex0
        context.coordinator.updateInteraction(toolMode: adapter.currentToolMode)
    }
    
    public static func dismantleUIView(_ uiView: PKCanvasView, coordinator: Coordinator) {
        coordinator.tearDown()
    }
    
    // MARK: - 协调者与防抖持久化 (Coordinator & Debounce)
    @MainActor
    public final class Coordinator: NSObject, PKCanvasViewDelegate, UIPencilInteractionDelegate {
        private let adapter: ReaderAdapter
        public var pageIndex0: Int
        public weak var canvasView: PKCanvasView?
        public weak var pencilInteraction: UIPencilInteraction?
        
        private var debounceTimer: Timer?
        private var currentRevision: Int = 1
        
        /// 记录上一次所选笔刷工具（用于硬件双击快速在笔与橡皮擦间往返平滑切换）
        private var lastActiveDrawingTool: PKTool = PKInkingTool(
            .pen,
            color: UIColor(red: 0.145, green: 0.388, blue: 0.922, alpha: 1.0),
            width: 2.0
        )
        
        public init(adapter: ReaderAdapter, pageIndex0: Int) {
            self.adapter = adapter
            self.pageIndex0 = pageIndex0
            super.init()
        }
        
        // MARK: - 触控隔离与防误触调度
        public func updateInteraction(toolMode: ReaderToolMode) {
            guard let canvas = canvasView else { return }
            switch toolMode {
            case .reading:
                // 纯阅读模式：触控穿透翻页，Pencil 硬件隔离
                canvas.isUserInteractionEnabled = true
                canvas.drawingPolicy = .pencilOnly // 防误触：手指导航，Pencil 作画
            case .textSelection:
                // 文本选择模式：彻底禁用手写画布交互，事件穿透至 PDFView
                canvas.isUserInteractionEnabled = false
            case .annotation:
                // 批注专注模式：激活触控与手写交互，保持防误触
                canvas.isUserInteractionEnabled = true
                canvas.drawingPolicy = .pencilOnly
            }
        }
        
        // MARK: - UIPencilInteractionDelegate (Apple Pencil 硬件双击手势)
        
        nonisolated public func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
            MainActor.assumeIsolated {
                self.handlePencilTap(interaction)
            }
        }
        
        @MainActor
        private func handlePencilTap(_ interaction: UIPencilInteraction) {
            guard let canvas = canvasView else { return }
            
            // 依据 iPadOS 系统偏好设置 (Settings -> Apple Pencil -> Double Tap)
            let preferredAction = UIPencilInteraction.preferredTapAction
            
            switch preferredAction {
            case .switchEraser:
                // 在当前绘图工具与橡皮擦之间平滑往返切换
                if canvas.tool is PKEraserTool {
                    canvas.tool = lastActiveDrawingTool
                    adapter.setToolMode(.annotation)
                } else {
                    lastActiveDrawingTool = canvas.tool
                    canvas.tool = PKEraserTool(.vector)
                    adapter.setToolMode(.annotation)
                }
                
            case .switchPrevious:
                // 切换至上一个使用的工具
                let current = canvas.tool
                canvas.tool = lastActiveDrawingTool
                lastActiveDrawingTool = current
                adapter.setToolMode(.annotation)
                
            case .showColorPalette:
                // 触发工具栏/模式切换并给出轻量反馈
                if adapter.currentToolMode == .annotation {
                    adapter.setToolMode(.reading)
                    adapter.onToastMessage?("Apple Pencil: 切换为纯阅读态")
                } else {
                    adapter.setToolMode(.annotation)
                    adapter.onToastMessage?("Apple Pencil: 切换为批注调色态")
                }
                
            case .ignore:
                // 用户在系统设置中关闭了硬件双击手势响应
                break
                
            @unknown default:
                // 兼容未来硬件手势扩展：默认往返切换橡皮擦与笔
                if canvas.tool is PKEraserTool {
                    canvas.tool = lastActiveDrawingTool
                } else {
                    lastActiveDrawingTool = canvas.tool
                    canvas.tool = PKEraserTool(.vector)
                }
                adapter.setToolMode(.annotation)
            }
        }
        
        // MARK: - PKCanvasViewDelegate (增量笔迹防抖持久化)
        
        nonisolated public func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            MainActor.assumeIsolated {
                self.handleDrawingChange(canvasView)
            }
        }
        
        @MainActor
        private func handleDrawingChange(_ canvasView: PKCanvasView) {
            // 1. 手写抬笔触发防抖定时器 (候选 2 秒防抖，UIREV-03)
            debounceTimer?.invalidate()
            
            let pageKey = PageKey(
                documentID: adapter.currentDocumentID,
                documentRevision: adapter.currentDocumentRevision,
                pageIndex0: pageIndex0
            )
            
            // 2. 固化不可变墨水快照
            let drawingData = canvasView.drawing.dataRepresentation()
            let snapshot = InkSaveSnapshot(
                pageKey: pageKey,
                readerSessionID: adapter.readerSessionID,
                snapshotID: UUID().uuidString,
                drawingBlob: drawingData,
                canvasToPageTransform: .identity,
                expectedRevision: currentRevision
            )
            
            // 3. 标记脏页
            adapter.markPageDirty(pageKey: pageKey, snapshot: snapshot)
            
            // 4. 启动定时器执行异步持久化
            debounceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    let result = await self.adapter.flushInk(snapshot: snapshot)
                    if case .success(let receipt) = result {
                        self.currentRevision = receipt.savedRevision
                    }
                }
            }
        }
        
        public func tearDown() {
            debounceTimer?.invalidate()
            debounceTimer = nil
            if let canvas = canvasView, let interaction = pencilInteraction {
                canvas.removeInteraction(interaction)
            }
            pencilInteraction = nil
        }
    }
}

#else

/// 跨平台降级视图（非 iOS/iPadOS 环境）
public struct PencilKitOverlayCanvas: View {
    @ObservedObject public var adapter: ReaderAdapter
    public let pageIndex0: Int
    
    public init(adapter: ReaderAdapter, pageIndex0: Int) {
        self.adapter = adapter
        self.pageIndex0 = pageIndex0
    }
    
    public var body: some View {
        Color.clear
    }
}
#endif

