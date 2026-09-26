# EasyApple

Apple 平台(iOS / iPadOS / macOS,后续扩展全平台)**无 IDE 命令行开发**的实践沉淀库。

对标 [`EasyIndie/EasyAndroid`](https://github.com/EasyIndie/EasyAndroid):同样是
「踩过的坑 + 验证过的结论 + 可直接复用的脚本」,而不是官方文档搬运。

> **开发机:M1 Air(macOS 27.0 / Apple Silicon)。** 构建、模拟器、验收都在本机完成。
> **纯原生工具链,不依赖第三方打包工具**(swift-bundler / XcodeGen / idb 均不用)。
> **arm64-only**,Intel Mac 不纳入支持(见 [`docs/00-decisions.md`](docs/00-decisions.md) D13)。

> ⚠️ **构建必须在 macOS 上。** iOS SDK 只随完整 `Xcode.app` 提供,而 Xcode 只在
> macOS 上运行。macOS 27 / Xcode 27 已不再支持 Intel,因此本仓库 **arm64-only**。
> 调研依据见
> [`docs/research/03-simulator-cross-platform.md`](docs/research/03-simulator-cross-platform.md)。

## 目录

| 路径 | 内容 |
|---|---|
| [`PLAN.md`](PLAN.md) | **执行计划(主交付物)** —— 分阶段、可勾选 |
| [`AGENTS.md`](AGENTS.md) | 给 AI 编码智能体的仓库说明与硬性约束 |
| [`docs/`](docs/) | 知识沉淀:决策记录、执行期文档、调研 |
| [`docs/00-decisions.md`](docs/00-decisions.md) | 决策记录(决策 / 理由 / 状态 / 怎么改) |
| [`docs/research/`](docs/research/) | 规划期调研:Apple 规则 / 跨平台能力 / 模拟器跨平台 / SwiftPM 打包 |

## 与 EasyAndroid 的关系

| | EasyAndroid | EasyApple |
|---|---|---|
| 构建机 | Windows / WSL2 / Linux 都能构建 | **只有 macOS 能构建**(arm64) |
| SDK 获取 | 单独装 `cmdline-tools`,不装 IDE | **必须装完整 Xcode**(可以从不打开 GUI) |
| 设备/运行 | `adb` + 真机 | `simctl` + 模拟器(真机需证书,暂缓) |
| 工程生成 | Gradle(工程自带 wrapper) | **SwiftPM**(不生成、不维护 `.xcodeproj`) |
| 打包 | AGP → APK | **自写原生打包脚本**(`codesign` + `plutil` + `simctl`) |
| 发版 | `tools/release.sh` 一条命令 | 复用同一套 Conventional Commits → SemVer |
| 版本唯一来源 | `version.properties` | 同样用 `version.properties` |

## 已确认的调研结论(摘要)

- **Apple 模拟器无法跨平台运行**,原理上不可行(它是 macOS 原生 App,依赖
  CoreSimulator + Darwin)。详见 [03](docs/research/03-simulator-cross-platform.md)。
- **跨平台 Apple 开发 = 远程 macOS**:自己的 Mac / 云 Mac / CI 的 macOS runner。
- **SwiftPM 打不出 `.app`**,用**自写原生打包脚本**补(不用 swift-bundler)。
- **完全无 Mac 也能构建 iOS 设备包**(Theos/xtool),但没有模拟器、偏侧载生态,
  本仓库首期不采用。详见 [02](docs/research/02-cross-platform-dev.md)。

## 许可

[MIT](LICENSE) © 2026 wangzhizhou
