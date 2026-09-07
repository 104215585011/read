import SwiftUI

/// 笔记卡片视图组件 (NoteCardView)
/// 严格对应 Note 契约模型与 UIREV-06 规范
/// 支持独立展示、AI 派生归属标签与原文档删除后的解绑指示
public struct NoteCardView: View {
    public let note: Note
    public let onNavigateToSource: ((SourceAnchor) -> Void)?
    public let onDeleteNote: (() -> Void)?
    
    @State private var isEditing: Bool = false
    @State private var currentText: String
    
    public init(
        note: Note,
        onNavigateToSource: ((SourceAnchor) -> Void)? = nil,
        onDeleteNote: (() -> Void)? = nil
    ) {
        self.note = note
        self.onNavigateToSource = onNavigateToSource
        self.onDeleteNote = onDeleteNote
        self._currentText = State(initialValue: note.editableText)
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: StudyTheme.Spacing.sm) {
            // 顶栏：AI 来源标签与时间戳
            HStack {
                if let ai = note.aiOrigin {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .foregroundColor(StudyTheme.Colors.accent)
                        Text("AI 助学生成")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(StudyTheme.Colors.accent.opacity(0.12))
                    .foregroundColor(StudyTheme.Colors.accent)
                    .cornerRadius(StudyTheme.Radius.sm)
                }
                
                Spacer()
                
                Text(note.updatedAt, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                if let onDelete = onDeleteNote {
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // 笔记内容主体
            Text(currentText)
                .font(.body)
                .lineSpacing(3)
                .foregroundColor(.primary)
            
            // 来源引用胶囊组
            if !note.sourceAnchors.isEmpty {
                Divider()
                    .background(StudyTheme.Colors.divider)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("关联来源:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: StudyTheme.Spacing.xs) {
                            ForEach(note.sourceAnchors.indices, id: \.self) { idx in
                                let anchor = note.sourceAnchors[idx]
                                citationBadge(anchor: anchor)
                            }
                        }
                    }
                }
            }
        }
        .padding(StudyTheme.Spacing.md)
        .background(Color(red: 0.98, green: 0.98, blue: 0.99))
        .cornerRadius(StudyTheme.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: StudyTheme.Radius.md)
                .stroke(StudyTheme.Colors.border, lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private func citationBadge(anchor: SourceAnchor) -> some View {
        let isDocDeleted = anchor.availability == .documentDeleted
        
        Button {
            if !isDocDeleted {
                onNavigateToSource?(anchor)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isDocDeleted ? "doc.badge.ellipsis" : "arrow.up.right.square")
                    .font(.system(size: 10))
                
                if isDocDeleted {
                    Text("P\(anchor.pageIndex0 + 1) (原文档已删除)")
                        .font(.caption2)
                        .strikethrough()
                } else {
                    Text("P\(anchor.pageIndex0 + 1) 来源")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isDocDeleted ? Color.gray.opacity(0.15) : StudyTheme.Colors.primary.opacity(0.1))
            .foregroundColor(isDocDeleted ? .secondary : StudyTheme.Colors.primary)
            .cornerRadius(StudyTheme.Radius.pill)
        }
        .buttonStyle(.plain)
        .disabled(isDocDeleted)
    }
}
