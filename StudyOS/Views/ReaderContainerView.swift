import SwiftUI

#if canImport(PDFKit)
import PDFKit
#endif

/// 阅读器主工作区容器 (ReaderContainerView)
/// 严格对齐 PRD R02–R05 与 ARCHITECTURE-AND-FLOWS.md 布局规范
/// 包含：沉浸式顶栏、70/30 自适应分栏 SplitView (≥540pt 约束保护)、底栏物理页码滑块、选区浮动菜单与发光边框图层
public struct ReaderContainerView: View {
    @ObservedObject public var viewModel: ReaderViewModel
    @Environment(\.dismiss) private var dismiss
    
    public init(viewModel: ReaderViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let isWideScreen = totalWidth >= StudyTheme.Layout.splitThresholdWidth
            
            VStack(spacing: 0) {
                // 1. 沉浸式顶部导航栏
                readerTopBar
                
                Divider()
                    .background(StudyTheme.Colors.divider)
                
                // 2. 主体工作区 (自适应 70/30 分栏 或 单视口)
                HStack(spacing: 0) {
                    // 左侧主阅读视口 (受 540pt 最小舒适下限保护)
                    mainReadingCanvas
                        .frame(
                            width: isWideScreen && viewModel.isAISidebarOpen
                                ? max(StudyTheme.Layout.minimumReaderWidth, totalWidth - sidebarWidth(for: totalWidth))
                                : totalWidth
                        )
                    
                    // 右侧 AI 助学侧栏 (宽屏分栏展示)
                    if isWideScreen && viewModel.isAISidebarOpen {
                        Divider()
                            .background(StudyTheme.Colors.divider)
                        
                        AISidebarView(viewModel: viewModel)
                            .frame(width: sidebarWidth(for: totalWidth))
                            .transition(.move(edge: .trailing))
                    }
                }
                .frame(maxHeight: .infinity)
                
                Divider()
                    .background(StudyTheme.Colors.divider)
                
                // 3. 底栏物理页码指示与滑块
                readerBottomBar
            }
            .background(StudyTheme.Colors.paperBackground)
            // 窄屏下 AI 侧栏转为自适应抽屉 Sheet
            .sheet(isPresented: Binding(
                get: { !isWideScreen && viewModel.isAISidebarOpen },
                set: { viewModel.isAISidebarOpen = $0 }
            )) {
                AISidebarView(viewModel: viewModel)
            }
            // 全文学习视图模态
            .sheet(isPresented: $viewModel.isFullStudyViewOpen) {
                FullDocumentStudyView(viewModel: viewModel)
            }
            // 轻量 Toast 提示
            .overlay(
                toastOverlay,
                alignment: .top
            )
        }
        .task {
            await viewModel.loadInitialSnapshot()
        }
    }
    
    // 计算 AI 侧栏宽度 (限制在 [320, 400] pt 且保障阅读区 >= 540pt)
    private func sidebarWidth(for totalWidth: CGFloat) -> CGFloat {
        let maxAllowedSidebar = totalWidth - StudyTheme.Layout.minimumReaderWidth
        let target = totalWidth * 0.30
        return min(StudyTheme.Layout.sidebarMaxWidth, max(StudyTheme.Layout.sidebarMinWidth, min(target, maxAllowedSidebar)))
    }
    
    // MARK: - 顶部沉浸式导航栏
    private var readerTopBar: some View {
        HStack(spacing: StudyTheme.Spacing.md) {
            // 返回资料库
            Button {
                dismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("资料库")
                }
                .font(.subheadline)
                .foregroundColor(StudyTheme.Colors.primary)
            }
            .buttonStyle(.plain)
            
            // 文档标题
            Text(viewModel.document.title)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
            
            // 工具态显式切换 (纯阅读 / 文本选择 / 批注)
            Picker("工具态", selection: Binding(
                get: { viewModel.adapter.currentToolMode },
                set: { viewModel.adapter.currentToolMode = $0 }
            )) {
                Text("阅读").tag(ReaderToolMode.reading)
                Text("选词").tag(ReaderToolMode.textSelection)
                Text("批注").tag(ReaderToolMode.annotation)
            }
            .pickerStyle(.segmented)
            .frame(width: 190)
            
            // 全文学习视图
            Button {
                viewModel.isFullStudyViewOpen = true
            } label: {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.body)
                    .foregroundColor(StudyTheme.Colors.secondary)
            }
            .buttonStyle(.plain)
            
            // ✨ AI 助学触发按钮 (带有活动高亮指示)
            Button {
                withAnimation(StudyTheme.Motion.splitSpring) {
                    viewModel.isAISidebarOpen.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                    Text("AI 助学")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(viewModel.isAISidebarOpen ? StudyTheme.Colors.primary : StudyTheme.Colors.primary.opacity(0.12))
                .foregroundColor(viewModel.isAISidebarOpen ? .white : StudyTheme.Colors.primary)
                .cornerRadius(StudyTheme.Radius.pill)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, StudyTheme.Spacing.md)
        .padding(.vertical, StudyTheme.Spacing.sm)
        .background(Color.systemBackground)
    }
    
    // MARK: - 主阅读视口与图层叠加
    private var mainReadingCanvas: some View {
        ZStack {
            // PDF 原生渲染层
            PDFKitPlatformBridge(
                adapter: viewModel.adapter,
                documentURL: URL(fileURLWithPath: viewModel.document.localFileRef)
            )
            
            // PencilKit 手绘图层 (按当前页挂载)
            PencilKitOverlayCanvas(
                adapter: viewModel.adapter,
                pageIndex0: viewModel.adapter.currentPageIndex0
            )
            
            // 选区浮动菜单 (当存在文本划选且有屏幕定位时)
            if let anchor = viewModel.selectionAnchor,
               let screenRect = viewModel.selectionScreenRect {
                SelectionCalloutMenu(
                    anchor: anchor,
                    screenRect: screenRect,
                    onAIExplain: {
                        viewModel.requestAIExplanation(for: anchor)
                    },
                    onAddToNote: {
                        Task {
                            await viewModel.saveNoteFromSelection(
                                text: anchor.quote ?? "选中文本",
                                anchor: anchor
                            )
                        }
                    },
                    onDismiss: {
                        viewModel.adapter.clearCurrentSelection()
                    }
                )
            }
            
            // 来源回跳发光边框动画层
            if let focusRect = viewModel.focusRingScreenRect {
                SourceAnchorFocusRing(
                    screenRect: focusRect,
                    token: viewModel.focusRingToken
                )
            }
        }
    }
    
    // MARK: - 底栏物理页码指示与滑块
    private var readerBottomBar: some View {
        HStack(spacing: StudyTheme.Spacing.lg) {
            // 书签切换按钮
            Button {
                Task {
                    await viewModel.toggleBookmarkForCurrentPage()
                }
            } label: {
                Image(systemName: "bookmark")
                    .foregroundColor(StudyTheme.Colors.primary)
            }
            .buttonStyle(.plain)
            
            // 快速翻页滑块 Scrubber
            Slider(
                value: Binding(
                    get: { Double(viewModel.adapter.currentPageIndex0) },
                    set: { newIndex in
                        _ = viewModel.adapter.goToPage(index0: Int(newIndex))
                    }
                ),
                in: 0...Double(max(0, viewModel.adapter.pageCount - 1)),
                step: 1.0
            )
            
            // 1-based 物理页码指示 (UIREV-04)
            Text("第 \(viewModel.adapter.currentPageIndex0 + 1) 页 / 共 \(max(1, viewModel.adapter.pageCount)) 页")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(minWidth: 110, alignment: .trailing)
        }
        .padding(.horizontal, StudyTheme.Spacing.lg)
        .padding(.vertical, StudyTheme.Spacing.sm)
        .background(Color.systemBackground)
    }
    
    // MARK: - Toast 轻量通知
    @ViewBuilder
    private var toastOverlay: some View {
        if viewModel.showToast, let msg = viewModel.toastMessage {
            Text(msg)
                .font(.subheadline)
                .padding(.horizontal, StudyTheme.Spacing.lg)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .cornerRadius(StudyTheme.Radius.pill)
                .shadow(radius: 6)
                .padding(.top, 56)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation {
                            viewModel.showToast = false
                        }
                    }
                }
        }
    }
}

