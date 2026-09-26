# 07 — 跨平台 / 无 Mac(首期不采用)

> **状态:结论已在 Air 核实。** 本仓库首期 **arm64-only + 只用 Mac**,本文记录备选路线以便将来。

## 1. 一句话

- **本地在非 macOS 上跑 iOS 模拟器:不存在,原理上不可行。**
- **跨平台做 Apple 开发 = 远程 macOS**(云 Mac / CI runner / 串流)。
- **完全无 Mac 也能出真机设备包**(Theos / xtool),但**没有模拟器**,偏侧载生态。

## 2. Apple 与 Android 的根本差异

| | Android | Apple |
|---|---|---|
| SDK 获取 | 独立 `cmdline-tools`,不装 IDE | **只能随完整 Xcode** |
| 编译器运行平台 | Windows/Linux/macOS | **仅 macOS**(官方) |
| 界面验证 | `uiautomator dump` 文本树 | 截图 / XCUITest |

## 3. 为什么模拟器不能跨平台

iOS 模拟器**不是 emulator**,而是「在 macOS 上原生运行的 App」:编译成宿主机架构、
链接 Apple 重实现的框架、底层跑 Darwin/XNU。核心是闭源 `CoreSimulator.framework`(macOS 组件)。
详见 [research/03](research/03-simulator-cross-platform.md)。

## 4. 本仓库的定位(决策 D2/D3/D13)

- 开发 = M1 Air 本机;**Windows 不参与开发**(原 SSH 远程抽象已废弃,D3)。
- **arm64-only**:macOS 27 / Xcode 27 已无 Intel 构建(D13)。
- 首期**不做**无 Mac 设备链路。

## 5. 将来若要「无 Mac 出设备包」

候选链路(仅记录,未在本仓库验证):Theos / TheosWin、[xtool](https://github.com/xtool-org/xtool),
配 `zsign` / `ldid` 签名、`libimobiledevice` 通信。**需要先下载 `Xcode.xip` 提取 darwin Swift SDK**,
且面向真机(无模拟器)。详见 [research/02](research/02-cross-platform-dev.md)。
