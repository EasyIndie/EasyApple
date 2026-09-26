# 02 — 跨平台开发能力(2026-09 快照)

> **状态:规划期调研,未在真机验证。** 本文回答:「不买 Mac,能用哪些方式写/构建
> Apple 平台的 app?」结论按「能不能真正产出 iOS app」分级。
>
> ⚠️ 本仓库已定 **arm64-only + 只用 Mac**(见 [`../00-decisions.md`](../00-decisions.md) D13),
> 本文的「无 Mac 设备链路」仅作备选记录,首期不采用。

## 1. 一句话结论

- **Swift 语言本身已经真正跨平台**(Windows / Linux / Android 都有官方 toolchain)。
- **但 SwiftUI / UIKit / 大量 Foundation 的 Apple 专有部分不开源、不可移植。**
- **所以「用 Swift 写跨平台逻辑」可行,「用 SwiftUI 写跨平台 UI 再直接跑在非 Apple
  设备上」不可行**(除非用转译/重实现方案,见 §3)。

## 2. Swift 官方跨平台支持

| 平台 | 官方支持 | 能跑 SwiftUI/UIKit 吗 |
|---|---|---|
| Windows 10/11 | ✅ 官方 toolchain(winget `Swift.Toolchain`,需 VS2022 C++ 工作负载) | ❌ |
| Linux(Ubuntu / Debian / Fedora / RHEL …) | ✅ 官方 + [`swiftly`](https://www.swift.org/install/linux/) 安装器 | ❌ |
| **Android** | ✅ **官方 Swift SDK for Android**(`swift-6.4.0-RELEASE_android.artifactbundle`) | ❌ |
| Apple 平台(iOS/macOS/watchOS/tvOS/visionOS) | ✅ 经 Xcode | ✅ |

**来源**:[swift.org/install/windows](https://www.swift.org/install/windows/)、
[swift.org/install/linux](https://www.swift.org/install/linux/)、
[Swift SDK for Android 入门](https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html)。

> 意义:SwiftPM 包里的**纯逻辑层**(`EnvDemoCore`)理论上可以编译到 Android/Linux/Windows。
> UI 层不行。这也是我们把包**分成 Core + App 两层**的原因之一(见 `PLAN.md` Phase B)。

## 3. 「SwiftUI 跨平台」的社区替代方案

| 方案 | 做法 | 局限 |
|---|---|---|
| [`moreSwift/swift-cross-ui`](https://github.com/moreSwift/swift-cross-ui)(~1.7k★) | 类 SwiftUI 的声明式 UI,后端 GTK / AppKit / WinUI | **不是 SwiftUI**,API 只是相似;生态小 |
| Tokamak | SwiftUI 子集渲染到 Web | 只覆盖子集 |
| OpenSwiftUI | 开源重实现 SwiftUI | 早期阶段 |
| [Skip](https://skip.tools) | 把 SwiftUI 源码**转译**成 Android Jetpack Compose | 转译而非运行时;iOS 侧仍需 Mac |
| Kotlin Multiplatform / Compose MP | Kotlin 写共享 UI,iOS 目标 | **Apple target 必须在 macOS 上编译** |
| Flutter / React Native / .NET MAUI / Unity / Godot | 各自的 iOS 构建 | **iOS 构建都需要 macOS**(或配对 Mac agent / 云 Mac) |

## 4. 完全不装 Xcode 的「设备构建」链路(真实存在)

如果你想在 Windows/Linux 上构建**真机**用的 iOS app,这条路是通的(**但没有模拟器**):

| 环节 | 工具 |
|---|---|
| 交叉编译 | [Theos](https://github.com/theos/theos) + LLVM/clang + linker + Apple SDK |
| Windows 原生 | [CacheW/TheosWin](https://github.com/CacheW/TheosWin):无需 WSL/VM/Mac,支持 C/ObjC/C++/**Swift**、多 SDK(16.5/18.6/26.5),用 `ldid` 签名,打包 `.deb`/`.ipa`。README 声称已在真机端到端验证(iOS 17.6.1 iPad + iOS 27.0 iPhone) |
| 一键跨平台 | [`xtool-org/xtool`](https://github.com/xtool-org/xtool)(~5.5k★,2026-09 活跃):Linux/WSL/macOS 上从 SwiftPM 构建并部署 iOS app。**仍需下载 `Xcode.xip` 提取「darwin Swift SDK」**,且**面向真机、不管模拟器**。详见 [04](04-swiftpm-packaging.md) |
| 签名 | `zsign` / `ldid` / `rcodesign` 等跨平台重实现 |
| 设备通信 | [libimobiledevice](https://github.com/libimobiledevice/libimobiledevice)、
[pymobiledevice3](https://github.com/doronz88/pymobiledevice3)、`ideviceinstaller` |
| 上传/元数据 | `fastlane`(Ruby,可跨平台)、App Store Connect API、Transporter(Java) |

> ⚠️ 这条路偏「越狱 / 侧载」生态,签名用的是自签或开发者证书,不适合作为上架正路;
> 而且**它解决的是「编译不需要 Mac」,不解决「看界面/跑模拟器不需要 Mac」**。

## 5. 与 EasyAndroid 的对照(为什么 Apple 更难)

| | Android | Apple |
|---|---|---|
| 官方 SDK 获取 | 独立 `cmdline-tools`,不装 IDE | **只能随完整 Xcode** |
| 编译器运行平台 | Windows/Linux/macOS | **仅 macOS**(官方) |
| 真机调试 | `adb`,零门槛 | 需要证书/profile(免费账号 7 天) |
| 界面验证 | `uiautomator dump` 文本树 | 需 `idb`/XCUITest 或截图 |
| 完全跨平台的可能 | 官方支持 | 只能靠非官方交叉工具链(无模拟器) |

## 6. 怎么复核

- Windows: `winget install --id Swift.Toolchain -e --source winget`,然后 `swift --version`。
- Linux: 按 [swift.org/install/linux](https://www.swift.org/install/linux/) 装 `swiftly`。
- 想验证 xtool: 见其 [Linux 安装文档](https://xtool.sh/documentation/xtooldocs/installation-linux),
  需要 Swift 6.4 + `usbmuxd` + `Xcode.xip`。**本仓库首期不做这条,仅作备选记录。**

## 7. 参考链接

- Swift on Windows: https://www.swift.org/install/windows/
- Swift on Linux: https://www.swift.org/install/linux/
- Swift SDK for Android: https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html
- SwiftCrossUI: https://github.com/moreSwift/swift-cross-ui
- Theos / TheosWin: https://github.com/theos/theos , https://github.com/CacheW/TheosWin
- xtool: https://github.com/xtool-org/xtool
- libimobiledevice: https://github.com/libimobiledevice/libimobiledevice
- pymobiledevice3: https://github.com/doronz88/pymobiledevice3
