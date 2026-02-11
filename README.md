<p align="center">
  <img src="ScreenTranslate/Resources/Assets.xcassets/AppIcon.appiconset/icon_128x128.png" alt="ScreenTranslate" width="128" height="128">
</p>

<h1 align="center">ScreenTranslate</h1>

<p align="center">
  macOS 菜单栏截图翻译工具，支持 OCR 识别、多引擎翻译和智能标注
</p>

<p align="center">
  <a href="https://github.com/hubo1989/ScreenTranslate/releases"><img src="https://img.shields.io/badge/version-1.0.2-blue.svg" alt="Version"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT"></a>
  <a href="https://www.apple.com/macos/"><img src="https://img.shields.io/badge/macOS-13.0%2B-brightgreen.svg" alt="macOS"></a>
  <a href="https://swift.org/"><img src="https://img.shields.io/badge/Swift-6.0-orange.svg" alt="Swift"></a>
</p>

## 功能特性

### 截图功能
- **区域截图** - 选择屏幕任意区域进行截图
- **多显示器支持** - 自动识别并支持多显示器环境
- **窗口高亮** - 截图前自动隐藏应用窗口，避免干扰

### OCR 文字识别
- **Apple Vision** - 原生 OCR，无需额外配置
- **PaddleOCR** - 可选外部引擎，中文识别更准确

### 多引擎翻译
- **Apple Translation** - 系统内置翻译，离线可用
- **MTranServer** - 自建翻译服务器，高质量翻译
- **VLM 视觉模型** - OpenAI GPT-4 Vision / Claude / Ollama 本地模型

### 标注工具
- 矩形框选
- 箭头标注
- 手绘涂鸦
- 文字注释
- 截图裁剪

### 其他功能
- **翻译历史** - 保存翻译记录，支持搜索和导出
- **双语对照** - 原文译文并排显示
- **覆盖层显示** - 翻译结果直接显示在截图上方
- **自定义快捷键** - 支持全局快捷键快速截图
- **多语言支持** - 支持 25+ 种语言翻译

## 安装要求

- macOS 13.0 (Ventura) 或更高版本
- 屏幕录制权限（首次使用时会提示）

## 下载安装

从 [Releases](../../releases) 页面下载最新版本。

> ⚠️ **注意：应用未经过 Apple 开发者签名**
>
> 由于目前没有 Apple Developer 账号，应用未进行代码签名。首次运行时 macOS 会提示「无法打开」或「开发者无法验证」。
>
> **解决方法**（二选一）：
>
> **方法 1 - 终端命令（推荐）**
> ```bash
> xattr -rd com.apple.quarantine /Applications/ScreenTranslate.app
> ```
>
> **方法 2 - 系统设置**
> 1. 打开「系统设置」→「隐私与安全性」
> 2. 在「安全性」部分找到关于 ScreenTranslate 的提示
> 3. 点击「仍要打开」
>
> 两种方法都只需要执行一次，之后可以正常使用。

## 使用说明

### 快捷键

| 快捷键 | 功能 |
|--------|------|
| `Cmd+Shift+5` | 区域截图翻译（默认） |

### 预览窗口操作

| 快捷键 | 功能 |
|--------|------|
| `Enter` / `Cmd+S` | 保存截图 |
| `Cmd+C` | 复制到剪贴板 |
| `Escape` | 关闭窗口 / 取消裁剪 |
| `R` / `1` | 矩形工具 |
| `D` / `2` | 手绘工具 |
| `A` / `3` | 箭头工具 |
| `T` / `4` | 文字工具 |
| `C` | 裁剪模式 |
| `Cmd+Z` | 撤销 |
| `Cmd+Shift+Z` | 重做 |

## 技术栈

- **Swift 6.0** - 现代 Swift 语言特性，严格并发检查
- **SwiftUI + AppKit** - 声明式 UI 与原生 macOS 组件结合
- **ScreenCaptureKit** - 系统级屏幕录制与截图
- **Vision** - Apple 原生 OCR 文字识别
- **Translation** - Apple 系统翻译框架
- **CoreGraphics** - 图像处理与渲染

## 项目结构

```
ScreenTranslate/
├── App/                    # 应用入口
├── Features/               # 功能模块
│   ├── Capture/           # 截图功能
│   ├── Preview/           # 预览与标注
│   ├── Overlay/           # 翻译覆盖层
│   ├── BilingualResult/   # 双语结果展示
│   ├── History/           # 历史记录
│   ├── Settings/          # 设置界面
│   ├── Onboarding/        # 首次引导
│   ├── MenuBar/           # 菜单栏控制
│   ├── Annotations/       # 标注工具
│   └── TranslationFlow/   # 翻译流程控制
├── Services/              # 业务服务
│   ├── OCREngine/         # OCR 引擎
│   ├── Translation/       # 翻译服务
│   ├── VLMProvider/       # 视觉语言模型
│   └── ...
├── Models/                # 数据模型
├── Extensions/            # 扩展
├── Resources/             # 资源文件
└── Utilities/             # 工具类
```

## 构建源码

```bash
# 克隆仓库
git clone https://github.com/hubo1989/ScreenTranslate.git
cd ScreenTranslate

# 用 Xcode 打开
open ScreenTranslate.xcodeproj

# 或命令行构建
xcodebuild -project ScreenTranslate.xcodeproj -scheme ScreenTranslate
```

## 贡献指南

欢迎提交 Issue 和 Pull Request。

## 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

---

Made with Swift for macOS
