// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ZhiMing",
    platforms: [
        .iOS(.v15),
        .macOS(.v14),
    ],
    products: [
        // xtool 工程应且只包含一个 library 产物，代表主 App
        .library(
            name: "ZhiMing",
            targets: ["ZhiMing"]
        ),
    ],
    targets: [
        // 纯逻辑层（模型 + 服务）：不依赖 UIKit/SwiftUI，可在 Linux 上 swift test
        .target(
            name: "ZhiMingCore",
            resources: [
                // R18 增强用的本地 Skill 包（fictional-erotica 单语言提取版）
                .copy("Resources/SkillPacks"),
            ],
            swiftSettings: [
                // 实施计划基于 Swift 5.9 语义；避免 Swift 6 严格并发模式对大量存量代码的破坏
                .swiftLanguageMode(.v5)
            ]
        ),
        .target(
            name: "ZhiMing",
            dependencies: ["ZhiMingCore"],
            resources: [
                // 分析进度页的祈祷 GIF
                .copy("Resources/praying.gif"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
            // 立项会话缓存使用系统自带 SQLite（libsqlite3.tbd，无第三方依赖）
            linkerSettings: [
                .linkedLibrary("sqlite3"),
            ]
        ),
        .testTarget(
            name: "ZhiMingCoreTests",
            dependencies: ["ZhiMingCore"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
    ]
)
