# AGENTS.md

给 AI 编码智能体的仓库说明。人类读者请看 [README.md](README.md)。

本仓库是 **Apple 平台(iOS/macOS)无 IDE 命令行开发**的实践沉淀库,对标
[`EasyIndie/EasyAndroid`](https://github.com/EasyIndie/EasyAndroid)。

> **当前阶段:规划期。** 仓库里只有文档,没有可运行代码。规划在 Windows 上完成,
> **所有需要 macOS 的结论都还没真机验证**。

---

## 0. 硬性规则

1. **不要在 Windows/Linux 上寻找「能跑 iOS 模拟器」的方案。**
   原理上不可行(iOS 模拟器是 macOS 上的原生 App,依赖 CoreSimulator + Darwin)。
   结论与依据见 [docs/research/03-simulator-cross-platform.md](docs/research/03-simulator-cross-platform.md)。
   这是本仓库最容易浪费时间的坑,已被多次研究并否决。
2. **构建/模拟器只能在 macOS 上。** Windows 上只能写文档和源码。
   不要尝试在 Windows 上 `swift build` / `xcodebuild` / `simctl`。
3. **Intel MBP(2015)不参与构建。** 它最高 Xcode 14.2 / Swift 5.7,解析不了
   `swift-tools-version:6.0`。见 [docs/00-decisions.md](docs/00-decisions.md) D1。
4. **不要把「桌面推演」写成「已验证」。**
   - 规划期调研放 `docs/research/`,措辞用「来源」「怎么复核」;
   - 只有真机跑通的结论才写进执行期文档(`docs/01`…`docs/09`),措辞用「已验证」。
   - 没有把握就标注「⚠️ 推测」。
5. **不要把真实内网 IP / 密钥 / token 写进任何被跟踪的文件。**
   文档示例统一用 RFC 5737 保留段(`192.0.2.x`)。提交前跑一次:
   ```bash
   git grep -nE '192\.168\.[0-9]+\.[0-9]+'
   git grep -nE 'ghp_[A-Za-z0-9]{20,}|gho_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|BEGIN [A-Z ]*PRIVATE KEY'
   ```
   两条都应零输出。
6. **提交信息必须写 `type(scope): 描述`(Conventional Commits)。**
   版本号将来从它机械推导(沿用 EasyAndroid)。文档改动也算,常用 `docs:`。
7. **版本号唯一来源是 `version.properties`**(执行期落地后生效)。
   仓库里不应出现版本号字面量。
8. **不提交签名凭据。** `*.p12` / `*.mobileprovision` / `tools/host.env` 已在
   `.gitignore`。当前零证书阶段尤其不要顺手加。
9. **不提交 `.xcodeproj`。** 它只是 XcodeGen 的生成物(见 D4/D5)。
10. **升级 Xcode / Swift / swift-bundler / runner 要单独开一次,别夹在功能开发里。**
    先升级、先在 Air 与 CI 上验过、再合。
11. **`swift-bundler` 必须 pin 到 commit**(见 D10),不要用 `@main` 浮动。

---

## 1. 仓库结构与「东西该放哪」

```
PLAN.md              执行计划(活文档,在 Air 上直接改)
HANDOFF.md           交接说明(当前状态 / Air 上要做什么 / 未验证假设)
docs/research/       规划期调研(未验证,带「怎么复核」)
docs/00-decisions.md 决策记录(决策/理由/状态/怎么改)
docs/NN-*.md         执行期文档(实测后写,执行阶段才创建)
apps/                可运行的 SwiftPM 工程(执行阶段才创建)
tools/               构建/模拟器/验收脚本(执行阶段才创建)
version.properties   版本号唯一来源(执行阶段才创建)
```

- **新的调研结论** → `docs/research/`,并在 `docs/research/README.md` 加一行。
- **新的决定** → `docs/00-decisions.md`,分配下一个 `Dx` 编号,状态 `proposed`,
  由人在 Air 上改 `accepted`。
- **踩到的坑** → 执行期进 `docs/09-gotchas.md`;规划期的疑问写进 `HANDOFF.md` 的
  「未验证假设」。
- **改了计划** → 直接改 `PLAN.md`,并在其附录 B 记一行变更。

---

## 2. 已否决的方案清单(不要重复调研)

| 方案 | 结论 | 依据 |
|---|---|---|
| Linux/Windows 上跑 iOS 模拟器 | ❌ 原理不可行 | [research/03](docs/research/03-simulator-cross-platform.md) §1–2 |
| Darling / Kakehashi / touchHLE 当开发环境 | ❌ 不适用 | 同上 |
| 非 Apple 硬件上的 macOS VM 作团队基线 | ❌ 违反 EULA | 同上 |
| 手写/手维护 `.xcodeproj` | ❌ 只生成不入库 | D4 / D5 |
| 让 Intel MBP 参与构建 | ❌ 除非退回到 tools-version 5.7 | D1 |

---

## 3. 文档写法

- 语言:中文,术语保留英文原文(如 `simctl`、`Info.plist`)。
- 每条结论尽量写**「怎么验证的」**(命令或来源链接),别只给结论。
- 版本号/日期一定带上快照时间(如「2026-09 快照」),环境会变。
- 交叉引用用相对路径链接,便于在 GitHub 上直接点开。

---

## 4. 环境速查(规划期,待 Air 上复核)

| 组件 | 规划期认知 | 复核命令 |
|---|---|---|
| Xcode | Air 可装 26/27;Intel 最高 14.2 | `xcodebuild -version` |
| macOS | Air = 26 Tahoe;Intel 最高 12 Monterey | `sw_vers` |
| Swift | 6.4(随 Xcode) | `swift --version` |
| 模拟器 runtime | 现代 Xcode 默认不带,需单独下载 | `xcrun simctl list runtimes` |
| 打包工具 | swift-bundler(pin commit) | `swift bundler --version` |
| 工程生成 | XcodeGen(逃生舱) | `xcodegen --version` |
