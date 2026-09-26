# tools/ — 构建 / 模拟器 / 验收脚本

所有脚本 `source tools/_common.sh`,**统一用 `xcrun`**(规避 swiftly PATH 坑),
平台固定 macOS(arm64)。不含任何第三方构建/打包工具。

| 脚本 | 用途 |
|---|---|
| `_common.sh` | 基座:`REPO_ROOT` / `DEVELOPER_DIR` / 日志函数 / 版本读取(被 source) |
| `doctor.sh` | 环境自检(**第一条要跑的命令**) |
| `bootstrap.sh` | 一次性装机引导(xcodes → Xcode 27 → iOS runtime;sudo/登录需人工) |
| `build.sh` | `swift build`(macOS,先校验版本) |
| `test.sh` | `swift test` |
| `bundle.sh` | **原生打包**:拼 `.app`(macOS / iOSSimulator)+ ad-hoc 签名 |
| `run-sim.sh` | 打包并在 iOS 模拟器运行(boot→install→launch,可选截图) |
| `sim.sh` | `simctl` 常用操作封装 |
| `ui-dump.sh` | 截图验收(文本树后置,D7) |
| `new-app.sh` | 以 EnvDemo 为模板生成 `apps/<Name>/` |
| `sync-version.sh` | 版本唯一来源(D8)输出 / 校验 |
| `verify-all.sh` | 总验收:doctor → sync-version → build → test → run-sim → ui-dump |
| `release.sh` | Conventional Commits → SemVer;改版本 / 打 tag |

## 常用

```bash
tools/doctor.sh                             # 环境体检
tools/run-sim.sh --screenshot /tmp/a.png    # 一条命令跑 iOS 模拟器
tools/verify-all.sh                         # 总验收
tools/release.sh --dry-run                  # 看下一个版本号
```

## 约定

- `bundle.sh --platform` 支持 `macOS`(默认)与 `iOSSimulator`。
- iOS 构建命令:`xcrun swift build -c release --triple arm64-apple-ios-simulator --sdk <iphonesimulator sdk>`;
  产物在 `.build/out/Products/Release-iphonesimulator/`。
- 版本号唯一来源是仓库根 `version.properties`;**源码里禁止版本字面量**(`sync-version.sh --check` 会拦)。
