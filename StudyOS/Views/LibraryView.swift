import SwiftUI

/// 资料库首页主视图 (LibraryView)
/// 严格对齐 PRD R01, R16 与 COMPONENTS-AND-STATES.md 规范
/// 包含：最近阅读横向卡片、全部文档列表、导入按钮、以及两路笔记删除弹窗 (UIREV-06)
public struct LibraryView: View {
    @StateObject public var viewModel: LibraryViewModel
    public let coreService: CoreServiceProtocol
    
    @State private var activeDocumentForReading: Document?
    @State private var isShowingFileImporter: Bool = false
    
    public init(coreService: CoreServiceProtocol) {
        self.coreService = coreService
        self._viewModel = StateObject(wrappedValue: LibraryViewModel(coreService: coreService))
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: StudyTheme.Spacing.lg) {
                    // 1. 最近阅读横向滚动区
                    if !viewModel.recentDocuments.isEmpty {
                        recentReadingSection
                    }
                    
                    // 2. 全部资料列表区
                    allDocumentsSection
                }
                .padding(StudyTheme.Spacing.lg)
            }
            .navigationTitle("资料库")
            .searchable(text: $viewModel.searchText, prompt: "搜索文档标题或资料...")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingFileImporter = true
                    } label: {
                        Label("导入 PDF", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .foregroundColor(StudyTheme.Colors.primary)
                    }
                }
            }
            .fileImporter(
                isPresented: $isShowingFileImporter,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let selectedURL = urls.first {
                        Task {
                            await viewModel.importPDF(from: selectedURL)
                        }
                    }
                case .failure(let err):
                    viewModel.errorMessage = "选择文件失败: \(err.localizedDescription)"
                }
            }
            .task {
                await viewModel.loadDocuments()
            }
            // 进入阅读器
            #if os(iOS)
            .fullScreenCover(item: $activeDocumentForReading) { doc in
                let readerVM = ReaderViewModel(
                    document: doc,
                    coreService: coreService
                )
                ReaderContainerView(viewModel: readerVM)
            }
            #endif
            // 两路笔记删除影响预览与确认弹窗 (UIREV-06)
            .sheet(item: $viewModel.selectedDocumentForDeletion) { _ in
                documentDeletionModal
            }
        }
    }
    
    // MARK: - 最近阅读横向卡片区
    private var recentReadingSection: some View {
        VStack(alignment: .leading, spacing: StudyTheme.Spacing.sm) {
            Text("最近研读")
                .font(.headline)
                .foregroundColor(.primary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: StudyTheme.Spacing.md) {
                    ForEach(viewModel.recentDocuments) { doc in
                        recentDocumentCard(doc)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private func recentDocumentCard(_ doc: Document) -> some View {
        Button {
            activeDocumentForReading = doc
        } label: {
            VStack(alignment: .leading, spacing: StudyTheme.Spacing.xs) {
                // 封面占位与页码角标
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: StudyTheme.Radius.md)
                        .fill(StudyTheme.Colors.primary.opacity(0.08))
                        .frame(width: 140, height: 180)
                        .overlay(
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 44))
                                .foregroundColor(StudyTheme.Colors.primary.opacity(0.4))
                        )
                    
                    Text("\(doc.pageCount) 页")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial)
                        .cornerRadius(StudyTheme.Radius.sm)
                        .padding(6)
                }
                
                Text(doc.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .frame(width: 140, alignment: .leading)
                    .foregroundColor(.primary)
                
                Text(doc.updatedAt, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 全部资料列表区
    private var allDocumentsSection: some View {
        VStack(alignment: .leading, spacing: StudyTheme.Spacing.sm) {
            HStack {
                Text("全部资料 (\(viewModel.filteredDocuments.count))")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView("正在加载资料库...")
                    Spacer()
                }
                .padding(.vertical, 32)
            } else if viewModel.filteredDocuments.isEmpty {
                VStack(spacing: StudyTheme.Spacing.sm) {
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("资料库暂无文档，点击右上角导入")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
            } else {
                LazyVStack(spacing: StudyTheme.Spacing.sm) {
                    ForEach(viewModel.filteredDocuments) { doc in
                        documentRow(doc)
                    }
                }
            }
        }
    }
    
    private func documentRow(_ doc: Document) -> some View {
        HStack(spacing: StudyTheme.Spacing.md) {
            Image(systemName: "doc.richtext")
                .font(.title2)
                .foregroundColor(StudyTheme.Colors.primary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(doc.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text("\(doc.pageCount) 页")
                    Text("•")
                    Text("版本 v\(doc.revision)")
                    Text("•")
                    Text(doc.createdAt, style: .date)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 操作菜单 (删除)
            Menu {
                Button(role: .destructive) {
                    Task {
                        await viewModel.requestDelete(document: doc)
                    }
                } label: {
                    Label("删除文档...", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body)
                    .padding(8)
                    .foregroundColor(.secondary)
            }
        }
        .padding(StudyTheme.Spacing.md)
        .background(Color.systemBackground)
        .cornerRadius(StudyTheme.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: StudyTheme.Radius.md)
                .stroke(StudyTheme.Colors.border, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            activeDocumentForReading = doc
        }
    }
    
    // MARK: - 两路笔记删除影响评估与确认弹窗 (UIREV-06)
    private var documentDeletionModal: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: StudyTheme.Spacing.lg) {
                if let doc = viewModel.selectedDocumentForDeletion,
                   let impact = viewModel.deleteImpact {
                    
                    Text("确定要删除资料 “\(doc.title)” 吗？")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    // 影响清单预览
                    VStack(alignment: .leading, spacing: 6) {
                        Text("删除影响评估清单:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        impactRow("PDF 原始文件", count: impact.originalFileCount)
                        impactRow("向量索引与分词条目", count: impact.indexCount)
                        impactRow("页面手写批注与涂鸦", count: impact.inkCount)
                        impactRow("关联笔记记录", count: impact.associatedNoteCount)
                    }
                    .padding(StudyTheme.Spacing.md)
                    .background(StudyTheme.Colors.paperBackground)
                    .cornerRadius(StudyTheme.Radius.md)
                    
                    // 两路笔记处理策略（强制二选一，无默认值）
                    VStack(alignment: .leading, spacing: 8) {
                        Text("请选择关联笔记处理策略 (必选):")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(StudyTheme.Colors.danger)
                        
                        Button {
                            viewModel.chosenNotePolicy = .keep
                        } label: {
                            HStack(alignment: .top) {
                                Image(systemName: viewModel.chosenNotePolicy == .keep ? "largecircle.fill.circle" : "circle")
                                    .foregroundColor(StudyTheme.Colors.primary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("保留笔记文字与图片副本 (推荐)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text("解除归属关系，原来源标记为 documentDeleted 不再支持跳转，笔记资产永久安全保留。")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 4)
                        
                        Button {
                            viewModel.chosenNotePolicy = .delete
                        } label: {
                            HStack(alignment: .top) {
                                Image(systemName: viewModel.chosenNotePolicy == .delete ? "largecircle.fill.circle" : "circle")
                                    .foregroundColor(StudyTheme.Colors.danger)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("连带彻底删除关联笔记")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(StudyTheme.Colors.danger)
                                    Text("连同所有基于该资料产生的笔记一同永久物理清除，不可恢复。")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 4)
                    }
                    
                    if let status = viewModel.cleanupPendingStatus {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text(status)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                } else {
                    ProgressView("正在评估删除影响...")
                    Spacer()
                }
            }
            .padding(StudyTheme.Spacing.lg)
            .navigationTitle("删除确认")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        viewModel.dismissDeletion()
                    }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("确认删除") {
                        Task {
                            await viewModel.confirmDelete()
                        }
                    }
                    .disabled(viewModel.chosenNotePolicy == nil || viewModel.isDeleting)
                }
            }
        }
    }
    
    private func impactRow(_ label: String, count: Int) -> some View {
        HStack {
            Text("• \(label)")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text("\(count) 项")
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

