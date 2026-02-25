# ScreenTranslate 架构重构设计

## 概述

本文档记录 ScreenTranslate 项目的架构重构计划，基于 2026-02-25 的架构审查结果。

## 设计决策

| 决策点 | 选择 | 理由 |
|--------|------|------|
| AppDelegate 拆分策略 | 按功能拆分多个 Manager | 边界清晰，适合 Agent 编码，增量重构 |
| 依赖注入策略 | 保持单例，测试时用协议 Mock | 改动最小，风险可控 |
| 拆分粒度 | 粗粒度（3 个 Coordinator） | 边界最清晰，改动范围可控 |

## 实施阶段

### 第一阶段：快速修复（任务 1-3）

#### 1. 修复 `showLoadingIndicator` 硬编码 scaleFactor

**问题**：`AppDelegate.swift:559` 硬编码 `scaleFactor: 2.0`，在非 Retina 或混合显示器上可能显示异常。

**方案**：从当前主屏幕动态获取 `backingScaleFactor`：
```swift
private func showLoadingIndicator() async {
    let scaleFactor = NSScreen.main?.backingScaleFactor ?? 2.0
    // ...
}
```

#### 2. 清理未使用代码

| 文件 | 内容 | 原因 |
|------|------|------|
| `AppDelegate.swift:679-688` | `showEmptyClipboardNotification()` | 未被调用 |
| `AppDelegate.swift:691-703` | `showSuccessNotification()` | 未被调用（translate-and-insert 改为静默操作） |

#### 3. 提取重复代码为公共方法

**3.1 AppDelegate 权限检查逻辑**
```swift
// 提取为私有方法
private func ensureAccessibilityPermission() async -> Bool {
    let permissionManager = PermissionManager.shared
    permissionManager.refreshPermissionStatus()

    if !permissionManager.hasAccessibilityPermission {
        let granted = await withCheckedContinuation { continuation in
            Task { @MainActor in
                let result = permissionManager.requestAccessibilityPermission()
                continuation.resume(returning: result)
            }
        }
        if !granted {
            await MainActor.run {
                permissionManager.showPermissionDeniedError(for: .accessibility)
            }
            return false
        }
    }
    return true
}
```

**3.2 SettingsViewModel 快捷键冲突检查**
```swift
// 提取为通用方法
private func checkShortcutConflict(_ shortcut: KeyboardShortcut, excluding: KeyboardShortcut?) -> Bool {
    let allShortcuts = [
        fullScreenShortcut, selectionShortcut, translationModeShortcut,
        textSelectionTranslationShortcut, translateAndInsertShortcut
    ].filter { $0 != excluding }
    return allShortcuts.contains(shortcut)
}
```

### 第二阶段：重构改进（任务 4-6）

#### 4. 重构 SettingsViewModel 快捷键录制逻辑

**当前问题**：5 个独立布尔变量 + 5 个几乎相同的录制方法

**方案**：使用枚举 + 单一状态变量
```swift
enum ShortcutRecordingType {
    case fullScreen, selection, translationMode
    case textSelectionTranslation, translateAndInsert

    var shortcut: KeyboardShortcut {
        switch self {
        case .fullScreen: return fullScreenShortcut
        case .selection: return selectionShortcut
        case .translationMode: return translationModeShortcut
        case .textSelectionTranslation: return textSelectionTranslationShortcut
        case .translateAndInsert: return translateAndInsertShortcut
        }
    }
}

var recordingType: ShortcutRecordingType?

func startRecording(_ type: ShortcutRecordingType) {
    recordingType = type
    recordedShortcut = nil
}
```

#### 5. 优化 PermissionManager 轮询机制

**当前问题**：每 2 秒轮询权限状态，浪费资源

**方案**：改用按需检查 + 应用激活时检查
```swift
// 移除定时器，改用通知监听
private func setupNotificationObservers() {
    NotificationCenter.default.addObserver(
        forName: NSApplication.didBecomeActiveNotification,
        object: nil,
        queue: .main
    ) { [weak self] _ in
        self?.refreshIfNeeded()
    }
}

private var lastCheckTime: Date = .distantPast

func refreshIfNeeded() {
    // 限流：最多每 5 秒检查一次
    if Date().timeIntervalSince(lastCheckTime) < 5 { return }
    refreshPermissionStatus()
    lastCheckTime = Date()
}
```

#### 6. 增强 TextInsertService 国际化支持

**当前问题**：`keyCodeForCharacter` 只支持美式键盘布局

**方案**：使用 `TISInputSource` API 获取当前键盘布局映射
```swift
import Carbon

private func getCurrentKeyboardLayoutMapping() -> [Character: CGKeyCode]? {
    guard let inputSource = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
          let layoutData = TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData) else {
        return nil
    }

    let layoutPtr = UnsafePointer<UCKeyboardLayout>(OpaquePointer(layoutData))
    // 构建字符到键码的映射表
    // ...
}
```

### 第三阶段：架构重构（任务 7-8）

#### 7. 拆分 AppDelegate 为 3 个 Coordinator

**新增文件：**

##### CaptureCoordinator.swift
```swift
/// 协调截图相关功能：全屏截图、区域截图、翻译模式截图
@MainActor
final class CaptureCoordinator {
    weak var appDelegate: AppDelegate?

    private var isCaptureInProgress = false
    private let displaySelector = DisplaySelector()

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
    }

    // 从 AppDelegate 迁移的方法
    func captureFullScreen() { ... }
    func captureSelection() { ... }
    func startTranslationMode() { ... }

    private func handleSelectionComplete(rect: CGRect, display: DisplayInfo) async { ... }
    private func handleTranslationSelection(rect: CGRect, display: DisplayInfo) async { ... }
}
```

##### TextTranslationCoordinator.swift
```swift
/// 协调文本翻译功能：文本选择翻译、翻译并插入
@MainActor
final class TextTranslationCoordinator {
    weak var appDelegate: AppDelegate?

    private var isTranslating = false

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
    }

    // 从 AppDelegate 迁移的方法
    func translateSelectedText() { ... }
    func translateClipboardAndInsert() { ... }

    private func handleTextSelectionTranslation() async { ... }
    private func handleTranslateClipboardAndInsert() async { ... }
    private func ensureAccessibilityPermission() async -> Bool { ... }
}
```

##### HotkeyCoordinator.swift
```swift
/// 协调热键管理：注册、注销、更新
@MainActor
final class HotkeyCoordinator {
    weak var appDelegate: AppDelegate?

    private var registrations: [HotkeyType: HotkeyManager.Registration] = [:]

    enum HotkeyType {
        case fullScreen, selection, translationMode
        case textSelectionTranslation, translateAndInsert
    }

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
    }

    func registerAllHotkeys() async { ... }
    func unregisterAllHotkeys() async { ... }
    func updateHotkeys() { ... }
}
```

**AppDelegate 精简后保留：**
- 应用生命周期管理（`applicationDidFinishLaunching`, `applicationWillTerminate`）
- MenuBarController 初始化
- Onboarding 流程
- Coordinator 实例持有和协调

#### 8. 引入协议抽象（为测试准备）

```swift
// TranslationServicing.swift
protocol TranslationServicing {
    func translate(
        segments: [String],
        to targetLanguage: String,
        preferredEngine: TranslationEngineType,
        from sourceLanguage: String?
    ) async throws -> [BilingualSegment]
}

// TextSelectionServicing.swift
protocol TextSelectionServicing {
    func captureSelectedText() async throws -> TextSelectionResult
    var canCapture: Bool { get }
}

// TextInsertServicing.swift
protocol TextInsertServicing {
    func insertText(_ text: String) async throws
    func deleteSelectionAndInsert(_ text: String) async throws
    var canInsert: Bool { get }
}

// 现有实现扩展
extension TranslationService: TranslationServicing {}
extension TextSelectionService: TextSelectionServicing {}
extension TextInsertService: TextInsertServicing {}
```

### 第四阶段：收尾和测试（任务 9-10）

#### 9. 改进代码文档

- 为新增的 Coordinator 添加文档注释
- 为公共 API 添加 `///` 文档
- 更新 README 中的架构说明（如有）

#### 10. 添加单元测试

**测试覆盖优先级：**

1. **TextTranslationFlow** - 核心翻译流程
   - 测试空输入处理
   - 测试翻译成功流程
   - 测试取消操作
   - 测试错误处理

2. **TextInsertService** - 文本插入逻辑
   - 测试权限检查
   - 测试 Unicode 文本插入
   - 测试 Delete + Insert 组合

3. **TranslationService** - 翻译服务编排
   - 测试 Provider 选择逻辑
   - 测试 Fallback 机制

4. **KeyboardShortcut** - 快捷键解析和验证
   - 测试键码转换
   - 测试修饰符转换
   - 测试验证逻辑

5. **SettingsViewModel** - 快捷键录制逻辑
   - 测试冲突检测
   - 测试录制状态管理

## 预估改动范围

| 阶段 | 新增文件 | 修改文件 | 代码行变化 |
|------|----------|----------|------------|
| 第一阶段 | 0 | 2 | +50 -80 |
| 第二阶段 | 0 | 2 | +100 -150 |
| 第三阶段 | 3 | 2 | +400 -300 |
| 第四阶段 | 5+ | 3 | +600 -50 |

## 文件结构变化

```
ScreenTranslate/
├── App/
│   ├── AppDelegate.swift          # 精简后
│   ├── ScreenTranslateApp.swift
│   └── Coordinators/              # 新增
│       ├── CaptureCoordinator.swift
│       ├── TextTranslationCoordinator.swift
│       └── HotkeyCoordinator.swift
├── Services/
│   ├── Protocols/                 # 新增
│   │   ├── TranslationServicing.swift
│   │   ├── TextSelectionServicing.swift
│   │   └── TextInsertServicing.swift
│   └── ...
└── Tests/                         # 新增
    ├── TextTranslationFlowTests.swift
    ├── TextInsertServiceTests.swift
    ├── TranslationServiceTests.swift
    ├── KeyboardShortcutTests.swift
    └── SettingsViewModelTests.swift
```

## 风险评估

| 风险 | 可能性 | 影响 | 缓解措施 |
|------|--------|------|----------|
| 重构引入回归 bug | 中 | 高 | 每阶段完成后手动测试核心功能 |
| TextInsertService 国际化改动影响现有功能 | 中 | 中 | 保留原美式布局作为 fallback |
| 测试覆盖不足 | 低 | 中 | 优先覆盖核心业务逻辑 |

## 验收标准

- [ ] 所有阶段完成，无编译错误
- [ ] 核心功能手动测试通过：
  - [ ] 全屏截图
  - [ ] 区域截图
  - [ ] 翻译模式
  - [ ] 文本选择翻译
  - [ ] 翻译并插入
- [ ] 单元测试覆盖率 >= 60%（核心模块）
- [ ] 代码通过 SwiftLint 检查
