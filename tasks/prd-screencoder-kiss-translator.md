# ScreenTranslate 架构重构需求文档
## 从 OCR 后翻译迁移至 ScreenCoder + KISS 风格翻译方案

---

## 1. 项目背景

### 1.1 当前架构

```
截图捕获 → Vision OCR → 纯文本 → Apple Translation → 翻译结果
```

**问题：** OCR 丢失布局信息，翻译服务单一，无法实现双语对照显示。

### 1.2 目标架构

```
截图捕获 → ScreenCoder (VLM) → 结构化文本+位置 → 多引擎翻译 → 双语对照渲染
```

**核心改进：**
- **ScreenCoder**：用 VLM 替代 OCR，提取文本同时保留精确位置信息
- **KISS 风格翻译**：借鉴 KISS Translator 的多引擎架构，自行实现 Provider 层（非接入 KISS 客户端）
- **双语对照**：在原始截图上叠加翻译结果，实现视觉对应

---

## 2. 功能需求

### FR-001: ScreenCoder 引擎 - 文本提取与定位

**描述：** 使用 VLM 分析截图，提取所有可见文本及其精确边界框。

**输入：** 截图图像 (CGImage)

**输出：**
```swift
struct TextSegment: Identifiable, Sendable {
    let id: UUID
    let text: String              // 原始文本
    let boundingBox: CGRect       // 在图像中的位置 (归一化坐标 0-1)
    let confidence: Float         // 识别置信度
}

struct ScreenAnalysisResult: Sendable {
    let segments: [TextSegment]
    let imageSize: CGSize
}
```

**VLM Prompt 示例：**
```
分析这张截图，提取所有可见文本。
对每段文本，返回 JSON 格式：
{
  "segments": [
    {"text": "文本内容", "bbox": [x1, y1, x2, y2]}
  ]
}
bbox 使用归一化坐标 (0-1)。
```

**验收标准：**
- [ ] 正确提取截图中所有可读文本
- [ ] 边界框定位精度 ≥ 90%
- [ ] 支持中英日韩混合文本

---

### FR-002: 双引擎翻译服务

**描述：** 支持 macOS 原生翻译 + MTransServer 本地翻译服务器。

**支持的引擎：**

| 引擎 | 描述 | 优先级 |
|------|------|--------|
| **macOS 原生** | Apple Translation 框架，离线可用，系统级集成 | P0 |
| **MTransServer** | 本地部署的翻译服务器，支持多种模型 | P0 |

**接口设计：**
```swift
protocol TranslationProvider: Sendable {
    var id: String { get }
    var name: String { get }
    var isAvailable: Bool { get async }
    
    func translate(
        texts: [String],
        from: LanguageCode?,
        to: LanguageCode
    ) async throws -> [String]
}

// 实现
// 1. AppleTranslationProvider - 使用 Translation 框架
// 2. MTransServerProvider - 调用本地 HTTP API
```

**MTransServer API 格式：**
```json
// 请求 POST /translate
{
  "text": "Hello World",
  "source_lang": "en",
  "target_lang": "zh"
}

// 响应
{
  "translation": "你好世界"
}
```

**配置项：**
```swift
struct TranslationConfig {
    var preferredProvider: ProviderType = .apple  // .apple | .mtransserver
    var mtransServerURL: URL = URL(string: "http://localhost:8989")!
    var fallbackEnabled: Bool = true  // 失败时切换到备选引擎
}
```

**验收标准：**
- [ ] macOS 原生翻译正常工作（复用现有 TranslationEngine）
- [ ] MTransServer 连接与翻译正常
- [ ] 支持引擎优先级选择
- [ ] 翻译失败时自动 fallback 到备选引擎

---

### FR-003: 双语对照渲染

**描述：** 将翻译结果以双语对照形式叠加在原始截图上。

**显示效果：**
```
┌─────────────────────────────┐
│  [原文区域]                  │
│  ┌───────────────────────┐  │
│  │ Hello World           │  │  ← 原始文本位置
│  │ ─────────────────────  │  │
│  │ 你好世界               │  │  ← 译文紧跟其下
│  └───────────────────────┘  │
│                             │
│  [另一原文区域]              │
│  ┌───────────────────────┐  │
│  │ Settings              │  │
│  │ ─────────────────────  │  │
│  │ 设置                   │  │
│  └───────────────────────┘  │
└─────────────────────────────┘
```

**实现方式：**
```swift
struct BilingualOverlay {
    let originalImage: CGImage
    let segments: [BilingualSegment]
}

struct BilingualSegment {
    let original: TextSegment      // 原文 + 位置
    let translated: String         // 译文
}

@MainActor
final class OverlayRenderer {
    func render(_ overlay: BilingualOverlay) -> NSImage {
        // 1. 绘制原始截图
        // 2. 在每个 segment 位置下方绘制译文
        // 3. 可选：半透明背景提高可读性
    }
}
```

**样式配置：**
```swift
struct OverlayStyle {
    var translationFont: NSFont = .systemFont(ofSize: 12)
    var translationColor: NSColor = .systemBlue
    var backgroundColor: NSColor = .white.withAlphaComponent(0.8)
    var padding: CGFloat = 4
}
```

**验收标准：**
- [ ] 译文位置与原文对应准确
- [ ] 支持自定义字体、颜色
- [ ] 长文本自动换行或截断
- [ ] 渲染结果可导出为图片

---

## 3. 技术架构

```
┌─────────────────────────────────────────────────────────┐
│                    Feature Layer                         │
│  ┌─────────────────────────────────────────────────┐    │
│  │           TranslationFlowController              │    │
│  │  1. 接收截图                                      │    │
│  │  2. 调用 ScreenCoder 提取文本                     │    │
│  │  3. 调用 TranslationService 翻译                  │    │
│  │  4. 调用 OverlayRenderer 渲染双语对照             │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
                           │
┌─────────────────────────────────────────────────────────┐
│                    Service Layer                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  │
│  │ScreenCoder  │  │Translation  │  │ Overlay         │  │
│  │Engine       │  │Service      │  │ Renderer        │  │
│  │(VLM调用)    │  │(多Provider) │  │ (双语渲染)      │  │
│  └─────────────┘  └──────┬──────┘  └─────────────────┘  │
│                          │                               │
│         ┌────────────────┼────────────────┐             │
│         ▼                ▼                ▼             │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐        │
│  │GoogleProvider│ │OpenAIProvider│ │OllamaProvider│     │
│  └────────────┘  └────────────┘  └────────────┘        │
└─────────────────────────────────────────────────────────┘
                           │
┌─────────────────────────────────────────────────────────┐
│                    Model Layer                           │
│  TextSegment, BilingualSegment, OverlayStyle, etc.      │
└─────────────────────────────────────────────────────────┘
```

---

## 4. 数据流

```
用户截图 (CGImage)
    │
    ▼
ScreenCoderEngine.analyze(image)
    │
    ▼
ScreenAnalysisResult { segments: [TextSegment] }
    │
    ▼
TranslationService.translate(segments, to: targetLang)
    │  ├─ 选择 Provider (Google/OpenAI/Ollama)
    │  ├─ 批量请求：["Hello", "Settings", ...] → ["你好", "设置", ...]
    │  └─ 组装结果
    ▼
[BilingualSegment] (原文+译文+位置)
    │
    ▼
OverlayRenderer.render(image, segments)
    │
    ▼
NSImage (双语对照截图)
```

---

## 5. 文件结构

```
ScreenTranslate/
├── Services/
│   ├── ScreenCoderEngine.swift         # VLM 文本提取
│   ├── TranslationService.swift        # 翻译编排层
│   ├── Providers/
│   │   ├── TranslationProvider.swift   # Provider 协议
│   │   ├── AppleTranslationProvider.swift  # macOS 原生翻译
│   │   └── MTransServerProvider.swift  # MTransServer 本地服务
│   └── OverlayRenderer.swift           # 双语渲染
├── Models/
│   ├── TextSegment.swift
│   ├── BilingualSegment.swift
│   └── OverlayStyle.swift
└── Features/
    └── Translation/
        └── TranslationFlowController.swift
```

---

## 6. 验收标准

### 功能验收
- [ ] ScreenCoder 能正确提取截图文本及位置
- [ ] 至少 2 个翻译引擎可正常工作
- [ ] 双语对照渲染效果符合设计
- [ ] 翻译失败时显示友好错误提示

### 性能验收
- [ ] 截图分析 < 3s
- [ ] 翻译延迟 < 2s（网络正常时）
- [ ] 渲染延迟 < 500ms

---

## 7. 参考资料

- [ScreenCoder GitHub](https://github.com/leigest519/ScreenCoder) - VLM UI 理解框架
- [KISS Translator Custom API](https://github.com/fishjar/kiss-translator/blob/main/custom-api_v2.md) - 多引擎翻译 API 设计参考

---

*v1.1 - 2026-02-06 - 精简版，聚焦双语对照核心功能*
