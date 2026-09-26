# 06 — UI 验收(截图为先)

> **状态:已在 Air 实测**(iPhone 17 模拟器截图成功,App 启动并在屏幕上渲染)。

## 1. 策略(决策 D7)

> **截图判「渲染对不对」;文本树判「输入有没有生效」。首期以截图为准,文本树后置。**

理由:iOS 没有 Android `uiautomator dump` 那样的原生文本树;`idb ui describe-all` 需要引入
第三方工具(与「只用原生工具」冲突)。首期用截图为验收基线。

## 2. 实测流程

```bash
# 一条命令:打包 + 装进模拟器 + 启动 + 截图
tools/run-sim.sh --screenshot /tmp/envdemo.png

# 或分步
tools/bundle.sh --platform iOSSimulator
xcrun simctl install <UDID> apps/EnvDemo/.build/bundle/EnvDemo.app
xcrun simctl launch  <UDID> com.easyapple.envdemo
xcrun simctl io <UDID> screenshot /tmp/envdemo.png
```

`tools/ui-dump.sh` 封装了截图(默认输出到 `.tmp/ui-<时间戳>.png`)。

## 3. 怎么判「对」

- 截图分辨率 = 设备的点分辨率 × 缩放(实测 iPhone 17:393×852 pt → 1206×2622 px)。
- 检查关键文本是否出现(EnvDemo 显示型号 / 系统 / 架构 / 内存 等)。
- 进阶(后置):文本树可用自写 XCUITest 打印 accessibility tree。

## 4. CI 上的截图

`ci.yml` 的「模拟器冒烟」步骤会跑 `run-sim --screenshot`,并把 `.tmp/*.png` 作为 artifact 上传
(`continue-on-error: true`,不阻塞)。实测在 GitHub `xcode-27` runner 上成功出图。

## 5. 已知限制

- 截图只能验证「渲染」,不能断言交互。
- 模拟器无 `FLAG_SECURE` 之类问题(与 Android/TV 不同),截图可靠。
