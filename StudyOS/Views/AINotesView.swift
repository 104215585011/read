import SwiftUI

/// AI 笔记沉淀流视图 (AINotesView - R11 P1 核心能力)
/// 严格对应 PRD R11 与 COMPONENTS-AND-STATES.md 规约
/// 支持卡片式笔记流呈现、关联来源引用胶囊双向定位、时间戳与手写批注关联标记、两路删除联动显示
public struct AINotesView: View {
    @ObservedObject public var viewModel: ReaderViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText: String = ""
    @State private var selectedTag: String? = nil
    
    public init(viewModel: ReaderViewModel) {
        self.viewModel = viewModel
    }
    
    // 过滤后的笔记列表
    private var filteredNotes: [AINoteCard] {
        viewModel.aiNotes.filter { note in
            let matchSearch = searchText.isEmpty
                || note.title.localizedCaseInsensitiveContains(searchText)
                || note.markdownContent.localizedCaseInsensitiveContains(searchText)
            
            let matchTag = selectedTag == nil || note.tags.contains(selectedTag ?? "")
            return matchSearch && matchTag
        }
    }
    
    // 收集所有已知标签
    private var allTags: [String] {
        Array(Set(viewModel.aiNotes.flatMap { $0.tags })).sorted()
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 顶部标签过滤条
                if !allTags.isEmpty {
                    tagFilterBar
                }
                
                Divider()
                    .background(StudyTheme.Colors.divider)
                
                // 笔记卡片流
                if filteredNotes.isEmpty {
                    emptyNotesView
                } else {
                    notesCardList
                }
            }
            .navigationTitle("AI 笔记 (R11)")
            .searchable(text: $searchText, prompt: "搜索 AI 笔记标题或内容...")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        viewModel.isAINotesOpen = false
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Text("\(viewModel.aiNotes.count) 条笔记")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .background(Color(red: 0.985, green: 0.985, blue: 0.99))
        }
        .task {
            await viewModel.loadAINotes()
        }
    }
    
    // MARK: - 标签过滤条
    private var tagFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Button {
                    selectedTag = nil
                } label: {
                    Text("全部")
                        .font(.caption2)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(selectedTag == nil ? StudyTheme.Colors.primary : Color.clear)
                        .foregroundColor(selectedTag == nil ? .white : .primary)
                        .cornerRadius(StudyTheme.Radius.pill)
                }
                .buttonStyle(.plain)
                
                ForEach(allTags, id: \.self) { tag in
                    Button {
                        if selectedTag == tag {
                            selectedTag = nil
                        } else {
                            selectedTag = tag
                        }
                    } label: {
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(selectedTag == tag ? StudyTheme.Colors.primary : StudyTheme.Colors.primary.opacity(0.1))
                            .foregroundColor(selectedTag == tag ? .white : StudyTheme.Colors.primary)
                            .cornerRadius(StudyTheme.Radius.pill)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, StudyTheme.Spacing.md)
            .padding(.vertical, 8)
        }
        .background(Color.systemBackground)
    }
    
    // MARK: - 笔记卡片列表
    private var notesCardList: some View {
        ScrollView {
            LazyVStack(spacing: StudyTheme.Spacing.md) {
                ForEach(filteredNotes) { note in
                    aiNoteCardRow(note: note)
                }
            }
            .padding(StudyTheme.Spacing.md)
        }
    }
    
    // MARK: - 单个 AI 笔记卡片
    private func aiNoteCardRow(note: AINoteCard) -> some View {
        VStack(alignment: .leading, spacing: StudyTheme.Spacing.sm) {
            // 顶栏：标签、AI 标识、时间戳与删除
            HStack(alignment: .center) {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                    Text("AI 研读沉淀")
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(StudyTheme.Colors.accent.opacity(0.12))
                .foregroundColor(StudyTheme.Colors.accent)
                .cornerRadius(StudyTheme.Radius.sm)
                
                ForEach(note.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(StudyTheme.Radius.sm)
                }
                
                Spacer()
                
                Text(note.createdAt, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Button(role: .destructive) {
                    Task {
                        await viewModel.deleteAINote(id: note.id)
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // 笔记标题
            Text(note.title)
                .font(.headline)
                .foregroundColor(.primary)
            
            // 笔记正文
            Text(note.markdownContent)
                .font(.subheadline)
                .lineSpacing(3)
                .foregroundColor(.primary.opacity(0.9))
            
            Divider()
                .background(StudyTheme.Colors.divider)
            
            // 底栏：来源引用胶囊与手写墨水关联标记
            HStack(alignment: .center, spacing: 8) {
                // 手写批注关联标记
                HStack(spacing: 3) {
                    Image(systemName: "pencil.tip.crop.circle")
                        .font(.system(size: 10))
                    Text("批注联动")
                        .font(.caption2)
                }
                .foregroundColor(StudyTheme.Colors.secondary)
                .padding(.trailing, 4)
                
                // 来源引用胶囊
                if !note.sourceSnapshot.sourceAnchors.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(note.sourceSnapshot.sourceAnchors.indices, id: \.self) { idx in
                                let anchor = note.sourceSnapshot.sourceAnchors[idx]
                                noteAnchorBadge(anchor: anchor)
                            }
                        }
                    }
                } else {
                    Text("整篇概览来源")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(StudyTheme.Spacing.md)
        .background(Color.systemBackground)
        .cornerRadius(StudyTheme.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: StudyTheme.Radius.md)
                .stroke(StudyTheme.Colors.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.02), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - 来源胶囊与两路删除指示
    private func noteAnchorBadge(anchor: SourceAnchor) -> some View {
        let isDocDeleted = anchor.availability == .documentDeleted
        
        return Button {
            if !isDocDeleted {
                Task {
                    await viewModel.navigateToSource(anchor)
                    viewModel.isAINotesOpen = false
                    dismiss()
                }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: isDocDeleted ? "doc.badge.ellipsis" : "arrow.up.right.square")
                    .font(.system(size: 9))
                
                if isDocDeleted {
                    Text("P\(anchor.pageIndex0 + 1) (原书已删)")
                        .font(.caption2)
                        .strikethrough()
                } else {
                    Text("P\(anchor.pageIndex0 + 1) 原文")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(isDocDeleted ? Color.gray.opacity(0.12) : StudyTheme.Colors.primary.opacity(0.1))
            .foregroundColor(isDocDeleted ? .secondary : StudyTheme.Colors.primary)
            .cornerRadius(StudyTheme.Radius.pill)
        }
        .buttonStyle(.plain)
        .disabled(isDocDeleted)
    }
    
    // MARK: - 空白状态
    private var emptyNotesView: some View {
        VStack(spacing: StudyTheme.Spacing.md) {
            Image(systemName: "note.text.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(StudyTheme.Colors.accent.opacity(0.6))
            
            Text("暂无 AI 笔记")
                .font(.headline)
            
            Text("在 AI 助学侧栏中提问或在全文学习研读视图中，点击「存为 AI 笔记」，即可将精华考点与导引沉淀为卡片笔记。")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(StudyTheme.Spacing.xl)
    }
}
