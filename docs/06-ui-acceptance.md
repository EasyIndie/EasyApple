# 06 — UI 验收(截图为先 + 原生 OCR 文本验收)

> **状态:已在 Air 实测**(截图、OCR、断言均跑通;数字见下)。

## 1. 策略

| 层次 | 手段 | 决策 |
|---|---|---|
| 渲染是否对 | 截图(`simctl io screenshot`) | [D7](00-decisions.md) 截图为先 |
| 文本是否对 | **原生 OCR**(Apple Vision) | **D15** |
| 逻辑在 iOS 运行时是否对 | `xcodebuild test`(SwiftPM 包,无需工程) | 已落地,见 §8 |
| 精确树 / 交互 | 未采用(需 XCUITest 或 idb) | 后置,见 §5 |

## 2. 截图(已验证)

```bash
tools/run-sim.sh --screenshot /tmp/envdemo.png   # 一条命令:打包→装→启动→截图
tools/ui-dump.sh --out /tmp/envdemo.png          # 只截图
```

实测:iPhone 17 截图分辨率 **1206×2622 px**(对应 393×852 pt)。

### 2.1 确定性截图(状态栏 / 外观 / 字号)

状态栏时间、电量、信号会进入画面与 OCR 文本(以前每次都不同,如 `01:22`),
导致断言与截图对比漂移。`ui-dump` / `ui-scan` / `ui-assert` 现在会在截图前自动固定、
截完恢复(`_common.sh` 的 `ui_env_lock` / `ui_env_restore`):

```bash
tools/ui-dump.sh --out /tmp/a.png                 # 默认:状态栏固定 09:41/满电/满格,截完复原
tools/ui-dump.sh --appearance dark --out /tmp/b.png          # 深色模式
tools/ui-dump.sh --content-size accessibility-large --out /tmp/c.png   # 大字号(无障碍)
tools/ui-scan.sh --appearance dark                # OCR 也可指定
tools/ui-assert.sh --app EnvDemo --no-fix-status  # 不想动状态栏时
```

> 固定只对**已启动**的设备生效;设备没启动时跳过(截图本身也要求 booted)。

实测(2026-10-19):固定后截图状态栏为 `09:41`,OCR 文本第一行稳定为 `09:41`;
截图结束后 `simctl status_bar list` 恢复为空,外观恢复为原值。
若模拟器**原本就有**状态栏覆盖,工具会保留并提示手动 `simctl status_bar <udid> clear`。

## 3. 文本级验收:原生 OCR(已验证,D15)

`tools/ui-scan.sh` 截图后交给 `tools/uiscan.swift`(Apple **Vision** 框架
`VNRecognizeTextRequest`)识别为文本;`tools/ui-assert.sh` 在其上做断言。

```bash
tools/ui-scan.sh                       # 对 booted 设备截图并输出文本
tools/ui-scan.sh --input /tmp/a.png    # 复用已有截图
tools/ui-scan.sh --json                # 带置信度 + 归一化坐标(x,y,w,h)
tools/ui-assert.sh --contains "arm64" --contains "模拟器" --not-contains "Error"
```

实测输出(EnvDemo,`--accurate` + `zh-Hans`):

```
01:22
型号：1Phone 17          ← OCR 把 iPhone 看成了 1Phone
系统：ios 26.4.1
模拟器：是
架构：arm64
屏幕：393 x 852 pt
内存：8.00 GB
存储：228.24 GB
GPU： Apple 10S simulator GPU
```

**性能**:中文模型冷加载约 **97 s**(一次性),之后热跑 **0.3–0.55 s**。

> ⚠️ **OCR 是「有损」识别**。断言要选**稳定、无歧义**的串(`arm64`、`模拟器`、`393 x 852`),
> 别用 OCR 易看错的(实测 `iPhone 17` → `1Phone 17`、`iOS` → `10S`)。
>
> ⚠️ **macOS 27 已知 bug**:语言列表**只认第一个**;中英混排必须 `[zh-Hans, en-US]`
> (反过来 `[en-US, zh-Hans]` 会把中文识别成乱码)。本工具默认就用这个顺序,见 [08](08-gotchas.md)。

### 3.1 每个应用自带断言文件(推荐)

断言可以写进 `apps/<Name>/ui-assertions.txt`,用 `--app` 引用:

```bash
tools/ui-assert.sh --app EnvDemo
```

语法(每行一条):

| 写法 | 含义 |
|---|---|
| `+串` | 必须出现 |
| `-串` | 必须不出现 |
| `裸串` | 等同 `+串` |
| `# …` / 空行 | 注释 |

`verify-all.sh` 与 CI 会**自动找**这个文件:有就跑断言,没有就 `[skip]`。
新建应用(`tools/new-app.sh`)会自动带一份拷贝,记得改成自己 UI 的串。

## 4. 为什么不用无障碍树 / XCUITest / idb(实测否决)

三条「精确」路线都试过/评估过,结论是**都不适配「无头 + 零第三方」**:

| 路线 | 否决原因(实测) |
|---|---|
| **宿主 AX API**(xctree / iosef 的做法) | 需 `AXIsProcessTrusted()==true`(本机实测 **false**,要人工到系统设置里授权);且它读的是 **Simulator.app 宿主进程**的树 —— `simctl boot` 无头启动时实测 `simulator app count: 0`,**根本没有宿主进程**。与「无头/CI」天然冲突。 |
| **XCUITest** | 是 Apple 官方的无头 UI 测试方案(不需要 GUI/授权),但**需要 `.xcodeproj` + UI Test target**,SwiftPM 不支持 UI 测试 bundle → 与 [D4/D5](00-decisions.md)「不生成 `.xcodeproj`」冲突。补充(2026-10):SDK 里的模块已叫 `XCUIAutomation`,`XCUIApplication(bundleIdentifier:)` 可驱动**已安装的任意 App** —— 意味着临时工程只需一个 UI test target、不必接管 App 构建;详见 [research/06](research/06-automated-testing-acceptance.md) §2.5(**未在本仓库验证**)。 |
| **idb** | 第三方(与「只用原生工具」冲突),且 [D7](00-decisions.md) 已明确不用。 |

→ 因此文本级验收选 **原生 OCR**(D15):免授权、可无头、可进 CI。

## 5. 交互断言(后置)

点击/输入这类**交互**目前**没做**:`simctl` 无 tap,精确交互只有 XCUITest / idb 两条路(见 §4)。
两条可选路径(都需新决策):

1. **XCUITest + 一次性生成(不入库)的 `.xcodeproj`** —— 保留「SwiftPM 是工程真相」,只为 UI 测试临时生成工程并 gitignore;
2. 引入 **idb** —— 放弃「零第三方」。

## 6. CI

`ci.yml` 现在跑三层测试/验收:

1. `tools/test.sh` —— 宿主机 `swift test`(快);
2. `tools/test-ios.sh` —— iOS 模拟器里的单测(无需 `.xcodeproj`),结果作 artifact 上传;
3. 「模拟器冒烟 + 文本断言」**遍历 `apps/` 下的每个应用**:
   `run-sim --app <Name> --screenshot` → `ui-scan` → `ui-assert --app <Name>`,截图作为 artifact 上传。

新增的 iOS 单测步骤是**阻塞的**(单测确定性强,失败就该挂);冒烟/OCR 仍 `continue-on-error`,
避免 runner 环境差异把 CI 拖红。

> **实测**:GitHub `xcode-27-arm64` runner 是 **VM(无真 GPU/ANE**,日志有 `AppleM2ScalerParavirtDriver`),
> `VNRecognizeTextRequest` 的 **`.accurate` 级别会失败**(`unknownError`/`nilError`),但 **`.fast` 级别可用**。
> `uiscan` 的多配置回退链会自动降级到 `.fast`,所以 **CI 上文本断言真的跑通了**(实测 `arm64`/`GB` 均通过)。
> 若某环境两种级别都不可用,CI 会**跳过**而不误报失败。

## 7. 已知限制

- OCR 只验「屏幕上有没有这段文字」,不验位置关系、不验交互。
- 首次(冷)识别慢约 90 s;断言串必须用稳定 token。
- 截图/OCR 在模拟器上可靠(模拟器无 Android 的 `FLAG_SECURE` 类限制)。
- 状态栏/外观/字号已可固定,但**动画、网络数据、系统弹窗**仍可能让截图不稳定 ——
  需要时用启动参数/预授权(`simctl privacy`)把 App 置入确定状态。

## 8. iOS 运行时单测(SwiftPM 包,无需 `.xcodeproj`)

`tools/test.sh` 只在**宿主机 macOS** 上跑 `swift test`;要靠 UIKit/真机语义的代码得在
iOS 运行时里跑。Xcode 会为 SwiftPM 包自动生成聚合 scheme **`<包名>-Package`**,它带 test action:

```bash
tools/test-ios.sh                      # 遍历 apps/,跑在默认模拟器
tools/test-ios.sh EnvDemo --coverage   # 覆盖率
tools/test-ios.sh --device "iPhone 17" --filter EnvDemoCoreTests/EnvironmentReportTests
```

实测(2026-10-19,Xcode 27.0 / iOS 26.4.1 模拟器):`EnvDemo` **3 通过 / 0 失败**,
增量 ≈ 16 s;产物在 `apps/<App>/.build/ios-test/result.xcresult`,可直接:

```bash
xcrun xcresulttool get test-results summary --path apps/EnvDemo/.build/ios-test/result.xcresult
xcrun xccov view --report apps/EnvDemo/.build/ios-test/result.xcresult   # 需 --coverage
```

> ⚠️ 不能用 `-scheme EnvDemoCore`:会报 *"Scheme is not currently configured for the test action"*。
> ⚠️ 真机不行:纯 SwiftPM 的单测是 tool-hosted,报 *"Tool-hosted testing is unavailable on device
> destinations"* —— 真机单测要 host app(即工程文件)。见 [08](08-gotchas.md)。
> 更完整的方案分层(性能基线 `measure`/`xctrace`、XCUITest 取舍、真机)见
> [research/06](research/06-automated-testing-acceptance.md)。
