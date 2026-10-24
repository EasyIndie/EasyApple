# 决策记录(Decision Log)

> 状态图例:`proposed` 提案 · `accepted` 已采纳 · `rejected` 已否决 · `superseded by Dx` 被取代。
> 本文件已在 Air 上定稿:规划期的 `proposed` 决策逐条裁决(2026-09-26)。

| 编号 | 决策 | 理由 | 状态 | 怎么改 |
|---|---|---|---|---|
| **D1** | **构建机只用 M1 Air。Intel MBP 不参与构建。** | MBP 2015 最高 macOS 12 → 最高 Xcode 14.2 / Swift 5.7;且 macOS 27 已无 Intel,连 macOS 26 app 都装不上。Air 可装 Xcode 27。 | `accepted` | 已与 D13 一致。 |
| **D2** | **构建/模拟器/验收在 macOS 上。** | iOS SDK 只随完整 Xcode 提供,Xcode 只在 macOS 上运行。 | `accepted` | 无(平台事实)。 |
| **D3** | ~~远程 Mac 走 SSH(`host.env` 别名)~~ | ~~Windows 需经 SSH 到 Air~~ | `superseded by D13` | **Windows 已退出开发**,不再需要 SSH 抽象。 |
| **D4** | **工程真相 = SwiftPM(`Package.swift`);不生成/不维护 `.xcodeproj`。** | 纯文本、可 diff;配原生打包脚本,连 XcodeGen 都不需要。 | `accepted` | 若要 Xcode 工程,需重引入 XcodeGen,但首期无此需求。 |
| **D5** | **打包 = 自写原生脚本(`codesign` + `plutil` + `simctl`)。不用 swift-bundler / XcodeGen。** | 原生工具零第三方依赖、完全可控;swift-bundler 无稳定 release、有 repo 路径歧义;XcodeGen 首期无 watchOS/扩展/XCUITest 需求。 | `accepted` | 若要 watchOS/App 扩展/XCUITest,再评估引入 XcodeGen。 |
| **D6** | **首期只做模拟器闭环,零证书。** | 模拟器不校验签名,零门槛跑通「改代码 → 看界面」;真机/分发需付费账号,后置。 | `accepted` | 要真机时:免费 Apple ID 7 天 profile;付费才长期/分发。 |
| **D7** | **验收:截图为先(`simctl io screenshot`);不用 idb。** | 原生截图零依赖;文本树需第三方(idb)或宿主 AX,首期后置。 | `accepted` | 文本级验收已由 **D15**(原生 OCR)覆盖;更精确的树/交互见 D15。 |
| **D8** | **版本唯一来源 = `version.properties`(严格 SemVer);仓库内禁止版本号字面量。** | 沿用 EasyAndroid,避免版本漂移。 | `accepted` | 无。 |
| **D9** | **CI runner = `macos-26` 显式 pin,不用 `-latest`。** | 换 OS = 换构建环境,不该无声发生;`macos-26` 已核实为 arm64,与 Air 对齐。 | `accepted` | 升 runner 单独开一次。 |
| **D10** | ~~`swift-bundler` pin 到具体 commit~~ | ~~当时计划用 swift-bundler~~ | `superseded by D5` | **已不用 swift-bundler**。 |
| **D11** | **远程仓库 = `EasyIndie/EasyApple`,origin 用 HTTPS。** | 与 EasyAndroid 同组织、同协议。已落地:2026-09-26 首次 push。 | `accepted` | 要换 SSH/组织/协议时改 `git remote set-url`。 |
| **D12** | **目标工具链 = Xcode 27.0(最新)。** | macOS 27.0 已满足 Xcode 27 的 ≥26.6 要求;锁最新、带 Swift 6.4 + iOS 27 SDK。 | `accepted` | 降级路径:Xcode 26.6(macOS 26.2+)。 |
| **D13** | **arm64-only,Intel Mac 不纳入构建与分发。** | Xcode 27 / macOS 27 已无 Intel 构建;手里唯一 Intel(2015 MBP)永久出局。 | `accepted` | 要支持 Intel 须退回 Xcode 26.6 + universal 构建 + 降 target,见 PLAN 附录 A。 |
| **D14** | **`xcodes` 仅用于 bootstrap 装机(装 Xcode + 模拟器 runtime),不进入构建/打包链路。** | 装机也要命令行化、可锁版本/架构;xcodes 是 Apple 下载页的自动化客户端,不改变 Xcode 本体。属于「装机」而非「构建/打包」,不违反 D5。 | `accepted` | 若要零第三方二进制,退路是官网直下 `.xip` + `xip --expand`。 |
| **D15** | **文本级验收用原生 OCR(Apple Vision),不用 idb / 宿主 AX API / XCUITest。** | 实测:宿主 AX 路线要 `AXIsProcessTrusted` 为真 + Simulator.app GUI(`simctl boot` 无头启动时 `simulator app count: 0`,根本没宿主进程);XCUITest 需 `.xcodeproj`(与 D4/D5 冲突);idb 是第三方。Vision OCR 完全原生、免授权、无头 + CI 可跑(热跑 <1s)。代价:**有损识别**,断言用稳定串。 | `accepted` | 要**精确**无障碍树 / 交互断言时,只剩两条路:一次性生成(不入库)`.xcodeproj` 跑 XCUITest,或引入 idb —— 都需新决策。见 [docs/06](06-ui-acceptance.md)。 |
| **D16** | **签名/公证等发布能力外置为独立仓库 `EasyIndie/EasyRelease`,EasyApple 不内置发布基础设施。** | 多项目复用需要独立版本与供应链边界;放进实践库会与产品版本、评审互相牵连。EasyRelease 以 composite action + reusable workflow 提供,坚持只用原生工具(受 D5 约束);EasyApple 作为首个消费方,已用组织共享凭据验证 Developer ID + 公证链路。 | `accepted` | 需要跨仓库一键发布 / 排队 / 审计时,再评估 GitHub App(只做控制面),另行决策。 |
| **D17** | **正式发布改用 EasyRelease:tag 触发 → matrix 构建 → Developer ID 签名 + 公证 + staple → zip + sha256 → GitHub Release。** | 组织共享凭据已验证;发布物应双击可开,不再附带绕过 Gatekeeper 的脚本。签名实现只在 EasyRelease 维护,`release.yml` 只做编排与发布。 | `accepted` | 需要 App Store / TestFlight 时另开链路;回退可恢复旧 ad-hoc release(历史 tag 不受影响)。 |

## 变更记录

| 日期 | 变更 |
|---|---|
| 2026-09-26 | 初版(D1–D11,全部 `proposed`,Windows 上落档) |
| 2026-09-26 | D11 修正:origin 改 HTTPS 并标记「已落地」 |
| 2026-09-26 | 在 Air 上定稿:D2/D4/D5/D6/D7/D8/D9/D11 采纳;D3/D10 被取代;新增 D12/D13 |
| 2026-09-26 | 新增 D14(xcodes 仅 bootstrap 装机) |
| 2026-09-27 | 新增 D15(文本级验收用原生 OCR);D7 收窄为「截图为先」 |
| 2026-10-24 | 新增 D16(发布能力外置为 EasyRelease;EasyApple 只做消费方) |
| 2026-10-24 | D16 落地:EasyRelease `apple-v0.4.0`;EnvDemo 用组织共享凭据验证 Developer ID + 公证 + staple + Gatekeeper 全部通过;composite action(run `40095862502`)、reusable workflow(run `40096049639`)、`secrets: inherit`(run `40097027827`)三链路均验证 |
| 2026-10-24 | 新增 D17:正式 `release.yml` 切换 EasyRelease,产出签名/公证 zip;dry-run run `40099918160` 通过 |
| 2026-10-24 | EasyRelease v0.6.0:`.dmg`/`.zip` 真链路验证通过;公证支持 API Key 与 App 专用密码(run `40099541736`) |
