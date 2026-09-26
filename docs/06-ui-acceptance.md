# 06 — UI 验收(截图为先 + 原生 OCR 文本验收)

> **状态:已在 Air 实测**(截图、OCR、断言均跑通;数字见下)。

## 1. 策略

| 层次 | 手段 | 决策 |
|---|---|---|
| 渲染是否对 | 截图(`simctl io screenshot`) | [D7](00-decisions.md) 截图为先 |
| 文本是否对 | **原生 OCR**(Apple Vision) | **D15** |
| 精确树 / 交互 | 未采用(需 XCUITest 或 idb) | 后置,见 §5 |

## 2. 截图(已验证)

```bash
tools/run-sim.sh --screenshot /tmp/envdemo.png   # 一条命令:打包→装→启动→截图
tools/ui-dump.sh --out /tmp/envdemo.png          # 只截图
```

实测:iPhone 17 截图分辨率 **1206×2622 px**(对应 393×852 pt)。

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

## 4. 为什么不用无障碍树 / XCUITest / idb(实测否决)

三条「精确」路线都试过/评估过,结论是**都不适配「无头 + 零第三方」**:

| 路线 | 否决原因(实测) |
|---|---|
| **宿主 AX API**(xctree / iosef 的做法) | 需 `AXIsProcessTrusted()==true`(本机实测 **false**,要人工到系统设置里授权);且它读的是 **Simulator.app 宿主进程**的树 —— `simctl boot` 无头启动时实测 `simulator app count: 0`,**根本没有宿主进程**。与「无头/CI」天然冲突。 |
| **XCUITest** | 是 Apple 官方的无头 UI 测试方案(不需要 GUI/授权),但**需要 `.xcodeproj` + UI Test target**,SwiftPM 不支持 UI 测试 bundle → 与 [D4/D5](00-decisions.md)「不生成 `.xcodeproj`」冲突。 |
| **idb** | 第三方(与「只用原生工具」冲突),且 [D7](00-decisions.md) 已明确不用。 |

→ 因此文本级验收选 **原生 OCR**(D15):免授权、可无头、可进 CI。

## 5. 交互断言(后置)

点击/输入这类**交互**目前**没做**:`simctl` 无 tap,精确交互只有 XCUITest / idb 两条路(见 §4)。
两条可选路径(都需新决策):

1. **XCUITest + 一次性生成(不入库)的 `.xcodeproj`** —— 保留「SwiftPM 是工程真相」,只为 UI 测试临时生成工程并 gitignore;
2. 引入 **idb** —— 放弃「零第三方」。

## 6. CI

`ci.yml` 的「模拟器冒烟」步骤跑 `run-sim --screenshot` 后做文本断言,截图作为 artifact 上传。

> **实测**:GitHub `xcode-27-arm64` runner 是 **VM(无真 GPU/ANE**,日志有 `AppleM2ScalerParavirtDriver`),
> `VNRecognizeTextRequest` 的 **`.accurate` 级别会失败**(`unknownError`/`nilError`),但 **`.fast` 级别可用**。
> `uiscan` 的多配置回退链会自动降级到 `.fast`,所以 **CI 上文本断言真的跑通了**(实测 `arm64`/`GB` 均通过)。
> 若某环境两种级别都不可用,CI 会**跳过**而不误报失败。

## 7. 已知限制

- OCR 只验「屏幕上有没有这段文字」,不验位置关系、不验交互。
- 首次(冷)识别慢约 90 s;断言串必须用稳定 token。
- 截图/OCR 在模拟器上可靠(模拟器无 Android 的 `FLAG_SECURE` 类限制)。
