# 04 — 原生打包脚本(SwiftPM → .app)

> **状态:已在 Air 实测**。macOS `.app` 与 iOS 模拟器 `.app` 均 `codesign` 通过、
> `simctl install` + `launch` 成功。**不用任何第三方打包工具**(见 [决策 D5](00-decisions.md))。

## 1. 问题:SwiftPM 打不出 `.app`

`swift build` 只产出可执行文件/库,不会做 **`.app` 打包**(`Info.plist`、图标、资源 bundle、
ad-hoc 签名、`simctl install`)。本仓库用约 150 行的 `tools/bundle.sh`,只用 Apple 原生工具补齐:
`codesign` / `plutil` / `simctl`。

## 2. 两种平台的结构

**macOS**:
```
EnvDemo.app/Contents/
├── Info.plist
├── MacOS/EnvDemo          # 可执行文件
├── Resources/             # 可选
└── _CodeSignature/        # codesign 生成
```

**iOS 模拟器**(扁平):
```
EnvDemo.app/
├── EnvDemo                # 可执行文件
├── Info.plist
└── _CodeSignature/
```

## 3. iOS 交叉编译(实测命令)

```bash
xcrun swift build -c release \
  --triple arm64-apple-ios-simulator \
  --sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)"
# 产物: .build/out/Products/Release-iphonesimulator/EnvDemo
```

用 `--show-bin-path` 稳定拿产物目录。验证平台:
```bash
vtool -show-build path/to/EnvDemo   # platform IOSSIMULATOR
```

## 4. 最小 Info.plist(实测跑通的键)

**iOS 模拟器**(就这 9 个键,app 就能起来):

| 键 | 值 |
|---|---|
| `CFBundleIdentifier` | `com.easyapple.envdemo` |
| `CFBundleName` | `EnvDemo` |
| `CFBundleExecutable` | `EnvDemo` |
| `CFBundlePackageType` | `APPL` |
| `CFBundleShortVersionString` | 由 `version.properties` 注入 |
| `CFBundleVersion` | `MAJOR*10000+MINOR*100+PATCH` |
| `MinimumOSVersion` | `17.0` |
| `UIDeviceFamily` | `[1, 2]`(iPhone + iPad) |
| `UILaunchScreen` | 空 `<dict/>`(不写可能被兼容模式处理) |

**macOS** 另需:`LSMinimumSystemVersion`、`NSPrincipalClass=NSApplication`、
`NSHighResolutionCapable`。

## 5. 签名

模拟器/本机调试**零证书**,ad-hoc 即可:

```bash
codesign --force --sign - App.app       # 实测:simctl install 直接接受
codesign --verify --deep --strict App.app
```

## 6. 一键

```bash
tools/bundle.sh                       # macOS(默认 release)
tools/bundle.sh --platform iOSSimulator
tools/run-sim.sh                      # 打包 + 装进模拟器 + 启动
```

`bundle.sh` 从仓库根 `version.properties` 读版本(D8),写入 `Info.plist`,再签名。

## 7. 限制

- **不支持 watchOS / App 扩展 / XCUITest / archive**(首期无此需求)。
- 需要时再评估 XcodeGen 逃生舱(见 [research/04](research/04-swiftpm-packaging.md))。

## 8. 分发:本地 ad-hoc 会被拦,正式发布已签名 + 公证

本地 `bundle.sh` 产物是 ad-hoc 签名,在**别的 Mac** 上双击会被拦(实测):

```bash
spctl -a -vv EnvDemo.app
# → EnvDemo.app: rejected
```

原因:没有 Developer ID 签名(无 Team ID)、也没有公证票据。这是**预期行为**,不是 app 坏了。

### 本地 ad-hoc 的手动绕过(仅限你信任的产物)

1. **右键 → 打开**(首次);或
2. **命令行去掉隔离属性**:
   ```bash
   xattr -dr com.apple.quarantine EnvDemo.app
   open EnvDemo.app
   ```

### 正式 Release:Developer ID + 公证 + staple

`release.yml` 不再发布 ad-hoc 产物,而是:

1. 按 `apps/` 列表 matrix 调用 EasyRelease reusable workflow;
2. Developer ID 签名(`--options runtime --timestamp`);
3. `notarytool` 公证 + `stapler staple`;
4. `ditto` 打 zip(保留 bundle 元数据/公证票据)并生成 `.sha256`;
5. `gh release create` 上传 zip + sha256。

因此 Release 包**不再附带 `open-unsigned-app.sh`**,下载解压后双击即可。
EasyRelease 也支持 `.dmg` 与 `.zip` 输入;`release.yml` 的发布步骤会按产物类型处理:
`.app` → zip,`.zip` → 直接发布,`.dmg` / `.pkg` → 原生文件。
`.pkg` 使用 Developer ID Installer 证书,公证后 `spctl -t install` 通过(2026-10-24 实测)。
实测 `spctl` 返回 `accepted` / `source=Notarized Developer ID`(2026-10-24,见 D17)。

`is_adhoc_signed()` 与 `tools/open-unsigned-app.sh` 仍保留给本地调试,但不再进入 Release。
