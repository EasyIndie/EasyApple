# 06 — Apple 正向开发的自动化测试 / 验收方案(2026-10 快照)

> **状态:方案调研 + 在 Air 上逐条实测**(命令、耗时、结果都来自本机,标注 ✅/⚠️)。
> 本文不改任何既有决策;建议落地项需另开决策([D16](../00-decisions.md) 待定)。

## 0. 结论:分 6 层,能落地的先落地

| 层 | 验什么 | 手段 | 要 `.xcodeproj`? | 本机状态 |
|---|---|---|---|---|
| **L0** 编译/风格门 | 能不能编、有没有警告/风格漂移 | `swift build -Xswiftc -warnings-as-errors`、`swift-format lint`(Xcode 自带) | ❌ | ✅ 工具在 |
| **L1** 宿主机单测 | 纯逻辑(`EnvDemoCore`) | `swift test`(+ `--xunit-output`、`--enable-code-coverage`) | ❌ | ✅ 已在用 |
| **L2** iOS 运行时单测 | 依赖 UIKit/真机语义的逻辑、`XCTest.measure` 性能基线 | `xcodebuild test -scheme <Pkg>-Package -destination 'platform=iOS Simulator,…'` | ❌ **不需要**(实测) | ✅ 实测通过 |
| **L3** 应用级验收 | 界面渲没渲染、文案对不对 | `simctl` 固定环境 → 截图 → OCR/像素比对(D7/D15) | ❌ | ✅ 已在用,可加强 |
| **L4** 交互 / 精确树 / 无障碍审计 | 点、输、滑、定位到具体元素、`performAccessibilityAudit` | XCUITest(`XCUIAutomation.framework`) | ✅ **必须**(UI test bundle) | ⚠️ 与 D4/D5 冲突,后置 |
| **L5** 真机 | 设备行为、性能、耗电 | `devicectl`(装/启/截图)、`xcodebuild test -destination id=…` | 单测要 host app;UI 测试要工程 | ⚠️ 设备与证书都在,纯 SwiftPM 到不了 |

**一句话**:正向开发的自动化验收,90% 的价值用 L0–L3 就能拿到,而且全部原生、无头、零第三方;
只有「模拟点击/精确定位/无障碍审计」必须付 `.xcodeproj` 的代价(L4)。

## 1. 关键实测发现(最有价值的三条)

### 1.1 SwiftPM 包可以直接在 iOS 模拟器上跑单测 —— 不需要工程文件

```bash
cd apps/EnvDemo
xcodebuild test -scheme EnvDemo-Package \        # 注意:不是 -scheme EnvDemoCore
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -resultBundlePath /tmp/xcdd/EnvDemoCore.xcresult
```

实测 2026-10-19(Xcode 27.0 / iOS 27.0 模拟器 / Swift 6.4):

- 3 个 `EnvDemoCoreTests` 全部通过,编译 + 跑测 **37 s**(冷),增量 ≈ 30 s;
- 结果 bundle 可用 `xcrun xcresulttool get test-results summary|tests --path …` 解析(JSON);
- `-enableCodeCoverage YES` + `xcrun xccov view --report` 给出逐文件/逐函数覆盖率(实测 35.92%);
- `-only-testing:EnvDemoCoreTests/EnvironmentReportTests/testFormatBytes` 过滤生效;
- `-testLanguage zh-Hans -testRegion CN` 生效(给 i18n 验收用);
- `build-for-testing` 产物里的 `*.xctestrun` 可复用:
  `xcodebuild test-without-building -xctestrun /tmp/xcdd/Build/Products/EnvDemo-Package_EnvDemo-Package_iphonesimulator27.0-arm64.xctestrun -destination id=<UDID>`
  → 实测 **29 s**(含模拟器开机),不再编译。

> 两个坑:`-scheme EnvDemoCore` 会报 *"Scheme is not currently configured for the test action"*,
> 要用 Xcode 自动生成的聚合 scheme **`<包名>-Package`**;`-destination` 用设备名时若同名设备
> 存在于多个 runtime(26.4.1 / 27.0 各一套)会歧义,改用 `id=<UDID>`。

### 1.2 纯 SwiftPM 到不了真机(单测层面)

```text
xcodebuild: error: Cannot test target "EnvDemoCoreTests" on "iPhoneSE3":
Tool-hosted testing is unavailable on device destinations.
Select a host application for the test target, or use a simulator destination instead.
```

即「tool-hosted」单测只在模拟器可用;真机单测必须挂一个 host app(→ 必须工程)。
本机确实连着 **iPhone SE3(iPhone14,6,iOS 27.0.1,paired)**,也有
`Apple Development` 证书,所以做**真机冒烟**(`devicectl` 装/启/截图)没问题,
但做**真机自动化测试**要临时工程。

### 1.3 截图验收可以做到「确定性」,OCR 断言才稳

`simctl` 原生就能固化那些会进 OCR 文本的随机量(状态栏时间/电量/信号):

```bash
xcrun simctl status_bar booted override --time "09:41" --batteryState charged \
  --batteryLevel 100 --wifiBars 3 --cellularBars 4
xcrun simctl ui booted appearance dark        # / light
xcrun simctl ui booted content_size extra-extra-extra-large   # 动态字体(无障碍)
xcrun simctl io booted screenshot /tmp/a.png
xcrun simctl status_bar booted clear          # 复位
```

实测:override 后截图状态栏固定为 `09:41`、满格电/满格信号(截图已核对)。
现状 `docs/06` 的 OCR 输出第一行就是 `01:22` 这种随机时间 —— 先 override 再截图,
断言里就不必绕开状态栏。

## 2. 各层细节与命令

### 2.1 L1 宿主机单测(已有,补两件原生能力)

```bash
swift test                                  # 现有 tools/test.sh
swift test --xunit-output /tmp/junit.xml    # ✅ 原生 JUnit,CI 直接吃
swift test --enable-code-coverage           # + swift test --show-codecov-path
swift test --parallel --num-workers 4
swift test --filter EnvironmentReportTests  # 也支持 --skip
```

Swift Testing(`import Testing` / `@Test` / `#expect`)在 `swift test` 与
`xcodebuild test` 下都能跑(本机用临时包实测:`✔ Test … passed`),可与 XCTest 混用。

### 2.2 L2 结果与覆盖率解析(全原生,JSON)

```bash
xcrun xcresulttool get test-results summary --path X.xcresult   # 通过/失败/设备/耗时
xcrun xcresulttool get test-results tests   --path X.xcresult   # 树状用例
xcrun xcresulttool get test-results metrics --path X.xcresult   # measure 指标
xcrun xcresulttool export attachments       --path X.xcresult --output-path /tmp/att
xcrun xcresulttool export coverage          --path X.xcresult --output-path /tmp/cov
xcrun xcresulttool compare A.xcresult --baseline-path B.xcresult --test-failures
xcrun xccov view --report --json X.xcresult
```

实测 `metrics` 会给出 `baselineAverage` / `maxPercentRegression` / 每次
`measurements` —— 性能基线就是靠这组字段做「不许退化超过 N%」。

### 2.3 L2 性能基线(不写 UI 测试也能做)

- XCTest `measure {}` 写在普通单测里,随 L2 一起跑,结果进 `xcresult`(实测);
- 需要更细(CPU/内存/卡顿/启动)时用 `xctrace`(模板已随 Xcode 安装,本机 30+ 个):

```bash
xcrun xctrace list templates      # Time Profiler / Allocations / Leaks / App Launch / Animation Hitches …
xcrun xctrace record --template 'Time Profiler' --device <SIM_UDID> \
  --time-limit 3s --all-processes --output /tmp/sim.trace
xcrun xctrace export /tmp/sim.trace --toc
```

实测:`--device` 直接吃模拟器 UDID,3 s 的 Time Profiler trace 约 **33 MB** →
只适合按需跑,别进每次 CI。

### 2.4 L3 应用级验收(在现有 `run-sim`/`ui-scan` 上加「确定性」+「无 UI 断言」)

除了截图+OCR,`simctl` 还提供一批**不依赖界面**的验收抓手(本机逐条 help 核对,
标注实测项):

| 能力 | 命令 | 用途 |
|---|---|---|
| 启动参数/环境变量 | `simctl launch booted <id> -Arg YES`;`SIMCTL_CHILD_*` 环境变量 | 让 App 进入「测试模式/固定数据」 |
| 收集 stdout/stderr | `simctl launch --stdout=/tmp/o.txt --stderr=/tmp/e.txt booted <id>` | 断言日志(✅ 实测,注意要 `=` 写法) |
| 系统日志断言 | `simctl spawn booted log show --last 1m --predicate 'process == "EnvDemo"'` | 断言 `os_log` 关键事件(✅ 实测) |
| 读数据容器 | `simctl get_app_container booted <id> data` | App 写 JSON 状态文件,宿主断言(✅ 实测) |
| 权限预置 | `simctl privacy booted grant photos <id>` | 跳过系统弹窗,避免卡住流程 |
| 深链导航 | `simctl openurl booted "<scheme>://…"` | 不开 UI 也能进到指定页面 |
| 推送 | `simctl push booted <id> payload.json` | 通知相关验收 |
| 定位 | `simctl location booted set 31.23,121.47` | 定位相关验收 |
| 剪贴板 | `simctl pbcopy booted < /tmp/t.txt` | 粘贴类验收 |
| 录屏 | `simctl io booted recordVideo --codec=h264 /tmp/a.mov` | 动画/交互留证 |
| 状态栏/外观/字号 | `simctl status_bar` / `ui appearance` / `ui content_size` | 截图确定性(✅ 实测) |

> 这些加起来,「无 UI 断言」已经很强:**启动参数决定状态 → 容器里的 JSON / os_log 决定结果**,
> 比 OCR 精确得多,且完全无头。

### 2.5 L4 交互 / 精确树 / 无障碍审计:唯一原生方案是 XCUITest,但必须工程

- SDK 里的模块已改名 **`XCUIAutomation.framework`**(不再是 `XCTest` 里的 XCUITest 命名),
  `XCUIApplication(bundleIdentifier:)` 可驱动**已安装的任意 App**(不必是 target app);
- 因此「临时生成一个只含 UI test target 的工程」理论上是可行且侵入最小的:
  App 仍由 `tools/bundle.sh` + `simctl install` 产出,测试工程只负责跑测试(⚠️ **本仓库未验证**);
- 顺带能拿到:`XCUIElement` 精确查询、`debugDescription` 文本树(可替代 idb 的 `ui describe-all`)、
  `performAccessibilityAudit(for:)`(对比度/命中区/描述缺失等,Apple 官方审计);
- 代价:UI test bundle 只能由 Xcode 工程产出 → 需要一个**生成即弃**(gitignore)的 `.xcodeproj`;
- 与 [D4/D5](../00-decisions.md)「不生成 `.xcodeproj`」直接冲突,所以**维持后置**,
  真要做按 `docs/06` §5 的路线另开决策。

⚠️ 未验证:XCUITest 在**无 Simulator.app 的无头**模式下是否稳定(CI 上通用做法,但本机没跑过);
按 D15 的实测,宿主 AX 路线在无头时没有宿主进程,二者不是一回事,别混。

### 2.6 L5 真机

```bash
xcrun devicectl list devices                       # 本机:iPhoneSE3 / paired / 27.0.1
xcrun devicectl device install app --device <UDID> MyApp.app
xcrun devicectl device process launch --device <UDID> com.easyapple.envdemo
xcrun devicectl device capture screenshot --device <UDID> --destination /tmp/real.png
xcrun xctrace record --template 'Time Profiler' --device <UDID> --attach EnvDemo
```

适合:发布前冒烟、真机性能采样、真实 GPU/ANE 行为。不适合进 CI(没有常驻真机)。

### 2.7 L0 质量门(零第三方)

```bash
xcrun swift-format lint --recursive apps/          # Xcode 自带(本机确认存在)
swift build -Xswiftc -warnings-as-errors
xcodebuild analyze -scheme EnvDemoCore -destination 'platform=iOS Simulator,…'      # ✅ 实测 ANALYZE SUCCEEDED
```

`xcodebuild analyze` 对纯 Swift 价值有限(它主要是 Clang analyzer),但能扫到 C/ObjC 桥接与
部分资源问题;Swift 侧的「静态检查」现实上靠编译警告 + `swift-format`。

## 3. 建议落地顺序(不改现有决策,先做 P0)

> **P0 已于 2026-10-19 落地**(实测见 §1.1 / §1.3 与 [docs/06](../06-ui-acceptance.md)):
> `tools/test-ios.sh` 与 `ui-dump`/`ui-scan`/`ui-assert` 的截图确定性。

| 优先级 | 动作 | 收益 | 成本 | 状态 |
|---|---|---|---|---|
| **P0** | `tools/ui-dump.sh` 截图前固定状态栏(可选外观/字号),截完恢复 | OCR/视觉断言不再被时间电量干扰 | ~10 行 | ✅ 已落地(延伸到 `ui-scan`/`ui-assert`) |
| **P0** | 新增 `tools/test-ios.sh`:`<Pkg>-Package` + 模拟器 + `-resultBundlePath` + `xcresulttool summary` | 逻辑能在 iOS 运行时验证(UIKit/API 差异) | ~40 行 | ✅ 已落地(3 通过/0 失败) |
| **P1** | `tools/test.sh` 加 `--xunit-output`(原生 JUnit),CI artifact 化 | 报告标准化,不引第三方 | ~3 行 | 待做 |
| **P1** | `tools/lint.sh`:`swift-format lint` + `-warnings-as-errors` | 风格/警告不允许退化 | ~20 行 | 待做 |
| **P2** | App 增「验收模式」:启动参数(`-UITestSeed 1`)+ 写状态 JSON + `os_log` | 无 UI 精确断言 | 每 App 少量代码 | 待做 |
| **P2** | `tools/perf.sh`:`measure` 单测 + `xcresulttool metrics` 阈值检查 | 性能不退化 | ~50 行 | 待做 |
| **P3** | XCUITest 临时工程(需 D16) | 点击/精确树/无障碍审计 | 高,慎重 | 待决策 |

## 4. 明确不采用的(与既有决策一致)

| 方案 | 结论 | 理由 |
|---|---|---|
| idb | ❌ | 第三方([D7](../00-decisions.md)) |
| Appium / WebDriverAgent / Maestro / Detox | ❌ | 第三方 + 需常驻服务/工程,与「只用原生工具」冲突 |
| 宿主 AX API 读树 | ❌ | 需 TCC 授权,且无头时没有宿主进程([D15](../00-decisions.md) 已实测否决) |
| Xcode UI 录制 | ❌ | 只能在 GUI 里点,与「无 IDE」冲突 |
| 截图逐像素全图比对 | ⚠️ 暂缓 | 抗噪差;先做确定性(状态栏/外观/字体/动画)再谈;原生 CoreGraphics 可自实现 diff,无需第三方 |

## 5. 怎么复核(在本机逐条可跑)

```bash
# L2:SwiftPM 包在模拟器跑单测(预期 3 tests 通过)
cd apps/EnvDemo && xcodebuild test -scheme EnvDemo-Package \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath /tmp/xcdd -resultBundlePath /tmp/xcdd/r.xcresult
xcrun xcresulttool get test-results summary --path /tmp/xcdd/r.xcresult

# 覆盖率
xcodebuild test -scheme EnvDemo-Package -destination 'platform=iOS Simulator,name=iPhone 17' \
  -enableCodeCoverage YES -resultBundlePath /tmp/xcdd/cov.xcresult
xcrun xccov view --report /tmp/xcdd/cov.xcresult

# 真机限制(预期报 tool-hosted 不可用)
xcodebuild test -scheme EnvDemo-Package -destination "id=$(xcrun devicectl list devices \
  | awk '/physical/{print $3; exit}' | tr -d '()')"

# 截图确定性(预期状态栏 09:41 / 满电)
xcrun simctl status_bar booted override --time "09:41" --batteryLevel 100 \
  --batteryState charged --wifiBars 3 --cellularBars 4
xcrun simctl io booted screenshot /tmp/det.png && xcrun simctl status_bar booted clear

# 工具能力清单(不跑测试)
xcrun xcresulttool get test-results --help; xcrun xctrace list templates; xcrun swift-format --version
```

## 6. 参考

- XCTest / 性能度量:`https://developer.apple.com/documentation/xctest`
- XCUIAutomation(XCUITest 的新模块名):`https://developer.apple.com/documentation/xcuiautomation/xcuiapplication`
- 无障碍审计:`https://developer.apple.com/documentation/xcuiautomation/xcuiapplication/performaccessibilityaudit(for:_:)`
- 测试计划 / 测试组织:`https://developer.apple.com/documentation/xcode/organizing-tests-to-improve-feedback`
- 本机证据:SDK 里同时存在 `XCTest.framework` / `XCUIAutomation.framework` / `Testing.framework` /
  `_Testing_UIKit.framework`(Xcode 27.0);`xcresulttool version 25115, schema 0.4.0`。

实测环境:`macOS 27.0.1 (26A434)` / `Xcode 27.0 (27A266a)` / `Swift 6.4` /
模拟器 iPhone 17(iOS 27.0 与 26.4.1 两套 runtime 并存)/ 真机 iPhone SE3(iOS 27.0.1)。
快照时间:2026-10-19。
