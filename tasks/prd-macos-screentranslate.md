# PRD: macOS 屏幕翻译工具 (ScreenTranslate)

## Overview

一个 macOS 菜单栏应用，允许用户通过快捷键截取屏幕任意区域，自动识别文字（OCR），调用本地 MTranServer 进行翻译，并以覆盖层形式在原位置展示译文（替换原文或在原文下方显示）。

## Goals

- 提供流畅的屏幕取词翻译体验，无需手动复制粘贴
- 支持两种译文展示模式：原位替换 和 原文下方显示
- 使用本地 OCR 和翻译服务，保护用户隐私
- 智能语言检测，同时允许用户手动覆盖
- 保存翻译历史，方便回顾

## Quality Gates

These commands must pass for every user story:
- `swift build` - Swift 编译检查
- `swift test` - 单元测试通过
- `swiftlint` - 代码风格检查（如项目配置）

## User Stories

### US-001: 项目初始化和菜单栏基础架构
As a developer, I want to set up the macOS menu bar app project structure so that subsequent features can be built on a solid foundation.

**Acceptance Criteria:**
- [ ] 创建 Swift 项目，使用 SwiftUI + AppKit 混合架构
- [ ] 配置菜单栏图标（StatusBarItem），点击显示下拉菜单
- [ ] 菜单包含：开始截图、设置、历史记录、退出
- [ ] 应用启动时不显示 Dock 图标（LSUIElement）
- [ ] 创建配置文件目录 `~/Library/Application Support/ScreenTranslate/`

### US-002: 全局快捷键注册与管理
As a user, I want to use a customizable global hotkey to trigger screenshot capture from anywhere.

**Acceptance Criteria:**
- [ ] 默认快捷键 Cmd+Shift+T 注册成功
- [ ] 使用 `MASShortcut` 或 `HotKey` 库实现全局快捷键监听
- [ ] 快捷键可在设置中修改，修改后立即生效
- [ ] 快捷键冲突时给出友好提示

### US-003: 屏幕截图区域选择
As a user, I want to select any rectangular region on screen for OCR processing.

**Acceptance Criteria:**
- [ ] 快捷键触发后进入截图模式，屏幕变暗
- [ ] 鼠标拖拽绘制选区，实时显示选区边框
- [ ] 支持按 Esc 取消截图
- [ ] 支持 Retina 屏幕，截图分辨率正确
- [ ] 选区确定后（鼠标松开）触发 OCR 流程

### US-004: PaddleOCR 本地集成
As a user, I want text to be recognized locally using PaddleOCR for privacy and speed.

**Acceptance Criteria:**
- [ ] 集成 PaddleOCR C++ 库或调用 Python 脚本
- [ ] 支持中英文混合识别
- [ ] OCR 结果包含：文字内容、置信度、每个文字的边界框坐标
- [ ] 异步执行 OCR，不阻塞主线程
- [ ] OCR 失败时显示友好错误提示

### US-005: MTranServer 翻译集成
As a user, I want recognized text to be translated using local MTranServer.

**Acceptance Criteria:**
- [ ] 实现 MTranServer HTTP API 客户端
- [ ] 支持自动检测源语言（可选配置）
- [ ] 支持配置目标语言（默认跟随系统，可手动覆盖）
- [ ] 翻译请求异步执行，带超时处理（默认 10 秒）
- [ ] 翻译失败时显示原文 + 错误提示

### US-006: 覆盖层渲染引擎 - 原位替换模式
As a user, I want to see translated text overlaid at the exact position of original text.

**Acceptance Criteria:**
- [ ] 创建透明覆盖窗口，覆盖整个屏幕或选区
- [ ] 根据 OCR 返回的边界框坐标定位译文
- [ ] 译文文字样式匹配原文区域（近似字体大小、颜色）
- [ ] 支持点击覆盖层外部关闭
- [ ] 支持按 Esc 关闭覆盖层

### US-007: 覆盖层渲染引擎 - 原文下方模式
As a user, I want to see translation displayed below the original text area.

**Acceptance Criteria:**
- [ ] 在选区下方创建浮窗展示完整译文
- [ ] 浮窗样式美观，带阴影和圆角
- [ ] 显示原文和译文对照（原文灰色，译文黑色）
- [ ] 支持复制译文到剪贴板
- [ ] 支持点击外部或按 Esc 关闭

### US-008: 设置面板 - 基础配置
As a user, I want to configure app settings through a preferences window.

**Acceptance Criteria:**
- [ ] 创建设置窗口，可从菜单栏打开
- [ ] 快捷键设置：显示当前快捷键，点击可修改
- [ ] MTranServer 地址配置（默认 localhost:8989）
- [ ] 翻译模式选择：原位替换 / 原文下方
- [ ] 设置变更立即保存到配置文件

### US-009: 设置面板 - 语言配置
As a user, I want to configure source and target languages for translation.

**Acceptance Criteria:**
- [ ] 源语言选项：自动检测、中文、英文、日文等
- [ ] 目标语言选项：跟随系统、中文、英文等
- [ ] 语言列表从 MTranServer 动态获取支持的语言对
- [ ] 语言配置保存并立即生效

### US-010: 翻译历史记录
As a user, I want to view and manage my recent translation history.

**Acceptance Criteria:**
- [ ] 每次翻译保存记录：时间、原文、译文、截图缩略图
- [ ] 历史记录窗口可从菜单栏打开
- [ ] 显示最近 50 条记录，支持滚动加载更多
- [ ] 支持搜索历史记录（按原文或译文内容）
- [ ] 支持删除单条或清空全部历史

### US-011: 首次启动引导
As a new user, I want to be guided through initial setup on first launch.

**Acceptance Criteria:**
- [ ] 检测首次启动，显示欢迎窗口
- [ ] 引导用户配置 MTranServer 地址
- [ ] 请求屏幕录制权限（macOS 隐私权限）
- [ ] 请求辅助功能权限（用于全局快捷键）
- [ ] 提供测试翻译按钮验证配置

## Functional Requirements

- FR-1: 应用以菜单栏图标形式常驻，不占用 Dock
- FR-2: 全局快捷键触发后，用户可通过拖拽选择屏幕区域
- FR-3: 选中区域自动进行 OCR 文字识别
- FR-4: 识别出的文字发送至 MTranServer 进行翻译
- FR-5: 支持两种译文展示模式：
  - FR-5.1: 原位替换 - 译文覆盖在原文位置
  - FR-5.2: 原文下方 - 译文显示在选区下方的浮窗中
- FR-6: 覆盖层支持点击外部或按 Esc 关闭
- FR-7: 快捷键可在设置中自定义，默认 Cmd+Shift+T
- FR-8: 源语言支持自动检测或手动指定
- FR-9: 目标语言默认跟随系统，可手动覆盖
- FR-10: 翻译历史自动保存，支持查看、搜索、删除
- FR-11: 应用启动时检查并请求必要的系统权限
- FR-12: 所有网络请求（MTranServer）使用本地地址，不泄露数据

## Non-Goals

- 不支持 Windows/Linux 平台
- 不支持云端 OCR 服务（仅本地 PaddleOCR）
- 不支持批量图片翻译
- 不支持 PDF 文档翻译
- 不支持翻译结果的持久化同步（如 iCloud）
- 不支持离线翻译（仍需本地运行 MTranServer）
- 不支持手写文字识别
- 不支持竖排文字的原位替换展示

## Technical Considerations

- **OCR 引擎**: PaddleOCR C++ 库通过 Swift Package Manager 或桥接头集成，或作为外部进程调用
- **截图实现**: 使用 `CGDisplayStream` 或 `SCScreenshotManager` (macOS 12.3+) 获取屏幕内容
- **覆盖层窗口**: 使用 `NSPanel` 配合 `NSWindow.Level` 设置为 `.screenSaver` 或更高
- **权限处理**: 屏幕录制权限（kTCCServiceScreenCapture）和辅助功能权限（Accessibility）
- **性能**: OCR 过程可能耗时，需在后台线程执行，避免 UI 卡顿
- **内存管理**: 历史记录中的截图缩略图需要压缩存储，避免内存膨胀

## Success Metrics

- 截图到展示译文的端到端延迟 < 3 秒（M1 Mac 标准）
- OCR 识别准确率 > 90%（标准印刷体）
- 应用内存占用 < 200MB
- 快捷键响应延迟 < 100ms
- 崩溃率 < 0.1%

## Open Questions

- PaddleOCR 模型文件如何分发？（随应用打包还是首次下载）
- 是否需要支持多显示器环境？
- 原位替换模式下，如何处理文字长度差异过大的情况？
- 是否需要支持翻译结果的语音朗读？