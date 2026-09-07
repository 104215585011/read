// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "StudyOS",
    defaultLocalization: "zh-Hans",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "StudyOS",
            targets: ["StudyOS"]
        ),
    ],
    dependencies: [
        // 本地优先设计，核心服务层保持纯原生、零外部重度第三方依赖
    ],
    targets: [
        .target(
            name: "StudyOS",
            dependencies: [],
            path: "StudyOS"
        ),
        .testTarget(
            name: "StudyOSTests",
            dependencies: ["StudyOS"],
            path: "StudyOSTests"
        ),
    ],
    swiftLanguageVersions: [.v5]
)
