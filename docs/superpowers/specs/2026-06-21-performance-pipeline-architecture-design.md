# TransFrame 性能 Pipeline 架构优化设计

## 概述

本文档定义 TransFrame 的性能架构优化方案。用户选择方案 3：以性能为目标重排核心 pipeline，而不是只做局部热点修补。目标是把截图、分析、翻译、渲染、历史写入和验证门禁变成可观测、可取消、可缓存、可测试的系统。

当前基线信息来自 2026-06-21 的代码梳理和一次命令行测试：

- Swift 源码约 3.65 万行，最大文件集中在 `SettingsViewModel`、`AppSettings`、`PaddleOCREngine`、`SelectionOverlayWindow`、VLM provider 和 `TranslationService`。
- `xcodebuild test -project TransFrame.xcodeproj -scheme TransFrame -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY=""` 已通过。
- 构建存在至少 2 个未使用变量 warning：`TextInsertService.swift` 的 `charString`、`SettingsViewModel.swift` 的 `oldValue`。
- Xcode Run Script build phase 每次都会运行，因为没有 output dependencies。
- `run_tests.sh` 和 `TransFrameTests/README.md` 存在旧 `ScreenCapture` 描述或过期测试说明。

## 目标

优化目标分为体验目标和工程目标。

体验目标：

- 热键触发到截图/预览出现的体感延迟可测、可回归。
- 选区截图到翻译结果窗口出现的链路可分阶段定位瓶颈。
- 选中文本翻译、翻译并插入的响应时间可测、可取消、错误可恢复。
- 大图、Retina、多屏、长文本、多引擎 fallback 或 parallel 场景下避免主线程长时间阻塞。

工程目标：

- 每个关键阶段都有统一 signpost、结构化指标和测试入口。
- 性能门禁覆盖 P95 延迟、主线程卡顿、内存峰值、构建 warning。
- 重活从 `@MainActor` 控制器和 ViewModel 中移出，UI 只触发流程并订阅状态。
- 迁移过程保持现有功能、快捷键、设置、历史、VLM/OCR/翻译行为兼容。

## 非目标

本轮不重做 UI 视觉设计，不替换 ScreenCaptureKit、Vision、Apple Translation、Sparkle 或 PermissionFlow，不改变默认快捷键和用户配置格式。除非性能迁移必需，不做无关文件重命名或大范围样式整理。

## 架构决策

| 决策点 | 选择 | 理由 |
|--------|------|------|
| 优化路线 | Architecture-first | 跨截图、OCR、VLM、翻译、渲染和存储的瓶颈需要统一边界 |
| 迁移策略 | 分阶段 strangler facade | 保持现有入口可用，逐步让控制器变薄 |
| 并发模型 | actor + Sendable value pipeline state | 现有项目已经使用 Swift actor 和严格并发 |
| 指标采集 | OSLog signpost + lightweight benchmark + XCTest 性能断言 | 兼顾 Instruments 和 CI 可运行检查 |
| UI 线程策略 | MainActor 只做 UI 状态和 AppKit 调用 | 防止 Vision、PaddleOCR、渲染、历史缩略图拖住主线程 |
| 缓存策略 | 显式短生命周期 cache | 避免重复 `SCShareableContent.current`、重复 provider 初始化和重复渲染 |

## 组件边界

### PerformanceKit

新增轻量性能基础设施，建议放在 `TransFrame/Services/Performance/`。

核心类型：

- `PerformanceMetric`: 一条阶段指标，包含 stage、operationID、duration、memoryDelta、threadInfo、success、errorCategory。
- `PerformanceRecorder`: actor，负责记录指标、写 signpost、汇总本次 session 的 P50/P95。
- `PerformanceBudget`: 配置 P95、主线程阻塞、内存峰值、warning policy。
- `BenchmarkScenario`: 描述可运行的轻量 benchmark 场景。

`PerformanceRecorder` 不直接依赖 UI，不持有图像大对象。它只接收数字和阶段名称，避免指标系统本身制造内存压力。

### CapturePipeline

负责热键、全屏截图、选区截图、窗口检测和 display 缓存。现有 `CaptureManager`、`ScreenDetector`、`WindowDetector` 保留，但新增 facade 把重复逻辑收口。

职责：

- 统一 `CaptureRequest`，支持 fullScreen、selection、window 和 translationSelection。
- 避免每次截图前无条件 `invalidateCache()` 和重复 `SCShareableContent.current`。
- 明确权限检查策略：快速路径用 cached permission，失败或设置界面刷新时做强校验。
- 为每次 capture 记录 permission、display lookup、captureImage、preview handoff 阶段指标。

输出：

- `CapturePipelineResult`，包含 `Screenshot`、display metadata、scale factor、capture metrics。

### AnalysisPipeline

负责 Vision OCR、PaddleOCR、本地/云 VLM、prompt leakage recovery 和文本过滤。

职责：

- 统一 `AnalysisRequest`，输入 `CGImage`、engine strategy、language hints、quality profile。
- 让 Vision OCR、PaddleOCR、VLM 都输出 `ScreenAnalysisResult`。
- 支持 fast/accurate profile：日常路径默认 fast-first，重负载或用户指定时走 accurate。
- 对 PaddleOCR 本地进程执行改为异步读 pipe 和可取消 task，避免 `waitUntilExit()` 阻塞 actor 执行器。
- 对 VLM provider cache 做配置 hash 管理，减少重复创建 provider。

输出：

- `AnalysisPipelineResult`，包含 segments、engineUsed、fallbackUsed、dedupeStats、analysis metrics。

### TranslationRenderPipeline

负责翻译、多引擎策略、overlay/bilingual 渲染和历史异步写入。

职责：

- 统一 `TranslationRenderRequest`，输入文本 segments、目标语言、scene、engine mode、original image。
- 复用 `TranslationService` 的 bundle API，但把语言检测、自翻译 bypass、fallback 和 parallel 的指标分阶段记录。
- `OverlayRenderer` 调用放到非 UI 路径，UI 只拿最终 `CGImage` 或错误状态。
- `HistoryStore` 的缩略图生成和 JSON encode 从主线程迁出，主线程只发布 entries。

输出：

- `TranslationRenderResult`，包含 bilingual segments、rendered image、engine bundle、history write status、metrics。

### UI Facade

现有入口保留，但逐步变薄：

- `CaptureCoordinator` 调用 `CapturePipeline`。
- `TranslationFlowController` 调用 `AnalysisPipeline` 和 `TranslationRenderPipeline`。
- `TextTranslationFlow` 调用 translation-only pipeline。
- `PreviewViewModel` 保留交互状态，但导出、OCR、翻译和历史写入通过 pipeline service。

UI facade 的规则是：可以读写 SwiftUI/AppKit 状态，可以打开窗口和 alert，不直接做图像编码、OCR、网络翻译、PaddleOCR 进程等待或历史缩略图生成。

## 数据流

截图翻译链路：

```text
Hotkey/Menu
  -> CaptureCoordinator
  -> CapturePipeline
  -> Preview/Bilingual loading window
  -> AnalysisPipeline
  -> TranslationRenderPipeline
  -> BilingualResultWindow + History async append
```

文本翻译链路：

```text
Hotkey/Menu
  -> TextTranslationCoordinator
  -> TextSelectionService
  -> TextTranslationFlow facade
  -> TranslationRenderPipeline translation-only mode
  -> Popup or insert flow
```

预览标注链路：

```text
PreviewWindow
  -> PreviewViewModel interaction state
  -> AnnotationCanvas cached draw path
  -> Export/Copy pipeline for compositing and encoding
```

每条链路共享 `operationID`，这样日志、signpost、benchmark 输出可以把 capture、analysis、translation、render、history 串起来。

## 错误处理

错误保留用户可理解的 `LocalizedError`，同时新增内部错误分类：

- `permission`: 屏幕录制、辅助功能、剪贴板访问。
- `capture`: display disconnected、ScreenCaptureKit failure、empty image。
- `analysis`: OCR/VLM unavailable、invalid output、prompt leakage、no text。
- `translation`: provider unavailable、timeout、fallback exhausted、language model missing。
- `render`: CGContext creation、font/layout failure、image memory pressure。
- `history`: thumbnail encode、UserDefaults decode/encode、storage size limit。
- `cancelled`: 用户取消、重复触发导致取消、窗口关闭。

pipeline 返回的错误必须包含 user-facing error 和 internal category。UI facade 根据 user-facing error 展示 alert 或 popup；PerformanceRecorder 只记录 category 和阶段，不记录敏感文本、API key、完整截图内容。

## 性能门禁

第一版门禁不承诺绝对数字一次到位，而是先建立可重复基线，然后逐步收紧。建议初始预算：

| 场景 | 初始预算 |
|------|----------|
| 全屏 capture 阶段 P95 | 目标低于 100ms，超过记录为 warning |
| 选区 capture 阶段 P95 | 目标低于 120ms，超过记录为 warning |
| Vision OCR lightweight fixture P95 | 目标低于 500ms，超过记录为 warning |
| overlay render lightweight fixture P95 | 目标低于 200ms，超过记录为 warning |
| 文本翻译 mock pipeline P95 | 目标低于 150ms，超过测试失败 |
| 主线程连续阻塞 | 超过 100ms 记录，超过 250ms 失败 |
| 构建 warning | 新增 warning 失败，既有 warning 在 cleanup phase 清零 |

网络型 VLM 和真实 Apple Translation 受外部状态影响，先做 metrics 采集和人工 benchmark，不作为 CI 硬失败项。mock provider 和 fixture-based render/OCR 可进入自动化测试。

## 测试策略

单元测试：

- `PerformanceRecorderTests`: 记录、聚合、P95、预算判断。
- `PipelineStateTests`: cancellation、stage transition、error category mapping。
- `TranslationRenderPipelineTests`: mock provider、fallback、parallel、history write status。
- `AnalysisPipelineTests`: OCR/VLM mock、prompt leakage recovery、empty result。

性能测试：

- 使用小型 fixture CGImage 构造 OCR/render benchmark。
- 使用 mock provider 固定延迟验证 P95 和 fallback 行为。
- 对 `OverlayRenderer`、history thumbnail、translation filtering 加 `measure` 或自定义 lightweight runner。

命令行验证：

- 更新 `run_tests.sh` 为 TransFrame 当前项目名和 scheme。
- `xcodebuild test -project TransFrame.xcodeproj -scheme TransFrame -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY=""` 作为基础回归。
- 新增性能 smoke 命令，默认只跑轻量 fixture，不触发真实网络 API 和系统权限弹窗。

## 迁移计划

### Phase 0: 基线与清理

- 修复 `run_tests.sh` 和测试 README 的旧项目名。
- 清除当前构建 warning。
- 给 Run Script build phase 增加 outputs 或改为按需执行。
- 新增性能基础设施和 lightweight benchmark 测试，不改变运行时行为。

### Phase 1: CapturePipeline

- 引入 `CapturePipeline` facade。
- 收口 display/permission/shareable content 缓存策略。
- 保留 `CaptureManager` 作为底层 adapter。
- 增加 capture benchmark 和 signpost。

### Phase 2: AnalysisPipeline

- 引入 `AnalysisPipeline` 和 OCR/VLM adapter。
- 把 prompt leakage fallback、文本过滤和 dedupe 指标化。
- 重做 PaddleOCR 进程执行为可取消异步流程。
- 增加 Vision fixture 和 VLM mock 测试。

### Phase 3: TranslationRenderPipeline

- 引入 translation/render/history pipeline。
- 将 overlay render、history thumbnail、history encode 移出主线程。
- 给 translation bundle、fallback、parallel、render、history append 加指标。
- 增加 mock provider 和 render fixture 性能测试。

### Phase 4: UI facade 瘦身

- `TranslationFlowController`、`TextTranslationFlow`、`PreviewViewModel` 改为调用 pipeline。
- 控制器保留窗口、alert、状态发布。
- 清理重复状态、重复 Task、重复 MainActor hop。

### Phase 5: 门禁收紧

- 将轻量 benchmark 接入脚本。
- 将 warning 清零作为常规门禁。
- 根据本机基线和真实场景结果收紧 P95、主线程阻塞和内存峰值预算。

## 风险与缓解

| 风险 | 缓解 |
|------|------|
| 架构改动范围大 | facade 分阶段迁移，每阶段保持 tests green |
| 性能测试不稳定 | 网络和系统权限不进 CI 硬门禁，fixture/mock 才硬门禁 |
| Swift strict concurrency 暴露新问题 | 先用 Sendable value types 和 actor boundary，避免共享 mutable state |
| UI 行为回归 | 入口函数和窗口控制器先保持方法签名，逐步替换内部实现 |
| 指标记录影响性能 | recorder 只记录轻量数据，截图和文本内容不进入指标 |
| 用户隐私泄露 | 日志不记录截图、原文、译文、API key，只记录长度、阶段和错误分类 |

## 验收标准

- 设计和实施计划已落档。
- `xcodebuild test` 通过。
- 现有构建 warning 清零，Run Script warning 处理完成。
- 至少有 capture、analysis、translation/render 三类 pipeline stage 指标。
- 轻量 benchmark 能在命令行运行，并输出每个场景的 P50/P95。
- 截图翻译、文本选择翻译、翻译并插入、预览导出四条用户路径保持可用。
- 重活不再直接驻留在 `@MainActor` 控制器中，主线程只做 UI 状态和 AppKit 调用。
- 性能优化的每个阶段都有测试或 benchmark 证据。

