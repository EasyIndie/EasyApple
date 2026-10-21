# Apple 开发 Agent Skills

> 状态：已落地；更新时间：2026-10-22。

本仓库维护可在多个 Apple 项目复用的 Codex 技能。通过 `tools/install-agent-skills.sh` 将仓库技能链接到当前 Mac 的 `~/.agents/skills/`，因此无需在每个项目重复安装。克隆 EasyApple 的新设备运行一次该脚本即可；Codex 重启或新建会话后发现技能。

## 技能来源

| 技能 | 来源 / 许可 | 更新方式 |
|---|---|---|
| `swiftui-pro` | [twostraws/SwiftUI-Agent-Skill](https://github.com/twostraws/SwiftUI-Agent-Skill)，MIT | 每周检查上游并开 PR；`.agents/skills-sources.lock.json` 记录已同步 commit |
| `swift-concurrency-pro` | [twostraws/Swift-Concurrency-Agent-Skill](https://github.com/twostraws/Swift-Concurrency-Agent-Skill)，MIT | 每周检查上游并开 PR；锁文件记录已同步 commit |
| `apple-native-product-design` | EasyApple 维护的 Apple 原生产品设计流程，GPL-3.0-or-later | 随本仓库人工审阅更新；不依赖 Figma |
| Xcode 导出的 Apple 技能 | 当前选择的 Xcode；Apple 官方说明可用 `xcrun agent skills export` 导出供其他工具使用 | 在安装/升级 Xcode 后运行安装脚本刷新。导出文件保留在本机 Xcode Coding Assistant 目录，不复制进仓库 |

Xcode 27 当前导出 SwiftUI、UIKit、App Intents、安全、测试、设备交互等官方技能。仓库不镜像这些未附单独再分发许可的导出文件；安装脚本从本机已安装的 Xcode 生成并链接它们。Apple 的导出方式见 [WWDC26 SwiftUI 新功能](https://developer.apple.com/videos/play/wwdc2026/269/) 和 [Xcode 27 Release Notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes)。

## 安装与刷新

```bash
# 在 EasyApple 仓库执行；每台需要共享技能的 Mac 执行一次
bash tools/install-agent-skills.sh

# 手动检查社区技能上游并同步到当前工作树
bash tools/update-agent-skills.sh
```

GitHub Actions 每周一检查两个 MIT 上游。发现变化时会更新技能目录和锁文件，并创建/更新 PR；审阅合并后，设备在 EasyApple 工作树执行 `git pull`，共享链接即指向新版本。需在 GitHub 仓库 Settings → Actions → General 中允许 Actions 使用 `GITHUB_TOKEN` 创建 Pull Request，否则定时任务无法创建更新 PR。这个流程不会在打开其他项目时静默联网或执行上游技能代码。

`~/.agents/skills/` 是 Codex 用户级共享位置，所以同一设备上的 Codex 项目都可发现这些技能；各技能描述负责限定适用场景。不同设备需先克隆/更新 EasyApple 并运行一次安装脚本。Apple 官方技能需要本机安装可导出技能的 Xcode；没有相应 Xcode 时，脚本仍链接仓库技能并提示缺少官方导出源。

## 最近核验

- 2026-10-22，在 Air 上运行 `bash tools/install-agent-skills.sh` 后，`apple-native-product-design`、`swiftui-pro`、`swift-concurrency-pro` 均已链接到本仓库的 `.agents/skills/`。Xcode 官方技能由 Xcode 27.0 导出。
- 同日核验 GitHub 上游自动更新工作流已随仓库配置；它创建待审 PR，不直接更新 `main`。创建 PR 需要仓库 Actions 设置允许 `GITHUB_TOKEN` 创建 Pull Request。
