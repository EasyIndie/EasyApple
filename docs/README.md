# 知识库索引

> 当前处于**规划期**:这里只有决策记录与调研。
> 执行期文档(`01`…`09`)在 Air 上实测后才创建。

## 现在有的

| 文档 | 主题 | 状态 |
|---|---|---|
| [00-decisions.md](00-decisions.md) | 决策记录(决策 / 理由 / 状态 / 怎么改) | ✅ 已有(全部 `proposed`) |
| [research/README.md](research/README.md) | 规划期调研索引 | ✅ 已有 |

### `research/` 四篇调研

| 文档 | 主题 |
|---|---|
| [research/01-apple-platform-rules-2026.md](research/01-apple-platform-rules-2026.md) | Apple 平台规则(2026-09 快照) |
| [research/02-cross-platform-dev.md](research/02-cross-platform-dev.md) | 跨平台开发能力(Swift/社区方案/无 Mac 设备链路) |
| [research/03-simulator-cross-platform.md](research/03-simulator-cross-platform.md) | **模拟器跨平台可行性(核心否定结论)** |
| [research/04-swiftpm-packaging.md](research/04-swiftpm-packaging.md) | SwiftPM 打不出包怎么补 |

> `research/` 与执行期文档的区别:research 是**规划期调研(未验证,带「怎么复核」)**;
> 执行期文档是**实测后**的结论与用法。同一主题两处都有是故意的,不要合并。

## 执行期文档(planned,待 Air 上实测定稿)

| 文档 | 主题 | 状态 |
|---|---|---|
| `01-headless-apple-build.md` | 无 IDE 的 Apple 构建环境(Xcode 必装、可不开) | ⏳ planned |
| `02-swiftpm-project-conventions.md` | SwiftPM 分层范式(Core / App) | ⏳ planned |
| `03-simulator-cli.md` | 模拟器 CLI 与 Xcode 27 Device Hub 变化 | ⏳ planned |
| `04-packaging-with-swift-bundler.md` | swift-bundler 原理与限制 | ⏳ planned |
| `05-xcodegen-escape-hatch.md` | XcodeGen 逃生舱 | ⏳ planned |
| `06-app-conventions.md` | 工程/命名/版本号/发版流程 + 决策记录 | ⏳ planned |
| `07-ui-acceptance.md` | UI 验收(截图 vs 无障碍文本) | ⏳ planned |
| `08-cross-platform-and-no-mac.md` | 跨平台 / 无 Mac 全景 | ⏳ planned |
| `09-gotchas.md` | 踩坑速查 + Intel MBP 实测边界 | ⏳ planned |

## 写法约定

- 语言:中文,术语保留英文原文。
- 每条结论尽量写**「怎么验证的」**(命令或来源链接)。
- 版本号/日期带上快照时间(环境会变)。
- 规划期内容写「来源」「待复核」;**不要写「已验证」**。
