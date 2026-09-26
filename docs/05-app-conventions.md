# 05 — 工程约定、版本号与发版

> **状态:已在 Air 实测**(版本校验、发版脚本 dry-run、CI 均跑过)。

## 1. 目录约定

```
apps/<AppName>/
├── Package.swift
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
CI 在 PR 上会校验(D1)。

## 4. 发版流程

```bash
tools/release.sh --dry-run     # 看建议的下一个 SemVer
tools/release.sh               # 改 version.properties + CHANGELOG,提交并打 tag
git push --follow-tags         # 触发 release.yml
```

推导规则:major=`type!:` · minor=`feat:` · patch=`fix|perf|refactor:`。

## 5. CI / 发布(已验证)

| | 说明 |
|---|---|
| `ci.yml` | `runs-on: xcode-27`,显式选 **Xcode_27.0.0.app(27A266a,与 Air 完全一致)**;doctor → 版本校验 → build → test → 模拟器冒烟 + 截图 artifact |
| `release.yml` | tag 推送触发 → 校验 tag==version.properties → `bundle.sh` → `gh release create` |

**重要(实测)**:`runs-on: macos-26` 默认只有 **Xcode 26.6**;只有 `xcode-27` 镜像才含
Xcode 27.x(27.0 / 27.1 / 27.2,含 beta)。选版本时要**显式优先 27.0**,否则「取最高」会选到 beta。
详见 [08](08-gotchas.md)。

CI 首跑(run `36257047066`、`36257758558`)均 **全绿**。
