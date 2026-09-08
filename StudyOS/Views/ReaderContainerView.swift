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
    
    // M4+ 平铺式可拖拽分割布局
    @State private var sidebarWidth: CGFloat = 380
    @State private var initialDragWidth: CGFloat? = nil
    
    public init(viewModel: ReaderViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let minSidebarWidth: CGFloat = 260
            let maxSidebarWidth: CGFloat = max(minSidebarWidth, totalWidth - 360)
            let effectiveSidebarWidth = min(max(sidebarWidth, minSidebarWidth), maxSidebarWidth)
            let readingWidth = viewModel.isAISidebarOpen ? max(360, totalWidth - effectiveSidebarWidth - 8) : totalWidth
            
            VStack(spacing: 0) {
                // 1. 沉浸式顶部导航栏
                readerTopBar
                
                Divider()
                    .background(StudyTheme.Colors.divider)
                
                // 2. 主体工作区 (平铺式可拖拽分割布局)
                HStack(spacing: 0) {
                    // 左侧主阅读视口
                    mainReadingCanvas
                        .frame(width: readingWidth)
                    
                    // 中间竖向可拖拽分割条 (配微手柄胶囊)
                    if viewModel.isAISidebarOpen {
                        resizerDivider(totalWidth: totalWidth)
                        
                        // 右侧 AI 助学侧栏 (平铺分栏展示)
                        AISidebarView(viewModel: viewModel, hostWidth: effectiveSidebarWidth)
                            .frame(width: effectiveSidebarWidth)
                            .transition(.move(edge: .trailing))
                    }
                }
                .frame(maxHeight: .infinity)
                
                Divider()
                    .background(StudyTheme.Colors.divider)
                
                // 3. 底栏物理页码指示与滑块 (带分栏比例显示)
                readerBottomBar(totalWidth: totalWidth)
            }
            .background(viewModel.selectedPaperTheme.backgroundColor)
            .preferredColorScheme(viewModel.selectedPaperTheme.isDark ? .dark : nil)
            // 大模型配置中心模态 (Model Hub)
            .sheet(isPresented: $viewModel.isModelConfigOpen) {
                ModelConfigurationSheet(viewModel: viewModel)
            }
            // 全文学习视图模态 (R10)
            .sheet(isPresented: $viewModel.isFullStudyViewOpen) {
                FullDocumentStudyView(viewModel: viewModel)
            }
            // AI 笔记沉淀流模态 (R11)
            .sheet(isPresented: $viewModel.isAINotesOpen) {
                AINotesView(viewModel: viewModel)
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
    
    // MARK: - 可拖拽竖向分割条 (配微手柄胶囊)
    private func resizerDivider(totalWidth: CGFloat) -> some View {
        ZStack {
            Rectangle()
                .fill(StudyTheme.Colors.divider)
                .frame(width: 8)
            
            // 微手柄胶囊（三圆点）
            Capsule()
                .fill(Color.secondary.opacity(0.35))
                .frame(width: 4, height: 36)
                .overlay(
                    VStack(spacing: 3) {
                        Circle().fill(Color.white).frame(width: 2, height: 2)
                        Circle().fill(Color.white).frame(width: 2, height: 2)
                        Circle().fill(Color.white).frame(width: 2, height: 2)
                    }
                )
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    let minSidebarWidth: CGFloat = 260
                    let maxSidebarWidth: CGFloat = max(minSidebarWidth, totalWidth - 360)
                    if initialDragWidth == nil {
                        initialDragWidth = sidebarWidth
                    }
                    let base = initialDragWidth ?? sidebarWidth
                    let newWidth = base - value.translation.width
                    sidebarWidth = min(max(newWidth, minSidebarWidth), maxSidebarWidth)
                }
                .onEnded { _ in
                    initialDragWidth = nil
                }
        )
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
            
            // 护眼与纸张底色一键切换菜单 (M4-RELEASE)
            Menu {
                ForEach(StudyTheme.PaperTheme.allCases) { theme in
                    Button {
                        viewModel.selectedPaperTheme = theme
                    } label: {
                        HStack {
                            Image(systemName: theme.iconName)
                            Text(theme.displayName)
                            if viewModel.selectedPaperTheme == theme {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.selectedPaperTheme.iconName)
                    Text(viewModel.selectedPaperTheme.displayName)
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(viewModel.selectedPaperTheme.isDark ? Color.white.opacity(0.12) : Color.primary.opacity(0.08))
                .foregroundColor(viewModel.selectedPaperTheme.isDark ? .white : .primary)
                .cornerRadius(StudyTheme.Radius.pill)
            }
            .buttonStyle(.plain)
            
            // 全文研读视图 (R10)
            Button {
                viewModel.isFullStudyViewOpen = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text.magnifyingglass")
                    Text("全文研读")
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(StudyTheme.Colors.secondary.opacity(0.12))
                .foregroundColor(StudyTheme.Colors.secondary)
                .cornerRadius(StudyTheme.Radius.pill)
            }
            .buttonStyle(.plain)
            
            // AI 笔记抽屉 (R11)
            Button {
                viewModel.isAINotesOpen = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "note.text")
                    Text("AI 笔记")
                    if !viewModel.aiNotes.isEmpty {
                        Text("\(viewModel.aiNotes.count)")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .background(StudyTheme.Colors.accent)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(StudyTheme.Colors.accent.opacity(0.12))
                .foregroundColor(StudyTheme.Colors.accent)
                .cornerRadius(StudyTheme.Radius.pill)
            }
            .buttonStyle(.plain)
            
            // ✨ AI 助学触发按钮 (带有离线模型指示与活动高亮指示)
            Button {
                withAnimation(StudyTheme.Motion.splitSpring) {
                    viewModel.isAISidebarOpen.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    if let status = viewModel.localModelStatus, status.isReady {
                        Circle()
                            .fill(StudyTheme.Colors.success)
                            .frame(width: 6, height: 6)
                    }
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
    // MARK: - 底栏物理页码指示与滑块
    private func readerBottomBar(totalWidth: CGFloat) -> some View {
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
            
            // 分栏比例指示 (PDF % | AI %)
            if viewModel.isAISidebarOpen && totalWidth > 0 {
                let aiRatio = Int(round((sidebarWidth / totalWidth) * 100))
                let pdfRatio = max(0, 100 - aiRatio)
                Text("PDF \(pdfRatio)% | AI \(aiRatio)%")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.08))
                    .foregroundColor(.secondary)
                    .clipShape(Capsule())
            }
            
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

