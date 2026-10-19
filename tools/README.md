# tools/ — 构建 / 模拟器 / 验收脚本

所有脚本 `source tools/_common.sh`,**统一用 `xcrun`**(规避 swiftly PATH 坑),
平台固定 macOS(arm64)。不含任何第三方构建/打包工具。

| 脚本 | 用途 |
|---|---|
| `_common.sh` | 基座:`REPO_ROOT` / `DEVELOPER_DIR` / 日志函数 / 版本读取(被 source) |
| `doctor.sh` | 环境自检(**第一条要跑的命令**) |
| `bootstrap.sh` | 一次性装机引导(xcodes → Xcode 27 → iOS runtime;sudo/登录需人工) |
| `build.sh` | `swift build`(macOS,先校验版本;无参 = 遍历所有应用) |
| `test.sh` | `swift test`(宿主机 macOS,无参 = 遍历所有应用) |
| `test-ios.sh` | **iOS 运行时单测**:`xcodebuild test -scheme <包名>-Package`(SwiftPM 包,无需 `.xcodeproj`) |
| `bundle.sh` | **原生打包**:拼 `.app`(macOS / iOSSimulator)+ ad-hoc 签名 |
| `run-sim.sh` | 打包并在 iOS 模拟器运行(boot→install→launch,可选截图) |
| `sim.sh` | `simctl` 常用操作封装 |
| `ui-dump.sh` | 截图验收(截图为先,D7);自动固定状态栏/外观/字号,截完恢复 |
| `ui-scan.sh` | **文本级验收**:截图 → 原生 OCR(Apple Vision)→ 文本/JSON(截图带确定性固定) |
| `ui-assert.sh` | **文本级断言**(可进 CI):`--contains` / `--not-contains` / `--app <Name>`(读 `apps/<Name>/ui-assertions.txt`) |
| `uiscan.swift` | `ui-scan` 用的原生 OCR 引擎(被 `_common.sh` 编译缓存,不单独跑) |
| `new-app.sh` | 以 EnvDemo 为模板生成 `apps/<Name>/`(克隆式,生成后自己重写 Sources) |
| `sync-version.sh` | 版本唯一来源(D8)输出 / 校验 |
| `verify-all.sh` | 总验收:遍历 `apps/` 下所有应用(doctor → sync-version → 每应用 build → test → run-sim → ui-dump → ui-assert) |
| `release.sh` | Conventional Commits → SemVer;改版本 / 打 tag |
| `open-unsigned-app.sh` | 打开 ad-hoc(未真实签名)产物:去 Gatekeeper 隔离 + 启动(发布包附带) |

## 常用

```bash
tools/doctor.sh                             # 环境体检
tools/run-sim.sh --screenshot /tmp/a.png    # 一条命令跑 iOS 模拟器
tools/test-ios.sh                           # 单测跑在 iOS 运行时(不需要工程文件)
tools/ui-scan.sh --input /tmp/a.png         # OCR 文本验收
tools/ui-assert.sh --contains "arm64"        # 文本断言(可进 CI)
tools/verify-all.sh                         # 总验收
tools/release.sh --dry-run                  # 看下一个版本号
```

> `ui-scan` / `ui-assert` 用 **Apple Vision OCR**,原生、免授权、可无头;
> 它是「文本级」验收(有损识别),不是无障碍树。截图前会自动固定状态栏(时间/电量/信号)
> 并恢复原状,使断言可复现;`--appearance light|dark`、`--content-size <档位>` 可验深色/大字号。
> 取舍与替代路线见 [docs/06](../docs/06-ui-acceptance.md),完整分层见
> [research/06](../docs/research/06-automated-testing-acceptance.md)。

## 约定

- **多应用**:应用都在 `apps/<Name>/`(`new-app.sh` 生成)。`build.sh` / `test.sh` / `verify-all.sh`
  无参 = 遍历全部;`bundle.sh` / `run-sim.sh` 在只有一个应用时自动选,多个则必须 `--app <Name>`。
  新建应用 / 多应用约定见 [docs/02](../docs/02-swiftpm-project-conventions.md#6-新建应用多应用支持)。
- `bundle.sh --platform` 支持 `macOS`(默认)与 `iOSSimulator`。
- iOS 构建命令:`xcrun swift build -c release --triple arm64-apple-ios-simulator --sdk <iphonesimulator sdk>`;
  产物在 `.build/out/Products/Release-iphonesimulator/`。
- 版本号唯一来源是仓库根 `version.properties`;**源码里禁止版本字面量**(`sync-version.sh --check` 会拦)。
