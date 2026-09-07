import SwiftUI

/// StudyOS 原生 App 主入口
/// 组装 CoreService 门面与 LibraryView 初始工作流
@main
public struct StudyOSApp: App {
    private let coreService: CoreServiceProtocol
    
    public init() {
        self.coreService = CoreService.makeDefault()
    }
    
    public var body: some Scene {
        WindowGroup {
            LibraryView(coreService: coreService)
                .accentColor(StudyTheme.Colors.primary)
        }
    }
}
