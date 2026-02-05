# PRD: 截图翻译流程优化与显示重构

## Overview

重构截图翻译功能的用户流程和显示方式。当前流程要求用户先等待 OCR 完成才能点击翻译按钮，改为点击即触发（自动完成 OCR + 翻译）。同时将译文显示从底部面板改为直接渲染在图片上，支持两种模式：覆盖原文（使用内容感知填充）或原文下方显示。此外修复截图编辑框尺寸与原始框选不一致的问题。

## Goals

- 简化用户操作流程：一键完成 OCR + 翻译
- 译文直接显示在图片上，视觉更直观
- 支持"覆盖原文"和"原文下方"两种显示模式
- 可保存/复制带译文的图片
- 编辑框尺寸与原始框选完全一致

## Quality Gates

These commands must pass for every user story:
- `swift build` - 编译通过
- Xcode 项目编译无错误

## User Stories

### US-001: 翻译按钮始终可点击
As a user, I want to click the translate button at any time so that I don't have to wait for OCR to complete first.

**Acceptance Criteria:**
- [ ] 翻译按钮在截图完成后立即可用（不再等待 OCR）
- [ ] `TranslateButtonView` 移除对 `ocrCompleted` 状态的依赖
- [ ] 按钮样式始终为可点击状态

### US-002: 点击翻译自动触发 OCR
As a user, I want clicking translate to automatically perform OCR first (if not done) so that the workflow is seamless.

**Acceptance Criteria:**
- [ ] 点击翻译时检查 OCR 是否已完成
- [ ] 若未完成，先执行 OCR，完成后自动继续翻译
- [ ] 若已完成，直接进行翻译
- [ ] 显示适当的加载状态（如"正在识别并翻译..."）
- [ ] OCR 或翻译失败时显示错误提示

### US-003: 读取翻译显示位置设置
As a user, I want the app to respect my display preference setting so that translations appear where I configured.

**Acceptance Criteria:**
- [ ] 找到并读取现有的翻译显示位置设置项
- [ ] 若设置项不存在，新增设置项（覆盖原文 / 原文下方）
- [ ] 翻译完成后根据设置决定显示方式
- [ ] 设置变更后立即生效

### US-004: 覆盖原文模式 - 内容感知填充
As a user, I want the original text area to be intelligently filled before showing translation so that the result looks clean.

**Acceptance Criteria:**
- [ ] 使用 OCR 返回的文字块坐标定位原文区域
- [ ] 尝试使用 macOS 内容感知填充 API（如 Core Image 的 inpainting）
- [ ] 若无合适 API，fallback 到模糊滤镜或背景色填充
- [ ] 填充后在该区域渲染译文

### US-005: 覆盖原文模式 - 译文渲染
As a user, I want translations to be rendered in place of original text so that I can see the translated content naturally.

**Acceptance Criteria:**
- [ ] 在填充后的区域绘制译文
- [ ] 译文字体大小根据区域高度自动调整
- [ ] 若译文较长，允许向右/下延伸超出原区域
- [ ] 译文颜色与背景形成足够对比

### US-006: 原文下方模式 - 译文渲染
As a user, I want translations to appear below each text block so that I can compare original and translated text.

**Acceptance Criteria:**
- [ ] 在每个 OCR 识别的文字块下方显示对应译文
- [ ] 译文与原文对齐（左对齐或居中，视原文情况）
- [ ] 若译文较长，允许向右/下延伸
- [ ] 译文使用区分性样式（如不同颜色或半透明背景）

### US-007: Preview 窗口图片渲染
As a user, I want to see the translated result directly on the image in the Preview window so that I get immediate visual feedback.

**Acceptance Criteria:**
- [ ] 在 `ScreenshotPreviewView` 中的图片上渲染译文
- [ ] 使用 overlay 或自定义绘制层实现
- [ ] 渲染层不影响原始截图数据
- [ ] 支持实时切换显示模式

### US-008: 保留底部面板作为备用
As a user, I want the bottom results panel to remain available so that I can still see plain text results if needed.

**Acceptance Criteria:**
- [ ] 保留 `resultsPanel` 组件和功能
- [ ] 面板可折叠或默认收起
- [ ] 面板仍显示原文和译文的纯文本版本
- [ ] 面板文本可复制

### US-009: 保存带译文的图片
As a user, I want to save the image with translations so that I can keep a permanent copy.

**Acceptance Criteria:**
- [ ] 添加"保存图片"按钮
- [ ] 将渲染后的图片（含译文）保存为 PNG/JPEG
- [ ] 提供文件保存对话框选择位置
- [ ] 保存成功后显示确认提示

### US-010: 复制带译文的图片到剪贴板
As a user, I want to copy the translated image to clipboard so that I can quickly paste it elsewhere.

**Acceptance Criteria:**
- [ ] 添加"复制图片"按钮
- [ ] 将渲染后的图片（含译文）复制到系统剪贴板
- [ ] 复制成功后显示确认提示（如短暂的 toast）
- [ ] 支持直接粘贴到其他应用

### US-011: 修复编辑框尺寸与原框选一致
As a user, I want the screenshot editor to show the exact size I selected so that what I see matches what I captured.

**Acceptance Criteria:**
- [ ] `ScreenshotPreviewView` 中图片显示为原始尺寸（1:1）
- [ ] 移除任何缩放逻辑或固定尺寸约束
- [ ] 若图片超出窗口，使用 ScrollView 允许滚动查看
- [ ] 窗口大小可调整，图片始终保持原始比例

## Functional Requirements

- FR-1: 翻译按钮在 `ScreenshotPreviewView` 加载后立即可用
- FR-2: 点击翻译触发 `performOCRIfNeeded() -> performTranslation()` 链式调用
- FR-3: 系统必须读取用户设置中的 `translationDisplayMode` 配置项
- FR-4: 覆盖模式必须使用 OCR 返回的 `boundingBox` 坐标定位文字区域
- FR-5: 图片渲染层必须独立于原始图片数据，支持导出
- FR-6: 编辑窗口必须使用截图的实际像素尺寸

## Non-Goals

- 不实现多语言选择 UI（使用现有设置）
- 不实现手动编辑 OCR 结果功能
- 不实现译文字体/颜色自定义
- 不实现实时翻译（逐字显示）
- 不重构 OCR 引擎本身

## Technical Considerations

- **OCR 坐标系统**：VNRecognizedTextObservation 的 boundingBox 使用归一化坐标 (0-1)，需转换为图片像素坐标
- **内容感知填充**：macOS 可能需要使用 Core ML 模型或 Vision 框架，若无现成 API，fallback 到 CIFilter 模糊
- **图片渲染**：考虑使用 `NSImage` + `NSGraphicsContext` 或 SwiftUI Canvas 进行绘制
- **剪贴板**：使用 `NSPasteboard` 写入图片数据

## Success Metrics

- 翻译按钮点击后 3 秒内完成 OCR + 翻译（常规尺寸截图）
- 译文正确显示在图片对应位置
- 保存/复制的图片包含完整译文渲染
- 编辑框尺寸与框选尺寸像素级一致

## Open Questions

- macOS 是否有开箱即用的 inpainting API？若无，模糊滤镜是否可接受作为 v1 方案？
- 设置项 `translationDisplayMode` 的确切位置和键名需确认
- 是否需要支持撤销译文渲染（恢复原图）？