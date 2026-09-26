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
- [x] **P1.6** 写 `tools/bundle.sh` 原型:拼 `App.app` + `codesign --force --sign -` + `simctl install/launch` → ✅ macOS 与 iOS 模拟器都验证通过
- [x] **P1.7** 实测 iOS 模拟器 bundle 的最小必需 Info.plist 键 → ✅ 已跑通(见下)

> 已确认(2026-09-26):`xcodes list` 显示 `27.0 (27A266a) [Apple Silicon]`(与 D12 一致;27.x 无 Intel 构建,印证 D13)。
> ⚠️ 踩坑:`brew install xcodesorg/made/xcodes` 走源码构建(git clone SPM 依赖),在受管沙箱里 getcwd 报 `Operation not permitted`;改直下 release 二进制(`xcodes.zip` → `/opt/homebrew/bin/xcodes`)。
>
> ✅ **原生打包已验证(2026-09-26)**:macOS + iOS 模拟器均跑通(iOS app 在 iPhone 17 模拟器 launch 成功、进程稳定)。
> iOS 模拟器 bundle 最小 Info.plist 键:CFBundleIdentifier / CFBundleName / CFBundleExecutable / CFBundlePackageType(APPL)/ CFBundleShortVersionString / CFBundleVersion / MinimumOSVersion(17.0)/ UIDeviceFamily(1,2)/ UILaunchScreen(空 dict)。
> iOS 构建命令:`xcrun swift build -c release --triple arm64-apple-ios-simulator --sdk $(xcrun --sdk iphonesimulator --show-sdk-path)`;产物在 `.build/out/Products/Release-iphonesimulator/`。

---

## Phase A — 仓库骨架

- [x] **A1** `git init -b main` + `git remote add origin https://github.com/EasyIndie/EasyApple.git`(已落地)
- [x] **A2** 建目录:`apps/ tools/ .github/workflows/`(✅ 已建,`.gitkeep` 占位)
- [x] **A3** `.gitignore`(已预置 `.build/`、`*.xcodeproj`、`*.p12`、`*.mobileprovision`、`.tmp/` 等)
- [x] **A4** `LICENSE`(✅)+ `README.md`(✅)+ `CHANGELOG.md`(✅)
- [x] **A5** 写 `version.properties`(✅ 首版 `0.0.1`,契约注释含 `CFBundleShortVersionString`/`CFBundleVersion` 映射)

---

## Phase B — SwiftPM 示例工程(`apps/EnvDemo`)

- [x] **B1** `apps/EnvDemo/Package.swift`,`swift-tools-version: 6.0`
  - 两个 product:`EnvDemoCore`(library,不 import SwiftUI)+ `EnvDemo`(executable `@main`)
  - `platforms: [.macOS(.v14), .iOS(.v17)]`;`swiftLanguageModes: [.v5]`(规避严格并发摩擦)
- [x] **B2** 写 `EnvDemoCore`(环境探测:型号 / OS / 是否模拟器 / 架构 / 屏幕 / 内存 / 存储 / Metal GPU;产出 `EnvironmentReport` + `formatAsText()` + `formatBytes()`)
- [x] **B3** 写 `Tests/EnvDemoCoreTests`(3 个用例:formatBytes / formatAsText 字段 / 屏幕为零时省略)
- [x] **B4** 写 `EnvDemo` SwiftUI App(`EnvDemoApp.swift` + `ContentView.swift`)
  - 刻意保守:不用新 SwiftUI API、不用宏、不用 Observation
- [ ] **B5** 手写 `apps/EnvDemo/Info.plist`(版本字段由 `tools/sync-version.sh` 生成)→ **并入 Phase C `bundle.sh` 一起做**
- [x] **B6** 在 Air 上首跑:✅ `swift build`(11.79s)+ `swift test`(**3 通过 0 失败**)全绿

---

## Phase C — `tools/` 脚本

> 约定:所有脚本 source `tools/_common.sh`;平台固定 macOS,无需跨平台分支。

- [x] **C1** `tools/_common.sh`(REPO_ROOT / DEVELOPER_DIR / `die`·`note`·`ok`·`skip` / 版本读取)
- [x] **C2** `tools/doctor.sh` —— 环境自检(✅ 9 项全绿)
- [x] **C3** `tools/bootstrap.sh` —— 引导装 xcodes → Xcode 27 → iOS runtime(幂等;sudo/登录人工)
- [x] **C4** `tools/sync-version.sh` —— 版本输出 / `--check`(SemVer + 源码无版本字面量,D8)
- [x] **C5** `tools/build.sh` —— `swift build`(先 `sync-version --check`)
- [x] **C6** `tools/test.sh` —— `swift test`
- [x] **C7** `tools/bundle.sh` —— 原生打包(macOS + iOSSimulator,读 version.properties 填版本,ad-hoc 签名)
- [x] **C8** `tools/run-sim.sh` —— 打包并跑 iOS 模拟器(boot→install→launch→可选截图)
- [x] **C9** `tools/sim.sh` —— `simctl` 封装(list/runtimes/boot/install/launch/screenshot/download-runtime)
- [x] **C10** `tools/ui-dump.sh` —— 截图验收(文本树后置)
- [x] **C11** `tools/new-app.sh` —— 以 EnvDemo 为模板生成 apps/<Name>/(✅ 已验证改名无残留)
- [x] **C12** `tools/verify-all.sh` —— 总验收(✅ 6/6 通过:doctor/sync-version/build/test/run-sim/ui-dump)
- [x] **C13** `tools/release.sh` —— Conventional Commits → SemVer(改版本 + 打 tag)
- [x] **C14** `tools/README.md` —— 脚本索引

---

## Phase D — CI(`.github/workflows/`)

- [x] **D1** `ci.yml`(✅ 已写:pin `macos-26`、选 Xcode 27、Conventional Commits 校验、doctor→sync-version→build→test→run-sim+截图→artifact)
- [x] **D2** `release.yml`(✅ 已写:tag 触发 → 校验 tag==version.properties → bundle → `gh release create`)
- [x] **D3** 开 Actions 验证首跑 → ✅ 成功。**发现**:`macos-26` 默认只有 Xcode 26.6;`xcode-27` 镜像含 27.0/27.1/27.2(+beta)。已改用 `xcode-27` + 优先选 `Xcode_27.0.0.app`(**Build 27A266a,与 Air 完全一致**);doctor/build/test/模拟器冒烟均绿。

---

## Phase E — 文档(`docs/`)

- [x] **E1** `01-headless-apple-build.md`(✅)
- [x] **E2** `02-swiftpm-project-conventions.md`(✅)
- [x] **E3** `03-simulator-cli.md`(✅)
- [x] **E4** `04-packaging-native.md`(✅)
- [x] **E5** `05-app-conventions.md`(✅)
- [x] **E6** `06-ui-acceptance.md`(✅)
- [x] **E7** `07-cross-platform-and-no-mac.md`(✅)
- [x] **E8** `08-gotchas.md`(✅)
- [x] **E9** `docs/research/` 保留作来源(01 平台规则 / 03 否定结论);已在 docs/README 标明分工
- [x] **E10** `docs/README.md` 索引更新(✅)

---

## Phase F — 静态自检与交付

- [x] **F1** `bash -n tools/*.sh` → ✅ 13 个脚本全通过
- [x] **F2** YAML 校验两个 workflow → ✅ 通过(ruby YAML)
- [x] **F3** 文档内部链接校验 → ✅ 全部存在(修掉执行期文档的 `../` 误用)
- [x] **F4** `git grep` 真实 IP / token / 私钥 → ✅ 零命中
- [x] **F5** 措辞检查 → ✅ research 标「未验证/已核实」,执行期文档用「实测」
- [x] **F6** `tools/verify-all.sh` 总验收 → ✅ 6/6 通过

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
| 2026-09-26 | Phase 0–C 完成:装 Xcode 27.0、EnvDemo 工程、原生打包全链路验证 | 执行期 |
| 2026-09-26 | Phase D 完成:CI/release 用 `xcode-27` label + Xcode 27.0 | 对齐 Air(实测) |
| 2026-09-26 | Phase E–F 完成:执行期文档 01–08 + 静态自检 + verify-all 6/6 | — |
