# 规划期调研(Research)

> ⚠️ **这批文档是「桌面调研」的产物,部分已在 Air 核实(2026-09-26),其余未在真机验证。**
> 每篇结尾都有「怎么复核」章节,列出在 Air 上应该跑的验证命令。
> 实测后请把结论回填到执行期文档(`docs/01`…`docs/09`)与本目录。

## 为什么单独放一个 `research/` 目录

EasyAndroid 的 `docs/` 是「实测过的结论」。EasyApple 目前**还没有实测**,如果直接
写进 `docs/`,会让人误以为已验证。所以:

- `docs/research/` = **规划期调研**(有来源、未验证,带「怎么复核」);
- `docs/NN-*.md`(执行期)= **实测后**的结论与用法;
- 同一主题两处都有是**故意的** —— 调研 ≠ 实测,合并会抹掉「验证与否」这条信息。

## 索引

| 文档 | 主题 | 一句话结论 |
|---|---|---|
| [01-apple-platform-rules-2026.md](01-apple-platform-rules-2026.md) | Apple 平台规则(2026-09 快照) | Xcode 27 / macOS 26 / Swift 6.4;App Store 要求 Xcode 26+;**iOS SDK 只随完整 Xcode** |
| [02-cross-platform-dev.md](02-cross-platform-dev.md) | 跨平台开发能力 | Swift 语言已跨平台(含 Android SDK),但 **SwiftUI 不可移植**;无 Mac 可用 Theos/xtool 出**设备包**(**首期不采用**) |
| [03-simulator-cross-platform.md](03-simulator-cross-platform.md) | **模拟器跨平台可行性** | **原理上不可行**(模拟器是 macOS 原生 App);跨平台 = **远程 macOS** |
| [04-swiftpm-packaging.md](04-swiftpm-packaging.md) | SwiftPM 打不出包怎么办 | **已改自写原生打包脚本**;swift-bundler 仅备选对照;xtool 是设备向备选 |

## 关键否决清单(避免重复调研)

以下路线经调研判定为**死路或不适合**,以后不要再花时间:

- ❌ Linux/Windows 上的 iOS 模拟器(Darling / Kakehashi / touchHLE / 各种「iOS emulator」仓库)
- ❌ 非 Apple 硬件上的 macOS VM 作为团队基线(违反 EULA)

详见 [03](03-simulator-cross-platform.md)。

## 更新记录

| 日期 | 变更 |
|---|---|
| 2026-09-26 | 初版(规划期,Windows 上完成) |
