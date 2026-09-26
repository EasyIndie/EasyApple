# EasyApple 执行计划

> **这份文件是「活文档」,随执行进度直接改。**
> 状态图例:`[ ]` 未做 · `[~]` 进行中 · `[x]` 已完成 · `[-]` 已砍掉。
>
> 开发机 = M1 Air(macOS 27.0 / arm64)。所有任务都在本机完成。

---

## 0. 背景与目标

做一个对标 [`EasyIndie/EasyAndroid`](https://github.com/EasyIndie/EasyAndroid) 的
**Apple 平台无 IDE 命令行开发实践库**,沉淀「只靠命令行构建/运行/验收 iOS + macOS
应用」的结论与脚本。

### 0.1 硬前提(已定,不反复)

1. **构建只能在 macOS 上**,且必须装**完整 Xcode**(可从不打开 GUI)。
2. **目标工具链 = Xcode 27.0**(macOS 27.0 已满足其 ≥26.6 要求)。见决策 D12。
3. **arm64-only。** macOS 27 / Xcode 27 已无 Intel 构建,Intel Mac 记 out-of-scope。见 D13。
4. **只用原生工具,不用第三方打包工具。** `.app` 由自写 `tools/bundle.sh` 拼装。见 D5。
5. **首期只做模拟器闭环、零证书。** 真机/分发后置。见 D6。

---

## Phase 0 — 环境核实

> 规划期在 Windows 上推演的版本矩阵,已在 Air 上部分核实。

- [x] **P0.1** `sw_vers` → **macOS 27.0**(build `26A428`,Golden Gate,已发布)
- [x] **P0.2** 芯片 → **Apple Silicon M1**(arm64,`T8103`)
- [x] **P0.3** Homebrew → ✅ 已装(`/opt/homebrew/bin/brew`)
- [x] **P0.4** Command Line Tools → ✅ 已装(`/Library/Developer/CommandLineTools`,且是当前 active dev dir)
- [x] **P0.5** `xcodebuild -version` → ✅ **Xcode 27.0 / Build 27A266a**(经 `DEVELOPER_DIR` 验证;`xcode-select` 仍指 CLT,待 `xcodes select 27.0`)
- [x] **P0.6** `xcrun --sdk iphonesimulator --show-sdk-path` → ✅ `.../iPhoneSimulator27.0.sdk`(iOS SDK 在)
- [x] **P0.7** `xcrun simctl list runtimes` → ✅ 已有 **iOS 26.4、visionOS 26.0**;**iOS 27.0 待下载**(P1.3)
- [x] **P0.8** `swift --version` → ✅ **Swift 6.4**(已摘掉 swiftly 的 PATH 注入,`swift` 现解析到 `/usr/bin/swift` → Xcode 6.4)

> ✅ **swiftly 坑已修复**:`~/.zprofile` 里的 `. "/Users/joker/.swiftly/env.sh"` 已删除,新 shell 的 `swift` 解析到 `/usr/bin/swift`(Xcode Swift 6.4)。工具脚本里仍建议用 `xcrun swift` 更稳。

---

## Phase 1 — 工具链安装 + 原生打包原型

- [x] **P1.1** 装 `xcodes`(bootstrap 工具,D14)→ ✅ 已装 **2.1.0**(直下 release 二进制;brew 源码构建被沙箱拦)→ ✅ `xcodes install 27.0`(Xcode 27.0 / 27A266a)
- [x] **P1.2** `sudo xcodebuild -license accept` + `xcodes select 27.0`(✅ `xcode-select -p` 已指向 Xcode)
- [x] **P1.3** 下载 iOS 模拟器 runtime:✅ `xcodes runtimes install "iOS 27.0"`(iOS 27.0 / 24A434 已装)
- [ ] **P1.4** 写 `tools/doctor.sh`(环境自检)
- [ ] **P1.5** 写 `tools/bootstrap.sh`(引导安装:装 xcodes → Xcode 27.0 → iOS runtime;xcodes 仅装机,不进构建链路)
- [ ] **P1.6** 写 `tools/bundle.sh` 原型:拼 `App.app/Contents/{MacOS,Info.plist,Resources}`
  + `codesign --force --sign -` + `simctl install/launch`
- [ ] **P1.7** 实测 iOS 模拟器 bundle 的最小必需 Info.plist 键,沉淀进
  `docs/04-packaging-native.md`(执行期创建)

> 已确认(2026-09-26):`xcodes list` 显示 `27.0 (27A266a) [Apple Silicon]`(与 D12 一致;27.x 无 Intel 构建,印证 D13)。
> ⚠️ 踩坑:`brew install xcodesorg/made/xcodes` 走源码构建(git clone SPM 依赖),在受管沙箱里 getcwd 报 `Operation not permitted`;改直下 release 二进制(`xcodes.zip` → `/opt/homebrew/bin/xcodes`)。

---

## Phase A — 仓库骨架

- [x] **A1** `git init -b main` + `git remote add origin https://github.com/EasyIndie/EasyApple.git`(已落地)
- [ ] **A2** 建目录:`apps/ tools/ .github/workflows/`(空目录 `.gitkeep` 占位)
- [x] **A3** `.gitignore`(已预置 `.build/`、`*.xcodeproj`、`*.p12`、`*.mobileprovision`、`.tmp/` 等)
- [~] **A4** `LICENSE`(✅)+ `README.md`(✅)+ `CHANGELOG.md`(待建)
- [ ] **A5** 写 `version.properties`(严格 SemVer 契约注释 + 版本历史区,首版 `0.0.1`)
  - 验收:注释写清 `CFBundleShortVersionString=version`、
    `CFBundleVersion=MAJOR*10000+MINOR*100+PATCH`、仓库内禁止版本字面量

---

## Phase B — SwiftPM 示例工程(`apps/EnvDemo`)

- [ ] **B1** `apps/EnvDemo/Package.swift`,`swift-tools-version: 6.0`
  - 两个 product:`EnvDemoCore`(library,不 import SwiftUI)+ `EnvDemo`(executable `@main`)
  - `platforms: [.macOS(.v14), .iOS(.v17)]`
- [ ] **B2** 写 `EnvDemoCore`(纯逻辑环境探测:型号 / OS / 是否模拟器 / 架构 /
  屏幕 / 内存 / 存储 / Metal GPU;产出 `EnvironmentReport` + `format(asText:)`)
- [ ] **B3** 写 `Tests/EnvDemoCoreTests`(只测可注入的纯逻辑)
- [ ] **B4** 写 `EnvDemo` SwiftUI App(`EnvDemoApp.swift` + `ContentView.swift`)
  - 刻意保守:不用新 SwiftUI API、不用宏、不用 Observation
- [ ] **B5** 手写 `apps/EnvDemo/Info.plist`(版本字段由 `tools/sync-version.sh` 生成)
- [ ] **B6** 在 Air 上首跑:`swift build` + `swift test`,修到全绿
  - 验收:`swift test` 全绿

---

## Phase C — `tools/` 脚本

> 约定:所有脚本 source `tools/_common.sh`;平台固定 macOS,无需跨平台分支。

- [ ] **C1** `tools/_common.sh`(定位 `swift`/`xcrun`/`xcodebuild`;`die`/`note`/`skip` 统一输出)
- [ ] **C2** `tools/doctor.sh` —— 环境自检(同 P1.4)
- [ ] **C3** `tools/bootstrap.sh` —— 引导安装 Xcode + iOS runtime(幂等)
- [ ] **C4** `tools/sync-version.sh` —— 从 `version.properties` 写 `Info.plist` 的
  `CFBundleShortVersionString` / `CFBundleVersion`;`--check` 只校验
- [ ] **C5** `tools/build.sh` —— `swift build`(先 `sync-version`)
- [ ] **C6** `tools/test.sh` —— `swift test`
- [ ] **C7** `tools/bundle.sh` —— 原生打包(拼 `.app` + `codesign -s -` + `simctl install`)
- [ ] **C8** `tools/run-sim.sh` —— `simctl boot` + `install` + `launch`
- [ ] **C9** `tools/sim.sh` —— 封装 `simctl`;含 `xcodebuild -downloadPlatform iOS`
- [ ] **C10** `tools/ui-dump.sh` —— 截图(`simctl io <device> screenshot`);文本树后置
- [ ] **C11** `tools/new-app.sh` —— 以 `EnvDemo` 为模板生成 `apps/<Name>/`
- [ ] **C12** `tools/verify-all.sh` —— 串 `doctor → sync-version --check → build →
  test → run-sim → ui-dump`,输出通过/失败/跳过计数
- [ ] **C13** `tools/release.sh` —— Conventional Commits → SemVer;写
  `version.properties` + `CHANGELOG.md`;打 tag;推;CI 出包
- [ ] **C14** `tools/README.md` —— 每个脚本一句话用途

---

## Phase D — CI(`.github/workflows/`)

- [ ] **D1** `ci.yml`
  - `runs-on: macos-26`(arm64,显式 pin,不用 `-latest`)
  - `fetch-depth: 0`、`timeout-minutes`
  - 步骤:doctor → sync-version --check → `swift build` → `swift test` →
    下载 iOS runtime → run-sim + 截图 → 上传 artifact
  - 加一步「提交信息规范(Conventional Commits)」校验
- [ ] **D2** `release.yml`
  - tag 触发(pattern `[0-9]+.[0-9]+.[0-9]+`) → 校验 tag == `version.properties` →
    bundle → 建 Release 挂 `.app`
  - `permissions: contents: write`
- [ ] **D3** 开 Actions 验证首跑(顺带验证「runner 默认 Xcode 与 Air 27.0 对齐」,
  必要时 `xcode-select` 或 `xcode-27` label)

---

## Phase E — 文档(`docs/`)

- [ ] **E1** `01-headless-apple-build.md`(无 IDE 的 Apple 构建环境)
- [ ] **E2** `02-swiftpm-project-conventions.md`(SwiftPM 分层范式)
- [ ] **E3** `03-simulator-cli.md`(模拟器 CLI 与 Xcode 27 Device Hub)
- [ ] **E4** `04-packaging-native.md`(原生打包脚本原理与踩坑)
- [ ] **E5** `05-app-conventions.md`(工程/命名/版本号/发版流程)
- [ ] **E6** `06-ui-acceptance.md`(截图 vs 无障碍文本)
- [ ] **E7** `07-cross-platform-and-no-mac.md`(跨平台 / 无 Mac 全景,首期不采用)
- [ ] **E8** `08-gotchas.md`(踩坑速查)
- [ ] **E9** 归档 `docs/research/`(执行期文档落地后,保留 01/03 作引用源)
- [ ] **E10** `docs/README.md` 索引更新

---

## Phase F — 静态自检与交付

- [ ] **F1** `for f in tools/*.sh; do bash -n "$f"; done` 全通过
- [ ] **F2** 用 YAML 解析器校验两个 workflow
- [ ] **F3** 校验文档内部链接与文件引用全部存在
- [ ] **F4** `git grep` 确认真实内网 IP / token / 私钥**零命中**
- [ ] **F5** 检查文档没有把「桌面推演」写成「已验证」
- [ ] **F6** 在 Air 上跑 `tools/verify-all.sh` 作为总验收

---

## 附录 A — 明确不做的事(out of scope)

- ❌ 找「Linux/Windows 上跑 iOS 模拟器」的方案 —— 原理上不可行,见
  [03-simulator-cross-platform.md](docs/research/03-simulator-cross-platform.md)。
- ❌ 非 Apple 硬件上的 macOS VM 作团队基线 —— 违反 EULA。
- ❌ **支持 Intel Mac** —— Xcode 27 / macOS 27 已无 Intel 构建,arm64-only(D13)。
- ❌ **第三方打包工具**(swift-bundler / XcodeGen / idb)—— 只用原生脚本(D5/D7)。
- ❌ 让 Intel MBP 参与构建 —— 最高 Xcode 14.2(D1)。
- ❌ 手写/手维护 `.xcodeproj` —— 不生成不入库(D4)。
- ❌ 首期做真机签名 / App Store 分发 —— 需付费账号,后置(D6)。

## 附录 B — 计划变更记录

| 日期 | 变更 | 原因 |
|---|---|---|
| 2026-09-26 | 初版(Windows 上落档) | 规划期完成 |
| 2026-09-26 | 在 Air 上重估:改原生打包 + arm64-only + 删交接文档 | 已上 Air,锁 Xcode 27,Windows 退出 |
| | | |
