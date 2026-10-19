# 05 — 虚拟 iPhone(vphone)调研(2026-10 快照)

> **状态:桌面调研 + 本机条件核对,未安装、未跑通。**
> 本文只回答三件事:`vphone` 是什么、现在能不能用、**要不要纳入本仓库的构建/验收链路**。
> 结论是**不纳入**(理由见 §1、§5、§7);下面的细节留作将来复评的依据。

## 1. 一句话结论

`vphone` 是「在 Apple Silicon Mac 上跑**一台真正的 iPhone**(完整 iOS userland +
内核 + SEP),基于 Virtualization.framework 的 research guest 与 Apple PCC
cloudOS 固件残件」的开源项目,**面向安全研究/逆向,不是模拟器的替代品**。

对本仓库:

- ❌ **不能替代 iOS 模拟器**(`simctl`/`xcodebuild test` 那套闭环用不了,见 §4);
- ❌ **不能作为团队基线**:要改宿主的 SIP/AMFI、每台机器吃 20 GB+ 磁盘、固件来源
  已开始枯竭(§5、§6);
- ✅ 唯一有价值的场景:**将来需要「真 iOS 行为」的验收时**(Metal、真实 daemon、
  真机独有 API),在外置 SSD + 16 GB 以上的机器上做**离线实验**,不进主链路。

## 2. 项目谱系(别找错仓库)

| 项目 | 定位 | 快照数据 |
|---|---|---|
| [wh1te4ever/super-tart-vphone](https://github.com/wh1te4ever/super-tart-vphone) | **原始实现**:改 `super-tart`,让它以 `vresearch101` 平台启动 iPhone | 413★;**2026-02-25 已 archive**;README 自称「不是给终端用户用的,大量硬编码 patch」 |
| [wh1te4ever/super-tart-vphone-writeup](https://github.com/wh1te4ever/super-tart-vphone-writeup) | 上面那个项目的长篇技术 writeup(原理、踩坑、Metal 补丁) | 1.3k★;一次性发布,无后续 |
| **[Lakr233/vphone-cli](https://github.com/Lakr233/vphone-cli)** | **现在的主线**:重写为产品形态(Launchpad GUI + CLI + 模板/克隆/RPC 自动化) | **15.7k★ / 1.8k fork**,MIT,2026-02-26 建仓,2026-10-19 仍在提交 |
| [zqxwce/vphone-ws](https://github.com/zqxwce/vphone-ws) | 第三方 macOS GUI 管理器(壳) | 1.1k★,MIT,2026-08 |

搜索「vphone」主要会命中上表;`vphone-aio` 之类是二手整理稿,不是上游。
本文以下都以 `Lakr233/vphone-cli`(下称 vphone-cli)为准。

## 3. 它到底是怎么跑起来的(原理)

不是模拟器、不是翻译执行,而是**把 iOS 当成 macOS 的虚拟机 guest 启动**:

1. **虚拟硬件**:用 Virtualization.framework 的私有 API 造出 research 机型
   (`_VZMacHardwareModelDescriptor`,`boardID 0x90`、`platformVersion 3`、
   `ISA 2`),即 Apple 给 PCC 研究用的 `vresearch101` 平台;分辨率按 iPhone
   面板配置(1290×2796 @460ppi 等)。
2. **boot ROM**:Apple 的 `AVPBooter.vresearch1.bin` / `AVPSEPBooter.vresearch1.bin`
   (随 Virtualization.framework 分发)。原始做法是用 IDA 把 AVPBooter 里
   签名校验函数的 epilogue 改成「永远返回 0」;vphone-cli 现在默认改用自研的
   开源替代 [OpenAVB](https://github.com/Lakr233/vphone-cli/tree/main/Research)
   / OpenSEP,做到「iBoot 之前没有一行 Apple 代码」。
3. **固件从哪来(关键)**:
   - **内核 / SEP / device tree** 来自 Apple **PCC(Private Cloud Compute)**
     `cloudOS` 镜像里的 `vphone600ap` 组件(设备号 `iPhone99,11`),即
     「iPhone Research Environment Virtual Machine」;
   - **userland(系统 App、框架)** 来自**普通 iPhone 的 restore IPSW**
     (iPhone17,3 / 16 系列为默认,可换 17/18 系列、iPad、Apple TV);
   - 两半拼起来后,对 iBSS/iBEC/LLB/TXM/kernelcache/DeviceTree 打一串 patch
     (签名校验、dyld shared cache、AMFI/TXM、调试端口等),再走一次**在线 DFU
     restore**(要连 Apple 取签名票据)。
4. **guest 侧 daemon**:`vphoned` 装进 guest,宿主通过 `<VM>/vphone.sock` 用一行
   JSON 控制它(tap/swipe/键盘/截屏/装 App/读 UI 树/文件/日志)。

这也解释了两个限制:**必须有真机 Apple Silicon**(research guest 不能嵌套)、
**必须让 AMFI 放行带 Apple 私有 entitlement 的 `vphone-vm`**(否则一行都跑不起来)。

## 4. 能做什么 / 不能做什么

能(官方文档 + 实测记录):

- 完整 iOS/iPadOS/tvOS GUI,Metal 加速(paravirtual GPU),真触摸注入;
- 快照、导出/导入、克隆(新 ECID/UDID/MAC)、模板(建一次克隆多台,每台约 0.35 GB);
- 通过 `vphoned` **装 IPA**(`apps.install`,自带重签,绕过 installd)、启动、读
  UI 树、截屏、录屏、`ideviceinstaller`/libimobiledevice 也能看到设备;
- 在 guest 里装 roothide bootstrap(apt/dpkg/ssh/curl…)做越狱环境研究;
- `vphone-launchpad-cli` 全命令行操作,输出 JSON —— 天然适合 agent 驱动。

**不能**(最影响本仓库的几条):

| 想做的事 | 现实 |
|---|---|
| `xcodebuild test` / `simctl` 跑单测 | ❌ 不是 simulator,没有 `simctl`;guest 只是「Xcode 设备列表里的一个设备」 |
| Xcode 直接 Install/Run/Debug | ❌ `xcrun devicectl device install app` **会卡住超时**;`devicectl list devices` 能列出(Reality 显示 `virtual`)。上游明确写「不要用 devicectl 装/启」 |
| LLDB 附加调试 | ⚠️ 有 patch 提供 `task_for_pid` 调试能力,但**不是** Xcode 的常规调试链路;文档没有给出可用的 Xcode 调试流程 |
| 登录 Apple Account / App Store | ❌ 默认 profile 直接关掉;IAP、CloudKit、推送等依赖账号的服务**无法验证**(推送/CloudKit 未在文档中背书,属未验证项) |
| 当 CI 跑 | ❌ 要 root、要改宿主安全设置、要在线票据、几十 GB 磁盘 |

## 5. 本机可行性(2026-10 在 Air 上核对的硬数字)

本机:`MacBookAir10,1` / Apple M1 / **8 GB RAM** / macOS 27.0.1 (26A434) /
Xcode 27.0 已装 / `/` 可用 **24 GiB** / SIP enabled。

| 门槛 | 要求 | 本机 | 判定 |
|---|---|---|---|
| CPU | Apple Silicon(M1 可用:原始 writeup 在 M1 Pro 32 GB 上跑通) | M1 | ✅ |
| 内存 | 默认 guest **8 核 / 8192 MB**,宿主还要同时跑 macOS + Xcode | 8 GB 总量 | ❌ 会重度 swap |
| 磁盘 | 单次创建约 **13.5 GB IPSW + 11 GB restore tree + 20.5 GB Disk.img ≈ 45 GB** | 24 GiB 可用 | ❌ 装不下 |
| 宿主安全设置 | Recovery 里 `csrutil allow-research-guests enable` + 至少 `csrutil enable --without debug`,并把 `vphone-vm` 的 cdhash 加白(每次重编译都要重加) | SIP 完整开启 | ⚠️ 需改动主力机 |

→ **本机(唯一开发机)不具备条件**,而且不该为了它把主力机的 SIP 降级。

## 6. 风险(比技术门槛更重要)

1. **固件来源已经枯竭**:`vphone600ap` 只存在于 `cloudOS 26.4-23E5207q`(beta);
   上游 2026-10-03 逐个核查 26.4 正式版之后的 cloudOS,`SupportedProductTypes`
   里已无 `iPhone99,11`,也没有 `kernelcache.*.vphone600` / `sep-firmware.vphone600`
   / `DeviceTree.vphone600ap`。**Apple 已经把这个组件收回**,现在能跑只是因为还留着
   那份 beta 镜像;哪天 Apple 停发签名票据,整条链路就断。
2. **性质是「把 Apple 未打算公开的 research VM 拼成零售 iOS」**:patch 掉签名校验、
   植入 jailbreak 补丁。个人安全研究可解释,但**不适合作为公司开发/分发的基线**,
   更不可能用于出 App Store 包。
3. **宿主安全面**:`--without debug` 是弱化 SIP 的一个边界(不是全关,但仍属降级);
   全关 + `amfi_get_out_of_my_way=1` 更激进。上游自己也在文档里反复提醒「这是机器
   所有者的事」「不要为了让 agent 跑通就改」。
4. **供应链**:你要运行的是别人打好的固件 patch 与签名过的 `VPhone.bundle`;
   虽然有版本校验/cdhash 白名单,但本质上是「在主力机上跑一个被改过的 iOS 内核」。
5. **可持续性**:仓库迭代极快(1.x → 2.x 格式不兼容,VM 不能原地升级),文档量大且
   每月变动;今天写下的操作步骤很可能下个月就失效。

## 7. 与本仓库既有决策的关系

| 既有决策 | 是否被 vphone 动摇 |
|---|---|
| [D5](../00-decisions.md) 只用原生工具、不引第三方打包链 | ❌ 不动摇。vphone 是「多一个运行目标」,不是打包工具;引入它反而多一层自制工具链 |
| [D7](../00-decisions.md) 验收以截图为先、idb 后置 | ⚠️ vphone 的 `guest send`/截屏确实能出图,但**成本(45 GB + 改 SIP)远高于 `simctl io screenshot`**;模拟器截图仍是首选 |
| [research/03](03-simulator-cross-platform.md) 模拟器不可跨平台、跨平台 = 远程 macOS | ❌ 不冲突:vphone 同样只能在物理 Apple Silicon 上跑,**还多了「不能嵌套 VM」** |
| [D15](../00-decisions.md) 文本级验收(OCR) | ❌ 不冲突;vphone 反而提供 `ui.describe` 文本树,但它不是「无 IDE」必需项 |
| 平台规则([research/01](01-apple-platform-rules-2026.md)) | ⚠️ 提醒:提交 App Store 仍必须用**官方 Xcode + 官方 SDK + 官方签名**,虚拟 iPhone 出不了包 |

## 8. 如果将来真要试(最小侵入版)

1. **换机器**:16 GB 以上内存 + 外置 SSD(APFS),把 `~/.vphone` 指到外置盘;
   **不要动主力 Air 的 SIP**。
2. 宿主设置走「保留 SIP」那条:
   `csrutil enable --without debug` + `csrutil allow-research-guests enable`,
   再用 bundle 自带的 `vphone-escalator allow` 按 cdhash 加白(每次重编都要重加)。
3. 只从 `-notarized` 的 release 装 Launchpad;Launchpad 与 `VPhone.bundle` 必须同
   series(前两位版本号一致)。
4. 第一台机器用 `--no-template`(独立 SEP/Data 密钥),之后同固件再建模板做克隆。
5. 验收方式用 `vphone-launchpad-cli guest rpc ...` + 截屏,**不要**指望 Xcode/`devicectl`。

## 9. 怎么复核

只读、无副作用(在 Air 上可随时跑):

```sh
# 硬件与磁盘是否够
sysctl -n hw.model; sysctl -n hw.memsize | awk '{print $1/1073741824 " GB"}'
df -h /System/Volumes/Data | cat

# 宿主安全设置现状(不要为了复核去改)
csrutil status

# 上游是否还活着、固件是否还发
curl -s https://api.github.com/repos/Lakr233/vphone-cli | \
  python3 -c "import sys,json;d=json.load(sys.stdin);print(d['pushed_at'],d['stargazers_count'])"
curl -s https://api.github.com/repos/Lakr233/vphone-cli/releases/latest | \
  python3 -c "import sys,json;d=json.load(sys.stdin);print(d['tag_name'],d['published_at'],[a['name'] for a in d['assets']])"
```

真要装的验证顺序(上游口径,失败就停在原地):

```sh
vphone-launchpad-cli status            # host 检查 / helper / 默认 bundle
vphone-launchpad-cli bundle list
vphone-launchpad-cli vm create ph --iphone-source <iPhone17,3 IPSW> \
  --cloudos-source <cloudOS 26.4-23E5207q IPSW> --no-template
vphone-launchpad-cli vm start ph --wait
vphone-launchpad-cli guest rpc ph device.info      # 拿到型号/系统版本才算通
```

⚠️ 复核时最容易踩的两个坑:`cloudOS` 必须含 `vphone600ap`(新版会被 `fw prepare`
直接拒);iPhone IPSW 与 cloudOS 的版本组合不是随便配的,先看
`Documents/Guides/compatibility.md` 的实测表。

## 10. 参考

- 主线仓库:https://github.com/Lakr233/vphone-cli
  - `Documents/Guides/host-setup.md`(SIP/AMFI 两条路)
  - `Documents/Guides/compatibility.md`(cloudOS `vphone600ap` 存亡表)
  - `Documents/Guides/create-and-run.md`(磁盘/模板/克隆/命名/时钟)
  - `Research/Host/disk_space.md`(20.5 GB 构成与省法)
  - `Skills/vphone-guest-control/SKILL.md`(agent 驱动口径:别用 devicectl)
- 原始实现与 writeup:https://github.com/wh1te4ever/super-tart-vphone ,
  https://github.com/wh1te4ever/super-tart-vphone-writeup
- Apple 官方 PCC 研究 VM 入口(页面 JS 渲染,正文未取到,⚠️ 细节未核实):
  https://security.apple.com/documentation/private-cloud-compute/vresetup

快照时间:2026-10-19(上游 `pushed_at`)/ 2026-10-19 本机核对。
