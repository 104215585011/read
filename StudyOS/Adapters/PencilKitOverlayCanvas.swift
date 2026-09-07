import SwiftUI

#if canImport(PencilKit) && canImport(UIKit)
import PencilKit
import UIKit

/// PencilKit 手写图层包装器 (按 PageKey 独立挂载与生命周期管理)
/// 严格满足 READER-ADAPTER-SPEC.md 规范与 UIREV-03 要求
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
        canvas.drawingPolicy = .anyInput // 默认支持 Apple Pencil 与手指
        canvas.delegate = context.coordinator
        
        context.coordinator.canvasView = canvas
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
    public final class Coordinator: NSObject, PKCanvasViewDelegate {
        private let adapter: ReaderAdapter
        public var pageIndex0: Int
        public weak var canvasView: PKCanvasView?
        
        private var debounceTimer: Timer?
        private var currentRevision: Int = 1
        
        public init(adapter: ReaderAdapter, pageIndex0: Int) {
            self.adapter = adapter
            self.pageIndex0 = pageIndex0
            super.init()
        }
        
        public func updateInteraction(toolMode: ReaderToolMode) {
            guard let canvas = canvasView else { return }
            switch toolMode {
            case .reading:
                canvas.isUserInteractionEnabled = true
                canvas.drawingPolicy = .pencilOnly // 纯阅读下仅允许 Pencil 书写，手指用于翻页
            case .textSelection:
                canvas.isUserInteractionEnabled = false // 文本选择模式下彻底穿透触控给 PDFView
            case .annotation:
                canvas.isUserInteractionEnabled = true
                canvas.drawingPolicy = .anyInput // 批注模式下触控与笔均激活
            }
        }
        
        public func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
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
                guard let self = self else { return }
                Task { @MainActor in
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
