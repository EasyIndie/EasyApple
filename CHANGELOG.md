# Changelog

本项目的所有显著变更都记录在此。

格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/),
版本号遵循 [SemVer](https://semver.org/lang/zh-CN/),且**唯一来源是 `version.properties`**。

## [Unreleased]

### Added

- **文本级 UI 验收**(决策 D15):`tools/ui-scan.sh` / `tools/ui-assert.sh` + 原生 OCR 引擎 `tools/uiscan.swift`(Apple Vision,免授权、可无头)。
- `verify-all` 增至 7 步;CI 冒烟步骤加入文本断言。

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
