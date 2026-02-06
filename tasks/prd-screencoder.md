# PRD: ScreenCoder 双语翻译模式

## Overview

将 ScreenTranslate 的翻译功能从现有截图-标注流程中独立出来，创建全新的「双语翻译模式」。用户通过独立快捷键触发，直接框选屏幕区域，使用 VLM (Vision Language Model) 提取文本及位置信息，调用多引擎翻译服务，最终在专用窗口中呈现双语对照结果。

核心改进：
- **ScreenCoder 引擎**：用 VLM 替代 OCR，提取文本同时保留精确位置
- **KISS 风格翻译**：借鉴 KISS Translator 的多引擎架构，自行实现 Provider 层
- **双语对照窗口**：独立窗口展示原文+译文的视觉对应

## Goals

- 实现独立于截图-标注的翻译入口（快捷键 + 菜单）
- 使用 VLM 提取屏幕文本及其精确边界框位置
- 支持多 VLM 提供商：OpenAI GPT-4V、Claude Vision、Ollama 本地模型
- 支持双翻译引擎：macOS 原生翻译 + MTransServer
- 在专用窗口中渲染双语对照结果
- 翻译引擎失败时自动 fallback 到备选引擎

## Quality Gates

These commands must pass for every user story:
- `xcodebuild -scheme ScreenTranslate build` - 编译通过
- SwiftLint 检查通过（如项目已配置）

UI 功能手动验证即可。

## User Stories

### US-001: 创建独立翻译入口
As a user, I want a dedicated shortcut and menu entry for translation mode so that I can translate screen content without going through the screenshot annotation flow.

**Acceptance Criteria:**
- [ ] 新增全局快捷键（如 ⌘⇧T）触发翻译模式
- [ ] 菜单栏添加「翻译模式」入口
- [ ] 快捷键可在设置中自定义
- [ ] 触发后进入区域框选状态（复用现有 `SelectionOverlayView` 或新建）

### US-002: 实现区域框选捕获
As a user, I want to select a screen region for translation so that I can choose exactly what content to translate.

**Acceptance Criteria:**
- [ ] 触发翻译模式后显示全屏半透明遮罩
- [ ] 用户可拖拽框选任意矩形区域
- [ ] 框选完成后捕获该区域为 CGImage
- [ ] 支持 ESC 取消框选
- [ ] 框选区域最小尺寸限制（避免误触）

### US-003: 定义 TextSegment 和 ScreenAnalysisResult 模型
As a developer, I want well-defined data models for text extraction results so that VLM output can be structured and passed through the pipeline.

**Acceptance Criteria:**
- [ ] 创建 `TextSegment` 结构体：id, text, boundingBox (CGRect, 归一化坐标 0-1), confidence
- [ ] 创建 `ScreenAnalysisResult` 结构体：segments, imageSize
- [ ] 所有模型遵循 `Sendable` 协议
- [ ] 添加必要的 Codable 支持（用于 JSON 解析）

### US-004: 实现 VLM Provider 协议
As a developer, I want a unified protocol for VLM providers so that different vision models can be swapped without changing business logic.

**Acceptance Criteria:**
- [ ] 创建 `VLMProvider` 协议，定义 `analyze(image:) async throws -> ScreenAnalysisResult`
- [ ] 协议包含 `id`, `name`, `isAvailable` 属性
- [ ] 支持配置项：apiKey, baseURL, modelName
- [ ] 定义标准化的 VLM Prompt 模板（提取文本+bbox 的 JSON 格式）

### US-005: 实现 OpenAI Vision Provider
As a user, I want to use OpenAI GPT-4V/GPT-4o for text extraction so that I can leverage OpenAI's vision capabilities.

**Acceptance Criteria:**
- [ ] 实现 `OpenAIVLMProvider` 遵循 `VLMProvider` 协议
- [ ] 支持配置：API Key, Base URL (可自定义), Model Name
- [ ] 正确处理 base64 图像编码
- [ ] 解析 JSON 响应为 `ScreenAnalysisResult`
- [ ] 处理 API 错误（rate limit, invalid key, timeout）

### US-006: 实现 Claude Vision Provider
As a user, I want to use Claude Vision for text extraction so that I have an alternative to OpenAI.

**Acceptance Criteria:**
- [ ] 实现 `ClaudeVLMProvider` 遵循 `VLMProvider` 协议
- [ ] 支持配置：API Key, Base URL, Model Name
- [ ] 使用 Anthropic Messages API 格式
- [ ] 正确处理图像 media type 和 base64 编码
- [ ] 解析响应为 `ScreenAnalysisResult`

### US-007: 实现 Ollama Vision Provider
As a user, I want to use local Ollama models for text extraction so that I can work offline without API costs.

**Acceptance Criteria:**
- [ ] 实现 `OllamaVLMProvider` 遵循 `VLMProvider` 协议
- [ ] 支持配置：Base URL (默认 localhost:11434), Model Name (如 llava, qwen-vl)
- [ ] 使用 Ollama API 格式发送图像
- [ ] 实现连接检测（`isAvailable`）
- [ ] 解析响应为 `ScreenAnalysisResult`

### US-008: 创建 ScreenCoder 引擎
As a developer, I want a unified ScreenCoder engine that manages VLM providers so that the translation flow has a single entry point for text extraction.

**Acceptance Criteria:**
- [ ] 创建 `ScreenCoderEngine` actor/class
- [ ] 管理多个 VLM Provider 实例
- [ ] 根据用户配置选择当前 Provider
- [ ] 提供 `analyze(image:) async throws -> ScreenAnalysisResult` 方法
- [ ] 封装 Provider 切换逻辑

### US-009: 扩展 MTransServerProvider 翻译能力
As a user, I want MTransServer to work as a translation provider so that I can use my local translation server.

**Acceptance Criteria:**
- [ ] 确认现有 `MTranServerEngine` 可复用或需要适配
- [ ] 实现 `TranslationProvider` 协议（如需新建）
- [ ] 支持批量翻译接口 `translate(texts:from:to:)`
- [ ] 正确处理 MTransServer API（POST /translate）
- [ ] 实现连接状态检测

### US-010: 创建 TranslationService 编排层
As a developer, I want a TranslationService that orchestrates multiple translation providers so that fallback logic is centralized.

**Acceptance Criteria:**
- [ ] 创建 `TranslationService` actor/class
- [ ] 管理 AppleTranslationProvider 和 MTransServerProvider
- [ ] 根据用户配置选择首选 Provider
- [ ] 实现 fallback 逻辑：首选失败时切换备选
- [ ] 提供 `translate(segments:to:) async throws -> [BilingualSegment]`

### US-011: 定义 BilingualSegment 和 OverlayStyle 模型
As a developer, I want models for bilingual content and rendering style so that the overlay renderer has structured input.

**Acceptance Criteria:**
- [ ] 创建 `BilingualSegment` 结构体：original (TextSegment), translated (String)
- [ ] 创建 `OverlayStyle` 结构体：translationFont, translationColor, backgroundColor, padding
- [ ] 提供合理的默认样式值
- [ ] 样式支持用户配置

### US-012: 实现 OverlayRenderer 双语渲染
As a developer, I want an OverlayRenderer that draws bilingual content on the original image so that users see translations in context.

**Acceptance Criteria:**
- [ ] 创建 `OverlayRenderer` 类
- [ ] 输入：原始 CGImage + [BilingualSegment] + OverlayStyle
- [ ] 输出：NSImage（双语对照图）
- [ ] 在每个原文位置下方绘制译文
- [ ] 译文带半透明背景提高可读性
- [ ] 长文本自动换行处理

### US-013: 创建双语对照展示窗口
As a user, I want a dedicated window to display bilingual translation results so that I can review and interact with translations.

**Acceptance Criteria:**
- [ ] 创建 `BilingualResultWindow` (NSWindow/SwiftUI)
- [ ] 显示渲染后的双语对照图像
- [ ] 支持图像缩放和滚动
- [ ] 提供「复制图片」按钮
- [ ] 提供「保存图片」按钮
- [ ] 窗口可调整大小
- [ ] ESC 或关闭按钮关闭窗口

### US-014: 实现 TranslationFlowController 主流程
As a developer, I want a TranslationFlowController that orchestrates the entire translation flow so that all components work together.

**Acceptance Criteria:**
- [ ] 创建 `TranslationFlowController`
- [ ] 流程：接收 CGImage → ScreenCoder 提取 → TranslationService 翻译 → OverlayRenderer 渲染 → 显示窗口
- [ ] 处理各阶段错误并显示用户友好提示
- [ ] 显示处理进度指示器
- [ ] 支持取消正在进行的翻译

### US-015: 添加 VLM 和翻译配置 UI
As a user, I want settings UI to configure VLM providers and translation preferences so that I can customize the translation behavior.

**Acceptance Criteria:**
- [ ] 在设置中添加「翻译模式」配置区
- [ ] VLM 配置：选择 Provider (OpenAI/Claude/Ollama)
- [ ] VLM 配置：API Key, Base URL, Model Name 输入框
- [ ] 翻译配置：首选引擎 (Apple/MTransServer)
- [ ] 翻译配置：MTransServer URL
- [ ] 翻译配置：Fallback 开关
- [ ] 配置持久化到 SettingsManager

### US-016: 集成快捷键到 AppDelegate
As a user, I want the translation shortcut to work globally so that I can trigger translation from any app.

**Acceptance Criteria:**
- [ ] 在 AppDelegate 或 HotKeyManager 注册翻译模式快捷键
- [ ] 快捷键触发 TranslationFlowController 启动框选
- [ ] 与现有快捷键不冲突
- [ ] 快捷键禁用/启用状态正确响应

## Functional Requirements

- FR-1: 翻译模式必须通过独立快捷键触发，与截图-标注流程完全分离
- FR-2: 用户框选区域后，系统必须捕获该区域图像并传入 VLM
- FR-3: VLM 必须返回所有识别文本及其归一化边界框坐标
- FR-4: 翻译服务必须支持 Apple Translation 和 MTransServer 两种引擎
- FR-5: 翻译失败时必须自动尝试备选引擎（如 fallback 已启用）
- FR-6: 双语对照结果必须在独立窗口中显示，译文位置与原文对应
- FR-7: 用户必须能够从结果窗口复制或保存双语对照图片
- FR-8: 所有 VLM Provider 必须支持完整配置（API Key + Base URL + Model Name）
- FR-9: 处理过程中必须显示进度指示，支持用户取消

## Non-Goals

- 不替换现有 OCR 功能（OCR 保留用于文字识别复制）
- 不与截图-标注流程集成（完全独立）
- ScreenCoder 不 fallback 到 OCR（仅使用 VLM）
- 不实现系统主题自动检测
- 不支持自定义翻译 prompt
- 不支持翻译历史记录（本期）
- 不支持翻译结果编辑（本期）

## Technical Considerations

- 复用现有 `SelectionOverlayView` 进行区域框选，或创建轻量级版本
- VLM 返回的 bbox 使用归一化坐标 (0-1)，渲染时需转换为实际像素坐标
- 考虑 VLM 调用的超时处理（建议 30s）
- MTransServer API 需确认实际端点格式是否为 `POST /translate`
- 使用 `@MainActor` 确保 UI 更新在主线程
- 翻译请求考虑批量发送以减少 API 调用次数

## Success Metrics

- 文本提取准确率 ≥ 90%（可读文本被正确识别）
- 边界框定位精度 ≥ 85%（译文位置与原文基本对应）
- 端到端延迟 < 5s（网络正常情况下）
- 两个翻译引擎均可正常工作
- 用户可成功保存/复制双语对照图片

## Open Questions

- MTransServer 批量翻译 API 是否支持？还是需要逐条调用？
- 是否需要支持指定源语言？还是始终自动检测？
- 双语对照窗口是否需要支持「仅显示译文」模式？
- 是否需要在结果窗口提供「重新翻译」按钮？