// swift-tools-version: 6.0
import PackageDescription

// 这是模板,不是可直接发布的 app。`tools/new-app.sh` 会把 TemplateApp 换成目标名称。
let package = Package(
    name: "TemplateApp",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "TemplateAppCore", targets: ["TemplateAppCore"]),
        .executable(name: "TemplateApp", targets: ["TemplateApp"]),
    ],
    targets: [
        .target(name: "TemplateAppCore"),
        .executableTarget(
            name: "TemplateApp",
            dependencies: ["TemplateAppCore"]
        ),
        .testTarget(
            name: "TemplateAppCoreTests",
            dependencies: ["TemplateAppCore"]
        ),
    ],
    // 与 apps/ 下的工程保持一致:Swift 5 语言模式,避免严格并发在 UI 探测代码上的摩擦。
    swiftLanguageModes: [.v5]
)
