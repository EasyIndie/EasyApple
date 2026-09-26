# 01 — Apple 平台开发规则(2026-09 快照)

> **状态:规划期调研,未在真机验证。** 本文所有版本号/日期都来自公开资料,权威性分级见每节
> 「来源」。**在 Air 上请以本机 `xcodebuild -version` / `xcrun` 的实际输出为准**
> (见文末「怎么复核」)。

## 1. 当前版本矩阵

| 组件 | 版本 | 备注 |
|---|---|---|
| **Xcode** | **27.0**(2026-09-14 发布,build `27A266a`) | 含 iOS 27.0 / macOS 27.0 / watchOS 27.0 / tvOS 27.0 / visionOS 27.0 SDK |
| 上一稳定大版本 | Xcode 26.x(26.0 = 2025-09-15;26.6 = 2026-06-25) | 26.x 仍在维护 |
| **macOS** | **26 Tahoe**(2025-09-15);macOS 27 在 beta | Tahoe 是**最后一个支持 Intel Mac 的 macOS 大版本** |
| **Swift** | **6.4**(swift.org 已发布 `swift-6.4.0-RELEASE`) | 各平台 toolchain(Windows/Linux/Android)同步 |
| **App Store 构建要求** | 必须 **Xcode 26 或更高** + 对应 iOS SDK | 见 §3 |
| App Review 指南最近更新 | **2026-06-08** | 见 §4 |

**来源**:
- Wikipedia [Xcode 版本历史表](https://en.wikipedia.org/wiki/Xcode)(数据源自 Apple release notes / xcodereleases.com)
- [swift.org/install/windows](https://www.swift.org/install/windows/)(列出 Swift 6.3.3 / 6.4 等)
- [swift.org 下载页](https://www.swift.org/install/linux/)(含 `swift-6.4.0-RELEASE_android.artifactbundle`)
- [Apple: Upcoming requirements](https://developer.apple.com/news/upcoming-requirements/)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

## 2. Xcode ↔ 最低运行 macOS

从 Wikipedia 的版本表抄下来的(单位:该 Xcode 大版本所需的**最低 macOS**)。

| Xcode | 最低 macOS | 自带 iOS SDK |
|---|---|---|
| 26.0 – 26.3 | macOS **15.6**(Sequoia) | iOS 26.0 – 26.2 |
| 26.4 – 26.6 | macOS **26.2**(Tahoe) | iOS 26.4 – 26.5 |
| **27.0** | macOS **26.6** | iOS 27.0 |

> ⚠️ 这张表直接决定了两台 Mac 的命运:
> - **MBP 2015 Early(Intel)最高 macOS 12 Monterey**(Wikipedia
>   [MacBook Pro (Intel-based) 支持表](https://en.wikipedia.org/wiki/MacBook_Pro_(Intel-based))),
>   所以**最高只能装 Xcode 14.2**(Xcode 14.3 起要求 Ventura 13)。
> - **MBA M1 支持 macOS 26 Tahoe**,可以装 Xcode 26 / 27。
>
> 首次进入本仓库请先确认 Air 的 `sw_vers` 与 `xcodebuild -version`,再决定装哪个 Xcode。

## 3. App Store 的硬性构建要求

Apple 的 [Upcoming requirements](https://developer.apple.com/news/upcoming-requirements/) 页面明确:
提交到 App Store 的 app 必须用 **Xcode 26 或更高**、并使用对应平台的 SDK 构建。
(原文:「…must be built with Xcode 26 or later using an SDK for iOS…」)

⚠️ 这条**只在你打算上架时才有约束**;模拟器开发和本机调试不受影响。
本仓库首期不做分发,所以它只是「未来会碰到」的约束,记录在此。

## 4. 其它 2025–2026 规则变化(与开发流程相关)

| 项 | 内容 | 影响 |
|---|---|---|
| 年龄分级问卷 | **2026-01-31** 前必须回答新的年龄分级问题,否则 app 更新会被拦截 | 上架相关,后置 |
| App Review 指南 | 2026-06-08 更新(持续小改) | 上架相关 |
| APNs 服务器证书 | 2025 年有生产/沙箱证书轮换 | 推送相关,后置 |
| visionOS | 「Developing for visionOS requires a Mac with Apple silicon」 | M1 Air 可做,Intel 不行 |

## 5. 「无 IDE」到底意味着什么(关键定性)

这是本仓库最容易踩的认知坑:

- **Android**:可以只装 `cmdline-tools`(SDK 命令行工具),完全不装 Android Studio。
  EasyAndroid 就是这么干的。
- **Apple**:**iOS SDK 只随完整 `Xcode.app` 提供。**只有 Command Line Tools(CLT)
  拿不到 iOS SDK,`xcrun --sdk iphonesimulator --show-sdk-path` 会失败。

因此 EasyApple 的「无 IDE」定义是:

> **装了完整 Xcode,但从不打开它的 GUI。所有操作走 `xcodebuild` / `xcrun` / `simctl` /
> `swift` 等命令行工具。**

佐证:`xtool`(跨平台构建 iOS 的工具)在 Linux 上的安装文档也要求先下载
`Xcode.xip`,再从中提取出 iOS Swift SDK —— 连跨平台方案都绕不开 Apple 的 SDK,
只是绕开了「在 Mac 上运行编译器」。见 [04](04-swiftpm-packaging.md)。

## 6. 签名与分发三条链路

| 链路 | 需要什么 | 本仓库首期 |
|---|---|---|
| 模拟器调试 | **零证书**,模拟器对签名几乎不校验(ad-hoc 即可) | ✅ 首期就做 |
| 真机调试 | 免费 Apple ID 可生成 7 天有效的 profile;付费账号($99/年)长期 | ⏳ 后置 |
| 分发(TestFlight / App Store / 公证) | 付费账号 + 证书 + provisioning;macOS 走 App Store 外分发还需 **notarization** | ❌ 后置 |

## 7. Xcode 27 的重要变化:`Simulator.app` 被移除

- **Xcode 26 起**:模拟器 UI 的默认宿主开始转向 **Device Hub**。
- **Xcode 27**:不再随包提供 `Simulator.app`,默认用 Device Hub 呈现模拟器。
- **CoreSimulator 仍在**,`xcrun simctl` 仍可用 —— 所以**纯 CLI 流程不受影响**。
- 社区工具 [`lynnswap/NeoSimulator`](https://github.com/lynnswap/NeoSimulator)(要求
  macOS 26.4+ / Apple Silicon / Xcode 27+)可以把 Xcode 26 的 `Simulator.app` 找回来当宿主。

> 对本仓库的影响:我们本来就只用 `simctl` + `swift-bundler`,不依赖 `Simulator.app`,
> 所以 Xcode 27 可用。但「想在屏幕上看到模拟器窗口」的人会受影响,需在文档里写清。

## 8. 怎么复核(在 Air 上跑)

```bash
sw_vers                          # macOS 版本
xcodebuild -version              # Xcode 版本/build
xcode-select -p                  # 当前选中的 Xcode 路径
xcrun --sdk iphonesimulator --show-sdk-path   # 确认 iOS SDK 在(验证 §5)
xcrun simctl list runtimes       # 已安装的模拟器 runtime
swift --version                  # Swift 版本(Swift 6.4 直接读这里的输出)
xcodebuild -showsdks             # 所有可用 SDK
```

把输出贴回 `HANDOFF.md` 的「实测结果」区,或修正本文件的 §1/§2 表格。
