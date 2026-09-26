// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EnvDemo",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "EnvDemoCore", targets: ["EnvDemoCore"]),
        .executable(name: "EnvDemo", targets: ["EnvDemo"]),
    ],
    targets: [
        .target(name: "EnvDemoCore"),
        .executableTarget(
            name: "EnvDemo",
            dependencies: ["EnvDemoCore"]
        ),
        .testTarget(
            name: "EnvDemoCoreTests",
            dependencies: ["EnvDemoCore"]
        ),
    ],
    // 刻意用 Swift 5 语言模式:规避 Swift 6 严格并发在 UIKit/AppKit 探测代码上的摩擦。
    // tools-version 仍为 6.0(见 PLAN B1),仅放宽语言模式。
    swiftLanguageModes: [.v5]
)
