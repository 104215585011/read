import Foundation
import SwiftUI
import Combine

/// 资料库状态机与业务逻辑 ViewModel
/// 驱动 LibraryView 响应式渲染，管理文档生命周期与两路删除确认 (UIREV-06)
@MainActor
public final class LibraryViewModel: ObservableObject {
    // MARK: - 响应式状态
    @Published public private(set) var documents: [Document] = []
    @Published public private(set) var recentDocuments: [Document] = []
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    @Published public var searchText: String = ""
    
    // 导入状态
    @Published public var isImporting: Bool = false
    @Published public var importProgressMessage: String?
    
    // 删除弹窗与影响评估状态 (UIREV-06)
    @Published public var selectedDocumentForDeletion: Document?
    @Published public var deleteImpact: DeleteImpact?
    @Published public var chosenNotePolicy: NotePolicy?
    @Published public var isDeleting: Bool = false
    @Published public var cleanupPendingStatus: String?
    
    // 核心服务门面
    private let coreService: CoreServiceProtocol
    
    public init(coreService: CoreServiceProtocol) {
        self.coreService = coreService
    }
    
    // MARK: - 过滤后文档列表
    public var filteredDocuments: [Document] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return documents
        }
        return documents.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    
    // MARK: - 加载文档列表
    public func loadDocuments() async {
        isLoading = true
        errorMessage = nil
        do {
            let docs = try await coreService.documentService.listDocuments()
            self.documents = docs
            // 最近阅读按更新时间排序取前 5
            self.recentDocuments = Array(docs.sorted(by: { $0.updatedAt > $1.updatedAt }).prefix(5))
        } catch {
            self.errorMessage = "加载资料库失败: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    // MARK: - 导入 PDF 文档
    public func importPDF(from url: URL) async {
        isImporting = true
        importProgressMessage = "正在校验并导入文档..."
        errorMessage = nil
        
        do {
            let doc = try await coreService.documentService.importPDF(fileURL: url, operationID: UUID().uuidString)
            self.documents.insert(doc, at: 0)
            self.recentDocuments.insert(doc, at: 0)
            importProgressMessage = nil
        } catch {
            self.errorMessage = "导入 PDF 失败: \(error.localizedDescription)"
        }
        
        isImporting = false
    }
    
    // MARK: - 删除文档影响评估 (UIREV-06)
    public func requestDelete(document: Document) async {
        selectedDocumentForDeletion = document
        chosenNotePolicy = nil
        deleteImpact = nil
        cleanupPendingStatus = nil
        
        do {
            let impact = try await coreService.documentService.previewDeleteDocument(
                documentID: document.id,
                revision: document.revision
            )
            self.deleteImpact = impact
        } catch {
            self.errorMessage = "获取删除影响清单失败: \(error.localizedDescription)"
            self.selectedDocumentForDeletion = nil
        }
    }
    
    // MARK: - 确认删除文档并执行策略 (UIREV-06)
    public func confirmDelete() async {
        guard let doc = selectedDocumentForDeletion,
              let impact = deleteImpact,
              let policy = chosenNotePolicy else {
            return
        }
        
        isDeleting = true
        do {
            let result = try await coreService.documentService.deleteDocument(
                documentID: doc.id,
                expectedRevision: doc.revision,
                notePolicy: policy,
                confirmedImpactID: impact.impactID,
                operationID: UUID().uuidString
            )
            
            switch result {
            case .completed:
                self.documents.removeAll(where: { $0.id == doc.id })
                self.recentDocuments.removeAll(where: { $0.id == doc.id })
                self.selectedDocumentForDeletion = nil
                self.deleteImpact = nil
                self.chosenNotePolicy = nil
                
            case .cleanupPending(_, _, _, let pendingFiles, _):
                self.cleanupPendingStatus = "文档已标记删除，剩余 \(pendingFiles) 个关联文件正在后台彻底清理..."
                // 从主列表中移除
                self.documents.removeAll(where: { $0.id == doc.id })
                self.recentDocuments.removeAll(where: { $0.id == doc.id })
            }
        } catch {
            self.errorMessage = "删除操作失败: \(error.localizedDescription)"
        }
        isDeleting = false
    }
    
    public func dismissDeletion() {
        selectedDocumentForDeletion = nil
        deleteImpact = nil
        chosenNotePolicy = nil
        cleanupPendingStatus = nil
    }
}
