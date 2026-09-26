# 04 — SwiftPM 打不出包,怎么补?(2026-09 快照)

> **状态:规划期调研,未在真机验证。**
> ⚠️ 本仓库已定 **用自写原生打包脚本,不用 swift-bundler**(见 [`../00-decisions.md`](../00-decisions.md) D5),
> 本文的 swift-bundler 内容仅作备选对照。
>
> 已确定工程真相用 **SwiftPM**(见 [`../00-decisions.md`](../00-decisions.md) D4),
> 本文回答:SwiftPM 只能产出可执行文件/库,不会做 `.app` 打包
> (`Info.plist`、图标、资源 bundle、ad-hoc 签名、`simctl install`)——这块由谁补。

## 1. 四方案对比

| 方案 | 做法 | 成熟度 | 支持 iOS 模拟器 | 支持全平台 | 本仓库定位 |
|---|---|---|---|---|---|
| **[swift-bundler](https://github.com/moreSwift/swift-bundler)** | 纯 SwiftPM,`Bundler.toml` 配置 | ~515★;**无稳定 release**(最新正式版 v2.0.4 / 2022),日常在 `main`(最近提交 2026-09-17,已适配 Swift 6.4) | ✅ `swift bundler run --platform iOSSimulator` | macOS/iOS/tvOS/visionOS **+ Linux/Windows/Android**;**不支持 watchOS** | **已弃用**(改原生脚本,D5) |
| **XcodeGen 薄壳** | 代码留在 SwiftPM;`project.yml` 生成薄 app target 依赖本地 package,`xcodebuild` 打包 | ~8.8k★,活跃(2026-09 有提交) | ✅(经 `xcodebuild`) | ✅ 全部 Apple 平台 | **备选**(首期不做) |
| 自写 bundling 脚本 | 自己拼 `.app` + `Info.plist` + `codesign -s -` + `simctl install` | 完全可控,~150 行 | ✅ | 需自己维护 | **主链路**(已定,D5) |
| **[xtool](https://github.com/xtool-org/xtool)** | 跨平台 Xcode 替代,从 SwiftPM 构建 iOS app 并部署 | ~5.5k★,活跃 | ❌(面向**真机**) | Linux/WSL/macOS | 将来做「无 Mac 出设备包」时用 |

## 2. 为什么选 swift-bundler 作主链路

它正好补在 SwiftPM 的缺口上,且是**纯 SwiftPM 工作流**(不生成 `.xcodeproj`):

```sh
# 创建(SwiftUI 模板)
swift bundler create HelloWorld --template SwiftUI

# 在 iOS 模拟器上跑(不指定则用第一个已 boot 的兼容模拟器)
swift bundler run --platform iOSSimulator --simulator "iPhone 16"

# 在 macOS 上跑
swift bundler run

# 出可分发的 .app(结果在 .build/bundler)
swift bundler bundle -c release
```

**配置**在包根的 `Bundler.toml`(`format_version = 2`):

```toml
format_version = 2

[apps.EnvDemo]
identifier = "com.easyapple.envdemo"
product = "EnvDemo"          # 对应 Package.swift 里的 executable product
version = "0.0.1"            # 由 tools/sync-version.sh 从 version.properties 生成
category = "public.app-category.developer-tools"
# icon = "icon.png"          # 可选,缺图标也能跑

[apps.EnvDemo.plist]
# 额外 Info.plist 键;支持 $(VERSION) 之类的变量替换
CFBundleShortVersionString = "$(VERSION)"
```

**平台参数**:在 macOS 上支持 `--platform macOS`(默认)、`iOSSimulator`、`iOS`、
`macCatalyst`、`tvOS`、`visionOS`;`--simulator` / `--device` 选择目标。

### ⚠️ 限制与风险(必须在 Air 上验证)

1. **无稳定 release**,官方建议 `mint install moreSwift/swift-bundler@main`。→
   **本仓库会 pin 到具体 commit**(Mint 支持 `@<commit>`),防止上游漂移。
2. **不支持 watchOS**。要 watchOS 就得走 XcodeGen 逃生舱。
3. **App 扩展(Widget 等)**、复杂 entitlements、XCUITest、`archive` 未覆盖 →
   逃生舱。
4. 文档站是 DocC(JS 渲染),离线查文档不便;主要看仓库里的
   `Sources/swift-bundler/SwiftBundler.docc/`。

## 3. XcodeGen 逃生舱(备用)

覆盖 swift-bundler 做不到的事,或需要完全用 Xcode 构建系统时。

```yaml
# apps/EnvDemo/project.yml(仅示意;本仓库首期不用 XcodeGen 逃生舱)
name: EnvDemo
options:
  bundleIdPrefix: com.easyapple
packages:
  EnvDemo:
    path: .
targets:
  EnvDemo-iOS:
    type: application
    platform: iOS
    deploymentTarget: "17.0"
    sources: [Sources/EnvDemoXcode]
    dependencies:
      - package: EnvDemo
        product: EnvDemoCore
  EnvDemo-macOS:
    type: application
    platform: macOS
    deploymentTarget: "14.0"
    sources: [Sources/EnvDemoXcode]
    dependencies:
      - package: EnvDemo
        product: EnvDemoCore
```

XcodeGen 的 `packages:` 支持 `path:` 指向本地 SwiftPM 包(见
[XcodeGen ProjectSpec 文档](https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md))。
生成物 `EnvDemo.xcodeproj` **不入库**(已在 `.gitignore`)。

## 4. xtool 的定位(仅记录,首期不做)

[`xtool-org/xtool`](https://github.com/xtool-org/xtool):Linux/WSL/macOS 上从 SwiftPM
构建 iOS app、签名、装真机。**但**:

- 需要 Swift 6.4 toolchain;
- **需要下载 `Xcode.xip`** 并从中提取「darwin Swift SDK」(`swift sdk list` → `darwin`);
- **面向真机,不管模拟器**;
- 需要 `usbmuxd` / libimobiledevice。

→ 它是「将来在 Windows/Linux 上出真机包」的候选,和本仓库首期(模拟器闭环)不冲突。
`tools/` 后续可加 `xtool.sh` 封装,但**不在 Phase C 范围内**。

## 5. 架构含义:Core / App 分层

正因为打包工具只负责「把 executable 变成 `.app`」,我们把代码分成两层:

- **`EnvDemoCore`(library)**:纯逻辑,不 import SwiftUI,可 `swift test` 在宿主机秒级测试,
  理论上还能编译到 Android/Linux(见 [02](02-cross-platform-dev.md))。
- **`EnvDemo`(executable)**:`@main` SwiftUI App,只做 UI 绑定。

这样打包工具的选择不影响核心逻辑,测试也不依赖模拟器。

## 6. 参考链接

- swift-bundler: https://github.com/moreSwift/swift-bundler
  - 配置: `Sources/swift-bundler/SwiftBundler.docc/configuration.md`
  - Darwin bundler: `.../bundlers/darwin-app-bundler.md`
- XcodeGen: https://github.com/yonaskolb/XcodeGen
- xtool: https://github.com/xtool-org/xtool ,文档 https://xtool.sh
- SwiftPM 官方文档: https://www.swift.org/documentation/package-manager/
