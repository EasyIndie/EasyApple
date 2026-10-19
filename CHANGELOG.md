# Changelog

本项目的所有显著变更都记录在此。

格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/),
版本号遵循 [SemVer](https://semver.org/lang/zh-CN/),且**唯一来源是 `version.properties`**。

## [Unreleased]

### Added

- **iOS 运行时单测**:`tools/test-ios.sh`。用 Xcode 为 SwiftPM 包自动生成的聚合 scheme
  `<包名>-Package`，在 iOS 模拟器里跑单测（不再只靠宿主机 `swift test`），支持
  `--device` / `--filter` / `--coverage`；结果落在 `apps/<App>/.build/ios-test/result.xcresult`。
- **截图确定性**：`ui-dump` / `ui-scan` / `ui-assert` 截图前自动固定状态栏（09:41 / 满电 / 满格），
  并可选 `--appearance light|dark`、`--content-size <档位>`，截完自动恢复；
  `--no-fix-status` 可关闭。OCR 断言不再被时间/电量影响。
- 调研文档：[research/06 自动化测试/验收方案](docs/research/06-automated-testing-acceptance.md)
  （六层分级 + 本机实测）、[research/05 虚拟 iPhone(vphone)](docs/research/05-virtual-iphone-vphone.md)。

### Changed

- `verify-all` 的截图/断言步骤隐式获得确定性环境（无需改调用）。
- CI:新增「测试(iOS 运行时)」阻塞步骤(`tools/test-ios.sh`),并上传 `result.xcresult` artifact。
- CI 提速:缓存 `apps/*/.build`(含 iOS 模拟器 DerivedData)与 SwiftPM 包缓存,
  key 按源码/依赖哈希;纯文档提交(`**/*.md`、`docs/**`、`LICENSE`)不再触发 CI。

### Fixed

- CI artifact 从未真正上传:`upload-artifact@v4` 默认 `include-hidden-files: false`,
  而截图在 `.tmp/`、xcresult 在 `.build/`(都是隐藏目录)。两条上传步骤已显式打开该开关,
  仓库产物数从 0 恢复为 2(截图 + iOS 单测结果)。

## [0.3.0] - 2026-09-27

### Added

- **多应用支持**:工具链按 `apps/` 遍历。`build.sh` / `test.sh` / `verify-all.sh` 无参 = 全部应用;
  `bundle.sh` / `run-sim.sh` 仅一个应用时自动选、多个必须 `--app <Name>`;CI / Release 遍历所有应用
  (每个应用一个 `<App>-<version>.tar.gz`)。
- **新建应用**:`tools/new-app.sh <Name>` 按模板生成,并在生成后提示需要手改的三处。
- **每应用 UI 断言文件**:`apps/<Name>/ui-assertions.txt` + `ui-assert.sh --app <Name>`。

### Fixed

- `tools/sync-version.sh` 的版本字面量检查改用**固定串匹配**(`grep -F`):此前把版本号当正则,
  其中 `.` 可匹配任意字符,版本为 `0.3.0` 时会误命中 ANSI 转义里的 `033[0`,造成 CI 假失败。

## [0.2.0] - 2026-09-27

### Added

- **文本级 UI 验收**(决策 D15):`tools/ui-scan.sh` / `tools/ui-assert.sh` + 原生 OCR 引擎 `tools/uiscan.swift`(Apple Vision,免授权、可无头)。
- `verify-all` 增至 7 步;CI 冒烟步骤加入文本断言。
- **未签名产物的便捷打开**:`tools/open-unsigned-app.sh`(去 Gatekeeper 隔离 + 启动);发布时**仅当产物是 ad-hoc 签名才附带**。

### Fixed

- `tools/release.sh` 改用**附注标签**(`-a`):轻量标签不被 `git push --follow-tags` 推送,导致 release 不触发。

## [0.1.0] - 2026-09-27

### Added

- 仓库骨架:规划期调研(`docs/research/`)、决策记录(`docs/00-decisions.md`)、`PLAN.md` / `README.md` / `AGENTS.md`。
- 工具链:锁定 Xcode 27.0 + iOS 27.0 模拟器 runtime(经 `xcodes` 装机)。
- 示例工程 `apps/EnvDemo`(SwiftPM 分层:Core + App + 单测)。
- `tools/` 工具链:**原生打包**(`bundle.sh`,codesign + plutil,零第三方)及 `run-sim` / `sim` / `build` / `test` / `doctor` / `new-app` / `sync-version` / `verify-all` / `release`。
- CI(`ci.yml`)与发布(`release.yml`):`xcode-27` runner + 锁定 Xcode 27.0。
- 执行期文档 `docs/01`…`docs/08`。

## [0.0.1] - 2026-09-26

### Added

- 初始版本:仓库骨架(无运行代码)。
