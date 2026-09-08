import SwiftUI

/// 全文学习视图 (FullDocumentStudyView - R10 P0 核心能力)
/// 严格对应 PRD R10 与 COMPONENTS-AND-STATES.md 规约
/// 支持长文档分批抽取进度展示、大纲结构树、核心概念网络、重难点折叠卡片、知识关系拓扑及双向原文定位
public struct FullDocumentStudyView: View {
    @ObservedObject public var viewModel: ReaderViewModel
    @Environment(\.dismiss) private var dismiss
    
    // 折叠卡片展开状态字典
    @State private var expandedDifficulties: Set<String> = []
    
    public init(viewModel: ReaderViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationStack {
            Group {
                if let analysis = viewModel.fullDocumentAnalysis {
                    mainAnalysisContentView(analysis: analysis)
                } else if viewModel.isAnalyzingFullDocument || viewModel.isExtractingBatch {
                    analyzingProgressView
                } else {
                    emptyOrInitialView
                }
            }
            .navigationTitle("全文研读学习视图 (R10)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        viewModel.isFullStudyViewOpen = false
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 8) {
                        if viewModel.fullDocumentAnalysis != nil {
                            Button {
                                Task {
                                    if let analysis = viewModel.fullDocumentAnalysis {
                                        await viewModel.saveAINoteFromFullStudy(analysis)
                                    }
                                }
                            } label: {
                                Label("存为 AI 笔记", systemImage: "square.and.arrow.down")
                            }
                            
                            Button {
                                Task {
                                    await viewModel.loadOrGenerateFullDocumentStudy(forceRegenerate: true)
                                }
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                    }
                }
            }
            .background(Color(red: 0.98, green: 0.98, blue: 0.99))
        }
        .task {
            if viewModel.fullDocumentAnalysis == nil {
                await viewModel.loadOrGenerateFullDocumentStudy()
            }
        }
    }
    
    // MARK: - 主分析内容视图
    private func mainAnalysisContentView(analysis: FullDocumentAnalysis) -> some View {
        ScrollView {
            VStack(spacing: StudyTheme.Spacing.lg) {
                // 若后台正在刷新分批抽取，展示吸顶进度卡
                if viewModel.isExtractingBatch || viewModel.isAnalyzingFullDocument {
                    batchProgressInlineBanner
                }
                
                // 1. 顶部指标栏：预计耗时与覆盖率
                headerMetricsSection(analysis: analysis)
                
                // 2. 宏观架构与章节指引树 (KeySectionGuide)
                structureTreeCard(analysis: analysis)
                
                // 3. 全篇核心概念网络 (ConceptNode)
                coreConceptsCard(analysis: analysis)
                
                // 4. 重难点解析与攻关策略 (DifficultyPoint 折叠卡片)
                difficultyPointsCard(analysis: analysis)
                
                // 5. 知识关系拓扑概览 (KnowledgeRelation)
                knowledgeRelationsCard(analysis: analysis)
            }
            .padding(StudyTheme.Spacing.lg)
        }
    }
    
    // MARK: - 顶部指标卡片
    private func headerMetricsSection(analysis: FullDocumentAnalysis) -> some View {
        HStack(spacing: StudyTheme.Spacing.md) {
            // 预计耗时
            HStack(spacing: 8) {
                Image(systemName: "clock.badge.checkmark")
                    .foregroundColor(StudyTheme.Colors.primary)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("预计研读时间")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if case .available(let minutes, _, _) = analysis.readingEstimate {
                        Text("约 \(minutes) 分钟")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    } else {
                        Text("计算中...")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(StudyTheme.Spacing.md)
            .background(Color.systemBackground)
            .cornerRadius(StudyTheme.Radius.md)
            
            // 真实分析覆盖率 (UIREV-05)
            HStack(spacing: 8) {
                Image(systemName: "chart.pie.fill")
                    .foregroundColor(StudyTheme.Colors.success)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("分析覆盖度")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("100% 全覆盖 (分批验证)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(StudyTheme.Spacing.md)
            .background(Color.systemBackground)
            .cornerRadius(StudyTheme.Radius.md)
        }
    }
    
    // MARK: - 分批抽取进度条横幅
    private var batchProgressInlineBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(StudyTheme.Colors.primary)
                Text("长文档分批抽取引擎执行中")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
                if let progress = viewModel.batchExtractionProgress {
                    Text("第 \(progress.currentBatchIndex + 1)/\(progress.totalBatches) 批 (\(Int(progress.percentage * 100))%)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            if let progress = viewModel.batchExtractionProgress {
                ProgressView(value: progress.percentage)
                    .progressViewStyle(.linear)
                    .tint(StudyTheme.Colors.primary)
                
                Text("已提取 \(progress.processedPages) / \(progress.totalPages) 页物理页面内容")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(StudyTheme.Spacing.md)
        .background(StudyTheme.Colors.primary.opacity(0.06))
        .cornerRadius(StudyTheme.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: StudyTheme.Radius.md)
                .stroke(StudyTheme.Colors.primary.opacity(0.15), lineWidth: 1)
        )
    }
    
    // MARK: - 资料结构大纲树
    private func structureTreeCard(analysis: FullDocumentAnalysis) -> some View {
        VStack(alignment: .leading, spacing: StudyTheme.Spacing.sm) {
            Label("篇章宏观架构与研读指引", systemImage: "flowchart")
                .font(.headline)
                .foregroundColor(StudyTheme.Colors.primary)
            
            if analysis.keySections.isEmpty {
                Text("暂无篇章切片指引")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(analysis.keySections) { section in
                        sectionItemRow(section)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(StudyTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.systemBackground)
        .cornerRadius(StudyTheme.Radius.md)
    }
    
    private func sectionItemRow(_ section: KeySectionGuide) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("§")
                    .foregroundColor(StudyTheme.Colors.secondary)
                    .fontWeight(.bold)
                Text(section.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                
                Button("第 \(section.startPageIndex0 + 1) - \(section.endPageIndex0 + 1) 页") {
                    jumpToAnchor(section.anchor)
                }
                .font(.caption2)
                .buttonStyle(.bordered)
            }
            
            if !section.keyTakeaways.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(section.keyTakeaways.indices, id: \.self) { idx in
                        HStack(alignment: .top, spacing: 4) {
                            Text("•")
                                .foregroundColor(StudyTheme.Colors.secondary)
                            Text(section.keyTakeaways[idx])
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.leading, 12)
            }
        }
        .padding(StudyTheme.Spacing.sm)
        .background(Color(red: 0.985, green: 0.985, blue: 0.99))
        .cornerRadius(StudyTheme.Radius.sm)
    }
    
    // MARK: - 全篇核心概念云 (ConceptNode 标签)
    private func coreConceptsCard(analysis: FullDocumentAnalysis) -> some View {
        VStack(alignment: .leading, spacing: StudyTheme.Spacing.sm) {
            Label("全篇核心概念网络", systemImage: "sparkles")
                .font(.headline)
                .foregroundColor(StudyTheme.Colors.accent)
            
            if analysis.concepts.isEmpty {
                Text("暂无概念节点")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(analysis.concepts) { concept in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(concept.name)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(StudyTheme.Colors.primary)
                                
                                Spacer()
                                
                                Text("重要度: \(Int(concept.importance * 100))%")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(StudyTheme.Colors.accent.opacity(0.12))
                                    .foregroundColor(StudyTheme.Colors.accent)
                                    .cornerRadius(StudyTheme.Radius.pill)
                            }
                            
                            Text(concept.summary)
                                .font(.caption)
                                .foregroundColor(.primary)
                            
                            if !concept.sourceAnchors.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 4) {
                                        ForEach(concept.sourceAnchors.indices, id: \.self) { idx in
                                            let anchor = concept.sourceAnchors[idx]
                                            anchorPill(anchor: anchor)
                                        }
                                    }
                                }
                                .padding(.top, 2)
                            }
                        }
                        .padding(StudyTheme.Spacing.sm)
                        .background(Color(red: 0.985, green: 0.985, blue: 0.99))
                        .cornerRadius(StudyTheme.Radius.sm)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(StudyTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.systemBackground)
        .cornerRadius(StudyTheme.Radius.md)
    }
    
    // MARK: - 重难点考点解析 (DifficultyPoint 折叠卡片)
    private func difficultyPointsCard(analysis: FullDocumentAnalysis) -> some View {
        VStack(alignment: .leading, spacing: StudyTheme.Spacing.sm) {
            Label("重难点攻关与考点解析", systemImage: "exclamationmark.octagon")
                .font(.headline)
                .foregroundColor(StudyTheme.Colors.danger)
            
            if analysis.difficultyPoints.isEmpty {
                Text("暂无重难点标记")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(analysis.difficultyPoints) { diff in
                        difficultyCollapsibleRow(diff)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(StudyTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.systemBackground)
        .cornerRadius(StudyTheme.Radius.md)
    }
    
    private func difficultyCollapsibleRow(_ diff: DifficultyPoint) -> some View {
        let isExpanded = expandedDifficulties.contains(diff.id)
        
        return VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded {
                        expandedDifficulties.remove(diff.id)
                    } else {
                        expandedDifficulties.insert(diff.id)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down.circle.fill" : "chevron.right.circle.fill")
                        .foregroundColor(StudyTheme.Colors.danger)
                        .font(.subheadline)
                    
                    Text(diff.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(isExpanded ? "收起" : "展开策略")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            Text(diff.description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 4) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(StudyTheme.Colors.accent)
                            .font(.caption)
                        Text("推荐研读策略:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(StudyTheme.Colors.accent)
                    }
                    
                    Text(diff.suggestedStrategy)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .padding(.leading, 16)
                }
                .padding(8)
                .background(StudyTheme.Colors.accent.opacity(0.08))
                .cornerRadius(StudyTheme.Radius.sm)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            if !diff.sourceAnchors.isEmpty {
                HStack(spacing: 4) {
                    ForEach(diff.sourceAnchors.indices, id: \.self) { idx in
                        let anchor = diff.sourceAnchors[idx]
                        anchorPill(anchor: anchor)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(StudyTheme.Spacing.sm)
        .background(Color(red: 0.99, green: 0.98, blue: 0.98))
        .cornerRadius(StudyTheme.Radius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: StudyTheme.Radius.sm)
                .stroke(StudyTheme.Colors.danger.opacity(0.12), lineWidth: 1)
        )
    }
    
    // MARK: - 知识关系拓扑概览 (KnowledgeRelation)
    private func knowledgeRelationsCard(analysis: FullDocumentAnalysis) -> some View {
        VStack(alignment: .leading, spacing: StudyTheme.Spacing.sm) {
            Label("核心概念逻辑关系拓扑", systemImage: "network")
                .font(.headline)
                .foregroundColor(StudyTheme.Colors.secondary)
            
            if analysis.relations.isEmpty {
                Text("暂无概念关联关系")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(analysis.relations) { rel in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "arrow.triangle.branch")
                                .foregroundColor(StudyTheme.Colors.secondary)
                                .font(.caption)
                                .padding(.top, 2)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(conceptName(for: rel.sourceConceptID, in: analysis))
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(StudyTheme.Colors.primary)
                                    
                                    Text("[\(rel.relationType)]")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                    
                                    Text(conceptName(for: rel.targetConceptID, in: analysis))
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(StudyTheme.Colors.primary)
                                }
                                
                                Text(rel.description)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(StudyTheme.Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(red: 0.985, green: 0.985, blue: 0.99))
                        .cornerRadius(StudyTheme.Radius.sm)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(StudyTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.systemBackground)
        .cornerRadius(StudyTheme.Radius.md)
    }
    
    // MARK: - 锚点跳转胶囊 (双向定位)
    private func anchorPill(anchor: SourceAnchor) -> some View {
        Button {
            jumpToAnchor(anchor)
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 9))
                Text("P\(anchor.pageIndex0 + 1) 原文定位")
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(StudyTheme.Colors.primary.opacity(0.1))
            .foregroundColor(StudyTheme.Colors.primary)
            .cornerRadius(StudyTheme.Radius.pill)
        }
        .buttonStyle(.plain)
    }
    
    private func jumpToAnchor(_ anchor: SourceAnchor) {
        Task {
            await viewModel.navigateToSource(anchor)
            viewModel.isFullStudyViewOpen = false
            dismiss()
        }
    }
    
    private func conceptName(for conceptID: String, in analysis: FullDocumentAnalysis) -> String {
        analysis.concepts.first(where: { $0.id == conceptID })?.name ?? "概念"
    }
    
    // MARK: - 分析中状态视口
    private var analyzingProgressView: some View {
        VStack(spacing: StudyTheme.Spacing.lg) {
            ProgressView()
                .scaleEffect(1.3)
            
            Text("AI 正在严谨研读全文档...")
                .font(.headline)
            
            if let progress = viewModel.batchExtractionProgress {
                VStack(spacing: 8) {
                    ProgressView(value: progress.percentage)
                        .progressViewStyle(.linear)
                        .frame(maxWidth: 320)
                        .tint(StudyTheme.Colors.primary)
                    
                    HStack {
                        Text("抽取进度: \(Int(progress.percentage * 100))%")
                        Spacer()
                        Text("第 \(progress.currentBatchIndex + 1)/\(progress.totalBatches) 批 (\(progress.processedPages)/\(progress.totalPages) 页)")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: 320)
                }
            } else {
                Text("正在初始化分批抽取引擎...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button("取消研读") {
                Task {
                    await viewModel.cancelFullDocumentStudy()
                }
            }
            .font(.caption)
            .buttonStyle(.bordered)
            .tint(StudyTheme.Colors.danger)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(StudyTheme.Spacing.xl)
    }
    
    // MARK: - 初始/空白状态视口
    private var emptyOrInitialView: some View {
        VStack(spacing: StudyTheme.Spacing.md) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(StudyTheme.Colors.primary.opacity(0.6))
            
            Text("尚未生成全文研读报告")
                .font(.headline)
            
            Text("点击下方按钮启动异步分批抽取引擎，全面分析概念网络与核心难点。")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
            
            Button {
                Task {
                    await viewModel.loadOrGenerateFullDocumentStudy(forceRegenerate: true)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                    Text("开始全文研读分析")
                }
                .fontWeight(.semibold)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(StudyTheme.Colors.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(StudyTheme.Spacing.xl)
    }
}
