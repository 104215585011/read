import Foundation

#if canImport(CoreGraphics)
import CoreGraphics
#endif

#if canImport(PencilKit)
import PencilKit
#endif

/// ReaderAdapter 核心通信协议 (UIREV-01, UIREV-03, UIREV-04)
/// 用于解耦 SwiftUI 声明式状态与底层的 PDFKit / PencilKit 命令式渲染
@MainActor
public protocol ReaderAdapterProtocol: AnyObject, Sendable {
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
    #if canImport(CoreGraphics)
    func zoom(to scale: CGFloat)
    #endif

    // 工具态与 PencilKit 管理 (UIREV-04)
    func setToolMode(_ mode: ReaderToolMode)

    #if canImport(PencilKit)
    func setPencilTool(_ tool: PKTool)
    #endif

    // 异步增量笔迹持久化 (UIREV-03, PageKey 与 Receipt 对齐)
    func flushInk(snapshot: InkSaveSnapshot) async -> Result<InkSaveReceipt, SaveInkError>
    func flushAllDirtyInks() async -> [PageKey: Result<InkSaveReceipt, SaveInkError>]
    func clearCurrentSelection()

    // 搜索与目录
    func search(keyword: String, completion: @escaping @Sendable ([SearchResultItem]) -> Void)
    func getOutlineTree() -> [OutlineNode]
}
