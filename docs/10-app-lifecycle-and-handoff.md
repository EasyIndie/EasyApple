# 10 — 应用生命周期:模板 → 孵化 → 交付

> **状态:已落地并实测**(模板冒烟、`handoff-app.sh` 导出后可在新目录独立构建/单测/自检)。
>
> 这一篇是 EasyAndroid 的 [`docs/12-client-repos`](https://github.com/EasyIndie/EasyAndroid/blob/main/docs/12-client-repos.md)
> 在 Apple 侧的对应物:应用在 `apps/` 里孵化,成熟后交付成独立仓库,工具链跟着走。

## 1. 三个角色,不要混

| 路径 | 角色 | 参与构建/发版 |
|---|---|---|
| [`template/`](../template/) | 新应用脚手架(`new-app.sh` 的复制源) | ❌ 不在 `apps/` 下 |
| `apps/EnvDemo/` | **示例 + 自检应用**,验证工具链链路 | ✅ |
| `apps/<Name>/` | 业务应用孵化区 | ✅ |

历史包袱:EnvDemo 曾经同时兼任模板,`new-app.sh` 直接 `cp -R apps/EnvDemo`。
结果是**模板会随示例代码漂移**,新工程还带着环境探测代码。现在模板独立(D18)。

## 2. 新建应用

```bash
tools/new-app.sh MyApp
```

它从 `template/` 复制,不是一个已有应用:

- `TemplateApp` → `MyApp`(包/产品/目标/路径/README)
- 应用名只允许字母开头 + 字母数字(Swift 模块名约束)
- 生成后若有 `TemplateApp` 残留就直接失败,不把问题留到构建阶段
- 不碰 `apps/EnvDemo`,也不会复制 `.build`

生成后的三件事(脚本会再提示):

1. 改 `Sources/MyApp/` 与 `Sources/MyAppCore/`
2. 改 `ui-assertions.txt` 成自己 UI 的稳定文本
3. `tools/build.sh MyApp && tools/test.sh MyApp && tools/run-sim.sh --app MyApp`

## 3. 模板冒烟(改模板后必跑)

```bash
tools/test-template.sh
```

`template/` 不参与 `apps/` 的常规构建,改坏了平时不会有人发现。这个脚本用真实链路跑一遍:

```
new-app.sh TemplateCheck --dest .tmp/template-check
  → xcrun swift build
  → xcrun swift test
  → 删除临时目录
```

CI 与 `verify-all.sh` 都包含这一步。

## 4. 交付(handoff)

应用成熟、要交给业务仓库时:

```bash
tools/handoff-app.sh MyApp --to ../MyApp            # 干跑:只做预检,不写文件
tools/handoff-app.sh MyApp --to ../MyApp --write    # 真正导出
```

### 4.1 为什么导出「应用 + 工具链」而不是只导出应用

所有脚本都用 `REPO_ROOT/apps/<App>` 找应用。只把源码甩出去,对方拿到的是**构建不了的壳**。
所以导出内容是一个能独立运行的小仓库:

```
<目标目录>/
├── apps/MyApp/              # 应用源码(不含 .build)
├── tools/                   # 构建/测试/模拟器/OCR/发版脚本
├── template/                # 之后还能 new-app
├── version.properties       # 版本唯一来源
├── CHANGELOG.md             # 从交付版本重新开始
├── README.md                # 构建/验收/发版说明
├── handoff-manifest.txt     # 来源 commit / 版本 / 每个源文件 sha256
└── handoff-manifest.sha256  # 可直接 `shasum -a 256 -c`
```

目标目录里可以直接跑:

```bash
tools/verify-all.sh          # repo-check → doctor → build → test → 模拟器 → OCR
```

### 4.2 预检项

`--write` 之前会检查,任何 ❌ 都会中止(不写半个仓库):

| 检查 | 失败/警告 |
|---|---|
| `apps/<App>/README.md` 存在 | ❌ 缺了对方不知道怎么构建 |
| `ui-assertions.txt` 存在 | ⚠️ 只能截图,不能文本断言 |
| 无 `TemplateApp` 残留 | ❌ 改名没改干净 |
| 无 `/Users/...` 绝对路径 | ⚠️ 换机器会坏 |
| 无 `*.p12` / `*.mobileprovision` | ❌ 签名凭据不能入库 |
| 无 >5MB 源文件 | ⚠️ 确认是否该入库 |
| `sync-version.sh --check` | ❌ 版本/字面量不规范 |

### 4.3 交付物里**没有**什么

- **CI workflows**:每个仓库的 runner/权限/发布策略不同,应该显式决定,不默认继承。
- **EasyRelease 签名/公证链路**:凭据在组织级 secrets,由目标仓库自己接。
- **`docs/` 与决策记录**:知识留在 EasyApple;交付仓库的 README 只写怎么用。
- **`.agents/skills`**:技能是开发机级共享的(`~/.agents/skills`),不随应用走。

需要时从 EasyApple 复制 `.github/workflows/release.yml` 或直接复用
`EasyIndie/EasyRelease`。

## 5. 交付后的版本与发版

- 交付仓库的 `version.properties` 从交付时的版本开始,之后**自己发自己的版**。
- `tools/release.sh` 同样按 Conventional Commits 推导(0.x 阶段 BREAKING 只升 MINOR)。
- 指纹/签名清单:等到真机签名链路(A1)落地后再加,格式参考 EasyAndroid 的
  `signing-manifest.txt`(只存 Team ID + 证书 SHA-256,不存私钥)。

## 6. 自检仓库(对应 EasyAndroid 的 `self-test/`)

EasyApple 目前用 `apps/EnvDemo` 当自检应用:它没有业务价值,只把环境信息渲染成一屏,
用 `arm64` / `GB` 做 OCR 断言。`verify-all.sh` 会遍历 `apps/`,所以它自动被验。

> 如果以后 `apps/` 里全是业务应用,再考虑把 EnvDemo 移到 `self-test/` 并让
> `verify-all` 优先选它 —— 跟 EasyAndroid 一样。现在只有一个示例,不提前拆。

## 7. 相关

- 工程结构:[02](02-swiftpm-project-conventions.md) §6
- 版本/发版:[05](05-app-conventions.md)
- UI 验收:[06](06-ui-acceptance.md)
- 决策:D18(模板独立)/ D19(仓库自检)/ D20(交付)
