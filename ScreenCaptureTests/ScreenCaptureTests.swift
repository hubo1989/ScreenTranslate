import XCTest

/// 测试入口文件
/// 此文件作为 Xcode 测试 target 的入口点
///
/// ## 运行测试
///
### 方式 1: 使用 Xcode
/// 1. 在 Xcode 中打开项目
/// 2. 选择 ScreenCapture scheme
/// 3. 按 Cmd+U 运行测试
///
### 方式 2: 使用 xcodebuild
/// ```bash
/// xcodebuild test -project ScreenCapture.xcodeproj \
///                 -scheme ScreenCapture \
///                 -destination 'platform=macOS'
/// ```
///
### 方式 3: 使用 swift test（需要先配置 SPM）
/// 需要先将项目配置为支持 SPM 测试

final class ScreenCaptureTests: XCTestCase {
    /// 基础测试 - 验证测试框架正常工作
    func testExample() throws {
        XCTAssertTrue(true)
    }

    /// 性能测试示例
    func testPerformance() throws {
        measure {
            // 测试代码性能
            _ = 1 + 1
        }
    }
}
