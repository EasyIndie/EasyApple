# template — 新应用的起点

**这不是一个可发布的应用,也不在 `apps/` 下,不参与构建/发版。**

`tools/new-app.sh <AppName>` 复制它,并把 `TemplateApp` 替换成目标名称:

- 包 / 产品 / 目标名:`TemplateApp` → `<AppName>`
- 路径:`Sources/TemplateApp/`、`Sources/TemplateAppCore/`、`Tests/TemplateAppCoreTests/`
- 说明文件:本 README 里的名称也会一起替换

## 里面有什么

| 文件 | 作用 |
|---|---|
| `Package.swift` | SwiftPM 工程真相(Core library + executable + 单测) |
| `Sources/TemplateAppCore/Greeting.swift` | 最小纯逻辑,不 import SwiftUI |
| `Sources/TemplateApp/TemplateApp.swift` | 最小 SwiftUI `@main` + 一屏文本 |
| `Tests/TemplateAppCoreTests/` | 宿主机 `swift test` 可跑的纯逻辑单测 |
| `ui-assertions.txt` | 默认 OCR 断言(`Hello` / `template`),生成后请改成自己的 |

## 改这个目录要注意

1. **它是所有新应用的源头。** 改完必须跑一次模板冒烟:

   ```bash
   tools/test-template.sh
   ```

   它会用 `new-app.sh` 生成一个临时应用、`swift build` + `swift test`、再删掉。
2. **不要放业务代码、不要放设备/环境探测。** 那些属于具体应用或 `apps/EnvDemo`。
3. **不要写死包名 / 版本号。** 版本号唯一来源是仓库根 `version.properties`(D8)。
4. **保持最小。** 模板只提供能构建、能跑、能断言的骨架;复杂度留给具体应用。
