import SwiftUI

/// 来源定位发光边框动画层 (Source Anchor Focus Ring)
/// 严格对齐 READER-ADAPTER-SPEC.md 4.2 动效规范
/// 支持无障碍 Reduce Motion 静态降级，点击穿透 (allowsHitTesting false)
public struct SourceAnchorFocusRing: View {
    public let screenRect: CGRect
    public let token: UUID
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var opacity: Double = 0.0
    @State private var scale: CGFloat = 1.0
    @State private var isVisible: Bool = true
    
    public init(screenRect: CGRect, token: UUID) {
        self.screenRect = screenRect
        self.token = token
    }
    
    public var body: some View {
        Group {
            if isVisible && screenRect.width > 0 && screenRect.height > 0 {
                ZStack {
                    // 外发光底衬
                    RoundedRectangle(cornerRadius: StudyTheme.Radius.sm)
                        .fill(StudyTheme.Colors.focusRingGlow)
                        .scaleEffect(scale)
                    
                    // 细实线边框
                    RoundedRectangle(cornerRadius: StudyTheme.Radius.sm)
                        .stroke(StudyTheme.Colors.citationHighlight, lineWidth: 2.0)
                        .scaleEffect(scale)
                }
                .frame(width: max(20, screenRect.width + 12), height: max(16, screenRect.height + 8))
                .position(x: screenRect.midX, y: screenRect.midY)
                .opacity(opacity)
                .allowsHitTesting(false) // 杜绝阻断手绘批注与阅读触控
            }
        }
        .onAppear {
            startAnimation()
        }
        .onChange(of: token) { _ in
            startAnimation()
        }
    }
    
    private func startAnimation() {
        isVisible = true
        if reduceMotion {
            // Reduce Motion 适配：静态半透明边框常驻 1.5 秒后平滑淡出，不产生缩放脉冲
            opacity = 0.85
            scale = 1.0
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeOut(duration: 0.3)) {
                    opacity = 0.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isVisible = false
                }
            }
        } else {
            // 常规动效：淡入并执行 2 次呼吸脉冲缩放 (0.6s 周期，共 1.2s)，随后衰减
            opacity = 0.2
            scale = 1.0
            
            withAnimation(.easeInOut(duration: 0.3)) {
                opacity = 0.85
                scale = 1.04
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    scale = 0.98
                    opacity = 0.5
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    scale = 1.02
                    opacity = 0.8
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    scale = 1.0
                    opacity = 0.6
                }
            }
            
            // 2.0 秒后自然隐去
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 0.4)) {
                    opacity = 0.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    isVisible = false
                }
            }
        }
    }
}
