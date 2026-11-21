# EnvDemo

仓库的**示例 + 自检应用**:证明「SwiftPM 工程 → 原生打包 → 模拟器 → OCR 断言」整条链路可用。

它曾经也是 `new-app.sh` 的模板来源,现在模板已独立到仓库根 [`template/`](../../template/),
EnvDemo 不再承担模板职责。

## 它做什么

启动后把当前设备/模拟器的环境信息渲染成一屏文本:型号、系统、是否模拟器、架构、
屏幕、内存、存储、GPU。纯逻辑在 `Sources/EnvDemoCore/`,可在宿主机秒级单测。

## 构建 / 运行 / 验收

```bash
tools/build.sh EnvDemo
tools/test.sh EnvDemo
tools/test-ios.sh --app EnvDemo          # 跑在 iOS 模拟器运行时
tools/run-sim.sh --app EnvDemo           # 打包 → 装 → 启动
tools/ui-assert.sh --app EnvDemo         # 截图 → OCR → 断言
```

一键端到端:`tools/verify-all.sh EnvDemo`。

## 断言

`ui-assertions.txt` 里只用稳定 ASCII 串(`arm64` / `GB`)。OCR 是有损识别,
不要加 `iPhone 17` 这类容易被认错的串,原因见 [docs/08](../../docs/08-gotchas.md)。
