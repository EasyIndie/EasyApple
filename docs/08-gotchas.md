# 08 — 踩坑速查

> **状态:全部为 Air / CI 实测踩到并解决的坑。** 按「症状 → 原因 → 解法」记。

## 1. `swift --version` 报 Toolchain could not be located

- **症状**:`swift --version` → `Toolchain Swift 6.3.3 could not be located in .../swift-6.3.3-RELEASE.xctoolchain/...`
- **原因**:`~/.zprofile` 里有 `. "$HOME/.swiftly/env.sh"`,把 `/Users/x/.swiftly/bin` 提前进 PATH;
  但 swiftly 安装的那个 toolchain 已缺失(`~/Library/Developer/Toolchains/` 为空)。
- **解法**:删掉 `~/.zprofile` 里 swiftly 那两行;并让脚本**统一用 `xcrun swift`**(本仓库 `tools/` 即如此)。

## 2. `brew install xcodesorg/made/xcodes` 失败

- **症状**:`git clone ... XcodesKit.git ... fatal: Unable to read current working directory: Operation not permitted` / `getcwd`
- **原因**:该 formula 走源码构建(SwiftPM 依赖),在受管沙箱里 git clone 的 cwd 访问被拦。
- **解法**:直下官方 **release 二进制**(Developer ID 签名、无需已装 Xcode):
  `curl -L -o xcodes.zip https://github.com/XcodesOrg/xcodes/releases/download/2.1.0/xcodes.zip` →
  `install -m 0755 xcodes /opt/homebrew/bin/xcodes`。

## 3. CI:`macos-26` 上根本没有 Xcode 27

- **症状**:workflow 里 `ls /Applications/Xcode_27*.app` 无匹配;`xcodebuild -version` 显示 Xcode 26.6。
- **原因**:`macos-26` 镜像默认只带 Xcode 26.6。Xcode 27.x 只在 **`xcode-27`** 镜像里。
- **解法**:`runs-on: xcode-27`。该镜像含 `Xcode_27.0.0 / 27.1 / 27.2`(+ beta)。

## 4. `xcode-27` 里「取最高版本」会选到 beta

- **症状**:`ls -d /Applications/Xcode_27*.app | sort -V | tail -1` → `Xcode_27.2_beta.app`。
- **原因**:beta 版本号比稳定版更高。
- **解法**:**显式优先 `*27.0*`**(`Xcode_27.0.0.app` → Build `27A266a`,与 Air 一致),找不到再退而取最高。

## 5. 现代 Xcode 默认不带模拟器 runtime

- **症状**:装完 Xcode 27.0,`simctl list runtimes` 只有 iOS 26.4 / visionOS 26.0,**没有 iOS 27.0**。
- **解法**:`xcodes runtimes install "iOS 27.0"` 或 `xcrun xcodebuild -downloadPlatform iOS`。

## 6. `#if` / `#endif` 后接 `return` 触发 dead-code 警告

- **症状**:`warning: code after 'return' will never be executed`。
- **原因**:两个平台分支都 `return` 后,末尾的兜底 `return` 永远到不了。
- **解法**:用 `#if … #elseif … #else … #endif` 三态写法(见 [02](02-swiftpm-project-conventions.md) §3)。

## 7. 模拟器首次启动慢

- **现象**:新 iPhone 17 模拟器首次 `bootstatus -b` 约 **~50 秒**。
- **解法**:正常现象,`bootstatus -b` 会阻塞到 ready;`run-sim.sh` 已封装。

## 8. SwiftPM 交叉编译产物路径

- `.build/out/Products/<Config>[-<platform>]/<product>`;
  用 `swift build ... --show-bin-path` 拿准,别硬编码 `.build/release/`。

## 9. 只有 CLT 没完整 Xcode 时

- `xcodebuild` / `xcrun simctl` / `--sdk iphonesimulator` 全不可用。见 [01](01-headless-apple-build.md) §1。

## 10. `git push --follow-tags` 推不动轻量标签

- **症状**:`git tag 0.1.0` 后 `git push --follow-tags`,远端无 tag,`release.yml` 不触发。
- **原因**:`--follow-tags` **只推附注标签(annotated)**,不推轻量标签(lightweight)。`git tag <名>` 默认建的是轻量标签。
- **校验**:`git cat-file -t <tag>` → `commit` 是轻量,`tag` 才是附注;`git ls-remote --tags origin` 看远端有没有。
- **解法**:`git tag -a <名> -m "Release <名>"`;或直接 `git push origin <tag>`。`tools/release.sh` 已改为 `-a`。

## 11. macOS 27 的 `VNRecognizeTextRequest` 只认语言列表第一个

- **症状**:中英混排文本 OCR 出乱码。以 `recognitionLanguages = ["en-US", "zh-Hans"]` 为例,"型号：iPhone 17" 的中文会变乱码/丢失。
- **原因**:macOS 27(至 27.2 Beta 1)的 Vision OCR bug —— **只使用列表第一个语言**;混排必须把 `zh-Hans` 放第一。
- **来源**:[missuo/macos27-vision-ocr-bug](https://github.com/missuo/macos27-vision-ocr-bug)(第三方复现,非 Apple 官方)。
- **解法**:用 `["zh-Hans", "en-US"]` 顺序(`tools/uiscan.swift` 默认即此);实测 zh-Hans 模型也能正确识别拉丁字符。

## 12. GitHub macOS runner 上 Vision OCR 不可用

- **症状**:本地 OCR 正常,CI 上 `uiscan` 报 `unknownError` / `nilError`,各种语言 + 级别都失败。
- **原因**:未查清(疑似 runner 上 Vision 模型资产缺失)。`xcode-27-arm64` 镜像实测如此。
- **解法**:CI 里 **OCR 不可用则跳过**(见 `.github/workflows/ci.yml`);把文本验收当本地能力。真正的模拟器冒烟(打包/安装/启动/截图)在 CI 上照常工作。
