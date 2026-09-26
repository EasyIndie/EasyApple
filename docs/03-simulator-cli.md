# 03 — 模拟器 CLI

> **状态:已在 Air 实测**(iPhone 17 上 `simctl install` + `launch` 成功,进程稳定)。

## 1. 核心命令(实测)

```bash
# 列设备 / runtime
xcrun simctl list devices available
xcrun simctl list runtimes

# 启动设备并等它 ready(-b = boot 并阻塞到完成)
xcrun simctl bootstatus <UDID> -b

# 安装 / 启动
xcrun simctl install <UDID> path/to/App.app
xcrun simctl launch  <UDID> com.easyapple.envdemo     # 返回 "<bundleid>: <PID>"

# 截图
xcrun simctl io <UDID> screenshot /tmp/a.png
```

实测:首次启动一台新 iPhone 17 模拟器约需 **~50 秒**(`bootstatus -b` 会等到完成)。

## 2. 封装脚本

- `tools/sim.sh`:`list` / `runtimes` / `boot` / `install` / `launch` / `screenshot` / `download-runtime`
- `tools/run-sim.sh`:打包 + boot + install + launch + 可选截图(一条命令闭环)

```bash
tools/run-sim.sh --device "iPhone 17" --screenshot /tmp/a.png
```

## 3. Xcode 27 的变化:`Simulator.app` 被移除

- Xcode 26 起模拟器 UI 宿主转向 **Device Hub**;Xcode 27 不再随包提供 `Simulator.app`。
- **`CoreSimulator` 仍在**,`xcrun simctl` 照常可用 —— **纯 CLI 流程不受影响**(实测无感)。
- 想在屏幕上看到模拟器窗口的人会受影响(需 Device Hub 或第三方宿主)。
  参见 [research/01](research/01-apple-platform-rules-2026.md) §7。

## 4. 拿设备 UDID 的小技巧(实测)

```bash
UDID="$(xcrun simctl list devices available | grep -F "iPhone 17 (" | head -1 \
  | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' | head -1)"
```

## 5. runtime 管理

现代 Xcode **默认不带**模拟器 runtime(实测装完 Xcode 27.0 后,已有的是 iOS 26.4 + visionOS 26.0,
没有 iOS 27.0)。补装:

```bash
xcodes runtimes install "iOS 27.0"          # 需登录,可能需 sudo
# 或
xcrun xcodebuild -downloadPlatform iOS
```

## 6. CI 上的模拟器(实测)

GitHub `xcode-27` runner 上 `tools/run-sim.sh --screenshot` 可成功跑通并出图(见
[05](05-app-conventions.md) 的 CI 说明)。
