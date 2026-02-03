import XCTest
import CoreGraphics
@testable import ScreenCapture

/// 针对OCR结果模型的单元测试
final class OCRResultTests: XCTestCase {
    // MARK: - 测试数据

    private let testImageSize = CGSize(width: 1920, height: 1080)

    private func makeOCRText(
        text: String = "测试文本",
        x: CGFloat = 0.1,
        y: CGFloat = 0.2,
        width: CGFloat = 0.3,
        height: CGFloat = 0.05,
        confidence: Float = 0.95
    ) -> OCRText {
        OCRText(
            text: text,
            boundingBox: CGRect(x: x, y: y, width: width, height: height),
            confidence: confidence
        )
    }

    // MARK: - OCRResult 测试

    func testEmptyResult() {
        let result = OCRResult.empty(imageSize: testImageSize)

        XCTAssertTrue(result.observations.isEmpty)
        XCTAssertEqual(result.imageSize, testImageSize)
        XCTAssertFalse(result.hasResults)
        XCTAssertEqual(result.count, 0)
        XCTAssertTrue(result.fullText.isEmpty)
    }

    func testResultWithObservations() {
        let texts = [
            makeOCRText(text: "第一行", y: 0.1),
            makeOCRText(text: "第二行", y: 0.2),
            makeOCRText(text: "第三行", y: 0.3)
        ]
        let result = OCRResult(observations: texts, imageSize: testImageSize)

        XCTAssertEqual(result.count, 3)
        XCTAssertTrue(result.hasResults)
        XCTAssertEqual(result.imageSize, testImageSize)
    }

    func testFullText() {
        let texts = [
            makeOCRText(text: "第一行", y: 0.3),
            makeOCRText(text: "第二行", y: 0.1),
            makeOCRText(text: "第三行", y: 0.2)
        ]
        let result = OCRResult(observations: texts, imageSize: testImageSize)

        // fullText 应该按 Y 坐标排序
        let lines = result.fullText.split(separator: "\n").map { String($0) }
        XCTAssertEqual(lines[0], "第二行")
        XCTAssertEqual(lines[1], "第三行")
        XCTAssertEqual(lines[2], "第一行")
    }

    func testFilterByConfidence() {
        let texts = [
            makeOCRText(text: "高置信度", confidence: 0.9),
            makeOCRText(text: "中置信度", confidence: 0.6),
            makeOCRText(text: "低置信度", confidence: 0.3)
        ]
        let result = OCRResult(observations: texts, imageSize: testImageSize)

        let filtered = result.filter(minimumConfidence: 0.5)
        XCTAssertEqual(filtered.count, 2)
    }

    func testObservationsInRegion() {
        let texts = [
            makeOCRText(text: "区域内", x: 0.1, y: 0.1, width: 0.2, height: 0.1),
            makeOCRText(text: "区域外", x: 0.8, y: 0.8, width: 0.1, height: 0.1)
        ]
        let result = OCRResult(observations: texts, imageSize: testImageSize)

        let region = CGRect(x: 0.0, y: 0.0, width: 0.5, height: 0.5)
        let inRegion = result.observations(in: region)

        XCTAssertEqual(inRegion.count, 1)
        XCTAssertEqual(inRegion.first?.text, "区域内")
    }

    // MARK: - OCRText 测试

    func testOCRTextProperties() {
        let text = makeOCRText(confidence: 0.85)

        XCTAssertEqual(text.text, "测试文本")
        XCTAssertTrue(text.isHighConfidence)
        XCTAssertFalse(text.isVeryHighConfidence)
    }

    func testVeryHighConfidence() {
        let text = makeOCRText(confidence: 0.95)

        XCTAssertTrue(text.isHighConfidence)
        XCTAssertTrue(text.isVeryHighConfidence)
    }

    func testPixelBoundingBox() {
        let text = makeOCRText(
            x: 0.5,
            y: 0.25,
            width: 0.2,
            height: 0.1
        )

        let pixelBox = text.pixelBoundingBox(in: CGSize(width: 1000, height: 500))

        XCTAssertEqual(pixelBox.origin.x, 500, accuracy: 0.1)
        XCTAssertEqual(pixelBox.origin.y, 125, accuracy: 0.1)
        XCTAssertEqual(pixelBox.width, 200, accuracy: 0.1)
        XCTAssertEqual(pixelBox.height, 50, accuracy: 0.1)
    }

    func testCenterPoint() {
        let text = makeOCRText(
            x: 0.2,
            y: 0.3,
            width: 0.4,
            height: 0.2
        )

        let center = text.centerPoint(in: CGSize(width: 1000, height: 500))

        XCTAssertEqual(center.x, 400, accuracy: 0.1) // (0.2 + 0.4/2) * 1000 = 400
        XCTAssertEqual(center.y, 200, accuracy: 0.1) // (0.3 + 0.2/2) * 500 = 200
    }

    func testOCRTextEquatable() {
        let text1 = makeOCRText(text: "相同", confidence: 0.9)
        let text2 = makeOCRText(text: "相同", confidence: 0.9)
        let text3 = makeOCRText(text: "不同", confidence: 0.9)

        // 注意：由于 UUID 不同，即使内容相同也不相等
        XCTAssertNotEqual(text1, text2)
        XCTAssertNotEqual(text1, text3)
    }

    // MARK: - 边界情况测试

    func testEmptyText() {
        let text = makeOCRText(text: "")

        XCTAssertEqual(text.text, "")
        XCTAssertTrue(text.text.isEmpty)
    }

    func testZeroConfidence() {
        let text = makeOCRText(confidence: 0.0)

        XCTAssertFalse(text.isHighConfidence)
        XCTAssertFalse(text.isVeryHighConfidence)
    }

    func testZeroSizeImage() {
        let result = OCRResult.empty(imageSize: .zero)

        XCTAssertEqual(result.imageSize, .zero)
        XCTAssertFalse(result.hasResults)
    }

    func testBoundaryCoordinates() {
        // 测试边界框在图像边缘的情况
        let text = makeOCRText(x: 0.9, y: 0.9, width: 0.1, height: 0.1)
        let pixelBox = text.pixelBoundingBox(in: CGSize(width: 1000, height: 1000))

        // 边界框可能会超出图像范围，这是允许的
        XCTAssertGreaterThanOrEqual(pixelBox.maxX, 900)
        XCTAssertGreaterThanOrEqual(pixelBox.maxY, 900)
    }

    func testFullTextWithEmptyObservations() {
        let result = OCRResult.empty(imageSize: testImageSize)

        XCTAssertTrue(result.fullText.isEmpty)
    }

    func testFilterWithZeroThreshold() {
        let texts = [
            makeOCRText(confidence: 0.0),
            makeOCRText(confidence: 0.5),
            makeOCRText(confidence: 1.0)
        ]
        let result = OCRResult(observations: texts, imageSize: testImageSize)

        let filtered = result.filter(minimumConfidence: 0.0)
        XCTAssertEqual(filtered.count, 3)
    }

    func testObservationsInNonIntersectingRegion() {
        let texts = [
            makeOCRText(x: 0.1, y: 0.1, width: 0.1, height: 0.1)
        ]
        let result = OCRResult(observations: texts, imageSize: testImageSize)

        // 完全不相交的区域
        let region = CGRect(x: 0.5, y: 0.5, width: 0.1, height: 0.1)
        let inRegion = result.observations(in: region)

        XCTAssertTrue(inRegion.isEmpty)
    }

    func testObservationsInOverlappingRegion() {
        let texts = [
            makeOCRText(x: 0.2, y: 0.2, width: 0.3, height: 0.3)
        ]
        let result = OCRResult(observations: texts, imageSize: testImageSize)

        // 部分重叠的区域
        let region = CGRect(x: 0.0, y: 0.0, width: 0.3, height: 0.3)
        let inRegion = result.observations(in: region)

        XCTAssertEqual(inRegion.count, 1)
    }
}
