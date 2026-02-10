# Spec: 区域选择模式 - 窗口自动识别与高亮

## 概述

在现有的区域截图/翻译模式中增加**窗口自动识别**能力。当用户进入区域选择模式后，系统实时检测鼠标光标下方的 UI 窗口，以轻微强调色边框高亮该窗口区域。用户可以直接点击来选取整个窗口范围，也可以忽略高亮框、按住拖动来手动圈选自定义区域。

## 动机

当前的区域选择模式只支持拖拽圈选，用户若想截取一个完整窗口，需要精确地拖拽出窗口边界，操作繁琐且难以精准对齐。macOS 原生截图工具（Cmd+Shift+4 后按空格）支持窗口选取模式，但它是一个独立的切换操作，不如"悬停检测 + 单击确认"来得流畅。本特性将两种选择方式无缝融合在同一个交互流程中。

## 用户故事

**US-1**: 作为用户，我进入区域选择模式后，光标悬停在某个窗口上时，该窗口会自动以高亮框标识出来，让我知道系统识别了哪个窗口。

**US-2**: 作为用户，我直接单击（不拖动），系统将截取/翻译当前高亮的窗口区域。

**US-3**: 作为用户，我按下鼠标并拖动，系统忽略窗口高亮，进入手动圈选模式，行为与现有逻辑完全一致。

**US-4**: 作为用户，我移动鼠标到不同窗口时，高亮框平滑地跟随切换到新窗口。

**US-5**: 作为用户，我光标移到桌面空白区域（无窗口）时，高亮框消失，只显示十字准线。

## 技术设计

### 1. 窗口信息获取

使用 `CGWindowListCopyWindowInfo` API 获取当前所有可见窗口的位置和尺寸信息。选择该 API 而非 ScreenCaptureKit 的 `SCShareableContent.windows`，原因：

- `CGWindowListCopyWindowInfo` 是同步调用，适合在 `mouseMoved` 高频事件中实时查询
- 返回结果包含 `kCGWindowBounds`（窗口 frame）、`kCGWindowLayer`（窗口层级）、`kCGWindowOwnerName`（应用名）等完整信息
- 无需额外权限（Screen Recording 权限已涵盖）

**新建文件**: `ScreenTranslate/Services/WindowDetector.swift`

```swift
/// 检测鼠标光标下方的窗口，提供窗口 frame 信息。
/// 该服务用于区域选择模式中的窗口自动识别。
@MainActor
final class WindowDetector {

    struct WindowInfo {
        let windowID: CGWindowID
        let frame: CGRect          // Quartz 坐标系 (Y=0 at top)
        let ownerName: String
        let windowName: String?
        let windowLayer: Int
    }

    /// 获取指定屏幕坐标点下方最顶层的可见窗口。
    /// - Parameter point: Quartz 坐标系中的屏幕坐标
    /// - Returns: 该点下方最顶层的可见窗口信息，无窗口则返回 nil
    func windowUnderPoint(_ point: CGPoint) -> WindowInfo? { ... }

    /// 获取所有可见窗口列表（排除自身覆盖层和系统级窗口）。
    /// - Returns: 按 Z-order 从前到后排序的窗口列表
    func visibleWindows() -> [WindowInfo] { ... }
}
```

**关键实现细节**：

- 使用 `CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID)` 获取当前屏幕上所有可见窗口
- 过滤条件：排除 `kCGWindowLayer` != 0 的系统级窗口（Dock、Menu Bar 等），排除自身应用的覆盖层窗口
- 窗口列表已按 Z-order 排序，遍历找第一个包含目标点的窗口即可
- 缓存策略：窗口列表在 `mouseDown` 时刷新一次，`mouseMoved` 时可使用最近一次的缓存结果（窗口在用户操作覆盖层期间不会移动）

### 2. SelectionOverlayView 改造

**修改文件**: `ScreenTranslate/Features/Capture/SelectionOverlayWindow.swift`

在 `SelectionOverlayView` 中增加窗口高亮绘制逻辑：

#### 2.1 新增属性

```swift
/// 当前高亮的窗口 frame（view 坐标系）
var highlightedWindowRect: CGRect?

/// 窗口检测器
private let windowDetector = WindowDetector()

/// 高亮框颜色（轻微强调色）
private let windowHighlightColor = NSColor.systemBlue.withAlphaComponent(0.3)
private let windowHighlightStrokeColor = NSColor.systemBlue.withAlphaComponent(0.6)

/// 拖拽阈值（像素），超过此距离判定为拖拽而非点击
private let dragThreshold: CGFloat = 4.0

/// mouseDown 时记录的初始位置（用于区分点击与拖拽）
private var mouseDownPoint: NSPoint?
```

#### 2.2 鼠标事件改造

**`mouseMoved`** — 增加窗口检测：

```
1. 获取鼠标屏幕坐标（Quartz 坐标系）
2. 调用 windowDetector.windowUnderPoint(screenPoint)
3. 若找到窗口，将窗口 frame 从 Quartz 屏幕坐标转换为 view 坐标
4. 更新 highlightedWindowRect 并触发重绘
5. 若未找到窗口，清除 highlightedWindowRect
```

**`mouseDown`** — 记录起始点，但不立即开始选区：

```
1. 记录 mouseDownPoint（用于后续判断是点击还是拖拽）
2. 刷新 windowDetector 缓存
3. 不设置 isDragging = true（延迟到确认拖拽后）
```

**`mouseDragged`** — 判断是否进入拖拽模式：

```
1. 计算当前点与 mouseDownPoint 的距离
2. 若距离 < dragThreshold 且未进入拖拽模式 → 忽略（视为手抖）
3. 若距离 >= dragThreshold →
   a. 设置 isDragging = true
   b. 清除 highlightedWindowRect（退出窗口高亮模式）
   c. 设置 selectionStart = mouseDownPoint
   d. 设置 selectionCurrent = 当前点
   e. 后续行为与现有拖拽逻辑一致
```

**`mouseUp`** — 判断是点击还是拖拽完成：

```
1. 若 isDragging == true → 执行现有的选区完成逻辑（不变）
2. 若 isDragging == false → 这是一次单击
   a. 若 highlightedWindowRect 不为 nil →
      将高亮窗口 frame 转换为 display-relative Quartz 坐标
      调用 delegate?.selectionOverlay(didSelectRect:on:)
   b. 若 highlightedWindowRect == nil →
      调用 delegate?.selectionOverlayDidCancel()（无窗口可选）
3. 重置所有状态
```

#### 2.3 绘制逻辑改造

在 `draw(_:)` 方法中增加窗口高亮绘制：

```
原有流程：
  1. 绘制暗色覆盖
  2. 有选区 → 绘制选区矩形 + 尺寸标签
  3. 无选区 → 绘制十字准线

新流程：
  1. 绘制暗色覆盖（如果有 highlightedWindowRect，在覆盖层上挖出窗口区域）
  2. 有选区（isDragging）→ 绘制选区矩形 + 尺寸标签
  3. 无选区 →
     a. 绘制十字准线
     b. 如果有 highlightedWindowRect → 绘制窗口高亮框
```

**窗口高亮框样式**：

- 填充：`systemBlue.withAlphaComponent(0.08)` — 极轻的蓝色着色，让窗口区域与暗色覆盖区分开
- 边框：`systemBlue.withAlphaComponent(0.5)`，线宽 2pt，圆角 0（精确贴合窗口边界）
- 暗色覆盖层在窗口区域挖洞（与现有选区挖洞逻辑类似，使用 even-odd fill rule）
- 窗口高亮区域的亮度应比暗色覆盖区域明显更亮，但不刺眼

**尺寸标签**：窗口高亮模式下同样显示窗口的像素尺寸标签（复用现有的 `drawDimensionsLabel` 方法）。

### 3. 坐标转换

窗口检测涉及多个坐标系之间的转换，这是实现中最关键的部分。

**坐标系说明**：

| 坐标系 | Y 轴方向 | 使用场景 |
|--------|---------|---------|
| Quartz (CGWindow) | Y=0 在屏幕顶部 | `CGWindowListCopyWindowInfo` 返回的窗口 frame |
| Cocoa (NSWindow/NSView) | Y=0 在主屏幕底部 | `NSView` 坐标、`NSWindow.convertToScreen` |
| Display-relative | Y=0 在显示器顶部 | `CaptureManager.captureRegion` 的输入参数 |

**转换路径**：

```
CGWindow frame (Quartz)
  → Cocoa 屏幕坐标 (翻转 Y 轴: cocoaY = primaryScreenHeight - quartzY - height)
    → NSWindow view 坐标 (通过 window.convertFromScreen)
      → 绘制高亮框

单击确认时的反向转换：
view 坐标中的 highlightedWindowRect
  → Cocoa 屏幕坐标 (window.convertToScreen)
    → Quartz 屏幕坐标 (翻转 Y 轴)
      → Display-relative 坐标 (减去 displayInfo.frame.origin)
        → 传给 delegate
```

该反向转换逻辑与现有 `mouseUp` 中 selectionRect 的转换完全一致（`SelectionOverlayView` 第 411-451 行），可直接复用。

### 4. 性能考量

**`mouseMoved` 调用频率**：macOS 默认 ~60Hz，每次调用 `CGWindowListCopyWindowInfo` 约 1-3ms。

**优化策略**：

1. **节流（Throttle）**：对窗口检测做 16ms（~60fps）节流，避免过于频繁的系统调用
2. **缓存窗口列表**：进入覆盖层后获取一次完整窗口列表并缓存，`mouseMoved` 只做 point-in-rect 检测（O(n)，n 通常 < 30）
3. **增量更新**：只在 `highlightedWindowRect` 发生变化时触发 `needsDisplay = true`
4. **脏区域重绘**：使用 `setNeedsDisplay(_:)` 指定只重绘高亮框变化的区域，而非整个 view

### 5. 边界情况处理

| 场景 | 处理方式 |
|------|---------|
| 光标在自身覆盖层窗口上 | `CGWindowListCopyWindowInfo` 结果中过滤掉自身 bundle ID 的窗口 |
| 光标在菜单栏/Dock 上 | 过滤 `kCGWindowLayer != 0` 的窗口，不高亮系统级 UI |
| 全屏应用窗口 | 正常检测和高亮，全屏窗口的 frame 等于整个屏幕 |
| 多显示器 | 每个显示器有独立的 SelectionOverlayView，窗口检测使用全局屏幕坐标，不受影响 |
| 窗口部分在屏幕外 | 高亮框裁剪到屏幕可见范围内（使用 `NSRect.intersection`） |
| 极小窗口（< 10x10） | 跳过不高亮，避免误操作 |
| 快速移动鼠标穿过多个窗口 | 节流机制 + 增量更新保证流畅 |

### 6. 视觉设计

```
┌─────────────────────────────────────────────────┐
│ ░░░░░░░░░░░░░ 暗色覆盖 (30% 黑) ░░░░░░░░░░░░░ │
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
│ ░░░░ ┌──────────────────────────┐ ░░░░░░░░░░░░ │
│ ░░░░ │                          │ ░░░░░░░░░░░░ │
│ ░░░░ │   窗口内容（明亮可见）    │ ░░░░░░░░░░░░ │
│ ░░░░ │   轻微蓝色着色 (8%)      │ ░░░░░░░░░░░░ │
│ ░░░░ │                          │ ░░░░░░░░░░░░ │
│ ░░░░ └──────────────────────────┘ ░░░░░░░░░░░░ │
│ ░░░░░░ 蓝色边框 (50%, 2pt) ░░░░░░░░░░░░░░░░░░ │
│ ░░░░░░░░░░░░░░░░░░░░░░░ ┌──────────┐ ░░░░░░░░ │
│ ░░░░░░░░░░░░░░░░░░░░░░░ │1440 × 900│ ░░░░░░░░ │
│ ░░░░░░░░░░░░░░░░░░░░░░░ └──────────┘ ░░░░░░░░ │
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
│                    ╋ (十字准线)                   │
└─────────────────────────────────────────────────┘
```

高亮框区域与暗色覆盖的对比效果类似于现有选区的"挖洞"效果——窗口内容清晰可见，周围被暗色覆盖压暗，视觉上突出目标窗口。

### 7. 交互流程状态机

```
                        ┌─────────────┐
               ESC      │    Idle     │
          ┌─────────────│ (十字准线)   │
          │             └──────┬──────┘
          │                    │ mouseMoved
          │                    ▼
          │           ┌─────────────────┐
          │  ESC      │ Window Hovering │ ◀─── mouseMoved (切换窗口)
          ├───────────│ (窗口高亮+准线) │
          │           └───┬─────────┬───┘
          │    mouseDown  │         │ mouseDown
          │    + drag     │         │ + click (no drag)
          │               ▼         ▼
          │    ┌──────────────┐  ┌──────────────────┐
          │    │  Dragging    │  │ Window Selected  │
          │    │ (手动圈选)    │  │ (窗口区域确认)    │
          │    └──────┬───────┘  └────────┬─────────┘
          │           │ mouseUp           │
          │           ▼                   ▼
          │    ┌──────────────────────────────┐
          └───▶│        Complete / Cancel     │
               │ (通知 delegate，关闭覆盖层)    │
               └──────────────────────────────┘
```

## 文件变更清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `ScreenTranslate/Services/WindowDetector.swift` | **新建** | 窗口检测服务，封装 `CGWindowListCopyWindowInfo` 调用和结果解析 |
| `ScreenTranslate/Features/Capture/SelectionOverlayWindow.swift` | **修改** | SelectionOverlayView 增加窗口高亮绘制、点击/拖拽区分逻辑 |

## 不需要改动的文件

- `AppDelegate.swift` — 调用入口不变，`captureSelection()` 和 `startTranslationMode()` 逻辑无需修改
- `SelectionOverlayController` — overlay 管理逻辑不变
- `SelectionOverlayDelegate` 协议 — 接口不变，`selectionOverlay(didSelectRect:on:)` 既可接收拖拽选区也可接收窗口选区
- `CaptureManager.swift` — 截图逻辑不变，只是输入的 rect 来源多了一种
- `TranslationFlowController.swift` — 翻译流程不变

## 测试计划

### 功能测试

1. **窗口高亮显示**：进入区域选择模式，移动鼠标到不同窗口，验证高亮框正确包围目标窗口
2. **单击选取窗口**：高亮某窗口后单击，验证截取的图像范围精确匹配窗口 frame
3. **拖拽自定义选区**：按住并拖动，验证高亮框消失，进入传统圈选模式，行为与改动前一致
4. **桌面空白区域**：鼠标移到无窗口区域，验证高亮框消失
5. **窗口切换**：快速在不同窗口间移动鼠标，验证高亮框平滑切换
6. **翻译模式验证**：翻译模式下同样支持窗口点击选取，翻译结果正确

### 边界测试

7. **多显示器**：跨显示器移动鼠标，验证窗口检测在所有显示器上正常工作
8. **全屏应用**：对全屏应用窗口进行高亮和点击截取
9. **极小窗口**：验证极小窗口不会被高亮
10. **ESC 取消**：在窗口高亮状态下按 ESC，验证正确取消并清除覆盖层

### 性能测试

11. **帧率验证**：在覆盖层显示期间快速移动鼠标，验证无明显卡顿（目标 ≥ 30fps 视觉更新）
12. **内存**：验证覆盖层关闭后 WindowDetector 缓存正确清理

## 里程碑

| 阶段 | 内容 | 预估工作量 |
|------|------|-----------|
| M1 | WindowDetector 服务实现 + 单元测试 | 小 |
| M2 | SelectionOverlayView 窗口高亮绘制 | 中 |
| M3 | 点击/拖拽区分逻辑 + 坐标转换 | 中 |
| M4 | 边界情况处理 + 性能优化 | 小 |
| M5 | 集成测试 + 多显示器验证 | 小 |
