import SwiftUI

#if canImport(PDFKit)
import PDFKit
#endif

#if canImport(UIKit)
import UIKit

/// PDFKit 原生视图桥接器 (iPadOS / iOS)
/// 负责封装 PDFView、响应页码滚动和文本选区变动、挂载 PencilKit 画布
public struct PDFKitPlatformBridge: UIViewRepresentable {
    @ObservedObject public var adapter: ReaderAdapter
    public let documentURL: URL?
    
    public init(adapter: ReaderAdapter, documentURL: URL? = nil) {
        self.adapter = adapter
        self.documentURL = documentURL
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(adapter: adapter)
    }
    
    public func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true
        pdfView.backgroundColor = UIColor.systemBackground
        
        adapter.pdfView = pdfView
        context.coordinator.attach(to: pdfView)
        
        if let url = documentURL, let pdfDoc = PDFDocument(url: url) {
            pdfView.document = pdfDoc
            adapter.pageCount = pdfDoc.pageCount
            if adapter.currentPageIndex0 > 0,
               adapter.currentPageIndex0 < pdfDoc.pageCount,
               let page = pdfDoc.page(at: adapter.currentPageIndex0) {
                pdfView.go(to: page)
            }
        }
        
        return pdfView
    }
    
    public func updateUIView(_ uiView: PDFView, context: Context) {
        // 当适配器或文档更新时进行必要调整
        if uiView.document == nil, let url = documentURL, let pdfDoc = PDFDocument(url: url) {
            uiView.document = pdfDoc
            adapter.pageCount = pdfDoc.pageCount
        }
    }
    
    public static func dismantleUIView(_ uiView: PDFView, coordinator: Coordinator) {
        coordinator.detach(from: uiView)
    }
    
    // MARK: - 协调者 (Coordinator)
    public final class Coordinator: NSObject {
        private let adapter: ReaderAdapter
        private var notificationTokens: [NSObjectProtocol] = []
        
        init(adapter: ReaderAdapter) {
            self.adapter = adapter
            super.init()
        }
        
        func attach(to pdfView: PDFView) {
            let center = NotificationCenter.default
            
            // 监听页面变动
            let pageToken = center.addObserver(
                forName: .PDFViewPageChanged,
                object: pdfView,
                queue: .main
            ) { [weak self, weak pdfView] _ in
                guard let self = self, let pdfView = pdfView,
                      let doc = pdfView.document,
                      let currentPage = pdfView.currentPage else { return }
                let pageIndex0 = doc.index(for: currentPage)
                self.adapter.updateCurrentPageFromScroll(pageIndex0: pageIndex0)
            }
            notificationTokens.append(pageToken)
            
            // 监听文本选择变动
            let selToken = center.addObserver(
                forName: .PDFViewSelectionChanged,
                object: pdfView,
                queue: .main
            ) { [weak self, weak pdfView] _ in
                guard let self = self, let pdfView = pdfView else { return }
                self.handleSelectionChange(in: pdfView)
            }
            notificationTokens.append(selToken)
        }
        
        func detach(from pdfView: PDFView) {
            let center = NotificationCenter.default
            for token in notificationTokens {
                center.removeObserver(token)
            }
            notificationTokens.removeAll()
        }
        
        private func handleSelectionChange(in pdfView: PDFView) {
            guard let currentSelection = pdfView.currentSelection,
                  let page = currentSelection.pages.first,
                  let document = pdfView.document,
                  let selectedText = currentSelection.string,
                  !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                adapter.updateSelection(anchor: nil, screenRect: nil)
                return
            }
            
            let pageIndex0 = document.index(for: page)
            let pdfBounds = currentSelection.bounds(for: page)
            
            let codableRect = CodableRect(
                x: pdfBounds.origin.x,
                y: pdfBounds.origin.y,
                width: pdfBounds.size.width,
                height: pdfBounds.size.height
            )
            
            let anchor = SourceAnchor(
                documentID: adapter.currentDocumentID,
                documentRevision: adapter.currentDocumentRevision,
                pageIndex0: pageIndex0,
                regions: [codableRect],
                quote: selectedText,
                precision: .region
            )
            
            // 计算视口屏幕坐标供选区浮动菜单定位
            let screenRect = pdfView.convert(pdfBounds, from: page)
            adapter.updateSelection(anchor: anchor, screenRect: screenRect)
        }
    }
}

#elseif canImport(AppKit)
import AppKit

/// macOS 备用桥接实现
public struct PDFKitPlatformBridge: NSViewRepresentable {
    @ObservedObject public var adapter: ReaderAdapter
    public let documentURL: URL?
    
    public init(adapter: ReaderAdapter, documentURL: URL? = nil) {
        self.adapter = adapter
        self.documentURL = documentURL
    }
    
    public func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        adapter.pdfView = pdfView
        if let url = documentURL, let doc = PDFDocument(url: url) {
            pdfView.document = doc
            adapter.pageCount = doc.pageCount
        }
        return pdfView
    }
    
    public func updateNSView(_ nsView: PDFView, context: Context) {}
}
#else

/// 跨平台降级视图（非 Apple GUI 环境）
public struct PDFKitPlatformBridge: View {
    @ObservedObject public var adapter: ReaderAdapter
    public let documentURL: URL?
    
    public init(adapter: ReaderAdapter, documentURL: URL? = nil) {
        self.adapter = adapter
        self.documentURL = documentURL
    }
    
    public var body: some View {
        Color.clear
    }
}
#endif

