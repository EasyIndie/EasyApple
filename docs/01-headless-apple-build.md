# 01 — 无 IDE 的 Apple 构建环境

> **状态:已在 Air(M1 / macOS 27.2)实测**(最近核验 2026-11-22)。命令均可复现。

## 1. 「无 IDE」的定义(关键)

> **装了完整 Xcode,但从不打开它的 GUI。** 所有操作走 `xcodebuild` / `xcrun` /
> `simctl` / `swift`。

**不等于「不装 Xcode」。** 实测证实:

| 只装 Command Line Tools | 完整 Xcode |
|---|---|
| `xcodebuild -version` → 报错「requires Xcode, but active developer directory is a command line tools instance」 | ✅ Xcode 27.2 |
| `xcrun --sdk iphonesimulator --show-sdk-path` → SDK 不存在 | ✅ iPhoneSimulator27.2.sdk |
| `xcrun simctl list runtimes` → 「unable to find utility simctl」 | ✅ 可用 |

**iOS SDK 只随完整 `Xcode.app` 提供。** 这是 Apple 与 Android 最大的不同
(Android 可只装 `cmdline-tools`)。

## 2. 本机(已验证)

| 组件 | 版本 |
|---|---|
| macOS | 27.2(build `26B123`) |
| 芯片 | Apple Silicon M1(arm64) |
| Xcode | **27.2**(build `27B52`) |
| Swift | 6.4.2(随 Xcode) |
| iOS 模拟器 SDK | iPhoneSimulator27.2.sdk |
| iOS runtime | iOS 27.2(`24B8117`) |

> 小版本跟随策略见 [决策 D21](00-decisions.md):Xcode 27 系列内用最新稳定版(排除 beta),
> 本地与 CI 同版本。升级 Xcode 仍单独开一次,不夹在功能开发里。

## 3. 装机流程(已验证)

用 `xcodes` 命令行装(见 [决策 D14](00-decisions.md);它只是**装机**工具,不进入构建链路):

```bash
# 1) 装 xcodes(直下官方 release 二进制,无需已装 Xcode)
#    ⚠️ brew install 会走源码构建,在受管沙箱里 getcwd 报 Operation not permitted
curl -fsSL -o xcodes.zip https://github.com/XcodesOrg/xcodes/releases/download/2.1.0/xcodes.zip
unzip -oq xcodes.zip -d .
install -m 0755 xcodes /opt/homebrew/bin/xcodes

# 2) 装 Xcode 27.2(需 Apple ID + 2FA)
xcodes install 27.2

# 3) 接受许可 + 选中
sudo xcodebuild -license accept
xcodes select 27.2

# 4) 下载 iOS 模拟器 runtime(现代 Xcode 默认不带)
xcodes runtimes install "iOS 27.2"
```

或一键引导:`bash tools/bootstrap.sh`(sudo / 登录仍要人工)。

## 4. 验证命令

```bash
xcode-select -p                              # 应指向 /Applications/Xcode*.app/Contents/Developer
xcodebuild -version                          # Xcode 27.2 / 27B52
xcrun --sdk iphonesimulator --show-sdk-path  # iPhoneSimulator27.2.sdk
xcrun swift --version                        # Apple Swift version 6.4.2
xcrun simctl list runtimes                   # 应含 iOS 27.2
bash tools/doctor.sh                         # 一键体检
```

## 5. 已排掉的坑

- **swiftly**:若 `~/.zprofile` 里有 `. "$HOME/.swiftly/env.sh"`,`swift` 会指向 swiftly 的
  shim;toolchain 缺失时报「Swift x.y.z could not be located」。**删掉该行**,或脚本里统一用
  `xcrun swift`(本仓库 `tools/` 全部用 `xcrun`)。详见 [08](08-gotchas.md)。
- **Intel**:macOS 27 / Xcode 27 已无 Intel 构建,本仓库 arm64-only(见 [决策 D13](00-decisions.md))。

## 6. 相关

- 调研依据:[research/01](research/01-apple-platform-rules-2026.md) §5
- 打包:[04](04-packaging-native.md) · 模拟器:[03](03-simulator-cli.md)
