//
//  PaddleOCRVLMProvider.swift
//  ScreenTranslate
//
//  PaddleOCR as a VLM provider for local, free, offline text extraction.
//

import CoreGraphics
import Foundation

/// PaddleOCR-based VLM provider for local text extraction.
/// Uses PaddleOCREngine for OCR and converts results to ScreenAnalysisResult.
struct PaddleOCRVLMProvider: VLMProvider, Sendable {
    // MARK: - VLMProvider Properties

    let id: String = "paddleocr"
    let name: String = "PaddleOCR"

    /// Empty configuration (PaddleOCR doesn't need API keys or URLs)
    let configuration: VLMProviderConfiguration

    // MARK: - Initialization

    init() {
        // Create an empty configuration for PaddleOCR
        self.configuration = VLMProviderConfiguration(
            apiKey: "",
            baseURL: URL(string: "http://localhost")!,
            modelName: "paddleocr"
        )
    }

    // MARK: - VLMProvider Protocol

    var isAvailable: Bool {
        get async {
            await PaddleOCREngine.shared.isAvailable
        }
    }

    func analyze(image: CGImage) async throws -> ScreenAnalysisResult {
        // Check availability
        guard await PaddleOCREngine.shared.isAvailable else {
            throw VLMProviderError.invalidConfiguration(
                "PaddleOCR is not installed. Install it using: pip3 install paddleocr paddlepaddle"
            )
        }

        // Build configuration from AppSettings
        let config = await buildConfiguration()

        // Perform OCR using PaddleOCREngine with settings
        let ocrResult = try await PaddleOCREngine.shared.recognize(image, config: config)

        // Convert OCRResult to ScreenAnalysisResult
        return convertToScreenAnalysisResult(ocrResult, mode: config.mode)
    }

    // MARK: - Private Methods

    @MainActor
    private func buildConfiguration() -> PaddleOCREngine.Configuration {
        let settings = AppSettings.shared
        var config = PaddleOCREngine.Configuration.default
        config.mode = settings.paddleOCRMode
        config.useCloud = settings.paddleOCRUseCloud
        config.cloudBaseURL = settings.paddleOCRCloudBaseURL
        config.cloudAPIKey = settings.paddleOCRCloudAPIKey
        return config
    }

    private func convertToScreenAnalysisResult(_ ocrResult: OCRResult, mode: PaddleOCRMode) -> ScreenAnalysisResult {
        // For precise mode (doc_parser), the output is already in block format, no need to group
        // For fast mode (ocr command), we need to group into lines
        let segments: [TextSegment]
        switch mode {
        case .precise:
            // Precise mode: already in block format, convert directly
            segments = ocrResult.observations.map { observation in
                TextSegment(
                    text: observation.text,
                    boundingBox: observation.boundingBox,
                    confidence: observation.confidence
                )
            }
        case .fast:
            // Fast mode: group into lines based on vertical position
            let lines = groupIntoLines(ocrResult.observations, imageSize: ocrResult.imageSize)
            segments = lines.map { line -> TextSegment in
                TextSegment(
                    text: line.text,
                    boundingBox: line.boundingBox,
                    confidence: line.confidence
                )
            }
        }

        return ScreenAnalysisResult(
            segments: segments,
            imageSize: ocrResult.imageSize
        )
    }

    /// Groups OCR texts into lines based on vertical position overlap
    private func groupIntoLines(_ observations: [OCRText], imageSize: CGSize) -> [MergedLine] {
        guard !observations.isEmpty else { return [] }

        // Sort by Y position (top to bottom), then by X position (left to right)
        let sortedObservations = observations.sorted { a, b in
            let yTolerance = min(a.boundingBox.height, b.boundingBox.height) * 0.5
            if abs(a.boundingBox.minY - b.boundingBox.minY) > yTolerance {
                return a.boundingBox.minY < b.boundingBox.minY
            }
            return a.boundingBox.minX < b.boundingBox.minX
        }

        var lines: [MergedLine] = []
        var currentLine: MergedLine?

        for observation in sortedObservations {
            if let line = currentLine {
                // Check if this observation is on the same line (Y position overlap)
                let yOverlap = max(0,
                    min(line.boundingBox.maxY, observation.boundingBox.maxY) -
                    max(line.boundingBox.minY, observation.boundingBox.minY)
                )
                let minHeight = min(line.boundingBox.height, observation.boundingBox.height)

                // If there's significant Y overlap, add to current line
                if yOverlap > minHeight * 0.3 {
                    currentLine = line.merged(with: observation)
                } else {
                    // Start a new line
                    lines.append(line)
                    currentLine = MergedLine(from: observation)
                }
            } else {
                currentLine = MergedLine(from: observation)
            }
        }

        // Don't forget the last line
        if let line = currentLine {
            lines.append(line)
        }

        return lines
    }
}

/// Helper struct to merge OCR texts into lines
private struct MergedLine {
    let text: String
    let boundingBox: CGRect
    let confidence: Float
    
    init(text: String, boundingBox: CGRect, confidence: Float) {
        self.text = text
        self.boundingBox = boundingBox
        self.confidence = confidence
    }
    
    init(from observation: OCRText) {
        self.text = observation.text
        self.boundingBox = observation.boundingBox
        self.confidence = observation.confidence
    }
    
    func merged(with other: OCRText) -> MergedLine {
        // Combine texts with space
        let combinedText = text + " " + other.text
        
        // Merge bounding boxes
        let mergedBox = boundingBox.union(other.boundingBox)
        
        // Average confidence weighted by text length
        let totalLength = text.count + other.text.count
        let weightedConfidence = (
            Float(text.count) * confidence +
            Float(other.text.count) * other.confidence
        ) / Float(totalLength)
        
        return MergedLine(
            text: combinedText,
            boundingBox: mergedBox,
            confidence: weightedConfidence
        )
    }
}
