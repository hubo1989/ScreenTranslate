# 多翻译引擎支持功能设计文档

**日期**: 2026-02-26
**版本**: 1.0
**状态**: 已批准

## 概述

为 ScreenTranslate 增加多翻译引擎支持，允许用户：
- 选择多种翻译模式（主备、并行、即时切换、场景绑定）
- 使用多个翻译引擎（云服务商、LLM、自定义接口）
- 为 AI 翻译引擎自定义提示词（分引擎、分场景）

## 需求总结

### 引擎选择模式
1. **主备模式** - 选择主引擎，失败自动切换备用引擎
2. **并行模式** - 同时调用多个引擎，展示所有结果
3. **即时切换** - 在结果窗口快速切换引擎对比
4. **场景绑定** - 不同场景使用不同默认引擎

### 支持的翻译引擎
- Apple Translation（现有）
- MTranServer（现有）
- LLM 翻译：OpenAI / Claude / Ollama
- 云服务商：Google Translate / DeepL / 百度翻译
- 自定义 OpenAI 兼容接口

### 提示词自定义
- 分引擎提示词
- 分场景提示词
- 支持模板变量：`{source_language}`, `{target_language}`, `{text}`

### 密钥管理
- 使用 macOS Keychain 安全存储 API 密钥

---

## 架构设计

### 1. 引擎类型层次

```swift
enum TranslationEngineType: String, CaseIterable, Sendable, Codable {
    // 现有
    case apple = "apple"
    case mtranServer = "mtran"

    // LLM 翻译
    case openai = "openai"
    case claude = "claude"
    case ollama = "ollama"

    // 云服务商
    case google = "google"
    case deepl = "deepl"
    case baidu = "baidu"

    // 自定义
    case custom = "custom"
}
```

### 2. 核心协议（保持现有）

```swift
protocol TranslationProvider: Sendable {
    var id: String { get }
    var name: String { get }
    var isAvailable: Bool { get async }

    func translate(text: String, from: String?, to: String) async throws -> TranslationResult
    func translate(texts: [String], from: String?, to: String) async throws -> [TranslationResult]
    func checkConnection() async -> Bool
}
```

### 3. 引擎注册表

```swift
actor TranslationEngineRegistry {
    static let shared = TranslationEngineRegistry()

    private var providers: [TranslationEngineType: any TranslationProvider] = [:]

    func register(_ provider: any TranslationProvider, for type: TranslationEngineType)
    func provider(for type: TranslationEngineType) -> (any TranslationProvider)?
    func availableEngines() -> [TranslationEngineType]
}
```

### 4. 选择模式枚举

```swift
enum EngineSelectionMode: String, Codable, CaseIterable {
    case primaryWithFallback  // 主备模式
    case parallel             // 并行模式
    case quickSwitch          // 即时切换
    case sceneBinding         // 场景绑定
}
```

---

## 配置模型

### 引擎配置

```swift
struct TranslationEngineConfig: Codable, Identifiable {
    let id: TranslationEngineType
    var isEnabled: Bool
    var credentials: EngineCredentials?
    var options: EngineOptions?
}

struct EngineCredentials: Codable {
    var keychainRef: String  // Keychain 条目的 service 标识
}

struct EngineOptions: Codable {
    var baseURL: String?
    var modelName: String?
    var timeout: TimeInterval?
}
```

### 提示词配置

```swift
struct TranslationPromptConfig: Codable {
    var enginePrompts: [TranslationEngineType: String]  // 分引擎
    var scenePrompts: [TranslationScene: String]        // 分场景

    static let defaultPrompt = """
        Translate the following text from {source_language} to {target_language}. \
        Only output the translation, no explanations.

        Text: {text}
        """
}

enum TranslationScene: String, Codable, CaseIterable {
    case screenshot          // 截图翻译
    case textSelection       // 文本选择翻译
    case translateAndInsert  // 翻译并插入
}
```

### 场景绑定配置

```swift
struct SceneEngineBinding: Codable {
    var scene: TranslationScene
    var primaryEngine: TranslationEngineType
    var fallbackEngine: TranslationEngineType?
    var fallbackEnabled: Bool
}
```

### AppSettings 扩展

```swift
extension AppSettings {
    var engineSelectionMode: EngineSelectionMode
    var engineConfigs: [TranslationEngineType: TranslationEngineConfig]
    var promptConfig: TranslationPromptConfig
    var sceneBindings: [TranslationScene: SceneEngineBinding]
    var parallelEngines: [TranslationEngineType]
}
```

---

## Keychain 密钥管理

### Keychain 服务

```swift
actor KeychainService {
    static let shared = KeychainService()

    private let service = "com.screentranslate.credentials"

    func saveCredentials(
        apiKey: String,
        for engine: TranslationEngineType,
        additionalData: [String: String]? = nil
    ) throws

    func getCredentials(for engine: TranslationEngineType) throws -> StoredCredentials?
    func deleteCredentials(for engine: TranslationEngineType) throws
    func hasCredentials(for engine: TranslationEngineType) -> Bool
}

struct StoredCredentials: Codable {
    let apiKey: String
    let appID: String?       // 百度翻译需要
    let additional: [String: String]?
}
```

### 引擎凭据需求

| 引擎 | 必需凭据 | 可选配置 |
|------|---------|---------|
| Apple | 无 | - |
| MTranServer | 无 | host, port |
| OpenAI | API Key | baseURL, model |
| Claude | API Key | baseURL, model |
| Ollama | 无 | baseURL, model |
| Compatible | API Key | baseURL, model |
| Google | API Key | - |
| DeepL | API Key | - |
| 百度 | API Key + App ID | - |

---

## 引擎实现

### LLM 翻译引擎

复用现有 `VLMProvider` 架构，仅替换提示词：

```swift
actor LLMTranslationProvider: TranslationProvider {
    let id: TranslationEngineType
    let vlmProvider: any VLMProvider
    let promptConfig: TranslationPromptConfig

    func translate(text: String, from: String?, to: String) async throws -> TranslationResult {
        let prompt = promptConfig.resolvedPrompt(
            for: id,
            scene: currentScene,
            sourceLanguage: from ?? "auto",
            targetLanguage: to,
            text: text
        )
        return try await vlmProvider.complete(prompt: prompt)
    }
}
```

### 云服务商引擎

```swift
// Google Translate
actor GoogleTranslationProvider: TranslationProvider {
    // POST https://translation.googleapis.com/language/translate/v2
}

// DeepL
actor DeepLTranslationProvider: TranslationProvider {
    // POST https://api-free.deepl.com/v2/translate (免费)
    // POST https://api.deepl.com/v2/translate (专业)
}

// 百度翻译（需要签名）
actor BaiduTranslationProvider: TranslationProvider {
    // 签名: md5(appid+q+salt+密钥)
    // GET https://fanyi-api.baidu.com/api/trans/vip/translate
}

// OpenAI 兼容接口
actor CompatibleTranslationProvider: TranslationProvider {
    // 复用 OpenAI Chat Completions API 格式
}
```

---

## TranslationService 重构

### 统一结果类型

```swift
struct TranslationResultBundle {
    let results: [EngineResult]
    let primaryEngine: TranslationEngineType

    var primaryResult: [BilingualSegment] {
        results.first { $0.engine == primaryEngine }?.segments ?? []
    }
}

struct EngineResult {
    let engine: TranslationEngineType
    let segments: [BilingualSegment]
    let latency: TimeInterval
    let error: Error?
}
```

### 服务重构

```swift
actor TranslationService {
    static let shared = TranslationService()

    private let registry: TranslationEngineRegistry
    private let settings: AppSettings

    func translate(
        segments: [String],
        to targetLanguage: String,
        from sourceLanguage: String?,
        scene: TranslationScene
    ) async throws -> TranslationResultBundle {
        let mode = settings.engineSelectionMode

        switch mode {
        case .primaryWithFallback:
            return try await translateWithFallback(...)
        case .parallel:
            return try await translateParallel(...)
        case .quickSwitch:
            return try await translateForQuickSwitch(...)
        case .sceneBinding:
            return try await translateByScene(...)
        }
    }
}
```

### 四种模式实现

```swift
extension TranslationService {
    // 1. 主备模式
    private func translateWithFallback(...) async throws -> TranslationResultBundle {
        let binding = getSceneBinding(for: scene)
        // 先尝试主引擎，失败则切换备用
    }

    // 2. 并行模式
    private func translateParallel(...) async throws -> TranslationResultBundle {
        let engines = settings.parallelEngines
        // 并发调用所有引擎，收集所有结果
    }

    // 3. 即时切换模式
    private func translateForQuickSwitch(...) async throws -> TranslationResultBundle {
        // 先返回主引擎结果，UI 可触发其他引擎的懒加载
    }

    // 4. 场景绑定模式
    private func translateByScene(...) async throws -> TranslationResultBundle {
        let binding = settings.sceneBindings[scene] ?? defaultBinding
        return try await translateWithFallback(..., binding: binding)
    }
}
```

---

## 设置界面

### 引擎设置 Tab

```
┌─────────────────────────────────────────────────────────────────┐
│ 翻译引擎设置                                                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│ ┌─ 引擎选择模式 ─────────────────────────────────────────────┐  │
│ │ ○ 主备模式（失败自动切换）                                   │  │
│ │ ○ 并行模式（同时调用多引擎）                                 │  │
│ │ ○ 即时切换（快速对比结果）                                   │  │
│ │ ○ 场景绑定（不同场景用不同引擎）                             │  │
│ └──────────────────────────────────────────────────────────────┘  │
│                                                                  │
│ ┌─ 可用引擎 ───────────────────────────────────────────────────┐  │
│ │ ☑ Apple Translation        [已启用 ✓]                        │  │
│ │ ☑ OpenAI GPT              [配置 API Key...]                  │  │
│ │ ☑ Claude                  [配置 API Key...]                  │  │
│ │ ☐ Google Translate        [配置...]                          │  │
│ │ ☐ DeepL                   [配置...]                          │  │
│ │ ☐ 百度翻译                [配置...]                          │  │
│ │ ☐ Ollama (本地)           [配置端点...]                       │  │
│ │ ☐ 自定义接口              [配置...]                          │  │
│ └──────────────────────────────────────────────────────────────┘  │
│                                                                  │
│ ┌─ [根据模式显示的动态配置区] ─────────────────────────────────┐  │
│ │ 并行模式: 勾选要并行调用的引擎                                │  │
│ │ 场景绑定: 为每个场景选择主/备引擎                             │  │
│ │ 主备模式: 选择主引擎和备引擎                                  │  │
│ └──────────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 提示词设置界面

```
┌─────────────────────────────────────────────────────────────────┐
│ 翻译提示词设置                                                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│ ┌─ 分引擎提示词 ───────────────────────────────────────────────┐  │
│ │ OpenAI:  [使用默认 ▼]  [编辑]                                │  │
│ │ Claude:  [使用默认 ▼]  [编辑]                                │  │
│ │ Ollama:  [使用默认 ▼]  [编辑]                                │  │
│ └──────────────────────────────────────────────────────────────┘  │
│                                                                  │
│ ┌─ 分场景提示词 ───────────────────────────────────────────────┐  │
│ │ 截图翻译:      [使用默认 ▼]  [编辑]                          │  │
│ │ 文本选择翻译:  [使用默认 ▼]  [编辑]                          │  │
│ │ 翻译并插入:    [使用默认 ▼]  [编辑]                          │  │
│ └──────────────────────────────────────────────────────────────┘  │
│                                                                  │
│ ┌─ 提示词编辑器 ───────────────────────────────────────────────┐  │
│ │ ┌──────────────────────────────────────────────────────────┐ │  │
│ │ │ Translate from {source_language} to {target_language}.   │ │  │
│ │ │ Only output the translation.                             │ │  │
│ │ │                                                          │ │  │
│ │ │ Text: {text}                                             │ │  │
│ │ └──────────────────────────────────────────────────────────┘ │  │
│ │ 可用变量: {source_language} {target_language} {text}         │  │
│ │ [恢复默认]  [测试]                                          │  │
│ └──────────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 文件结构

### 新增文件

```
ScreenTranslate/
├── Models/
│   ├── TranslationEngineType.swift      # 扩展引擎枚举
│   ├── TranslationEngineConfig.swift    # 新增：引擎配置模型
│   ├── TranslationPromptConfig.swift    # 新增：提示词配置
│   ├── TranslationScene.swift           # 新增：场景枚举
│   └── EngineSelectionMode.swift        # 新增：选择模式枚举
│
├── Services/
│   ├── Translation/
│   │   ├── TranslationService.swift     # 重构：支持多模式
│   │   ├── TranslationEngineRegistry.swift  # 新增：引擎注册表
│   │   └── Providers/
│   │       ├── GoogleTranslationProvider.swift
│   │       ├── DeepLTranslationProvider.swift
│   │       ├── BaiduTranslationProvider.swift
│   │       ├── LLMTranslationProvider.swift
│   │       └── CompatibleTranslationProvider.swift
│   │
│   └── Security/
│       └── KeychainService.swift        # 新增：密钥管理
│
├── Features/Settings/
│   ├── EngineSettingsTab.swift          # 重构：引擎选择
│   ├── PromptSettingsView.swift         # 新增：提示词设置
│   └── EngineConfigSheet.swift          # 新增：引擎配置弹窗
```

---

## 实现阶段

| 阶段 | 内容 | 预估工作量 |
|------|------|-----------|
| Phase 1 | 基础架构 - 枚举扩展、配置模型、Keychain 服务 | 小 |
| Phase 2 | 引擎注册表 + TranslationService 重构 | 中 |
| Phase 3 | LLM 翻译 Provider | 小 |
| Phase 4 | 云服务商 Provider（Google/DeepL/百度） | 中 |
| Phase 5 | OpenAI 兼容接口 Provider | 小 |
| Phase 6 | 设置界面重构 | 中 |
| Phase 7 | 四种选择模式 UI + 逻辑 | 中 |
| Phase 8 | 提示词编辑器 + 测试功能 | 中 |

---

## 风险与考量

1. **API 限流** - 云服务商 API 可能有调用频率限制，需要在 UI 中提供错误提示
2. **网络超时** - 并行模式下单个引擎超时不应影响其他引擎结果
3. **密钥安全** - Keychain 访问需要处理权限和错误情况
4. **向后兼容** - 现有用户的设置需要平滑迁移到新配置模型
5. **LLM 翻译成本** - 需要提示用户 LLM 翻译可能产生 API 费用

---

## 后续扩展

- 支持更多云服务商（有道翻译、腾讯翻译君等）
- 翻译结果质量评分
- 用户自定义翻译后处理规则
- 离线翻译模型支持
