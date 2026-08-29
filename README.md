<div align="center">

# AtaKonitena

_TaHiti 语「AtaKonitena」= 容器_

**跨平台、轻量级应用沙盒容器** — 内置自研语言 **AtaLanguage**，以 **`.atak`** 为应用安装包格式，像 LiveContainer 一样运行第三方应用，同时把数据与权限隔离在各自的沙盒里。

</div>

---

## 简介

AtaKonitena 是一个用 **Flutter** 构建的全端应用容器。它的核心理念：

```
AtaKonitena = 沙盒容器 + AtaLanguage 语言 + .atak 安装体系
```

- 每个 `.atak` 应用运行在独立沙盒中，只能访问自己的存储与清单声明的能力。
- 应用用容器内置的 **AtaLanguage** 脚本语言编写（亦可原生实现接口）。
- 支持在「应用市场」安装 / 重装示例，或导入外部 `.atak` 文件。
- 提供交互式 **Ata 控制台**，可实时求值 AtaLanguage 代码，方便学习调试。
- 附带 **内置文档 / 手册**，覆盖语言参考、宿主 API、包格式与权限模型。

## 支持平台

| 平台 | 说明 |
| --- | --- |
| Android | APK（按 ABI）+ AppBundle |
| iOS | unsigned `.app` |
| Web | Static build（localStorage 沙盒）|
| Linux | Debian bundle |
| macOS | arm64 `.app` |
| Windows | x64 release |

## 快速开始

### 运行

```bash
flutter pub get
flutter run            # 选择目标设备 / 平台
```

### 打开应用

1. 进入「应用市场」，安装内置示例。
2. 回到「应用」页，点击「启动」运行。
3. 也可在「控制台」直接输入 AtaLanguage 代码试运行。
4. 在「文档 / 手册」查阅完整语法与 API。

## AtaLanguage 速览

AtaLanguage 是容器内置的轻量脚本语言：结构化、无类型标注、JavaScript 风格。

```js
ata.heading("你好，AtaKonitena！");
let name = ata.input("你的名字？");
if (name != null && name != "") {
  ata.show("欢迎你，${name}！");
} else {
  ata.show("好吧，匿名者。");
}
```

## .atak 包格式

`.atak` 本质是一个 **Zip 归档**，内含 `manifest.json`、入口脚本与资源：

```
app.atak
├── manifest.json     # 应用清单（必填）
├── app.ata           # 入口脚本（由 entry 指定）
├── resources/        # 资源（可选）
└── vendor/           # 随包模块（可选）
```

权限通过 `manifest.json` 的 `permissions` 声明，沙盒只放行已声明能力对应的 API。

## 目录结构

```
lib/
├── core/
│   ├── ata_language/     # AtaLanguage 解释器（词法/语法/AST/求值/标准库）
│   ├── atak/             # .atak 包管理（manifest/打包/安装/卸载/升级）
│   ├── container/        # 容器管理与沙盒隔离（类似 LiveContainer）
│   └── examples.dart     # 内置示例应用
├── data/                 # 跨平台存储抽象（桌面/移动端文件系统 + Web LocalStorage）
├── features/             # 界面：已安装/市场/导入/控制台/文档/运行
├── ui/                   # 主题与主框架
├── app.dart
├── app_services.dart
└── main.dart
```

## 持续集成

`.github/workflows/build.yml` 在提交到 `main`、PR 或手动触发时，会在 GitHub Actions 上构建全部平台并上传制品；打 `v*` 标签时汇总成 `draft` Release。

## 构建产物验证

本地可用 lint 检查约束的完善程度：

```bash
flutter analyze
# → No issues found!
```

## 许可证

[MIT](LICENSE)

---

_由 AtaKonitena 团队维护_