import CoreGraphics
import XCTest
@testable import TransFrame

final class HistoryStoreTests: XCTestCase {
    func testGenerateThumbnailDataCreatesBoundedJPEG() throws {
        let image = try XCTUnwrap(Self.makeImage(width: 512, height: 256))

        let data = HistoryStore.generateThumbnailData(from: image)

        XCTAssertNotNil(data)
        XCTAssertLessThanOrEqual(data?.count ?? .max, 10 * 1024)
    }

    private static func makeImage(width: Int, height: Int) -> CGImage? {
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}

