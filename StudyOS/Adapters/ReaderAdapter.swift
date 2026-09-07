import Foundation
import Combine

#if canImport(CoreGraphics)
import CoreGraphics
#endif

#if canImport(PDFKit)
import PDFKit
#endif

#if canImport(PencilKit)
import PencilKit
#endif

/// ReaderAdapter 核心通信与生命周期实现
/// 严格遵守 ReaderAdapterProtocol (UIREV-01, UIREV-03, UIREV-04)
/// 隔离 SwiftUI 声明式状态与底层的 PDFKit / PencilKit 命令式渲染
@MainActor
public final class ReaderAdapter: ReaderAdapterProtocol, ObservableObject {
    // MARK: - 状态与属性 (ReaderAdapterProtocol)
    public let readerSessionID: String
    public let currentDocumentID: String
    public let currentDocumentRevision: Int
    
    @Published public private(set) var currentPageIndex0: Int = 0
    @Published public private(set) var currentSelectionAnchor: SourceAnchor?
    @Published public var currentToolMode: ReaderToolMode = .reading
    
    // MARK: - 依赖服务与内部状态
    private let coreService: CoreServiceProtocol
    public var pageCount: Int = 0
    
    /// 按 PageKey 维护的最新已落盘持久化版本号
    private var persistedRevisions: [PageKey: Int] = [:]
    /// 内存中待排队提交的笔迹快照 (排队前固化)
    private var pendingSnapshots: [PageKey: InkSaveSnapshot] = [:]
    /// 标记未持久化脏页集合 (仅用于未保存指示，不作为笔画恢复凭证)
    private var dirtyPages: Set<PageKey> = []
    
    #if canImport(PDFKit)
    public weak var pdfView: PDFView?
    #endif
    
    // MARK: - UI 事件回调
    public var onPageChanged: ((Int) -> Void)?
    public var onSelectionChanged: ((SourceAnchor?, CGRect?) -> Void)?
    public var onFocusHighlight: ((CGRect) -> Void)?
    public var onToastMessage: ((String) -> Void)?
    
    // MARK: - 初始化
    public init(
        readerSessionID: String = UUID().uuidString,
        documentID: String,
        documentRevision: Int = 1,
        initialPageIndex0: Int = 0,
        pageCount: Int = 0,
        coreService: CoreServiceProtocol
    ) {
        self.readerSessionID = readerSessionID
        self.currentDocumentID = documentID
        self.currentDocumentRevision = documentRevision
        self.currentPageIndex0 = max(0, initialPageIndex0)
        self.pageCount = max(0, pageCount)
        self.coreService = coreService
    }
    
    // MARK: - 页面导航与核对 (UIREV-01, UIREV-04)
    
    /// 安全跳转至指定 0-based 物理页
    public func goToPage(index0: Int) -> Bool {
        guard index0 >= 0, index0 < pageCount || pageCount == 0 else {
            onToastMessage?("目标页面索引无效 (越界或不可用)")
            return false
        }
        
        self.currentPageIndex0 = index0
        onPageChanged?(index0)
        
        #if canImport(PDFKit)
        if let pdfView = pdfView, let document = pdfView.document,
           index0 < document.pageCount,
           let page = document.page(at: index0) {
            pdfView.go(to: page)
        }
        #endif
        return true
    }
    
    /// 来源精准定位与跨会话主执行域核对 (UIREV-01, UIREV-04, UI-T04, UI-T07)
    public func navigateTo(source: SourceAnchor) async -> NavigationResult {
        // 1. 发起前捕获当前执行域会话快照
        let capturedSessionID = self.readerSessionID
        let capturedDocID = self.currentDocumentID
        let capturedDocRevision = self.currentDocumentRevision
        
        // 2. 调用核心服务解析来源
        let resolution = await coreService.resolveSource(source)
        
        // 3. await 返回后必须在主执行域进行严格会话核对 (UIREV-04)
        guard self.readerSessionID == capturedSessionID else {
            // 会话已切换或关闭，绝不乱跳
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
            guard target.pageIndex0 >= 0 else {
                onToastMessage?("目标页面索引非法")
                return .invalidPageIndex
            }
            
            #if canImport(PDFKit)
            guard let pdfView = self.pdfView,
                  let document = pdfView.document,
                  target.pageIndex0 < document.pageCount,
                  let page = document.page(at: target.pageIndex0) else {
                onToastMessage?("目标页面越界或不可用")
                return .invalidPageIndex
            }
            
            self.currentPageIndex0 = target.pageIndex0
            self.onPageChanged?(target.pageIndex0)
            
            if target.precision == .page || target.regions.isEmpty {
                // 页级引用降级定位
                pdfView.go(to: page)
                onToastMessage?("已导航至第 \(target.pageIndex0 + 1) 页 (页级来源)")
                return .success
            }
            
            // 区域级精准定位 (Apple 原生 API pdfView.go 入参必须为 PDF 空间坐标)
            let firstRegion = target.regions[0]
            let targetPdfRect = CGRect(
                x: firstRegion.x,
                y: firstRegion.y,
                width: firstRegion.width,
                height: firstRegion.height
            )
            pdfView.go(to: targetPdfRect, on: page)
            
            // 转换为屏幕坐标后供 SourceAnchorFocusRing 动画绘制
            let screenRect = pdfView.convert(targetPdfRect, from: page)
            onFocusHighlight?(screenRect)
            return .success
            #else
            self.currentPageIndex0 = target.pageIndex0
            self.onPageChanged?(target.pageIndex0)
            return .success
            #endif
            
        case .staleReference:
            // UIREV-01: 来源基于旧版本，禁止跳转旧页码
            onToastMessage?("引用基于旧版本文档（版本不一致），无法定位至当前内容")
            return .staleReference
            
        case .unavailable:
            // 引用目标失效或原文档已删除
            onToastMessage?("引用目标已失效或原文档已被删除")
            return .unavailable
        }
    }
    
    #if canImport(CoreGraphics)
    public func zoom(to scale: CGFloat) {
        #if canImport(PDFKit)
        pdfView?.scaleFactor = max(0.5, min(5.0, scale))
        #endif
    }
    #endif
    
    // MARK: - 工具态与 PencilKit 管理 (UIREV-04)
    public func setToolMode(_ mode: ReaderToolMode) {
        self.currentToolMode = mode
    }
    
    #if canImport(PencilKit)
    public func setPencilTool(_ tool: PKTool) {
        // 交由挂载的 PKCanvasView 或 PKToolPicker 处理
    }
    #endif
    
    // MARK: - 异步增量手写持久化 (UIREV-03, UI-T05)
    
    /// 提交排队前固化的不可变墨水快照
    public func flushInk(snapshot: InkSaveSnapshot) async -> Result<InkSaveReceipt, SaveInkError> {
        // 会话一致性检查
        guard snapshot.readerSessionID == self.readerSessionID else {
            return .failure(.staleReference)
        }
        
        let result = await coreService.flushInk(snapshot: snapshot)
        
        switch result {
        case .success(let receipt):
            // 仅在会话仍有效时更新持久化版本
            if receipt.readerSessionID == self.readerSessionID {
                self.persistedRevisions[receipt.pageKey] = receipt.savedRevision
                self.dirtyPages.remove(receipt.pageKey)
                self.pendingSnapshots.removeValue(forKey: receipt.pageKey)
            }
            return .success(receipt)
            
        case .failure(let error):
            if case .conflict(let serverRev) = error {
                self.persistedRevisions[snapshot.pageKey] = serverRev
            }
            return .failure(error)
        }
    }
    
    /// 刷盘所有脏页笔画
    public func flushAllDirtyInks() async -> [PageKey: Result<InkSaveReceipt, SaveInkError>] {
        var results: [PageKey: Result<InkSaveReceipt, SaveInkError>] = [:]
        for (pageKey, snapshot) in pendingSnapshots {
            let res = await flushInk(snapshot: snapshot)
            results[pageKey] = res
        }
        return results
    }
    
    public func clearCurrentSelection() {
        self.currentSelectionAnchor = nil
        onSelectionChanged?(nil, nil)
        #if canImport(PDFKit)
        pdfView?.clearSelection()
        #endif
    }
    
    // MARK: - 搜索与大纲 (Search & Outline)
    public func search(keyword: String, completion: @escaping @Sendable ([SearchResultItem]) -> Void) {
        guard !keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            completion([])
            return
        }
        
        #if canImport(PDFKit)
        guard let document = pdfView?.document else {
            completion([])
            return
        }
        
        let selections = document.findString(keyword, withOptions: .caseInsensitive)
        var items: [SearchResultItem] = []
        
        for sel in selections {
            guard let page = sel.pages.first else { continue }
            let pageIndex = document.index(for: page)
            let excerpt = sel.string ?? keyword
            let bounds = sel.bounds(for: page)
            let codableRect = CodableRect(
                x: bounds.origin.x,
                y: bounds.origin.y,
                width: bounds.size.width,
                height: bounds.size.height
            )
            let anchor = SourceAnchor(
                documentID: self.currentDocumentID,
                documentRevision: self.currentDocumentRevision,
                pageIndex0: pageIndex,
                regions: [codableRect],
                quote: excerpt,
                precision: .region
            )
            items.append(SearchResultItem(anchor: anchor, excerpt: excerpt))
        }
        completion(items)
        #else
        completion([])
        #endif
    }
    
    public func getOutlineTree() -> [OutlineNode] {
        #if canImport(PDFKit)
        guard let outlineRoot = pdfView?.document?.outlineRoot else {
            return []
        }
        
        func convertNode(_ pdfOutline: PDFOutline) -> OutlineNode? {
            guard let title = pdfOutline.label, let destination = pdfOutline.destination,
                  let page = destination.page,
                  let doc = pdfView?.document else {
                return nil
            }
            let pageIndex = doc.index(for: page)
            var children: [OutlineNode] = []
            for i in 0..<pdfOutline.numberOfChildren {
                if let childOutline = pdfOutline.child(at: i),
                   let childNode = convertNode(childOutline) {
                    children.append(childNode)
                }
            }
            return OutlineNode(title: title, pageIndex0: pageIndex, children: children)
        }
        
        var nodes: [OutlineNode] = []
        for i in 0..<outlineRoot.numberOfChildren {
            if let child = outlineRoot.child(at: i),
               let converted = convertNode(child) {
                nodes.append(converted)
            }
        }
        return nodes
        #else
        return []
        #endif
    }
    
    // MARK: - 内部辅助方法
    public func updateCurrentPageFromScroll(pageIndex0: Int) {
        guard pageIndex0 >= 0, self.currentPageIndex0 != pageIndex0 else { return }
        self.currentPageIndex0 = pageIndex0
        self.onPageChanged?(pageIndex0)
    }
    
    public func updateSelection(anchor: SourceAnchor?, screenRect: CGRect?) {
        self.currentSelectionAnchor = anchor
        self.onSelectionChanged?(anchor, screenRect)
    }
    
    public func markPageDirty(pageKey: PageKey, snapshot: InkSaveSnapshot) {
        self.dirtyPages.insert(pageKey)
        self.pendingSnapshots[pageKey] = snapshot
    }
}
