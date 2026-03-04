# 标注与钉图功能增强设计

## 概述

为 ScreenTranslate 添加**钉图功能**和**预制形状**，提升截图标注的实用性。

## 功能需求

### 1. 钉图功能

- **单图固定**: 将截图窗口固定在屏幕最上层 (always on top)
- **多图钉住**: 支持同时钉住多张截图，作为快速参考/对比

### 2. 预制形状

#### 基础形状
- **圆形/椭圆** (Ellipse): 可调整填充/描边
- **直线** (Line): 可调整线宽和颜色

#### 强调形状
- **马赛克** (Mosaic): 像素化区域，隐藏敏感信息
- **高亮荧光笔** (Highlight): 半透明背景，强调文字区域

#### 标注形状
- **编号标签** (Number Label): 自动递增编号 (①②③...)
- **对话框/气泡** (Callout): 带箭头的气泡框

## 架构设计

### 目录结构

```text
ScreenTranslate/
├── Features/
│   ├── Preview/
│   │   ├── PreviewWindow.swift          # 添加钉图状态管理
│   │   ├── PreviewToolBar.swift         # 添加新工具按钮
│   │   ├── AnnotationCanvas.swift       # 添加新形状渲染
│   │   └── PreviewViewModel.swift       # 扩展 AnnotationToolType
│   ├── Annotations/
│   │   ├── EllipseTool.swift            # 新增
│   │   ├── LineTool.swift               # 新增
│   │   ├── MosaicTool.swift             # 新增
│   │   ├── HighlightTool.swift          # 新增
│   │   ├── NumberLabelTool.swift        # 新增
│   │   └── CalloutTool.swift            # 新增
│   └── Pinned/                          # 新增目录
│       ├── PinnedWindow.swift
│       └── PinnedWindowsManager.swift
├── Models/
│   └── Annotation.swift                 # 扩展 enum + 新增 6 个 struct
```

### 数据模型

#### Annotation 枚举扩展

```swift
enum Annotation: Identifiable, Equatable, Sendable {
    // 现有
    case rectangle(RectangleAnnotation)
    case freehand(FreehandAnnotation)
    case arrow(ArrowAnnotation)
    case text(TextAnnotation)
    // 新增
    case ellipse(EllipseAnnotation)
    case line(LineAnnotation)
    case mosaic(MosaicAnnotation)
    case highlight(HighlightAnnotation)
    case numberLabel(NumberLabelAnnotation)
    case callout(CalloutAnnotation)
}
```

#### 新增形状结构体

```swift
// 圆形/椭圆
struct EllipseAnnotation: Identifiable, Equatable, Sendable {
    let id: UUID
    var rect: CGRect
    var style: StrokeStyle
    var isFilled: Bool
}

// 直线
struct LineAnnotation: Identifiable, Equatable, Sendable {
    let id: UUID
    var startPoint: CGPoint
    var endPoint: CGPoint
    var style: StrokeStyle
}

// 马赛克
struct MosaicAnnotation: Identifiable, Equatable, Sendable {
    let id: UUID
    var rect: CGRect
    var blockSize: Int  // 8-32
}

// 高亮
struct HighlightAnnotation: Identifiable, Equatable, Sendable {
    let id: UUID
    var rect: CGRect
    var color: CodableColor  // 默认黄色
    var opacity: Double      // 默认 0.3
}

// 编号标签
struct NumberLabelAnnotation: Identifiable, Equatable, Sendable {
    let id: UUID
    var position: CGPoint
    var number: Int
    var style: TextStyle
}

// 对话框/气泡
struct CalloutAnnotation: Identifiable, Equatable, Sendable {
    let id: UUID
    var rect: CGRect          // 气泡框位置
    var tailPoint: CGPoint    // 箭头指向的点
    var content: String
    var style: TextStyle
}
```

#### 穷举 Switch 同步检查清单

添加新 Annotation case 时，必须更新以下位置：

| 文件 | 符号/位置 | 更新内容 |
|------|----------|----------|
| `Models/Annotation.swift` | `enum Annotation` | 添加新 case |
| `Models/Annotation.swift` | `var id: UUID` | 添加 switch 分支返回对应 ID |
| `Models/Annotation.swift` | `var bounds: CGRect` | 添加 switch 分支返回对应 bounds |
| `Features/Preview/PreviewViewModel.swift` | `enum AnnotationToolType` | 添加新工具类型 |
| `Features/Preview/PreviewViewModel.swift` | `currentTool` switch | 添加工具创建逻辑 |
| `Features/Preview/AnnotationCanvas.swift` | `renderAnnotation()` | 添加渲染逻辑 |
| `Services/ImageExporter+AnnotationRendering.swift` | `renderAnnotation()` | 添加导出渲染逻辑 |
| `Features/Preview/PreviewToolBar.swift` | 工具按钮列表 | 添加工具按钮 |

新增 case 分支行为模板：
- `ellipse`: 椭圆/圆形，支持填充
- `line`: 直线，两点连接
- `mosaic`: 马赛克块，基于 rect
- `highlight`: 半透明高亮矩形
- `numberLabel`: 编号标签，基于 position
- `callout`: 气泡框，带箭头和文本

### 工具类型扩展

```swift
enum AnnotationToolType: String, CaseIterable, Identifiable, Sendable {
    // 现有
    case rectangle
    case freehand
    case arrow
    case text
    // 新增
    case ellipse
    case line
    case mosaic
    case highlight
    case numberLabel
    case callout
    
    var systemImage: String {
        switch self {
        case .rectangle: return "rectangle"
        case .freehand: return "pencil.tip"
        case .arrow: return "arrow.up.right"
        case .text: return "textformat"
        case .ellipse: return "circle"
        case .line: return "line.diagonal"
        case .mosaic: return "checkerboard.rectangle"
        case .highlight: return "highlighter"
        case .numberLabel: return "number.circle"
        case .callout: return "bubble.right"
        }
    }
    
    var keyboardShortcut: Character {
        switch self {
        case .rectangle: return "r"
        case .freehand: return "d"
        case .arrow: return "a"
        case .text: return "t"
        case .ellipse: return "o"
        case .line: return "l"
        case .mosaic: return "m"
        case .highlight: return "h"
        case .numberLabel: return "n"
        case .callout: return "b"
        }
    }
}
```

#### 快捷键别名映射

`keyboardShortcut` 保持单一 `Character`，通过 `hotkeyAliases` 字典支持多键绑定：

```swift
extension AnnotationToolType {
    /// 主快捷键别名映射（数字键作为字母键的备选）
    static let hotkeyAliases: [Character: AnnotationToolType] = [
        // 主键
        "r": .rectangle, "d": .freehand, "a": .arrow, "t": .text,
        "o": .ellipse, "l": .line, "m": .mosaic, "h": .highlight,
        "n": .numberLabel, "b": .callout,
        // 数字别名
        "5": .ellipse, "6": .line, "7": .highlight, "8": .mosaic,
        "9": .numberLabel, "0": .callout
    ]
}
```

### 钉图管理器

```swift
@MainActor
final class PinnedWindowsManager {
    static let shared = PinnedWindowsManager()
    private(set) var pinnedWindows: [UUID: PinnedWindow] = [:]
    
    /// 钉住截图
    func pinScreenshot(_ screenshot: Screenshot, annotations: [Annotation]) -> PinnedWindow
    
    /// 取消钉住
    func unpinWindow(_ id: UUID)
    
    /// 取消所有钉住
    func unpinAll()
    
    /// 获取钉住数量
    var pinnedCount: Int { pinnedWindows.count }
}
```

### PinnedWindow

```swift
final class PinnedWindow: NSPanel {
    private let screenshot: Screenshot
    private let annotations: [Annotation]
    
    init(screenshot: Screenshot, annotations: [Annotation])
    
    /// 配置为始终置顶
    func configureAsPinned() {
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        styleMask = [.borderless, .nonactivatingPanel]
        // 简化 UI，只保留关闭按钮
    }
}
```

## UI 设计

### 工具栏布局

```text
[矩形 R] [圆形 O] [直线 L] [箭头 A] [画笔 D] | [高亮 H] [马赛克 M] | [文字 T] [编号 N] [气泡 B] | [裁剪 C] [钉图 P]
```

工具分组：
- 基础形状: 矩形、圆形、直线、箭头、画笔
- 强调工具: 高亮、马赛克
- 文字标注: 文字、编号、气泡
- 操作: 裁剪、钉图

### 钉图按钮状态

- 未钉住: `pin` 图标，点击后钉住
- 已钉住: `pin.fill` 图标，点击后取消钉住

## 快捷键

| 功能 | 快捷键 |
|------|--------|
| 圆形 | `O` 或 `5` |
| 直线 | `L` 或 `6` |
| 高亮 | `H` 或 `7` |
| 马赛克 | `M` 或 `8` |
| 编号 | `N` 或 `9` |
| 气泡 | `B` 或 `0` |
| 钉图 | `P` |

## 实现计划

### Phase 1: 钉图功能
1. 创建 `PinnedWindow` 和 `PinnedWindowsManager`
2. 在 `PreviewToolBar` 添加钉图按钮
3. 实现钉图状态切换逻辑

### Phase 2: 基础形状
1. 扩展 `Annotation` enum
2. 实现 `EllipseAnnotation` 和 `EllipseTool`
3. 实现 `LineAnnotation` 和 `LineTool`
4. 在 `AnnotationCanvas` 添加渲染逻辑

### Phase 3: 强调形状
1. 实现 `MosaicAnnotation` 和 `MosaicTool`
2. 实现 `HighlightAnnotation` 和 `HighlightTool`
3. 在 `AnnotationCanvas` 添加渲染逻辑

### Phase 4: 标注形状
1. 实现 `NumberLabelAnnotation` 和 `NumberLabelTool`
2. 实现 `CalloutAnnotation` 和 `CalloutTool`
3. 在 `AnnotationCanvas` 添加渲染逻辑

### Phase 5: 测试与优化
1. 单元测试覆盖
2. 性能优化
3. 边界情况处理

## 技术考虑

### 马赛克渲染
使用 Core Image 的 `CIPixellate` 滤镜或手动像素化算法：
```swift
func applyMosaic(to image: NSImage, in rect: CGRect, blockSize: Int) -> NSImage
```

### 高亮渲染
使用半透明矩形覆盖：
```swift
context.fill(path, with: .color(color.color.withAlphaComponent(opacity)))
```

### 编号标签
使用 `NumberFormatter` 或 Unicode 圈数字字符 (①②③...)：
- Unicode 范围: U+2460 - U+2473 (①-⑳)
- 超过 20 时使用 "21" 等数字

### 气泡框
使用贝塞尔曲线绘制圆角矩形 + 三角形箭头：
```swift
func drawCalloutBubble(in context: CGContext, rect: CGRect, tailPoint: CGPoint)
```

## 风险与缓解

| 风险 | 缓解措施 |
|------|---------|
| 工具栏过于拥挤 | 分组设计，考虑二级菜单 |
| 马赛克性能 | 缓存像素化结果，仅在导出时计算 |
| 多钉图内存占用 | 限制最大钉图数量 (建议 5 个) |
| 快捷键冲突 | 避免与系统快捷键冲突，提供自定义选项 |
