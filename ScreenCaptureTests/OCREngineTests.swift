import XCTest
import CoreGraphics
import Vision
@testable import ScreenCapture

/// OCR 引擎的单元测试
/// 注意：由于 Vision 框架在测试环境中的限制，某些测试可能需要 mock 或跳过
final class OCREngineTests: XCTestCase {
    // MARK: - 属性

    private var engine: OCREngine!

    // MARK: - 设置与清理

    override func setUp() async throws {
        try await super.setUp()
        engine = await OCREngine.shared
    }

    override func tearDown() async throws {
        engine = nil
        try await super.tearDown()
    }

    // MARK: - 辅助方法

    /// 创建一个简单的测试图像（纯白色背景）
    private func createTestImage(width: Int = 100, height: Int = 100) -> CGImage? {
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        return context.makeImage()
    }

    /// 创建一个包含简单文本的测试图像
    /// 注意：在测试环境中绘制文本可能不产生可识别的 OCR 结果
    private func createTestImageWithText() -> CGImage? {
        let width = 200
        let height = 100

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        // 白色背景
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        // 黑色文本
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))

        // 绘制简单的矩形形状代替文本（Vision 无法识别绘制文本）
        context.fill(CGRect(x: 20, y: 20, width: 160, height: 60))

        return context.makeImage()
    }

    // MARK: - 配置测试

    func testDefaultConfiguration() {
        let config = OCREngine.Configuration.default

        XCTAssertTrue(config.useAutoLanguageDetection)
        XCTAssertEqual(config.minimumConfidence, 0.0)
        XCTAssertTrue(config.languages.isEmpty)
        XCTAssertEqual(config.recognitionLevel, .accurate)
        XCTAssertFalse(config.prefersFastRecognition)
    }

    func testCustomConfiguration() {
        var config = OCREngine.Configuration.default
        config.languages = [.english, .chineseSimplified]
        config.minimumConfidence = 0.5
        config.useAutoLanguageDetection = false
        config.recognitionLevel = .fast
        config.prefersFastRecognition = true

        XCTAssertEqual(config.languages.count, 2)
        XCTAssertTrue(config.languages.contains(.english))
        XCTAssertEqual(config.minimumConfidence, 0.5)
        XCTAssertFalse(config.useAutoLanguageDetection)
        XCTAssertEqual(config.recognitionLevel, .fast)
        XCTAssertTrue(config.prefersFastRecognition)
    }

    // MARK: - 识别语言测试

    func testRecognitionLanguageCount() {
        // 确保我们有合理的语言支持
        XCTAssertGreaterThan(OCREngine.RecognitionLanguage.allCases.count, 5)
    }

    func testEnglishLanguage() {
        let lang = OCREngine.RecognitionLanguage.english

        XCTAssertEqual(lang.rawValue, "en-US")
        XCTAssertEqual(lang.visionLanguage, "en-US")
    }

    func testChineseSimplifiedLanguage() {
        let lang = OCREngine.RecognitionLanguage.chineseSimplified

        XCTAssertEqual(lang.rawValue, "zh-Hans")
        XCTAssertEqual(lang.visionLanguage, "zh-Hans")
    }

    func testChineseTraditionalLanguage() {
        let lang = OCREngine.RecognitionLanguage.chineseTraditional

        XCTAssertEqual(lang.rawValue, "zh-Hant")
        XCTAssertEqual(lang.visionLanguage, "zh-Hant")
    }

    // MARK: - 错误处理测试

    func testInvalidImage() async {
        // 创建无效图像（0x0）
        let result = await OCRResult.empty(imageSize: .zero)

        XCTAssertTrue(result.observations.isEmpty)
    }

    func testEmptyImageRecognition() async throws {
        guard let image = createTestImage() else {
            XCTFail("Failed to create test image")
            return
        }

        // 对空白图像进行 OCR 应该成功，但无结果
        let result = try await engine.recognize(image)

        XCTAssertNotNil(result)
        XCTAssertEqual(result.imageSize.width, 100)
        XCTAssertEqual(result.imageSize.height, 100)
        // 空白图像可能没有识别结果
    }

    // MARK: - 并发测试

    func testConcurrentRecognition() async throws {
        guard let image1 = createTestImage(width: 100, height: 100),
              let image2 = createTestImage(width: 100, height: 100) else {
            XCTFail("Failed to create test images")
            return
        }

        // 并发执行两次识别应该不会冲突（由于 actor 保护）
        async let result1 = engine.recognize(image1)
        async let result2 = engine.recognize(image2)

        let (r1, r2) = try await (result1, result2)

        XCTAssertNotNil(r1)
        XCTAssertNotNil(r2)
    }

    // MARK: - 配置变体测试

    func testRecognitionWithFastLevel() async throws {
        guard let image = createTestImage() else {
            XCTFail("Failed to create test image")
            return
        }

        var config = OCREngine.Configuration.default
        config.recognitionLevel = .fast
        config.prefersFastRecognition = true

        let result = try await engine.recognize(image, config: config)

        XCTAssertNotNil(result)
    }

    func testRecognitionWithHighConfidenceThreshold() async throws {
        guard let image = createTestImageWithText() else {
            XCTFail("Failed to create test image")
            return
        }

        var config = OCREngine.Configuration.default
        config.minimumConfidence = 0.9

        let result = try await engine.recognize(image, config: config)

        // 所有结果应该都满足高置信度要求
        for observation in result.observations {
            XCTAssertGreaterThanOrEqual(observation.confidence, 0.9)
        }
    }

    func testRecognitionWithSpecificLanguages() async throws {
        guard let image = createTestImage() else {
            XCTFail("Failed to create test image")
            return
        }

        let languages: Set<OCREngine.RecognitionLanguage> = [.english, .chineseSimplified]
        let result = try await engine.recognize(image, languages: languages)

        XCTAssertNotNil(result)
    }

    // MARK: - 边界情况测试

    func testVerySmallImage() async throws {
        guard let image = createTestImage(width: 1, height: 1) else {
            XCTFail("Failed to create test image")
            return
        }

        let result = try await engine.recognize(image)

        XCTAssertNotNil(result)
        XCTAssertEqual(result.imageSize.width, 1)
        XCTAssertEqual(result.imageSize.height, 1)
    }

    func testVeryLargeImage() async throws {
        // 测试大图像（但保持合理大小以避免内存问题）
        guard let image = createTestImage(width: 4000, height: 3000) else {
            XCTFail("Failed to create test image")
            return
        }

        let result = try await engine.recognize(image)

        XCTAssertNotNil(result)
        XCTAssertEqual(result.imageSize.width, 4000)
        XCTAssertEqual(result.imageSize.height, 3000)
    }

    func testNonSquareImage() async throws {
        let wideImage = createTestImage(width: 200, height: 50)
        let tallImage = createTestImage(width: 50, height: 200)

        guard let wide = wideImage, let tall = tallImage else {
            XCTFail("Failed to create test images")
            return
        }

        let wideResult = try await engine.recognize(wide)
        let tallResult = try await engine.recognize(tall)

        XCTAssertEqual(wideResult.imageSize.width, 200)
        XCTAssertEqual(wideResult.imageSize.height, 50)

        XCTAssertEqual(tallResult.imageSize.width, 50)
        XCTAssertEqual(tallResult.imageSize.height, 200)
    }

    // MARK: - 性能测试

    func testRecognitionPerformance() async throws {
        guard let image = createTestImage(width: 1000, height: 1000) else {
            XCTFail("Failed to create test image")
            return
        }

        // 测量识别时间
        let start = Date()
        _ = try await engine.recognize(image)
        let duration = Date().timeIntervalSince(start)

        // 识别应该在合理时间内完成（10 秒内）
        // 注意：这只是粗略检查，实际时间可能因系统负载而异
        XCTAssertLessThan(duration, 10.0, "OCR recognition took too long")
    }

    // MARK: - 结果结构测试

    func testResultImageSize() async throws {
        let testWidth = 800
        let testHeight = 600

        guard let image = createTestImage(width: testWidth, height: testHeight) else {
            XCTFail("Failed to create test image")
            return
        }

        let result = try await engine.recognize(image)

        XCTAssertEqual(result.imageSize.width, CGFloat(testWidth))
        XCTAssertEqual(result.imageSize.height, CGFloat(testHeight))
    }

    func testResultTimestamp() async throws {
        guard let image = createTestImage() else {
            XCTFail("Failed to create test image")
            return
        }

        let before = Date()
        let result = try await engine.recognize(image)
        let after = Date()

        // 时间戳应该在执行时间范围内
        XCTAssertGreaterThanOrEqual(result.timestamp, before)
        XCTAssertLessThanOrEqual(result.timestamp, after)
    }
}
