# 05 — 工程约定、版本号与发版

> **状态:已在 Air 实测**(版本校验、发版脚本 dry-run、CI 均跑过)。

## 1. 目录约定

```
apps/<AppName>/
├── Package.swift
├── README.md                   # 怎么构建/运行/验收(repo-check 会查)
├── ui-assertions.txt           # OCR 文本断言(见 06)
├── Sources/<AppName>/          # executable(@main)
├── Sources/<AppName>Core/      # library(纯逻辑)
├── Tests/<AppName>CoreTests/
└── .build/bundle/<AppName>.app # 打包产物(不入库)
```

- Bundle ID 约定:`com.easyapple.<appname 小写>`。
- 端口名:`<AppName>` / `<AppName>Core` / `<AppName>CoreTests`。

## 2. 版本号:唯一来源是 `version.properties`(决策 D8)

```properties
version=0.0.1
```

映射(由 `tools/bundle.sh` 注入 `Info.plist`):

| 产物字段 | 来自 |
|---|---|
| `CFBundleShortVersionString` | `version` |
| `CFBundleVersion` | `MAJOR*10000 + MINOR*100 + PATCH` |

**源码里禁止版本字面量。** 校验:

```bash
tools/sync-version.sh --check
# → [ ok ] 版本校验通过: version=0.0.1  CFBundleVersion=1
```

`tools/build.sh` 会先跑这个检查。

## 3. 提交规范(Conventional Commits)

`type(scope): 描述`,常用 `feat` / `fix` / `docs` / `ci` / `chore` / `refactor`。
CI 在 PR 上会校验,本地可先跑:

```bash
tools/release.sh --check-commits                 # 上一个 tag..HEAD
tools/release.sh --check-commits origin/main..HEAD
```

## 4. 发版流程

```bash
tools/release.sh --dry-run     # 看建议的下一个 SemVer
tools/release.sh               # 改 version.properties + CHANGELOG,提交并打 tag
git push --follow-tags         # 触发 release.yml
```

推导规则:

| 提交 | 段位 |
|---|---|
| `type!:` 或正文含 `BREAKING CHANGE:` | MAJOR |
| `feat:` | MINOR |
| `fix:` / `perf:` / `refactor:` | PATCH |
| 其他(`docs` / `ci` / `chore` …) | 不发版 |

> **0.x 阶段例外:BREAKING 只升 MINOR。** 0.x 本来就不承诺稳定,直接跳 1.0.0 会让人
> 误以为已经稳定;真要到 1.0.0 应显式决定。这与 EasyAndroid 的 `release.sh` 语义一致。

发布流水线支持 dry-run(不建 Release,只产出可下载的 zip):

```bash
gh workflow run release.yml -R EasyIndie/EasyApple -f tag=<version> -f dry_run=true
```

## 5. CI / 发布(已验证)

| | 说明 |
|---|---|
| `ci.yml` | `runs-on: xcode-27` + `.github/actions/select-xcode`(默认 **27.2**,排除 beta,与本地一致);repo-check → 版本校验 → 模板冒烟 → build → test → iOS 运行时单测 → 模拟器冒烟 + 截图 artifact |
| `release.yml` | tag 推送触发 → 校验 tag==version.properties → matrix 调 EasyRelease(Developer ID + 公证 + staple)→ 按产物类型发布:`.app` 用 `ditto` 打 zip、`.zip` 直传、`.dmg`/`.pkg` 原生 → sha256 → `gh release create` |

**重要(实测)**:`runs-on: macos-26` 默认只有 **Xcode 26.6**;只有 `xcode-27` 镜像才含
Xcode 27.x(27.0 / 27.1 / 27.2,含 beta)。选版本时**必须排除 beta**,并优先指定版本;
逻辑集中在 `.github/actions/select-xcode`,不要在 workflow 里各抄一份。
详见 [08](08-gotchas.md) §4 与决策 D21。

`repo-check.sh` 会校验:workflow 的 `runs-on` 不写 `-latest`、action 主版本不倒退、
EasyRelease pin 到具体 tag、所有选 Xcode 的输入版本一致。

CI 首跑(run `36257047066`、`36257758558`)均 **全绿**。

## 6. 交付到独立仓库

应用成熟后用 `tools/handoff-app.sh` 导出成自包含仓库(应用 + 工具链 + manifest):

```bash
tools/handoff-app.sh MyApp --to ../MyApp --write
```

见 [10](10-app-lifecycle-and-handoff.md)。
