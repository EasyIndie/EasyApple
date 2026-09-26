# 02 — SwiftPM 工程范式(Core / App 分层)

> **状态:已在 Air 实测**(`swift build` 通过 / `swift test` 3 用例全绿)。

## 1. 分层

```
apps/EnvDemo/
├── Package.swift
├── Sources/
│   ├── EnvDemoCore/      # library:纯逻辑,不 import SwiftUI,可 swift test
│   └── EnvDemo/          # executable:@main SwiftUI App,只做 UI 绑定
└── Tests/
    └── EnvDemoCoreTests/ # 只测 Core 的纯逻辑
```

**为什么分层**:打包工具只负责「把 executable 变成 `.app`」,分层后核心逻辑不依赖 UI 框架,
`swift test` 可在宿主机秒级跑;未来核心逻辑理论上还能编译到其他平台。

## 2. Package.swift(实测可用)

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EnvDemo",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "EnvDemoCore", targets: ["EnvDemoCore"]),
        .executable(name: "EnvDemo", targets: ["EnvDemo"]),
    ],
    targets: [
        .target(name: "EnvDemoCore"),
        .executableTarget(name: "EnvDemo", dependencies: ["EnvDemoCore"]),
        .testTarget(name: "EnvDemoCoreTests", dependencies: ["EnvDemoCore"]),
    ],
    // 刻意用 Swift 5 语言模式:规避 Swift 6 严格并发在 UIKit/AppKit 探测代码上的摩擦。
    swiftLanguageModes: [.v5]
)
```

要点:
- `swift-tools-version: 6.0`(Air 上是 Swift 6.4,向下兼容 6.0)。
- **`swiftLanguageModes: [.v5]`**:tools-version 6.0 默认启用 Swift 6 严格并发,而环境探测
  代码要摸 `UIScreen.main` / `NSScreen.main` 等,`.v5` 能少一大堆并发标注。这是「刻意保守」。
- `platforms` 决定 `minos`(实测:构建出的 iOS 二进制 `minos 17.0`)。

## 3. 跨平台探测的写法

`EnvDemoCore` 里按平台条件编译,避免把 UI 框架硬塞给 library:

```swift
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
```

`screenSizePoints()` 用 `#if canImport(AppKit) / #elseif canImport(UIKit) / #else` 三段,
**不要在 `#endif` 后再写 `return`**(会触发 dead-code 警告,实测遇到过)。

## 4. 构建与测试(实测命令)

```bash
# macOS(宿主机)
xcrun swift build            # Build complete!
xcrun swift test             # Executed 3 tests, 0 failures

# iOS 模拟器(交叉编译,见 04)
xcrun swift build -c release --triple arm64-apple-ios-simulator \
  --sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)"
```

用封装脚本:`tools/build.sh` / `tools/test.sh`。

## 5. 单元测试的可测性

只测**纯逻辑**(如 `formatBytes` / `formatAsText`),不测真实环境读取。

- `formatBytes`:固定 `en_US_POSIX` locale,输出确定(避免 `ByteCountFormatter` 的本地化差异)。
- 用整数字面量断言:`formatBytes(17_179_869_184) == "16.00 GB"`。
