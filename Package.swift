// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ZhiMing",
    platforms: [
        .iOS(.v17),
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
        .target(
            name: "ZhiMing",
            swiftSettings: [
                // 实施计划基于 Swift 5.9 语义；避免 Swift 6 严格并发模式对大量存量代码的破坏
                .swiftLanguageMode(.v5)
            ]
        ),
    ]
)
