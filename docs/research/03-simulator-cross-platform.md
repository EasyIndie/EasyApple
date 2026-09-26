# 03 — Apple 模拟器能否跨平台运行?

> **状态:规划期调研,未在真机验证。** 这是本仓库最重要的否定结论:
> **不要在 Windows/Linux 上寻找「能跑 iOS 模拟器」的方案 —— 原理上不存在。**

## 1. 为什么不行(原理)

**iOS Simulator 不是模拟器(emulator),而是「在 macOS 上原生运行的 App」。**

- App 被编译成**宿主机架构**(Intel Mac 上是 x86_64,Apple Silicon 上是 arm64),
  不是模拟 ARM 指令;
- 它链接的是 Apple **重实现**的 UIKit/Foundation 等框架,底层跑在 **Darwin/XNU 内核**上;
- 宿主进程是闭源的 **`CoreSimulator.framework`**(macOS 组件)+ `SimulatorTrampoline`。

结论:模拟器**在架构上就绑定 macOS**。没有项目把 CoreSimulator 移植到 Linux/Windows,
因为那等于要在非 Darwin 内核上重实现整套运行环境。

> **来源/佐证**:
> [`appium/coresim`](https://github.com/appium/coresim) 是 macOS 上
> `CoreSimulator.framework` 的原生绑定(平台限定);
> [`lynnswap/NeoSimulator`](https://github.com/lynnswap/NeoSimulator) 明确要求
> macOS 26.4+ / Apple Silicon / Xcode 27。

## 2. 社区方案逐条评估

| 方案 | 能跑现代 iOS 模拟器? | 说明 |
|---|---|---|
| [Darling](https://github.com/darlinghq/darling)(~13k★) | ❌ | Linux 上的 macOS 用户态兼容层(Mach-O loader + darlingserver + 框架重实现)。GUI/AppKit/Metal 仍在开发中,**跑不了 Xcode/Simulator** |
| [Kakehashi](https://github.com/wie-project/kakehashi) | ❌ | macOS ARM64 → Linux aarch64 翻译层。**作者已声明停止维护**;且需要先从 macOS 26 拷贝 `/bin /usr/bin` 等系统目录(鸡生蛋问题);无 GUI |
| [touchHLE](https://github.com/touchHLE/touchHLE)(~3.9k★) | ❌ | 高保真 HLE 模拟器,但**只支持 iPhone OS 2.x/3.0 的 32 位老 app**,官方明确「**Never: 64-bit iOS**」。不适合开发 |
| [MarbleLabs1/IOS-emulator](https://github.com/MarbleLabs1/IOS-emulator) | ⚠️ 存疑 | 号称 QEMU 跑 iPhone 14/15。iOS 需要 Apple 签名的 iBoot + Apple Silicon,QEMU 无法引导,**判断为营销性仓库**,不依赖 |
| macOS VM(QEMU + OpenCore) | ✅ 能 | [Docker-OSX](https://github.com/sickcodes/Docker-OSX)(Linux/Windows via WSL2)、[OneClick-macOS-Simple-KVM](https://github.com/notAperson535/OneClick-macOS-Simple-KVM)、[ultimate-macOS-KVM](https://github.com/Coopydood/ultimate-macOS-KVM)。**本质是「在虚拟机里跑一台 Mac」** |
| 真 Mac / 云 Mac | ✅ | 最正的路,见 §3 |

### ⚖️ 法律/合规提醒

Apple 的 macOS 软件许可协议规定 macOS 只能安装在 **Apple 品牌硬件**上(或在 Apple
硬件上的虚拟机里)。**Hackintosh / 非 Apple 硬件上的 macOS VM 违反 EULA。**
技术上能做,但风险自担,本仓库**不把它作为主链路或团队基线**。
参考:Docker-OSX README 里的 [「Is Hackintosh, OSX-KVM, or Docker-OSX legal?」](https://sick.codes/is-hackintosh-osx-kvm-or-docker-osx-legal/)。

## 3. 真正的「跨平台 Apple 开发」= 远程 macOS

业界的答案不是「移植模拟器」,而是「**把 macOS 放到远端,把界面/控制流回到本地**」。

| 类别 | 方案 | 说明 |
|---|---|---|
| CI macOS runner | **GitHub Actions `macos-26`(arm64)/ `macos-15`**、Cirrus CI、Codemagic | ⚠️ macOS runner 是 **10× 计费倍率**(免费 2000 分钟/月 ≈ 200 macOS 分钟);`macos-latest` 现在是 macOS 26 arm64 |
| 云端 Mac(整机) | MacStadium、MacinCloud、AWS EC2 Mac、Scaleway Mac mini | 租真 Mac,SSH 进去,和本地一样 |
| 模拟器串流 | [Limrun](https://limrun.com/)(YC 背书,remote Xcode + cloud iOS simulator,主打给 AI agent)、[Appetize.io](https://appetize.io)、BrowserStack、Sauce Labs、AWS Device Farm、Firebase Test Lab | 模拟器跑在人家 Mac 上,画面/控制流回本地 |
| 自建串流 | [facebook/idb](https://github.com/facebook/idb)(~5.3k★):**companion 跑在 macOS、python client 可跑任意系统**;[badoo/ios-device-server](https://github.com/badoo/ios-device-server)、[ios-bridge](https://github.com/himanshkukreja/ios-bridge) | 自己有 Mac 时,把模拟器控制/画面暴露到 Windows/Linux |
| 无 Mac 编排 | [kanjariyaraj/ibuilder](https://github.com/kanjariyaraj/ibuilder) | 本地 CLI,底层调 GitHub macOS runner 构建/签名/发布 |
| 虚拟真 iOS | [Corellium](https://www.corellium.com/) | ARM 原生虚拟化真 iOS(支持 iOS 26),但面向**安全研究**,不是 app 开发/模拟器 |

## 4. 对本仓库的决策影响

- 我们的两台 Mac(M1 Air + Intel MBP)都在手边,**不需要走云 Mac/串流**。
- 但「Windows 上开发」的唯一可行形态是:
  - **写代码/文档** → 在 Windows;
  - **构建/模拟器/验收** → 经 SSH 到 Air,或走 GitHub `macos-26` runner。
- 这条决定写进了 [`docs/00-decisions.md`](../00-decisions.md) 的 D2/D3。

## 5. 一句话结论(可引用)

> **本地跨平台跑 Apple 模拟器:不存在,且原理上不可行。**
> **跨平台做 Apple 开发:可行,但本质是「远程 macOS」。**
> **完全无 Mac 编译设备包:可行(Theos/zsign),但没有模拟器、偏侧载生态。**

## 6. 怎么复核

- 想确认「模拟器依赖 macOS」:在 Air 上 `ls /Applications/Xcode.app/Contents/Developer/Applications/`
  看 `Simulator.app`(26.x)/ Device Hub,并 `otool -L` 模拟器二进制看它链接的 macOS 框架。
- 想确认 Xcode 27 变化:见 [NeoSimulator README](https://github.com/lynnswap/NeoSimulator)。
- 想确认 idb 可远程:`idb --help` 与官方 README 的「Remote Automation」一节。
