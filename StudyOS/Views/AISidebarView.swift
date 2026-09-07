import SwiftUI

/// AI 助学侧栏主视图 (AISidebarView)
/// 严格对应 COMPONENTS-AND-STATES.md 规约与 PRD R06–R09
/// 包含：三级范围选择器、六段式助学卡片流、自由问答流与来源校验胶囊
public struct AISidebarView: View {
    @ObservedObject public var viewModel: ReaderViewModel
    @State private var selectedTab: AISidebarTab = .studyGuide
    
    public enum AISidebarTab: String, CaseIterable {
        case studyGuide = "六段助学"
        case askAI = "自由问答"
    }
    
    public init(viewModel: ReaderViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // 1. 范围选择与诊断头
            scopeHeader
            
            // 2. 助学 / 问答 选项卡切换
            Picker("", selection: $selectedTab) {
                ForEach(AISidebarTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, StudyTheme.Spacing.md)
            .padding(.vertical, StudyTheme.Spacing.sm)
            
            Divider()
                .background(StudyTheme.Colors.divider)
            
            // 3. 主体内容区
            if selectedTab == .studyGuide {
                sixSectionStudyFeed
            } else {
                askAIConversationFlow
            }
            
            // 4. 底栏：自由问答输入条
            if selectedTab == .askAI {
                askInputBar
            }
        }
        .background(Color(red: 0.985, green: 0.985, blue: 0.99))
    }
    
    // MARK: - 范围选择器与诊断头
    private var scopeHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("AI 助学范围")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 6) {
                    Image(systemName: scopeIconName)
                        .foregroundColor(StudyTheme.Colors.primary)
                    Text(scopeDescription)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
            
            Spacer()
            
            // 全文学习视图快捷入口
            Button {
                viewModel.isFullStudyViewOpen = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chart.bar.doc.horizontal")
                    Text("全文视图")
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(StudyTheme.Colors.secondary.opacity(0.12))
                .foregroundColor(StudyTheme.Colors.secondary)
                .cornerRadius(StudyTheme.Radius.sm)
            }
            .buttonStyle(.plain)
        }
        .padding(StudyTheme.Spacing.md)
        .background(Color.systemBackground)
    }
    
    private var scopeIconName: String {
        switch viewModel.currentScope {
        case .selection: return "selection.pin.in.out"
        case .page: return "doc.text"
        case .chapter: return "bookmark"
        case .document: return "books.vertical"
        }
    }
    
    private var scopeDescription: String {
        switch viewModel.currentScope {
        case .selection(let anchor):
            if let quote = anchor.quote, !quote.isEmpty {
                return "选区: “\(quote.prefix(12))...”"
            }
            return "当前选中文本"
        case .page(let p):
            return "第 \(p + 1) 页 (物理页)"
        case .chapter(_, let start, let end):
            return "章节 (第 \(start + 1)–\(end + 1) 页)"
        case .document:
            return "全文研读"
        }
    }
    
    // MARK: - 六段式助学卡片流 (Six-Section Study Feed)
    private var sixSectionStudyFeed: some View {
        ScrollView {
            LazyVStack(spacing: StudyTheme.Spacing.md) {
                // ① 这一部分在讲什么
                studyCard(
                    title: "① 这一部分在讲什么",
                    icon: "text.alignleft",
                    color: StudyTheme.Colors.primary
                ) {
                    Text("本段落系统梳理了核心接口规范与多层抽象协议，阐明了在现代客户端架构中保持并发安全与模块隔离的基本设计准则。")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                
                // ② 阅读重点清单
                studyCard(
                    title: "② 阅读重点清单",
                    icon: "checklist",
                    color: StudyTheme.Colors.secondary
                ) {
                    VStack(alignment: .leading, spacing: 6) {
                        bulletRow("关注不可变快照在任务入队前的内存固化机制")
                        bulletRow("对比 0-based 内部逻辑页码与物理页码显示映射")
                        bulletRow("识别异步操作完成后对主执行域会话一致性的校验边界")
                    }
                }
                
                // ③ 前置知识
                studyCard(
                    title: "③ 前置知识",
                    icon: "graduationcap",
                    color: StudyTheme.Colors.accent
                ) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• Swift 结构化并发模型 (Task, @MainActor)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("• Apple PencilKit 矢量笔划序列化协议")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // ④ 核心概念
                studyCard(
                    title: "④ 核心概念卡片组",
                    icon: "lightbulb",
                    color: Color.purple
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        conceptRow(title: "ReaderAdapter", desc: "解耦 SwiftUI 响应式状态与底层 PDFKit/PencilKit 命令式生命周期")
                        conceptRow(title: "PageKey", desc: "由 documentID + revision + pageIndex0 构成的单页手写隔离主键")
                    }
                }
                
                // ⑤ 容易理解错的地方 (⚠️ 警示卡片)
                studyCard(
                    title: "⑤ 容易理解错的地方 ⚠️",
                    icon: "exclamationmark.triangle",
                    color: StudyTheme.Colors.danger
                ) {
                    Text("误区：认为脏标记 (dirty) 本身可以恢复未持久化的手写。规范明确声明：dirty 标记仅为未落盘状态指示，必须依赖不可变快照写盘保障。")
                        .font(.subheadline)
                        .foregroundColor(StudyTheme.Colors.danger)
                }
                
                // ⑥ 阅读思考问题 (PRD: 默认无答案)
                studyCard(
                    title: "⑥ 阅读思考问题",
                    icon: "questionmark.bubble",
                    color: StudyTheme.Colors.success
                ) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("1. 为什么必须在 resolveSource 的 await 返回后校验 readerSessionID？")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("2. 若网络在分批分析第 18 页中断，系统如何保障已生成结论不丢失？")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }
            .padding(StudyTheme.Spacing.md)
        }
    }
    
    // MARK: - 自由问答流 (Ask AI Conversation Flow)
    private var askAIConversationFlow: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: StudyTheme.Spacing.md) {
                    if viewModel.messages.isEmpty {
                        VStack(spacing: StudyTheme.Spacing.sm) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 36))
                                .foregroundColor(.secondary.opacity(0.6))
                            Text("针对当前资料向 AI 提问")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("所有解答均基于真实来源锚点，杜绝虚构。")
                                .font(.caption2)
                                .foregroundColor(.secondary.opacity(0.8))
                        }
                        .padding(.top, 48)
                    } else {
                        ForEach(viewModel.messages) { msg in
                            messageBubble(msg)
                                .id(msg.id)
                        }
                    }
                    
                    if viewModel.isAIGenerating {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("AI 正在严谨研读并提取证据...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, StudyTheme.Spacing.md)
                        .id("generating_indicator")
                    }
                }
                .padding(StudyTheme.Spacing.md)
            }
            .onChange(of: viewModel.messages.count) { _ in
                if let last = viewModel.messages.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - 消息气泡与引用胶囊
    @ViewBuilder
    private func messageBubble(_ msg: AIMessageItem) -> some View {
        VStack(alignment: msg.isUser ? .trailing : .leading, spacing: 6) {
            HStack {
                if msg.isUser { Spacer() }
                
                Text(msg.text)
                    .font(.subheadline)
                    .padding(StudyTheme.Spacing.md)
                    .background(msg.isUser ? StudyTheme.Colors.primary : Color.systemBackground)
                    .foregroundColor(msg.isUser ? .white : .primary)
                    .cornerRadius(StudyTheme.Radius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: StudyTheme.Radius.md)
                            .stroke(msg.isUser ? Color.clear : StudyTheme.Colors.border, lineWidth: 1)
                    )
                
                if !msg.isUser { Spacer() }
            }
            
            // AI 回答下的引用来源胶囊
            if !msg.isUser && !msg.sources.isEmpty {
                HStack(spacing: 6) {
                    ForEach(msg.sources.indices, id: \.self) { idx in
                        let anchor = msg.sources[idx]
                        citationButton(anchor)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func citationButton(_ anchor: SourceAnchor) -> some View {
        Button {
            Task {
                await viewModel.navigateToSource(anchor)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 11))
                Text("P\(anchor.pageIndex0 + 1) 依据")
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(StudyTheme.Colors.primary.opacity(0.12))
            .foregroundColor(StudyTheme.Colors.primary)
            .cornerRadius(StudyTheme.Radius.pill)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 问答输入条
    private var askInputBar: some View {
        HStack(spacing: StudyTheme.Spacing.sm) {
            TextField("输入学术问题或指令...", text: $viewModel.askInputText)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    viewModel.sendQuestion()
                }
            
            if viewModel.isAIGenerating {
                Button {
                    viewModel.cancelAIGeneration()
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.title2)
                        .foregroundColor(StudyTheme.Colors.danger)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    viewModel.sendQuestion()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(viewModel.askInputText.isEmpty ? .secondary : StudyTheme.Colors.primary)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.askInputText.isEmpty)
            }
        }
        .padding(StudyTheme.Spacing.md)
        .background(Color.systemBackground)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(StudyTheme.Colors.divider),
            alignment: .top
        )
    }
    
    // MARK: - 辅助组件
    @ViewBuilder
    private func studyCard<Content: View>(
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: StudyTheme.Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.subheadline)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            content()
        }
        .padding(StudyTheme.Spacing.md)
        .background(Color.systemBackground)
        .cornerRadius(StudyTheme.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: StudyTheme.Radius.md)
                .stroke(StudyTheme.Colors.border, lineWidth: 1)
        )
    }
    
    private func bulletRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
                .foregroundColor(StudyTheme.Colors.secondary)
            Text(text)
                .font(.caption)
                .foregroundColor(.primary)
        }
    }
    
    private func conceptRow(title: String, desc: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(StudyTheme.Colors.primary)
            Text(desc)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// 跨平台适配系统背景色扩展
private extension Color {
    static var systemBackground: Color {
        #if canImport(UIKit)
        return Color(UIColor.systemBackground)
        #else
        return Color.white
        #endif
    }
}
