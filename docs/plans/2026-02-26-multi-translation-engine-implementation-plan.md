# 多翻译引擎支持功能 - 实现计划

**基于设计文档**: `docs/plans/2026-02-26-multi-translation-engine-design.md`
**创建日期**: 2026-02-26

---

## Phase 0: 文档发现与 API 确认（已完成）

### 已确认的现有代码

| 组件 | 文件路径 | 可复用程度 |
|------|---------|-----------|
| TranslationProvider 协议 | `Services/TranslationProvider.swift:14-51` | ✅ 直接使用 |
| AppleTranslationProvider | `Services/AppleTranslationProvider.swift:12-62` | ✅ 参考模式 |
| MTranServerEngine | `Services/MTranServerEngine.swift:4-303` | ✅ 参考模式 |
| TranslationService | `Services/TranslationService.swift:13-102` | ⚠️ 需重构 |
| VLMProvider 协议 | `Services/VLMProvider.swift:39-57` | ✅ LLM翻译参考 |
| OpenAIVLMProvider | `Services/OpenAIVLMProvider.swift` | ✅ HTTP请求模式参考 |
| SettingsViewModel | `Features/Settings/SettingsViewModel.swift:701-755` | ✅ 测试连接模式 |
| EngineSettingsTab | `Features/Settings/EngineSettingsTab.swift:15-129` | ✅ UI模式参考 |
| AppSettings | `Models/AppSettings.swift` | ⚠️ 需扩展 |

### 已确认不存在的组件（需新建）

- Keychain 服务
- TranslationScene 枚举
- EngineSelectionMode 枚举
- TranslationEngineRegistry
- 云服务商 Provider（Google/DeepL/百度）
- LLMTranslationProvider
- CompatibleTranslationProvider

### Keychain API 参考

```swift
import Security

// 保存密钥
func SecItemAdd(_ query: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus

// 获取密钥
func SecItemCopyMatching(_ query: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus

// 删除密钥
func SecItemDelete(_ query: CFDictionary) -> OSStatus

// 常用常量
kSecClass, kSecClassGenericPassword, kSecAttrService, kSecAttrAccount, kSecValueData, kSecReturnData, kSecMatchLimit
```

---

## Phase 1: 基础架构 - 枚举与配置模型

### 目标
创建新引擎类型、选择模式和场景枚举，以及配置模型。

### 任务清单

#### 1.1 扩展 TranslationEngineType 枚举
**文件**: `Models/TranslationEngineType.swift`

**操作**: 在现有枚举中添加新 case

```swift
enum TranslationEngineType: String, CaseIterable, Sendable, Codable {
    // 现有
    case apple = "apple"
    case mtranServer = "mtran"

    // 新增 - LLM 翻译
    case openai = "openai"
    case claude = "claude"
    case ollama = "ollama"

    // 新增 - 云服务商
    case google = "google"
    case deepl = "deepl"
    case baidu = "baidu"

    // 新增 - 自定义
    case custom = "custom"
}
```

**为每个新引擎添加**:
- `localizedName` 属性（参考现有实现）
- `description` 属性
- `requiresAPIKey: Bool` 属性
- `requiresAppID: Bool` 属性（仅百度需要）

#### 1.2 创建 EngineSelectionMode 枚举
**文件**: `Models/EngineSelectionMode.swift`（新建）

```swift
enum EngineSelectionMode: String, Codable, CaseIterable, Identifiable {
    case primaryWithFallback = "primary_fallback"
    case parallel = "parallel"
    case quickSwitch = "quick_switch"
    case sceneBinding = "scene_binding"

    var id: String { rawValue }

    var localizedName: String { ... }
    var description: String { ... }
}
```

#### 1.3 创建 TranslationScene 枚举
**文件**: `Models/TranslationScene.swift`（新建）

```swift
enum TranslationScene: String, Codable, CaseIterable, Identifiable {
    case screenshot = "screenshot"
    case textSelection = "text_selection"
    case translateAndInsert = "translate_and_insert"

    var id: String { rawValue }
    var localizedName: String { ... }
}
```

#### 1.4 创建引擎配置模型
**文件**: `Models/TranslationEngineConfig.swift`（新建）

```swift
struct TranslationEngineConfig: Codable, Identifiable, Equatable {
    let id: TranslationEngineType
    var isEnabled: Bool
    var options: EngineOptions?

    init(id: TranslationEngineType, isEnabled: Bool = false, options: EngineOptions? = nil)
}

struct EngineOptions: Codable, Equatable {
    var baseURL: String?
    var modelName: String?
    var timeout: TimeInterval?
}
```

#### 1.5 创建场景绑定配置
**文件**: `Models/SceneEngineBinding.swift`（新建）

```swift
struct SceneEngineBinding: Codable, Identifiable, Equatable {
    let scene: TranslationScene
    var primaryEngine: TranslationEngineType
    var fallbackEngine: TranslationEngineType?
    var fallbackEnabled: Bool

    var id: TranslationScene { scene }
}
```

#### 1.6 创建提示词配置模型
**文件**: `Models/TranslationPromptConfig.swift`（新建）

```swift
struct TranslationPromptConfig: Codable, Equatable {
    var enginePrompts: [TranslationEngineType: String]
    var scenePrompts: [TranslationScene: String]

    static let defaultPrompt: String
    static let defaultInsertPrompt: String

    func resolvedPrompt(
        for engine: TranslationEngineType,
        scene: TranslationScene,
        sourceLanguage: String,
        targetLanguage: String,
        text: String
    ) -> String
}
```

### 验证清单
- [ ] `TranslationEngineType.allCases.count == 9`
- [ ] `EngineSelectionMode.allCases.count == 4`
- [ ] `TranslationScene.allCases.count == 3`
- [ ] 所有枚举都实现 `Codable` 和 `Sendable`
- [ ] 编译通过，无警告

### 参考文件
- 现有枚举模式: `Models/TranslationEngineType.swift:5-48`
- 现有枚举模式: `Models/VLMProviderType.swift:11-83`

---

## Phase 2: Keychain 服务

### 目标
实现安全的 API 密钥存储服务。

### 任务清单

#### 2.1 创建 KeychainService
**文件**: `Services/Security/KeychainService.swift`（新建目录和文件）

```swift
import Security
import Foundation

actor KeychainService {
    static let shared = KeychainService()

    private let service = "com.screentranslate.credentials"

    // 保存凭据
    func saveCredentials(
        apiKey: String,
        for engine: TranslationEngineType,
        additionalData: [String: String]? = nil
    ) throws

    // 获取凭据
    func getCredentials(for engine: TranslationEngineType) throws -> StoredCredentials?

    // 删除凭据
    func deleteCredentials(for engine: TranslationEngineType) throws

    // 检查凭据是否存在
    func hasCredentials(for engine: TranslationEngineType) -> Bool
}

struct StoredCredentials: Codable, Sendable {
    let apiKey: String
    let appID: String?
    let additional: [String: String]?
}
```

#### 2.2 实现 Keychain 错误类型
**文件**: `Services/Security/KeychainService.swift`（同一文件）

```swift
enum KeychainError: LocalizedError, Sendable {
    case itemNotFound
    case duplicateItem
    case invalidData
    case unexpectedStatus(OSStatus)

    var errorDescription: String? { ... }
}
```

#### 2.3 实现 OSStatus 扩展
```swift
extension OSStatus {
    var asNSError: NSError {
        let domain = String(kSecErrorDomain)
        let code = Int(self)
        let description = SecCopyErrorMessageString(self, nil)
        return NSError(domain: domain, code: code, userInfo: [
            NSLocalizedDescriptionKey: description ?? "Unknown keychain error"
        ])
    }
}
```

### Keychain 查询字典模板

```swift
// 保存/更新
let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: service,
    kSecAttrAccount as String: engine.rawValue,
    kSecValueData as String: encodedData,
    kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
]

// 查询
let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: service,
    kSecAttrAccount as String: engine.rawValue,
    kSecReturnData as String: true,
    kSecMatchLimit as String: kSecMatchLimitOne
]

// 删除
let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: service,
    kSecAttrAccount as String: engine.rawValue
]
```

### 验证清单
- [ ] 可以保存 API Key
- [ ] 可以读取已保存的 API Key
- [ ] 可以删除 API Key
- [ ] 未找到时返回 `nil` 而非抛出错误
- [ ] 编译通过

### 参考文件
- Keychain API: Apple Security Framework 文档
- 错误处理模式: `Services/TranslationProvider.swift:56-89`

---

## Phase 3: 引擎注册表与 TranslationService 重构

### 目标
创建引擎注册表，重构 TranslationService 支持多种选择模式。

### 任务清单

#### 3.1 创建 TranslationEngineRegistry
**文件**: `Services/Translation/TranslationEngineRegistry.swift`（新建）

```swift
actor TranslationEngineRegistry {
    static let shared = TranslationEngineRegistry()

    private var providers: [TranslationEngineType: any TranslationProvider] = [:]
    private let keychain = KeychainService.shared

    init() {
        // 注册内置引擎
        registerBuiltinProviders()
    }

    func register(_ provider: any TranslationProvider, for type: TranslationEngineType)
    func provider(for type: TranslationEngineType) -> (any TranslationProvider)?
    func availableEngines() async -> [TranslationEngineType]
    func isEngineConfigured(_ type: TranslationEngineType) async -> Bool
}
```

#### 3.2 创建翻译结果包模型
**文件**: `Models/TranslationResultBundle.swift`（新建）

```swift
struct TranslationResultBundle: Sendable {
    let results: [EngineResult]
    let primaryEngine: TranslationEngineType

    var primaryResult: [BilingualSegment] { ... }
    var hasErrors: Bool { ... }
    var successfulEngines: [TranslationEngineType] { ... }
}

struct EngineResult: Sendable {
    let engine: TranslationEngineType
    let segments: [BilingualSegment]
    let latency: TimeInterval
    let error: Error?
}
```

#### 3.3 重构 TranslationService
**文件**: `Services/TranslationService.swift`（修改现有文件）

**新增方法**:

```swift
actor TranslationService {
    // 现有属性保持不变
    private let registry: TranslationEngineRegistry

    // 新增: 统一入口
    func translate(
        segments: [String],
        to targetLanguage: String,
        from sourceLanguage: String?,
        scene: TranslationScene,
        mode: EngineSelectionMode
    ) async throws -> TranslationResultBundle

    // 新增: 四种模式实现
    private func translateWithFallback(...) async throws -> TranslationResultBundle
    private func translateParallel(...) async throws -> TranslationResultBundle
    private func translateForQuickSwitch(...) async throws -> TranslationResultBundle
    private func translateByScene(...) async throws -> TranslationResultBundle
}
```

**保持向后兼容**:
- 保留现有 `translate(segments:to:preferredEngine:from:)` 方法签名
- 内部调用新的统一入口

### 验证清单
- [ ] 可以注册和获取 Provider
- [ ] 可以列出可用引擎
- [ ] 主备模式正常工作
- [ ] 现有翻译功能不受影响

### 参考文件
- 现有实现: `Services/TranslationService.swift:35-76`
- Provider 模式: `Services/TranslationProvider.swift`

---

## Phase 4: LLM 翻译 Provider

### 目标
实现基于 LLM 的翻译引擎（OpenAI/Claude/Ollama）。

### 任务清单

#### 4.1 创建 LLMTranslationProvider
**文件**: `Services/Translation/Providers/LLMTranslationProvider.swift`（新建目录和文件）

```swift
actor LLMTranslationProvider: TranslationProvider {
    let id: TranslationEngineType
    let name: String

    private let baseURL: URL
    private let modelName: String
    private let apiKey: String?
    private let keychain: KeychainService.shared

    init(type: TranslationEngineType) async throws

    var isAvailable: Bool { get async }

    func translate(text: String, from: String?, to: String) async throws -> TranslationResult
    func translate(texts: [String], from: String?, to: String) async throws -> [TranslationResult]
    func checkConnection() async -> Bool
}
```

#### 4.2 实现提示词构建
```swift
private func buildTranslationPrompt(
    text: String,
    sourceLanguage: String?,
    targetLanguage: String
) -> String {
    // 从 TranslationPromptConfig 获取提示词
    // 替换模板变量: {source_language}, {target_language}, {text}
}
```

#### 4.3 实现 API 调用（复用 OpenAI 兼容格式）
```swift
private func callChatAPI(prompt: String) async throws -> String {
    var request = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    // OpenAI 格式
    let body: [String: Any] = [
        "model": modelName,
        "messages": [
            ["role": "user", "content": prompt]
        ],
        "temperature": 0.3
    ]
    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    // Claude 需要 x-api-key header
    if id == .claude {
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
    } else if let apiKey = apiKey {
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    }

    let (data, response) = try await URLSession.shared.data(for: request)
    // 解析响应...
}
```

### 验证清单
- [ ] OpenAI 翻译正常
- [ ] Claude 翻译正常
- [ ] Ollama 本地翻译正常
- [ ] API Key 从 Keychain 读取
- [ ] 错误处理完整

### 参考文件
- HTTP 请求模式: `Services/OpenAIVLMProvider.swift:290-356`
- 错误处理: `Services/OpenAIVLMProvider.swift:359-390`
- Claude 特定: `Services/ClaudeVLMProvider.swift`

---

## Phase 5: 云服务商 Provider

### 目标
实现 Google Translate、DeepL、百度翻译 Provider。

### 任务清单

#### 5.1 Google Translate Provider
**文件**: `Services/Translation/Providers/GoogleTranslationProvider.swift`

```swift
actor GoogleTranslationProvider: TranslationProvider {
    let id = TranslationEngineType.google
    let name = "Google Translate"

    // API 端点: https://translation.googleapis.com/language/translate/v2
    // 请求格式:
    // {
    //   "q": "text to translate",
    //   "source": "en",
    //   "target": "zh",
    //   "format": "text"
    // }
    // Header: Authorization: Bearer {API_KEY}
}
```

#### 5.2 DeepL Provider
**文件**: `Services/Translation/Providers/DeepLTranslationProvider.swift`

```swift
actor DeepLTranslationProvider: TranslationProvider {
    let id = TranslationEngineType.deepl
    let name = "DeepL"

    // API 端点:
    // 免费: https://api-free.deepl.com/v2/translate
    // 专业: https://api.deepl.com/v2/translate
    // 请求格式:
    // {
    //   "text": ["text to translate"],
    //   "source_lang": "EN",
    //   "target_lang": "ZH"
    // }
    // Header: Authorization: DeepL-Auth-Key {API_KEY}
}
```

#### 5.3 百度翻译 Provider
**文件**: `Services/Translation/Providers/BaiduTranslationProvider.swift`

```swift
actor BaiduTranslationProvider: TranslationProvider {
    let id = TranslationEngineType.baidu
    let name = "百度翻译"

    // API 端点: https://fanyi-api.baidu.com/api/trans/vip/translate
    // 请求方式: GET
    // 参数: q, from, to, appid, salt, sign
    // 签名: MD5(appid + q + salt + 密钥)

    private func generateSign(query: String, appID: String, salt: String, secretKey: String) -> String {
        let input = appID + query + salt + secretKey
        return input.md5
    }
}
```

### 验证清单
- [ ] Google Translate API 调用成功
- [ ] DeepL API 调用成功
- [ ] 百度翻译 API 调用成功（含签名验证）
- [ ] API Key 存储在 Keychain
- [ ] 错误处理完整

### 参考文件
- HTTP 请求模式: `Services/MTranServerEngine.swift:67-117`
- JSON 解析: `Services/MTranServerEngine.swift:294-336`

---

## Phase 6: OpenAI 兼容接口 Provider

### 目标
实现通用的 OpenAI 兼容接口 Provider。

### 任务清单

#### 6.1 创建 CompatibleTranslationProvider
**文件**: `Services/Translation/Providers/CompatibleTranslationProvider.swift`

```swift
actor CompatibleTranslationProvider: TranslationProvider {
    let id = TranslationEngineType.custom
    let name: String  // 用户自定义名称

    private let config: CompatibleConfig

    struct CompatibleConfig: Codable, Equatable {
        var displayName: String
        var baseURL: String
        var modelName: String
        var hasAPIKey: Bool
    }
}
```

#### 6.2 实现 API 调用
- 使用标准 OpenAI Chat Completions API 格式
- 支持自定义 baseURL
- 支持可选的 API Key

### 验证清单
- [ ] 可以配置自定义端点
- [ ] API 调用成功
- [ ] 无 API Key 模式正常工作

### 参考文件
- OpenAI 请求格式: `Services/OpenAIVLMProvider.swift:541-552`

---

## Phase 7: AppSettings 扩展

### 目标
扩展 AppSettings 以支持新的配置模型。

### 任务清单

#### 7.1 添加新配置键
**文件**: `Models/AppSettings.swift`

在 `Keys` 枚举中添加:
```swift
// 引擎选择模式
static let engineSelectionMode = prefix + "engineSelectionMode"

// 引擎配置（JSON 编码存储）
static let engineConfigs = prefix + "engineConfigs"

// 提示词配置
static let promptConfig = prefix + "promptConfig"

// 场景绑定
static let sceneBindings = prefix + "sceneBindings"

// 并行引擎列表
static let parallelEngines = prefix + "parallelEngines"

// 兼容接口配置
static let compatibleProviderConfigs = prefix + "compatibleProviderConfigs"
```

#### 7.2 添加新属性
```swift
// 新增属性
var engineSelectionMode: EngineSelectionMode
var engineConfigs: [TranslationEngineType: TranslationEngineConfig]
var promptConfig: TranslationPromptConfig
var sceneBindings: [TranslationScene: SceneEngineBinding]
var parallelEngines: [TranslationEngineType]
var compatibleProviderConfigs: [CompatibleTranslationProvider.CompatibleConfig]
```

#### 7.3 实现默认值
```swift
// init() 中添加
engineSelectionMode = .primaryWithFallback

engineConfigs = [
    .apple: TranslationEngineConfig(id: .apple, isEnabled: true),
    .mtranServer: TranslationEngineConfig(id: .mtranServer, isEnabled: false),
    // 其他引擎默认禁用
]

sceneBindings = [
    .screenshot: SceneEngineBinding(scene: .screenshot, primaryEngine: .apple, fallbackEngine: .mtranServer, fallbackEnabled: true),
    .textSelection: SceneEngineBinding(scene: .textSelection, primaryEngine: .apple, fallbackEngine: .mtranServer, fallbackEnabled: true),
    .translateAndInsert: SceneEngineBinding(scene: .translateAndInsert, primaryEngine: .apple, fallbackEngine: .mtranServer, fallbackEnabled: true)
]

promptConfig = TranslationPromptConfig(
    enginePrompts: [:],
    scenePrompts: [:]
)
```

### 验证清单
- [ ] 配置可以保存到 UserDefaults
- [ ] 配置可以从 UserDefaults 正确加载
- [ ] 默认值正确

### 参考文件
- 现有模式: `Models/AppSettings.swift:176-206`
- 加载逻辑: `Models/AppSettings.swift:295-310`

---

## Phase 8: 设置界面 - 引擎配置

### 目标
重构引擎设置界面，支持多引擎配置和选择模式。

### 任务清单

#### 8.1 创建引擎配置弹窗组件
**文件**: `Features/Settings/EngineConfigSheet.swift`（新建）

```swift
struct EngineConfigSheet: View {
    let engine: TranslationEngineType
    @Binding var config: TranslationEngineConfig

    var body: some View {
        VStack(spacing: 16) {
            // API Key 输入（使用 SecureField）
            // Base URL 输入（如适用）
            // Model Name 输入（如适用）
            // 测试连接按钮
        }
    }
}
```

#### 8.2 重构 EngineSettingsTab
**文件**: `Features/Settings/EngineSettingsTab.swift`

新增组件:
- `EngineSelectionModeSection` - 选择模式
- `AvailableEnginesSection` - 可用引擎列表
- `DynamicConfigSection` - 根据模式显示的动态配置

```swift
struct EngineSettingsContent: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            EngineSelectionModeSection(viewModel: viewModel)
            AvailableEnginesSection(viewModel: viewModel)
            DynamicConfigSection(viewModel: viewModel)
        }
    }
}
```

#### 8.3 扩展 SettingsViewModel
**文件**: `Features/Settings/SettingsViewModel.swift`

添加:
```swift
// 新增属性
var engineSelectionMode: EngineSelectionMode
var engineConfigs: [TranslationEngineType: TranslationEngineConfig]
var parallelEngines: [TranslationEngineType]
var sceneBindings: [TranslationScene: SceneEngineBinding]

// 新增方法
func testEngineConnection(_ engine: TranslationEngineType) async
func toggleEngine(_ engine: TranslationEngineType)
func setPrimaryEngine(_ engine: TranslationEngineType, for scene: TranslationScene)
```

### 验证清单
- [ ] 可以切换选择模式
- [ ] 可以启用/禁用引擎
- [ ] 可以配置引擎参数
- [ ] 测试连接功能正常

### 参考文件
- UI 模式: `Features/Settings/EngineSettingsTab.swift:15-129`
- 测试方法: `Features/Settings/SettingsViewModel.swift:701-755`

---

## Phase 9: 设置界面 - 提示词配置

### 目标
创建提示词编辑界面。

### 任务清单

#### 9.1 创建提示词设置视图
**文件**: `Features/Settings/PromptSettingsView.swift`（新建）

```swift
struct PromptSettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    @State private var editingPrompt: PromptEditTarget?
    @State private var promptText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            EnginePromptsSection(viewModel: viewModel)
            ScenePromptsSection(viewModel: viewModel)
        }
        .sheet(item: $editingPrompt) { target in
            PromptEditorSheet(
                target: target,
                prompt: $promptText,
                onSave: { ... }
            )
        }
    }
}
```

#### 9.2 创建提示词编辑器
```swift
struct PromptEditorSheet: View {
    let target: PromptEditTarget
    @Binding var prompt: String
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("编辑提示词")

            TextEditor(text: $prompt)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 200)

            // 可用变量提示
            HStack {
                Text("可用变量:")
                ForEach(["{source_language}", "{target_language}", "{text}"], id: \.self) { variable in
                    Button(variable) { insertVariable(variable) }
                        .buttonStyle(.borderless)
                }
            }

            HStack {
                Button("恢复默认") { ... }
                Spacer()
                Button("取消") { ... }
                Button("保存") { onSave() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}
```

#### 9.3 创建测试功能
```swift
struct PromptTestView: View {
    let engine: TranslationEngineType
    let prompt: String

    @State private var testText: String = ""
    @State private var result: String?
    @State private var isTesting: Bool = false

    var body: some View {
        // 输入测试文本
        // 显示翻译结果
    }
}
```

### 验证清单
- [ ] 可以编辑分引擎提示词
- [ ] 可以编辑分场景提示词
- [ ] 变量插入功能正常
- [ ] 恢复默认功能正常

### 参考文件
- Sheet 模式: 现有设置界面中的弹窗组件

---

## Phase 10: 集成与验证

### 目标
集成所有组件，进行端到端测试。

### 任务清单

#### 10.1 更新 TranslationFlowController
**文件**: `Features/TranslationFlow/TranslationFlowController.swift`

确保使用新的 TranslationService API:
```swift
func performTranslation(
    segments: [String],
    scene: TranslationScene
) async throws -> TranslationResultBundle {
    try await translationService.translate(
        segments: segments,
        to: settings.translationTargetLanguage?.rawValue ?? "zh-Hans",
        from: settings.translationSourceLanguage.rawValue,
        scene: scene,
        mode: settings.engineSelectionMode
    )
}
```

#### 10.2 更新结果展示组件
确保 `BilingualResultView` 可以处理多引擎结果。

#### 10.3 添加本地化字符串
**文件**: `Resources/en.lproj/Localizable.strings` 和 `Resources/zh-Hans.lproj/Localizable.strings`

添加所有新引擎和模式的本地化字符串。

### 验证清单

#### 功能验证
- [ ] Apple Translation 正常工作
- [ ] MTranServer 正常工作
- [ ] 新增 LLM 翻译引擎正常工作
- [ ] 新增云服务商引擎正常工作
- [ ] 自定义接口正常工作

#### 模式验证
- [ ] 主备模式正常切换
- [ ] 并行模式返回所有结果
- [ ] 即时切换可以懒加载其他引擎
- [ ] 场景绑定按场景使用正确引擎

#### 配置验证
- [ ] API Key 存储在 Keychain
- [ ] 配置持久化正常
- [ ] 设置界面显示正确

#### 错误处理
- [ ] 网络错误正确显示
- [ ] API Key 错误正确提示
- [ ] 超时处理正确

### Anti-Pattern 检查
```bash
# 检查是否使用了不存在的 API
grep -r "SecItemUpdate" ScreenTranslate/  # 应该不存在（使用 SecItemAdd + delete 策略）

# 检查是否硬编码 API Key
grep -r "sk-" ScreenTranslate/  # 应该只在测试文件中

# 检查是否在 UserDefaults 存储 API Key（旧代码迁移）
grep -r "apiKey.*UserDefaults" ScreenTranslate/  # 应该不存在
```

---

## 文件变更摘要

### 新建文件
```
ScreenTranslate/
├── Models/
│   ├── EngineSelectionMode.swift
│   ├── TranslationScene.swift
│   ├── TranslationEngineConfig.swift
│   ├── SceneEngineBinding.swift
│   ├── TranslationPromptConfig.swift
│   └── TranslationResultBundle.swift
│
├── Services/
│   ├── Security/
│   │   └── KeychainService.swift
│   │
│   └── Translation/
│       ├── TranslationEngineRegistry.swift
│       └── Providers/
│           ├── LLMTranslationProvider.swift
│           ├── GoogleTranslationProvider.swift
│           ├── DeepLTranslationProvider.swift
│           ├── BaiduTranslationProvider.swift
│           └── CompatibleTranslationProvider.swift
│
└── Features/Settings/
    ├── EngineConfigSheet.swift
    └── PromptSettingsView.swift
```

### 修改文件
```
ScreenTranslate/
├── Models/
│   ├── TranslationEngineType.swift  # 扩展枚举
│   └── AppSettings.swift  # 添加新配置
│
├── Services/
│   └── TranslationService.swift  # 重构
│
└── Features/Settings/
    ├── EngineSettingsTab.swift  # 重构
    └── SettingsViewModel.swift  # 扩展
```

---

## 风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|---------|
| Keychain 权限问题 | 用户无法保存 API Key | 提供清晰的错误提示和恢复指南 |
| API 限流 | 翻译失败 | 实现重试机制和限流提示 |
| 并行模式性能 | UI 卡顿 | 使用 TaskGroup 并发，限制最大并发数 |
| 配置迁移 | 现有用户配置丢失 | 提供迁移逻辑，保留旧配置格式兼容 |
| LLM 翻译成本 | 用户产生意外费用 | UI 明确提示，提供测试功能预览 |

---

## 里程碑

| 里程碑 | 包含 Phase | 预期成果 |
|--------|-----------|---------|
| M1: 基础架构 | Phase 1-2 | 新枚举、Keychain 服务可用 |
| M2: 引擎实现 | Phase 3-6 | 所有引擎可独立工作 |
| M3: 配置系统 | Phase 7 | AppSettings 支持新配置 |
| M4: UI 完成 | Phase 8-9 | 设置界面完整可用 |
| M5: 集成测试 | Phase 10 | 端到端功能验证 |
