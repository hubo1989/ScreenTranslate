# OCR 测试文档

## 概述

本目录包含 OCR 功能的单元测试。

## 测试文件

- `OCRResultTests.swift` - OCR 结果数据模型测试
- `OCREngineTests.swift` - OCR 引擎测试
- `ScreenCaptureTests.swift` - 测试入口文件

## 运行测试

### 使用 Xcode (推荐)

1. 在 Xcode 中打开项目：
   ```bash
   open ScreenCapture.xcodeproj
   ```

2. 确保选择了正确的 scheme (ScreenCapture)

3. 运行测试：
   - 按 `Cmd + U` 运行所有测试
   - 在测试导航器中选择特定测试运行

### 使用 xcodebuild

```bash
# 运行所有测试
xcodebuild test \
  -project ScreenCapture.xcodeproj \
  -scheme ScreenCapture \
  -destination 'platform=macOS'

# 仅运行特定测试类
xcodebuild test \
  -project ScreenCapture.xcodeproj \
  -scheme ScreenCapture \
  -destination 'platform=macOS' \
  -only-testing:ScreenCaptureTests/OCRResultTests
```

## 测试覆盖范围

### OCRResultTests

- 空结果测试
- 结果观察集合测试
- 全文本提取（按位置排序）
- 置信度过滤
- 区域内观察筛选
- 像素坐标转换
- 中心点计算
- 边界情况

### OCREngineTests

- 配置测试
- 识别语言测试
- 错误处理
- 并发识别
- 配置变体
- 边界情况（小图像、大图像、非方形图像）
- 性能测试
- 结果结构验证

## 注意事项

1. **Vision 框架限制**：在单元测试环境中，Vision 框架的行为可能与实际应用略有不同。某些依赖于实际图像识别的测试可能会产生空结果。

2. **性能测试**：性能测试的执行时间可能因系统负载而异，已设置合理的阈值。

3. **并发测试**：OCR 引擎使用 actor 保证线程安全，并发测试验证了这一点。

## 添加新测试

要添加新的测试用例：

1. 在相应的测试文件中创建新的测试方法
2. 方法名以 `test` 开头
3. 使用 `XCTAssert*` 系列宏进行断言

示例：
```swift
func testMyNewFeature() async throws {
    // 准备
    let input = createTestData()

    // 执行
    let result = try await engine.process(input)

    // 断言
    XCTAssertEqual(result.expectedValue, input.expectedValue)
}
```
