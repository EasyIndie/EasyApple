# 决策记录(Decision Log)

> **状态一律为 `proposed`(提案)。** 这是在 Windows 上做的规划,还没有在 macOS 上
> 验证过。**在 Air 上请把同意的那几条改成 `accepted`;不同意的直接推翻,写上新理由。**
>
> 状态图例:`proposed` 提案 · `accepted` 已采纳 · `rejected` 已否决 · `superseded by Dx` 被取代。

| 编号 | 决策 | 理由 | 状态 | 怎么改 |
|---|---|---|---|---|
| **D1** | **构建机只用 M1 Air。Intel MBP 不参与构建。** | MBP 2015 Early 最高 macOS 12 Monterey → 最高 Xcode 14.2 / Swift 5.7,解析不了 `swift-tools-version:6.0` 的包,也跑不了 swift-bundler(需 Swift 6)。Air 能装最新 Xcode,能覆盖同样的旧模拟器。 | `proposed` | 要支持 Intel,须把 `swift-tools-version` 降到 5.7、改走 XcodeGen + Xcode 14.2,并放弃 Swift 6 特性。在 `PLAN.md` Phase B 与本文 D10 同步改。 |
| **D2** | **构建/模拟器/验收在 macOS 上;Windows 只写代码与文档。** | iOS SDK 只随完整 Xcode 提供,而 Xcode 只在 macOS 上运行(见 [research/01](research/01-apple-platform-rules-2026.md) §5)。 | `proposed` | 无(这是平台事实)。 |
| **D3** | **远程 Mac 走 SSH(`tools/host.env` 里的别名),不引入云 Mac/串流服务。** | 两台 Mac 都在手边,自己的机器最省事;云 Mac/串流(见 [research/03](research/03-simulator-cross-platform.md) §3)是备选。 | `proposed` | 若要远程办公,改用云 Mac(MacStadium/EC2 Mac)或 GitHub `macos-26` runner 即可,`mac_run` 抽象层不用改。 |
| **D4** | **工程真相 = SwiftPM(`Package.swift`);`.xcodeproj` 只是生成物,不入库。** | 纯文本、可 diff、无 Xcode 私有格式;`swift test` 可在宿主机秒级测逻辑。 | `proposed` | 若坚持用 Xcode 工程,可改成「XcodeGen 生成 + 入库 `project.yml`」,但那样就失去 SwiftPM 的跨平台测试优势。 |
| **D5** | **打包 = swift-bundler 主 + XcodeGen 逃生舱。** | SwiftPM 打不出 `.app`;swift-bundler 正好补且支持 iOS 模拟器;它不支持的场景(watchOS/扩展/XCUITest/archive)用 XcodeGen。 | `proposed` | 见 [research/04](research/04-swiftpm-packaging.md)。若要更稳,可把 XcodeGen 提升为主链路,swift-bundler 降为可选。 |
| **D6** | **首期只做模拟器闭环,零证书。** | 模拟器不校验签名,零门槛就能跑通「改代码 → 看界面」的循环;真机/分发需要付费账号,后置。 | `proposed` | 要真机时:免费 Apple ID 可做 7 天 profile;付费账号才能长期/分发。 |
| **D7** | **验收:截图判「渲染对不对」,文本判「输入有没有生效」;优先可 grep 的文本。** | 沿用 EasyAndroid 的结论(那边电视截图不可靠、Pico 截图被 FLAG_SECURE 挡)。iOS 侧文本树优先用 `idb ui describe-all`,缺失时退化到截图。 | `proposed` | 若不愿引入 `idb`,则只保留截图 + 人工判读,并在文档里标注这一限制。 |
| **D8** | **版本唯一来源 = `version.properties`(严格 SemVer);仓库内禁止版本号字面量。** | 沿用 EasyAndroid。CMake/Gradle/Xcode 各处的版本都从它推导,避免漂移。 | `proposed` | 无。 |
| **D9** | **CI runner = `macos-26` 显式 pin,不用 `-latest`。** | 换 OS = 换构建环境,不该无声发生(沿用 EasyAndroid 对 `ubuntu-24.04` 的同款约定)。macOS runner 是 arm64,与 Air 对齐。 | `proposed` | 升 runner 单独开一次、先在 CI 上验过再合。 |
| **D10** | **`swift-bundler` pin 到具体 commit(不用 `@main` 浮动)。** | 它无稳定 release,官方建议从 `main` 装;浮动会带来不可复现的构建。 | `proposed` | 升级时改 `tools/bootstrap.sh` 里的 commit,并在 `doctor.sh` 记录实际版本。 |
| **D11** | **远程仓库 = `EasyIndie/EasyApple`,origin 用 HTTPS(`https://github.com/EasyIndie/EasyApple.git`)。** | 与 EasyAndroid 同组织、同协议,复用同一套发版约定。**已落地**:2026-09-26 首次 push(commit `8802cf0`)。WSL 侧无 GitHub SSH key,故用 HTTPS + `gh` 凭据助手。 | `proposed` | 要换 SSH/组织/协议时,改 `git remote set-url origin …` 与 CI/README 里的链接。 |

## 变更记录

| 日期 | 变更 |
|---|---|
| 2026-09-26 | 初版(D1–D11,全部 `proposed`,Windows 上落档) |
| 2026-09-26 | D11 修正:origin 改为 HTTPS 并标记「已落地」(首次 push 完成) |
