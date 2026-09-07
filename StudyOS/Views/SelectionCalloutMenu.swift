import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// 选区浮动快捷菜单 (Selection Callout Menu)
/// 严格对齐 PRD R05 与 COMPONENTS-AND-STATES.md 规范
/// 支持高亮、下划线、复制、✨助学解释、加入笔记五大核心能力
public struct SelectionCalloutMenu: View {
    public let anchor: SourceAnchor
    public let screenRect: CGRect
    public let onAIExplain: () -> Void
    public let onAddToNote: () -> Void
    public let onHighlight: () -> Void
    public let onUnderline: () -> Void
    public let onDismiss: () -> Void
    
    public init(
        anchor: SourceAnchor,
        screenRect: CGRect,
        onAIExplain: @escaping () -> Void,
        onAddToNote: @escaping () -> Void,
        onHighlight: @escaping () -> Void = {},
        onUnderline: @escaping () -> Void = {},
        onDismiss: @escaping () -> Void
    ) {
        self.anchor = anchor
        self.screenRect = screenRect
        self.onAIExplain = onAIExplain
        self.onAddToNote = onAddToNote
        self.onHighlight = onHighlight
        self.onUnderline = onUnderline
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        HStack(spacing: StudyTheme.Spacing.xs) {
            // ✨ AI 助学解释 (核心主推操作)
            Button {
                onAIExplain()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .foregroundColor(StudyTheme.Colors.accent)
                    Text("✨ 助学解释")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .padding(.horizontal, StudyTheme.Spacing.sm)
                .padding(.vertical, 6)
                .background(StudyTheme.Colors.primary.opacity(0.12))
                .foregroundColor(StudyTheme.Colors.primary)
                .cornerRadius(StudyTheme.Radius.pill)
            }
            .buttonStyle(.plain)
            
            Divider()
                .frame(height: 18)
                .background(StudyTheme.Colors.divider)
            
            // 复制
            Button {
                #if canImport(UIKit)
                if let quote = anchor.quote {
                    UIPasteboard.general.string = quote
                }
                #endif
                onDismiss()
            } label: {
                Label("复制", systemImage: "doc.on.doc")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            
            // 高亮
            Button {
                onHighlight()
                onDismiss()
            } label: {
                Label("高亮", systemImage: "highlighter")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            
            // 下划线
            Button {
                onUnderline()
                onDismiss()
            } label: {
                Label("下划线", systemImage: "underline")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            
            // 加入笔记
            Button {
                onAddToNote()
            } label: {
                Label("存笔记", systemImage: "square.and.pencil")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, StudyTheme.Spacing.sm)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: StudyTheme.Radius.pill)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: StudyTheme.Radius.pill)
                        .stroke(StudyTheme.Colors.border, lineWidth: 1)
                )
        )
        // 浮动在选区上方
        .position(
            x: max(160, min(screenRect.midX, 600)),
            y: max(50, screenRect.minY - 32)
        )
        .transition(.opacity.combined(with: .scale(scale: 0.92)))
        .zIndex(100)
    }
}
