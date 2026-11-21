# Changelog

本项目的所有显著变更都记录在此。

格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/),
版本号遵循 [SemVer](https://semver.org/lang/zh-CN/),且**唯一来源是 `version.properties`**。

## [Unreleased]

## [0.4.1] - 2026-11-22

### Added

- **官方技能导出全量重建**:Xcode 27.2 导出 11 个技能(新增 `app-resizability` / `xctrace`);
  安装脚本改为临时目录 + 整体替换,并清理目标已不存在的旧链接(27.0 的 `uikit-app-modernization`)。
- **社区技能更新**:合并 PR #1,`swiftui-pro` 同步到上游 `f2920b6`(`swift-concurrency-pro` 已最新)。

### Fixed

- **发布 job 缺少 checkout**:`gh release create --verify-tag` 报 `fatal: not a git repository`;
  publish job 现在先检出仓库(修复后才补发 0.4.0 Release)。
- **模拟器/OCR 调用可能挂死**:`run_timeout` 包住 simctl boot/install/launch/screenshot 与
  Vision OCR,CI 冒烟步骤加 20 分钟上限。

## [0.4.0] - 2026-11-22

### Added

- **工程化收口(对齐 EasyAndroid 的结构化实践)**
  - `template/`:模板从 `apps/EnvDemo` 独立,`new-app.sh` 改为从模板生成(D18);
    `tools/test-template.sh` 做模板冒烟(临时生成 → build → test → 清理)。
  - `tools/repo-check.sh`:仓库自检,守 workflow 的 `-latest` / action 主版本 /
    EasyRelease pin、文档相对链接、应用必备文件、决策索引、敏感信息(D19);
    作为 `verify-all.sh` 第一步,CI 也直接调用。
  - `tools/handoff-app.sh`:交付应用为「应用 + 工具链」的自包含仓库,
    附 `handoff-manifest.txt`(commit / 版本 / sha256)(D20);新增 [docs/10](docs/10-app-lifecycle-and-handoff.md)。
  - `.github/actions/select-xcode`:Xcode 选择集中化(默认 27.2,排除 beta),
    替换 7 个 workflow 里各自复制的一份(D21)。
- **`.pkg` 签名 + 公证验证通过**:EasyRelease `v0.6.4` 修复 `productsign` 无头卡住;
  EasyApple run `40105139059`,submission `aa154aa3-...`,Installer 身份签名,
  `spctl -t install` 通过。
- **Apple ID + App 专用密码公证验证通过**:EasyApple run `40101281656`,
  submission `cff3b8b8-...`;`.pkg` 已用真实 Installer 证书验证通过(run `40105139059`)。
- **EasyRelease 支持 `.dmg` / `.zip` 与 App 专用密码**:`.dmg` 已完成 Developer ID +
  公证 + staple 真链路验证;`.zip` 支持「解包 → 签名/公证/staple 内层 → 重新打包 →
  再解压校验」;公证认证可选 API Key 或 Apple ID + App 专用密码。
- **正式发布接入 EasyRelease**:`release.yml` 按 `apps/` matrix 调用
  `EasyIndie/EasyRelease` reusable workflow，产出 Developer ID 签名 + 公证 + staple 的
  `.app`，用 `ditto` 打 zip 并附 `.sha256`，不再发布 ad-hoc 包。支持
  `workflow_dispatch + dry_run` 验证整条流水线。详见 `D17`。
- **Apple 开发 Agent Skills**:集中维护 SwiftUI、Swift Concurrency 与 Apple 原生产品设计技能;可链接到 Codex 用户级共享目录,并从本机 Xcode 导出 Apple 官方技能。社区上游由每周 GitHub Actions 检查并创建审阅 PR。详见 [docs/09](docs/09-agent-skills.md)。
- **iOS 运行时单测**:`tools/test-ios.sh`。用 Xcode 为 SwiftPM 包自动生成的聚合 scheme
  `<包名>-Package`，在 iOS 模拟器里跑单测（不再只靠宿主机 `swift test`），支持
  `--device` / `--filter` / `--coverage`；结果落在 `apps/<App>/.build/ios-test/result.xcresult`。
- **截图确定性**：`ui-dump` / `ui-scan` / `ui-assert` 截图前自动固定状态栏（09:41 / 满电 / 满格），
  并可选 `--appearance light|dark`、`--content-size <档位>`，截完自动恢复；
  `--no-fix-status` 可关闭。OCR 断言不再被时间/电量影响。
- 调研文档：[research/06 自动化测试/验收方案](docs/research/06-automated-testing-acceptance.md)
  （六层分级 + 本机实测）、[research/05 虚拟 iPhone(vphone)](docs/research/05-virtual-iphone-vphone.md)。

### Changed

- `run-sim` / `ui-dump` / `ui-assert` / `sim`:模拟器设备解析统一走 `simctl_resolve_device`,
  支持 `--udid`;自动挑设备(已启动 iPhone > iPhone 17 > 最新 runtime),不再按名字取列表第一个。
- `release.sh`:新增 `--check-commits`;0.x 阶段 BREAKING 只升 MINOR(与 EasyAndroid 一致),
  正文里的 `BREAKING CHANGE:` 也纳入判断。CI 改为调用同一脚本。
- 环境快照刷新:macOS 27.2 / Xcode 27.2 / Swift 6.4.2 / iOS 27.2(AGENTS、PLAN、README、docs/01、03、05)。
- `release.yml` 的 `prepare` 与 `update-agent-skills.yml` 显式 pin `ubuntu-24.04`。
- `release.yml`:从 ad-hoc 打包改为 EasyRelease 签名/公证发布;不再附带
  `open-unsigned-app.sh`，下载解压后双击即可。
- `verify-all` 的截图/断言步骤隐式获得确定性环境（无需改调用）。
- CI:新增「测试(iOS 运行时)」阻塞步骤(`tools/test-ios.sh`),并上传 `result.xcresult` artifact。
- CI 提速:缓存 `apps/*/.build`(含 iOS 模拟器 DerivedData)与 SwiftPM 包缓存,
  key 按源码/依赖哈希;纯文档提交(`**/*.md`、`docs/**`、`LICENSE`)不再触发 CI。

### Fixed

- **文档环境快照过期**:文档仍写 Xcode 27.0 / macOS 27.0.1,实机已是 27.2;
  CI 仍选 27.0 却声称「与 Air 一致」。现统一到 27.2,选择逻辑收进 composite action。
- **`docs/README` 决策索引漂移**:仍写 D1–D16,实际已有 D17;`repo-check` 现在会拦。
- **`new-app.sh` 模板漂移**:不再复制 `apps/EnvDemo`,改从 `template/` 生成。
- **`release.sh` 0.x 语义**:`feat!:` 不再把 0.x 直接推到 1.0.0。
- **Agent 技能描述超出规范上限**：Xcode 导出的 `app-intents-specialist` / `app-intents-whats-new-27` 描述超过 Agent Skills 规范的 1024 字符上限，导致 pi / Claude 报「技能冲突」并拒绝加载。新增 `tools/apple-skill-descriptions.json`（短描述覆盖表）与 `tools/apply-skill-description-overrides.py`，由 `tools/install-agent-skills.sh` 在每次导出后自动应用，`tools/doctor.sh` 复用同一校验。详见 [docs/09](docs/09-agent-skills.md)。
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
