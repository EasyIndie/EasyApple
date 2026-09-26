# EasyApple

Apple 平台(iOS / iPadOS / macOS,后续扩展全平台)**无 IDE 命令行开发**的实践沉淀库。

对标 [`EasyIndie/EasyAndroid`](https://github.com/EasyIndie/EasyAndroid):同样是
「踩过的坑 + 验证过的结论 + 可直接复用的脚本」,而不是官方文档搬运。

> ⚠️ **当前处于「规划期」——仓库里只有文档,没有任何可运行的代码。**
> 规划在 Windows 上完成,所有需要 macOS 的结论**都还没在真机验证**。
> 下一步见 [`HANDOFF.md`](HANDOFF.md):在 M1 Air 上拉取本仓库 → 先改
> [`PLAN.md`](PLAN.md) → 再进入执行阶段。

> ⚠️ **开发机前提:构建必须在 macOS 上。** Android 可以在 Windows 上装
> `cmdline-tools` 纯命令行编译;iOS/macOS **不能** —— iOS SDK 只随完整
> `Xcode.app` 提供,而 Xcode 只在 macOS 上运行。所以本仓库里
> **Windows 只能写文档和源码,构建/模拟器/验收都在 Mac(本地或远程)上**。
> 调研依据见 [`docs/research/03-simulator-cross-platform.md`](docs/research/03-simulator-cross-platform.md)。

## 目录

| 路径 | 内容 |
|---|---|
| [`PLAN.md`](PLAN.md) | **执行计划(主交付物)** —— 分阶段、可勾选,在 Air 上直接改 |
| [`HANDOFF.md`](HANDOFF.md) | **交接说明** —— 当前状态、Air 上要做什么、未验证假设、回填要求 |
| [`AGENTS.md`](AGENTS.md) | 给 AI 编码智能体的仓库说明与硬性约束 |
| [`docs/`](docs/) | 知识沉淀:调研结论、决策记录、后续专题文档 |
| [`docs/research/`](docs/research/) | **规划期调研**:Apple 规则 / 跨平台能力 / 模拟器跨平台 / SwiftPM 打包 |
| [`docs/00-decisions.md`](docs/00-decisions.md) | 决策记录(决策 / 理由 / 状态 / 怎么改) |

## 与 EasyAndroid 的关系

| | EasyAndroid | EasyApple |
|---|---|---|
| 构建机 | Windows / WSL2 / Linux 都能构建 | **只有 macOS 能构建** |
| SDK 获取 | 单独装 `cmdline-tools`,不装 IDE | **必须装完整 Xcode**(可以从不打开 GUI) |
| 设备/运行 | `adb` + 真机(TCL TV / Pico 4) | `simctl` + 模拟器(真机需证书,暂缓) |
| 工程生成 | Gradle(工程自带 wrapper) | **SwiftPM**(`.xcodeproj` 只生成、不入库) |
| 打包 | AGP → APK | SwiftPM 打不出 `.app` → 用 **swift-bundler** 补 |
| 发版 | `tools/release.sh` 一条命令 | 计划复用同一套 Conventional Commits → SemVer |
| 版本唯一来源 | `version.properties` | 计划同样用 `version.properties` |

## 已确认的调研结论(摘要)

- **Apple 模拟器无法跨平台运行**,原理上不可行(它不是 emulator,是 macOS 上的原生
  App,依赖 CoreSimulator + Darwin)。详见 [03](docs/research/03-simulator-cross-platform.md)。
- **跨平台 Apple 开发 = 远程 macOS**:自己的 Mac / 云 Mac / CI 的 macOS runner /
  模拟器串流服务。详见 [03](docs/research/03-simulator-cross-platform.md)。
- **SwiftPM 打不出 `.app`**,由 `swift-bundler`(主)+ XcodeGen 薄壳(逃生舱)补上。
  详见 [04](docs/research/04-swiftpm-packaging.md)。
- **完全无 Mac 也能构建 iOS 设备包**(Theos/xtool + zsign + libimobiledevice),但
  **没有模拟器**,且偏侧载生态。详见 [02](docs/research/02-cross-platform-dev.md)。

## 许可

[MIT](LICENSE) © 2026 wangzhizhou
