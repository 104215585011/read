import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

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
        
        /// 统一跨平台系统背景色令牌
        public static var systemBackground: Color {
            #if canImport(UIKit)
            return Color(uiColor: .systemBackground)
            #else
            return Color.white
            #endif
        }
        
        /// 阅读器底衬温润纸张色 (Warm Paper Background)
        public static let paperBackground = Color(red: 0.980, green: 0.973, blue: 0.961) // #FAF8F5
        
        /// 专业护眼纸张色板 (Eye-Care Paper Themes, M4-RELEASE)
        /// 纯白精细: 极致清晰纯净
        public static let pureWhite = Color(red: 0.992, green: 0.992, blue: 0.996) // #FDFDFE
        /// 护眼羊皮纸暖黄: 过滤高能蓝光，温润护眼
        public static let warmSepia = Color(red: 0.965, green: 0.941, blue: 0.898) // #F6F0E5
        /// 墨水屏哑光灰: 类电子墨水漫反射质感
        public static let eInkGray = Color(red: 0.918, green: 0.918, blue: 0.906) // #EAEAE7
        /// 夜间深邃黑: 低亮度高对比防眩光
        public static let nightDark = Color(red: 0.118, green: 0.125, blue: 0.141) // #1E2024
        
        /// 边框与微弱分割线
        public static let border = Color.primary.opacity(0.08)
        public static let divider = Color.primary.opacity(0.06)
        
        /// 引用高亮边框色
        public static let citationHighlight = Color(red: 0.145, green: 0.388, blue: 0.922).opacity(0.85)
        /// 来源聚焦光环底色
        public static let focusRingGlow = Color(red: 0.145, green: 0.388, blue: 0.922).opacity(0.18)
    }

    // MARK: - 纸张与护眼主题 (Paper & Eye-Care Themes)
    public enum PaperTheme: String, CaseIterable, Identifiable, Sendable {
        case pureWhite = "pureWhite"
        case warmSepia = "warmSepia"
        case eInkGray = "eInkGray"
        case nightDark = "nightDark"
        
        public var id: String { rawValue }
        
        public var displayName: String {
            switch self {
            case .pureWhite: return "纯白精细"
            case .warmSepia: return "羊皮暖黄"
            case .eInkGray: return "水墨哑光"
            case .nightDark: return "夜间深邃"
            }
        }
        
        public var iconName: String {
            switch self {
            case .pureWhite: return "doc.plaintext"
            case .warmSepia: return "sun.max"
            case .eInkGray: return "newspaper"
            case .nightDark: return "moon.stars"
            }
        }
        
        public var backgroundColor: Color {
            switch self {
            case .pureWhite: return Colors.pureWhite
            case .warmSepia: return Colors.warmSepia
            case .eInkGray: return Colors.eInkGray
            case .nightDark: return Colors.nightDark
            }
        }
        
        public var textColor: Color {
            switch self {
            case .nightDark: return Color(red: 0.88, green: 0.89, blue: 0.90)
            default: return Color.primary
            }
        }
        
        public var isDark: Bool {
            self == .nightDark
        }
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

// MARK: - 共享系统色彩扩展
extension Color {
    public static var systemBackground: Color {
        StudyTheme.Colors.systemBackground
    }
}

