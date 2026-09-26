# EasyApple 执行计划

> **这份文件是「活文档」,就是给你在 Air 上直接改的。**
> 改计划不需要先改代码:直接编辑本文件里的复选框与步骤描述即可。
> 改完可以先把「计划变更」单独提交一次(`docs: 在 Air 上调整执行计划`),
> 再进入执行阶段。
>
> 状态图例:`[ ]` 未做 · `[~]` 进行中 · `[x]` 已完成 · `[-]` 已砍掉。
> 环境图例:`[W]` Windows 可做 · `[M]` 必须在 macOS(Air)上做 · `[W/M]` 两边都能做。

---

## 0. 背景与目标

做一个对标 [`EasyIndie/EasyAndroid`](https://github.com/EasyIndie/EasyAndroid) 的
**Apple 平台无 IDE 命令行开发实践库**,并在其中沉淀「怎么在只有命令行的情况下
构建/运行/验收 iOS + macOS 应用」的结论与脚本。

调研上下文(规划期已完成,尚未真机验证)见:

- [`docs/research/01-apple-platform-rules-2026.md`](docs/research/01-apple-platform-rules-2026.md)
- [`docs/research/02-cross-platform-dev.md`](docs/research/02-cross-platform-dev.md)
- [`docs/research/03-simulator-cross-platform.md`](docs/research/03-simulator-cross-platform.md)
- [`docs/research/04-swiftpm-packaging.md`](docs/research/04-swiftpm-packaging.md)

决策记录见 [`docs/00-decisions.md`](docs/00-decisions.md)。

### 0.1 硬前提(改计划前先读)

1. **构建只能在 macOS 上。** Windows 上能写文档/源码,不能构建、不能跑模拟器。
2. **必须先装完整 Xcode**,但可以从不打开 GUI。「无 IDE」= 无 Xcode GUI,
   不是无 Xcode。CLT 拿不到 iOS SDK。
3. **Intel MBP(2015)最高 Xcode 14.2 / Swift 5.7**,不参与构建(见决策 D1)。
4. **首期只做模拟器闭环、零证书**(见决策 D6)。真机/分发后置。

---

## Phase 0 — 决策(planning,已在 `docs/00-decisions.md` 记录)

- [~] **P0.1 [W/M]** 冻结技术决策,状态标为 `proposed`
  - 产出:`docs/00-decisions.md`
  - 验收:每条都有「决策 / 理由 / 状态 / 怎么改」四列
  - 👉 **在 Air 上请把同意的那几条改成 `accepted`,不同意的直接推翻并写理由**

---

## Phase A — 仓库骨架

- [ ] **A1 [W]** `git init -b main`,建 `docs/ apps/ tools/ .github/workflows/`
  - 验收:`git status` 正常,空目录用 `.gitkeep` 占位或推迟创建
- [ ] **A2 [W]** 写 `.gitignore`(已预置 `.build/`、`DerivedData/`、`*.xcodeproj`、
  `tools/host.env`、`*.p12`、`*.mobileprovision`、`.tmp/` 等)
- [ ] **A3 [W]** 写 `LICENSE`(MIT © 2026 wangzhizhou)、`README.md`、`CHANGELOG.md`
- [ ] **A4 [W]** 写 `version.properties`(严格 SemVer 契约注释 + 版本历史区,首版 `0.0.1`)
  - 验收:注释里写清 `CFBundleShortVersionString=version`、
    `CFBundleVersion=MAJOR*10000+MINOR*100+PATCH`、仓库内禁止版本字面量

---

## Phase B — SwiftPM 示例工程(`apps/EnvDemo`)

- [ ] **B1 [W]** `apps/EnvDemo/Package.swift`,`swift-tools-version: 6.0`
  - 两个 product:`EnvDemoCore`(library,不 import SwiftUI)+ `EnvDemo`(executable `@main`)
  - `platforms: [.macOS(.v14), .iOS(.v17)]`
  - 验收:`swift package dump-package` 能解析(需在 Air 上跑)
- [ ] **B2 [W]** 写 `EnvDemoCore`(纯逻辑环境探测:型号 / OS / 是否模拟器 / 架构 /
  屏幕 / 内存 / 存储 / Metal GPU;产出 `EnvironmentReport` + `format(asText:)`)
- [ ] **B3 [W]** 写 `Tests/EnvDemoCoreTests`(只测可注入的纯逻辑,任何 Mac 都能过)
- [ ] **B4 [W]** 写 `EnvDemo` SwiftUI App(`EnvDemoApp.swift` + `ContentView.swift`)
  - **刻意保守**:不用新 SwiftUI API、不用宏、不用 Observation,降低 Windows 盲写的编译风险
- [ ] **B5 [W]** 写 `apps/EnvDemo/Bundler.toml`(swift-bundler 配置)
  - `identifier` / `product` / `version` / `category`,`icon` 先注释
  - `[apps.EnvDemo.plist]` 预留版本注入点;注释标注哪些字段由脚本生成
- [ ] **B6 [W]** 写 `apps/EnvDemo/project.yml`(XcodeGen 逃生舱,非主链路)
- [ ] **B7 [W]** 写 `apps/EnvDemo/README.md`(做什么 / 目标平台 / 构建 / 验收 / 已知限制)
- [ ] **B8 [M]** **在 Air 上首跑**:`swift build` + `swift test`
  - 预期:第一次大概率有编译错误(Windows 盲写),逐个修掉并提交
  - 验收:`swift test` 全绿

---

## Phase C — `tools/` 脚本

> 约定:所有脚本 source `tools/_common.sh`;平台差异(超时/临时目录/路径转换)统一在基座抹平。
> 参考 EasyAndroid 的 `tools/` 经验。

- [ ] **C1 [W]** `tools/_common.sh`
  - `_host_is_macos`、定位 `swift`/`xcrun`/`xcodebuild`/`xcodegen`/`swift-bundler`
  - `run_timeout` / `mktmp` / `win_of` / `mac_run`(经 `host.env` 的 SSH 别名转发)
  - `die` / `note` / `skip` 统一输出;非 macOS 提示「只能远程/CI 模式」
- [ ] **C2 [W]** `tools/host.env.example`(`MAC_SSH_ALIAS` / `MAC_REPO_PATH` /
  `SIM_DEVICE` / `SIM_RUNTIME`)
- [ ] **C3 [W]** `tools/doctor.sh` —— **Air 上的第一条命令**
  - 检测 `xcode-select -p`、`xcodebuild -version`、
    `xcrun --sdk iphonesimulator --show-sdk-path`、`swift --version`、
    `xcrun simctl list runtimes`、`xcodegen --version`、`swift bundler --version`、
    `idb --version`(可选)
  - 缺失项给出可复制安装命令
- [ ] **C4 [W]** `tools/bootstrap.sh` —— Air 一次性安装(幂等)
  - `brew install xcodegen mint`、`mint install moreSwift/swift-bundler@<PINNED_COMMIT>`
  - 可选 `brew install idb-companion`;检查/下载 iOS runtime
  - **不代替人做需要密码 / Apple ID 登录的操作**
- [ ] **C5 [W]** `tools/sync-version.sh`
  - 从 `version.properties` 写 `Bundler.toml` 的 `version` 与 `CFBundleShortVersionString` /
    `CFBundleVersion`;`--check` 只校验(供 CI 与 `verify-all`)
- [ ] **C6 [W]** `tools/build.sh`(`swift build`,先 `sync-version`;产物落 `.tmp/`)
- [ ] **C7 [W]** `tools/test.sh`(`swift test`;`--all` 时走逃生舱 `xcodebuild test`)
- [ ] **C8 [W]** `tools/run-sim.sh`(主链路:`swift bundler run --platform iOSSimulator`)
  - 支持 `--platform macOS` / `--bundle-only` / `--list`
- [ ] **C9 [W]** `tools/sim.sh`(封装 `simctl`;含 `xcodebuild -downloadPlatform iOS`)
  - 文档标注 **Xcode 27 移除 `Simulator.app` 改 Device Hub**,对 CLI 无影响
- [ ] **C10 [W]** `tools/bundle.sh`(`swift bundler bundle`,`--universal`)
- [ ] **C11 [W]** `tools/xcodegen.sh`(逃生舱:`generate` / `build` / `archive`)
- [ ] **C12 [W]** `tools/ui-dump.sh`(截图 + 尽力取文本树;对齐「文本优先」约定)
- [ ] **C13 [W]** `tools/new-app.sh`(以 `EnvDemo` 为模板生成 `apps/<Name>/`)
- [ ] **C14 [W]** `tools/verify-all.sh`(串 `doctor → sync-version --check → build →
  test → run-sim → ui-dump`,输出通过/失败/跳过计数)
- [ ] **C15 [W]** `tools/release.sh`(Conventional Commits → SemVer;写
  `version.properties` + `CHANGELOG.md`;打 tag;推;CI 出包)
- [ ] **C16 [W]** `tools/README.md`(跨平台速记 + 每个脚本一句话用途)
- [ ] **C17 [M]** 在 Air 上逐个跑通并修 bug

---

## Phase D — CI(`.github/workflows/`)

- [ ] **D1 [W]** `ci.yml`
  - `runs-on: macos-26`(**显式 pin,不用 `-latest`**;注释写清 arm64 与 10× 计费)
  - `fetch-depth: 0`、`timeout-minutes`
  - 步骤:bootstrap(缓存 brew/mint) → `doctor` → `sync-version --check` →
    `swift build` → `swift test` → 条件下载 iOS runtime → `run-sim` + 截图 → 上传 artifact
  - 加一步「提交信息规范(Conventional Commits)」校验
- [ ] **D2 [W]** `release.yml`
  - tag 触发(pattern `[0-9]+.[0-9]+.[0-9]+`) → 校验 tag == `version.properties` →
    `swift bundler bundle` → 建 Release 挂 `.app`
  - `permissions: contents: write`;注释预留后续签名 secrets 命名
- [ ] **D3 [M]** 在 Air 上开 Actions 验证首跑

---

## Phase E — 文档(`docs/`)

- [ ] **E1 [W]** `01-headless-apple-build.md`(无 IDE 的 Apple 构建环境;Xcode 必装、可不开)
- [ ] **E2 [W]** `02-swiftpm-project-conventions.md`(SwiftPM 分层范式)
- [ ] **E3 [W]** `03-simulator-cli.md`(模拟器 CLI 与 Xcode 27 Device Hub)
- [ ] **E4 [W]** `04-packaging-with-swift-bundler.md`(原理与限制)
- [ ] **E5 [W]** `05-xcodegen-escape-hatch.md`(逃生舱)
- [ ] **E6 [W]** `06-app-conventions.md`(工程/命名/版本号/发版流程 + 决策记录)
- [ ] **E7 [W]** `07-ui-acceptance.md`(截图 vs 无障碍文本)
- [ ] **E8 [W]** `08-cross-platform-and-no-mac.md`(跨平台/无 Mac 全景)
- [ ] **E9 [W]** `09-gotchas.md`(踩坑 + **Intel MBP 实测边界**)
- [ ] **E10 [W]** `docs/README.md` 索引更新(把 `planned` 改成实际状态)

> E1–E9 是「执行期文档」,与 `docs/research/` 的区别:research 是**规划期调研结论**,
> 执行期文档是**实测后怎么写、怎么用**。同一主题两处都有是故意的(调研 ≠ 实测)。

---

## Phase F — 静态自检与交付

- [ ] **F1 [W]** `for f in tools/*.sh; do bash -n "$f"; done` 全通过
- [ ] **F2 [W]** 用 YAML 解析器校验两个 workflow
- [ ] **F3 [W]** 校验文档内部链接与文件引用全部存在
- [ ] **F4 [W]** `git grep` 确认真实内网 IP / token / 私钥**零命中**
- [ ] **F5 [W]** 检查文档没有把「桌面推演」写成「已验证」(只写「怎么验证」)
- [ ] **F6 [M]** 在 Air 上跑 `tools/verify-all.sh` 作为总验收

---

## 附录 A — 明确不做的事(out of scope)

- ❌ 找「Linux/Windows 上跑 iOS 模拟器」的方案 —— 原理上不可行,见
  [03-simulator-cross-platform.md](docs/research/03-simulator-cross-platform.md)。
- ❌ Hackintosh / 非 Apple 硬件上的 macOS VM 作为团队基线 —— 违反 Apple EULA,只作
  个人研究,不写进主链路。
- ❌ 让 Intel MBP 参与构建 —— 除非把 `swift-tools-version` 压到 5.7 并放弃 Swift 6
  (明显退步,不推荐)。
- ❌ 手写/手维护 `.xcodeproj` —— 它只是 XcodeGen 的生成物,不入库。
- ❌ 首期做真机签名 / App Store 分发 —— 需要付费账号,后置。

## 附录 B — 计划变更记录

| 日期 | 变更 | 原因 |
|---|---|---|
| 2026-09-26 | 初版(在 Windows 上落档) | 规划期完成,待 Air 复核 |
| | | |
