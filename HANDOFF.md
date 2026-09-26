# HANDOFF — 交接说明

> **这不是最终交接,是「规划期交接」。** 执行阶段会重写/扩充本文件。
> 当前仓库里**只有文档,没有可运行代码**,而且**零次 macOS 构建验证**。

## 0. 当前状态(务必先读)

| 项 | 状态 |
|---|---|
| 仓库内容 | 纯文档:计划、调研、决策、交接 |
| 代码 | ❌ 无(`apps/`、`tools/` 尚未创建) |
| 验证 | ❌ **零构建验证**。所有 Swift/工具链结论都是桌面推演 |
| 完成环境 | Windows(WSL/Git Bash) |
| 下一步 | **在 M1 Air 上拉取 → 先改 `PLAN.md` → 再进入执行阶段** |

规划期产出了这些文件,请按顺序读:

1. [`README.md`](README.md) — 定位与现状
2. [`PLAN.md`](PLAN.md) — **执行计划(活文档,就是给你改的)**
3. [`docs/00-decisions.md`](docs/00-decisions.md) — 决策记录(全部 `proposed`,待你裁决)
4. [`docs/research/`](docs/research/) — 四篇调研(Apple 规则 / 跨平台 / 模拟器 / SwiftPM 打包)
5. [`AGENTS.md`](AGENTS.md) — 硬约束与已否决方案

---

## 1. 你在 Air 上要做的第一件事:改计划,不是写代码

```bash
# 1) 把仓库弄到 Air 上(二选一)
#    a. 如果已经推到 GitHub:
git clone git@github.com:EasyIndie/EasyApple.git
#    b. 如果还没推(见 §5),先用 U 盘 / scp / 共享盘把 E:\EasyApple 拷过来
cd EasyApple

# 2) 读计划
$EDITOR PLAN.md                # 或直接在 GitHub / 编辑器里看
$EDITOR docs/00-decisions.md   # 逐条把 proposed 改成 accepted 或推翻

# 3) 读完先自问:Phase B 的 EnvDemo 设计要不要变?Phase C 的脚本清单够不够?
#    改完提交:
git add -A && git commit -m "docs: 在 Air 上调整执行计划与决策"
```

**为什么先改计划**:计划是在 Windows 上、没有 Mac 的情况下推演的。你手上才有真机
事实(Xcode 版本、模拟器 runtime、swift-bundler 实际行为)。**先把计划校准,再动代码,
能省掉大量返工。**

---

## 2. 计划校准后,预计的执行顺序(执行阶段会补齐脚本)

```
bootstrap → doctor → build → test → run-sim → ui-dump → verify-all
```

对应的命令(执行阶段落地后):

```bash
bash tools/bootstrap.sh     # 一次性安装 brew 依赖 / swift-bundler(pin commit)
bash tools/doctor.sh        # 环境自检(第一条真正要跑的命令)
bash tools/build.sh         # swift build(Core + App)
bash tools/test.sh          # swift test(Core 单测)
bash tools/run-sim.sh       # swift bundler run --platform iOSSimulator
bash tools/ui-dump.sh       # 截图 + 尽量取文本树
bash tools/verify-all.sh    # 总验收
```

> ⚠️ **这一节现在是「预告」,不是「使用说明」。** 脚本还不存在。等你改完计划,
> 执行阶段才会把 Phase A–F 落成实际文件。

---

## 3. Air 前置条件清单

- [ ] macOS 版本够高(见 [research/01](docs/research/01-apple-platform-rules-2026.md) §2;
      跑 Xcode 27 需要 macOS 26.6+,跑 Xcode 26.4+ 需要 macOS 26.2+)
- [ ] **完整 Xcode**(不是只有 Command Line Tools),已至少启动过一次、接受许可
      - `sudo xcodebuild -license accept`(如未接受)
      - `xcode-select -p` 指向 `/Applications/Xcode.app/...`
- [ ] 已安装的模拟器 runtime(现代 Xcode 默认不带,需下载)
      - `xcodebuild -downloadPlatform iOS` 或 `xcrun simctl runtime add <dmg>`
- [ ] `brew`(用于装 xcodegen / mint / 可选 idb)
- [ ] **Apple ID(免费即可)** —— 首期模拟器闭环其实不需要登录,但备着
- [ ] 若要远程开发:系统设置 → 通用 → 共享 → **远程登录** 打开,并知道 SSH 别名

---

## 4. 需要在 Air 上复核的「未验证假设」清单

> 逐条跑命令,把真实结果写回对应文档(或本文件末尾「实测结果」)。

| # | 假设 | 复核命令 | 结论回填到 |
|---|---|---|---|
| 1 | Air 的 macOS / Xcode / Swift 版本 | `sw_vers` `xcodebuild -version` `swift --version` | [research/01](docs/research/01-apple-platform-rules-2026.md) §1 |
| 2 | iOS SDK 确实只在完整 Xcode 里,CLT 不够 | `xcrun --sdk iphonesimulator --show-sdk-path` | research/01 §5 |
| 3 | 已安装哪些模拟器 runtime | `xcrun simctl list runtimes` | research/01 §8 |
| 4 | Xcode 27 是否真的没有 `Simulator.app`(用 Device Hub) | `ls /Applications/Xcode.app/Contents/Developer/Applications/` | research/01 §7 |
| 5 | `swift-bundler` 能装且能在模拟器上跑 | 见 [research/04](docs/research/04-swiftpm-packaging.md) §2 | research/04 |
| 6 | `swift-tools-version: 6.0` 的包在 Air 上能构建 | `swift package dump-package` | PLAN Phase B1 |
| 7 | Intel MBP 确实止步 Xcode 14.2(可选,如你想用那台) | 在 Intel 上 `sw_vers` / `xcodebuild -version` | `docs/09-gotchas.md`(执行期创建) |
| 8 | `idb` 是否需要 / 可用 | `brew install idb-companion && idb --version` | 决策 D7 / `docs/07-ui-acceptance.md`(执行期创建) |
| 9 | GitHub `macos-26` runner 的 Xcode 版本够不够 | 开 Actions 后看日志,或查 [runner-images](https://github.com/actions/runner-images) | CI 日志 |
| 10 | xtool / Theos 等无 Mac 方案(仅记录,首期不做) | — | research/02 |

---

## 5. GitHub 与「首次 push 在哪里做」

- 目标仓库:`EasyIndie/EasyApple`(SSH:`git@github.com:EasyIndie/EasyApple.git`;
  组织与 EasyAndroid 一致)。
- 仓库**可能还没在 GitHub 上创建**;若没有,请先建(public,与 EasyAndroid 一致)。

### ⚠️ 两个已知坑

1. **受管沙箱(如 WorkBuddy)里,`git` 写远程跟踪引用会静默失败**
   (`git push` 报成功但没推上去,`git status -sb` 出现 `[gone]`)。→ **首次 push
   建议在 Air 上做**(你的终端不受这个限制)。
2. **不要用 `git push "https://x-access-token:$TOKEN@github.com/..."` 配 `-u`** ——
   token 会被写进 `.git/config` 的 upstream。用已配好的凭据助手,直接 `git push`。

### 首次 push 步骤(Air 上)

```bash
# 若尚未配置远程:
git remote add origin git@github.com:EasyIndie/EasyApple.git
git branch -M main
git push -u origin main
```

> 当前 Windows 本地仓库**只做了 `git init` + 提交,没有 push**(按你的要求省略了
> 推送步骤)。所以你要么先在 Windows 上推、要么把目录拷到 Air 再推。

---

## 6. 未决问题(执行前请拍板)

1. **Intel MBP 是否纳入构建?** 默认不纳入(见 D1)。若要纳入,须退回 tools-version 5.7。
2. **是否引入 `idb` 做文本树验收?** 默认「可选」,缺失时退化为截图。
3. **首期是否需要 App 扩展(Widget)/ entitlements / watchOS?** 默认不需要;需要则加大
   XcodeGen 逃生舱的投入。
4. **swift-bundler 的 pin commit** 取哪个?(执行阶段 `bootstrap.sh` 会写死一个,
   你可在 Air 上按实际 `main` HEAD 调整。)
5. **远程仓库用 SSH 还是 HTTPS?** 默认 SSH;EasyAndroid 用的是 HTTPS。

---

## 7. 在 Windows 上继续开发的方式(改代码/文档)

- ✅ 可以:写文档、写 Swift 源码、写 shell 脚本(用 `bash -n` 做语法检查)、改 `.github/workflows`。
- ❌ 不可以:构建、跑模拟器、跑 `swift test`、验证 SwiftAPI。
- 需要构建时:经 SSH 到 Air(`tools/host.env` 的 `MAC_SSH_ALIAS`),执行阶段会提供
  `mac_run` 包装;或推到 GitHub 让 CI 跑。

---

## 8. 实测结果(在 Air 上填)

> 跑完 §4 的复核命令后,把结果贴在这里,或直接更新对应文档并提交。

```
sw_vers:
xcodebuild -version:
swift --version:
xcrun --sdk iphonesimulator --show-sdk-path:
xcrun simctl list runtimes:
ls /Applications/Xcode.app/Contents/Developer/Applications/:
swift bundler --version:
xcodegen --version:
idb --version:
```

---

## 9. 回传方式(长期工作约定)

本项目长期是「Windows 写 → Air 验」的闭环:

1. 在 Windows 上改代码/文档并提交;
2. 在 Air 上 `git pull`,跑验证;
3. 把**失败输出**或新建的 `handoff-report.md` 回传(贴回来 / 提交进仓库);
4. 在 Windows 上据此修;
5. 回到第 2 步。

**不要因为一条命令失败就改仓库结构** —— 先把原始输出回传,确认是环境问题还是代码问题。
