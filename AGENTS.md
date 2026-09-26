# AGENTS.md

给 AI 编码智能体的仓库说明。人类读者请看 [README.md](README.md)。

本仓库是 **Apple 平台(iOS/macOS)无 IDE 命令行开发**的实践沉淀库,对标
[`EasyIndie/EasyAndroid`](https://github.com/EasyIndie/EasyAndroid)。

> **当前阶段:执行期。** 开发机 = **M1 Air(macOS 27.0 / arm64)**。构建、模拟器、
> 验收都在本机完成。规划期(Windows 上推演)已结束,交接文档已删除。

---

## 0. 硬性规则

1. **构建/模拟器只能在 macOS 上。** iOS 模拟器是 macOS 原生 App(依赖 CoreSimulator
   + Darwin),原理上不可跨平台。依据:
   [docs/research/03-simulator-cross-platform.md](docs/research/03-simulator-cross-platform.md)。
2. **构建必须装完整 Xcode(当前锁 Xcode 27.0),但可以从不打开 GUI。**
   只有 Command Line Tools 拿不到 iOS SDK。见
   [docs/research/01-apple-platform-rules-2026.md](docs/research/01-apple-platform-rules-2026.md) §5。
3. **arm64-only,Intel Mac 不纳入构建与分发。** macOS 27 / Xcode 27 已无 Intel 构建;
   仓库里的 Intel MBP(2015)最高 Xcode 14.2 / Swift 5.7,连 macOS 26 app 都装不上。
   见 [docs/00-decisions.md](docs/00-decisions.md) D1、D13。
4. **只用原生工具,不引入第三方打包工具。** swift-bundler / XcodeGen / idb / mint
   均不采用;`.app` 由自写脚本(`tools/bundle.sh`)用 `codesign` / `plutil` /
   `simctl` 拼装。见 D5。
5. **不要把「桌面推演」写成「已验证」。**
   - 规划期调研在 `docs/research/`,措辞用「来源」「怎么复核」;
   - 只有真机跑通的结论才写进执行期文档(`docs/01`…`docs/09`),措辞用「已验证」;
   - 没有把握就标注「⚠️ 推测」。
6. **不要把真实内网 IP / 密钥 / token 写进任何被跟踪的文件。**
   文档示例统一用 RFC 5737 保留段(`192.0.2.x`)。提交前跑一次:
   ```bash
   git grep -nE '192\.168\.[0-9]+\.[0-9]+'
   git grep -nE 'ghp_[A-Za-z0-9]{20,}|gho_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|BEGIN [A-Z ]*PRIVATE KEY'
   ```
   两条都应零输出。
7. **提交信息必须写 `type(scope): 描述`(Conventional Commits)。** 文档改动也算,常用 `docs:`。
8. **版本号唯一来源是 `version.properties`。** 仓库里不应出现版本号字面量。
9. **不提交签名凭据。** `*.p12` / `*.mobileprovision` 已在 `.gitignore`。
10. **不提交 `.xcodeproj`。** 本仓库用 SwiftPM + 原生打包脚本,不生成 Xcode 工程。
11. **升级 Xcode / Swift 要单独开一次,别夹在功能开发里。** 先升级、先在 Air 与 CI 上验过、再合。

---

## 1. 仓库结构与「东西该放哪」

```
PLAN.md              执行计划(活文档)
docs/research/       规划期调研(带「怎么复核」)
docs/00-decisions.md 决策记录(决策/理由/状态/怎么改)
docs/NN-*.md         执行期文档(实测后写,执行阶段创建)
apps/                可运行的 SwiftPM 工程
tools/               构建/模拟器/验收脚本
version.properties   版本号唯一来源
```

- **新的调研结论** → `docs/research/`,并在 `docs/research/README.md` 加一行。
- **新的决定** → `docs/00-decisions.md`,分配下一个 `Dx` 编号。
- **踩到的坑** → 执行期进 `docs/08-gotchas.md`。
- **改了计划** → 直接改 `PLAN.md`,并在其附录 B 记一行变更。

---

## 2. 已否决的方案清单(不要重复调研)

| 方案 | 结论 | 依据 |
|---|---|---|
| Linux/Windows 上跑 iOS 模拟器 | ❌ 原理不可行 | [research/03](docs/research/03-simulator-cross-platform.md) §1–2 |
| Darling / Kakehashi / touchHLE 当开发环境 | ❌ 不适用 | 同上 |
| 非 Apple 硬件上的 macOS VM 作团队基线 | ❌ 违反 EULA | 同上 |
| 手写/手维护 `.xcodeproj` | ❌ 不生成不入库 | D4 |
| swift-bundler 作主打包链路 | ❌ 只用原生脚本 | D5 |
| XcodeGen 逃生舱(首期) | ❌ 无 watchOS/扩展/XCUITest 需求 | D5 |
| idb 做文本树验收(首期) | ❌ 截图为先 | D7 |
| 支持 Intel Mac(arm64-only 之外) | ❌ Xcode 27 已无 Intel | D13 |
| 让 Intel MBP 参与构建 | ❌ 最高 Xcode 14.2 | D1 |

---

## 3. 文档写法

- 语言:中文,术语保留英文原文(如 `simctl`、`Info.plist`)。
- 每条结论尽量写**「怎么验证的」**(命令或来源链接),别只给结论。
- 版本号/日期一定带上快照时间(如「2026-09 快照」),环境会变。
- 交叉引用用相对路径链接,便于在 GitHub 上直接点开。

---

## 4. 环境速查(执行期)

| 组件 | 版本/状态 | 复核命令 |
|---|---|---|
| macOS | 27.0(build `26A428`,Golden Gate) | `sw_vers` |
| 芯片 | Apple Silicon M1(arm64) | `uname -m` |
| Xcode | 目标 27.0(待装) | `xcodebuild -version` |
| Swift | 6.4(随 Xcode 27) | `swift --version` |
| Homebrew | ✅ 已装 | `brew --version` |
| Command Line Tools | ✅ 已装(但拿不到 iOS SDK) | `xcode-select -p` |
| 模拟器 runtime | 需单独下载 | `xcrun simctl list runtimes` |
| 打包 | 自写原生脚本(`tools/bundle.sh`) | — |

---

## 5. GitHub 推送注意

- `origin` = `https://github.com/EasyIndie/EasyApple.git`(HTTPS)。
- **受管沙箱(如 WorkBuddy)里,`git push` 可能静默失败**(报成功但没推上去,
  `git status -sb` 出现 `[gone]`)。推完核对 `git status -sb` 与远端 HEAD。
- **不要用 `git push "https://x-access-token:$TOKEN@github.com/..."` 配 `-u`** ——
  token 会被写进 `.git/config`。用凭据助手,直接 `git push`。
