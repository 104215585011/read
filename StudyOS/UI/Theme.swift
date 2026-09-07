import SwiftUI

/// StudyOS 设计系统令牌与主题规约 (Theme & Design Tokens)
/// 遵循 PRD 学术极简主义哲学与 ARCHITECTURE-AND-FLOWS.md 规范
public enum StudyTheme {
    // MARK: - 色彩系统 (Color Palette)
    public enum Colors {
        /// 学术主蓝 (Academic Blue)
        public static let primary = Color(red: 0.145, green: 0.388, blue: 0.922) // #2563EB
        /// 辅助靛蓝 (Deep Indigo)
        public static let secondary = Color(red: 0.310, green: 0.275, blue: 0.898) // #4F46E5
        /// 灵感琥珀 / 提示金 (Insight Amber)
        public static let accent = Color(red: 0.851, green: 0.467, blue: 0.024) // #D97706
        /// 确认翠绿 (Verified Emerald)
        public static let success = Color(red: 0.020, green: 0.588, blue: 0.412) // #059669
        /// 警示玫红 (Warning Rose)
        public static let danger = Color(red: 0.882, green: 0.114, blue: 0.282) // #E11D48
        
        /// 阅读器底衬温润纸张色 (Warm Paper Background)
        public static let paperBackground = Color(red: 0.980, green: 0.973, blue: 0.961) // #FAF8F5
        
        /// 边框与微弱分割线
        public static let border = Color.primary.opacity(0.08)
        public static let divider = Color.primary.opacity(0.06)
        
        /// 引用高亮边框色
        public static let citationHighlight = Color(red: 0.145, green: 0.388, blue: 0.922).opacity(0.85)
        /// 来源聚焦光环底色
        public static let focusRingGlow = Color(red: 0.145, green: 0.388, blue: 0.922).opacity(0.18)
    }

    // MARK: - 间距系统 (Spacing Tokens)
    public enum Spacing {
        public static let xxs: CGFloat = 2
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 24
        public static let xxl: CGFloat = 32
        public static let xxxl: CGFloat = 48
    }

    // MARK: - 圆角系统 (Corner Radii)
    public enum Radius {
        public static let sm: CGFloat = 6
        public static let md: CGFloat = 10
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 24
        public static let pill: CGFloat = 999
    }

    // MARK: - 布局尺寸与断点约束 (Layout Constraints)
    public enum Layout {
        /// 阅读区舒适下限 (UIREV-02 / ARCHITECTURE-AND-FLOWS.md 严格约束)
        public static let minimumReaderWidth: CGFloat = 540
        /// AI 侧栏推荐最小宽度
        public static let sidebarMinWidth: CGFloat = 320
        /// AI 侧栏推荐最大宽度
        public static let sidebarMaxWidth: CGFloat = 400
        /// 分栏模式自适应阈值 (屏幕宽 >= 900pt 时支持左右分栏，否则折叠为抽屉 Sheet)
        public static let splitThresholdWidth: CGFloat = 900
        /// 选区浮动菜单高度基准
        public static let calloutMenuHeight: CGFloat = 44
    }

    // MARK: - 动效规范 (Motion & Animation)
    public enum Motion {
        /// 70/30 分栏阻尼动效 (UIREV-02)
        public static let splitSpring = Animation.spring(response: 0.35, dampingFraction: 0.82)
        /// 菜单淡入淡出
        public static let menuTransition = Animation.easeInOut(duration: 0.2)
        /// 来源高亮脉冲缩放周期
        public static let focusPulseDuration: Double = 0.6
    }
}
