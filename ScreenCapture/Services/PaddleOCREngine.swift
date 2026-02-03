import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import os.log

/// PaddleOCR engine implementation.
/// Communicates with PaddleOCR CLI for text recognition.
actor PaddleOCREngine {
    // MARK: - Properties

    /// Shared instance for PaddleOCR operations
    static let shared = PaddleOCREngine()

    /// Whether PaddleOCR is available on the system
    var isAvailable: Bool { PaddleOCRChecker.isAvailable }

    /// PaddleOCR executable path
    private let executablePath = "/usr/local/bin/paddleocr"

    /// Maximum concurrent operations
    private var isProcessing = false

    // MARK: - Configuration

    /// PaddleOCR configuration options
    struct Configuration: Sendable {
        /// Recognition languages (ch, en for mixed Chinese-English)
        var languages: Set<Language>

        /// Minimum confidence threshold (0.0 to 1.0)
        var minimumConfidence: Float

        /// Whether to use GPU acceleration
        var useGPU: Bool

        /// Whether to use direction classification for rotated text
        var useDirectionClassify: Bool

        /// Detection model type
        var detectionModel: DetectionModel

        static let `default` = Configuration(
            languages: [.chinese, .english],
            minimumConfidence: 0.0,
            useGPU: false,
            useDirectionClassify: true,
            detectionModel: .default
        )
    }

    /// Supported languages for PaddleOCR
    enum Language: String, CaseIterable, Sendable {
        case chinese = "ch"
        case english = "en"
        case french = "french"
        case german = "german"
        case korean = "korean"
        case japanese = "japan"

        /// CLI argument value for language
        var cliValue: String {
            switch self {
            case .chinese: return "ch"
            case .english: return "en"
            case .french: return "french"
            case .german: return "german"
            case .korean: return "korean"
            case .japanese: return "japan"
            }
        }

        /// Localized display name
        var localizedName: String {
            switch self {
            case .chinese: return NSLocalizedString("lang.chinese", comment: "")
            case .english: return NSLocalizedString("lang.english", comment: "")
            case .french: return NSLocalizedString("lang.french", comment: "")
            case .german: return NSLocalizedString("lang.german", comment: "")
            case .korean: return NSLocalizedString("lang.korean", comment: "")
            case .japanese: return NSLocalizedString("lang.japanese", comment: "")
            }
        }
    }

    /// Detection model types
    enum DetectionModel: String, Sendable {
        case `default`
        case server
        case mobile
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Performs OCR on a CGImage with the specified configuration.
    /// - Parameters:
    ///   - image: The image to process
    ///   - config: OCR configuration (uses default if not specified)
    /// - Returns: OCRResult containing all recognized text
    /// - Throws: PaddleOCRError if recognition fails
    func recognize(
        _ image: CGImage,
        config: Configuration = .default
    ) async throws -> OCRResult {
        // Check availability
        guard isAvailable else {
            throw PaddleOCREngineError.notInstalled
        }

        // Prevent concurrent operations
        guard !isProcessing else {
            throw PaddleOCREngineError.operationInProgress
        }
        isProcessing = true
        defer { isProcessing = false }

        // Validate image
        guard image.width > 0 && image.height > 0 else {
            throw PaddleOCREngineError.invalidImage
        }

        // Save image to temporary file
        let tempURL = try saveImageToTempFile(image)

        defer {
            // Clean up temp file
            try? FileManager.default.removeItem(at: tempURL)
        }

        // Build PaddleOCR command arguments
        let arguments = buildArguments(config: config, imagePath: tempURL.path)

        // Execute PaddleOCR
        let result = try await executePaddleOCR(arguments: arguments)

        // Parse output
        let observations = try parsePaddleOCROutput(result, imageSize: CGSize(width: image.width, height: image.height))

        // Filter by confidence
        let filteredTexts = observations.filter { $0.confidence >= config.minimumConfidence }

        return OCRResult(
            observations: filteredTexts,
            imageSize: CGSize(width: image.width, height: image.height)
        )
    }

    /// Performs OCR on a CGImage with default configuration.
    /// - Parameter image: The image to process
    /// - Returns: OCRResult containing all recognized text
    /// - Throws: PaddleOCRError if recognition fails
    func recognize(_ image: CGImage) async throws -> OCRResult {
        try await recognize(image, config: .default)
    }

    /// Performs OCR with specific languages.
    /// - Parameters:
    ///   - image: The image to process
    ///   - languages: Set of languages to recognize
    /// - Returns: OCRResult containing all recognized text
    /// - Throws: PaddleOCRError if recognition fails
    func recognize(
        _ image: CGImage,
        languages: Set<Language>
    ) async throws -> OCRResult {
        var config = Configuration.default
        config.languages = languages
        return try await recognize(image, config: config)
    }

    // MARK: - Private Methods

    /// Saves a CGImage to a temporary PNG file
    private func saveImageToTempFile(_ image: CGImage) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent(
            "ocr_input_\(UUID().uuidString).png"
        )

        guard let destination = CGImageDestinationCreateWithURL(
            tempURL as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw PaddleOCREngineError.failedToSaveImage
        }

        CGImageDestinationAddImage(destination, image, nil)

        guard CGImageDestinationFinalize(destination) else {
            throw PaddleOCREngineError.failedToSaveImage
        }

        return tempURL
    }

    /// Builds command line arguments for PaddleOCR
    private func buildArguments(config: Configuration, imagePath: String) -> [String] {
        var args = [
            "--image_path", imagePath,
            "--use_angle_cls", config.useDirectionClassify ? "true" : "false",
            "--lang", config.languages.map(\.rawValue).joined(separator: ",")
        ]

        if config.useGPU {
            args.append("--use_gpu")
            args.append("true")
        }

        switch config.detectionModel {
        case .default:
            break
        case .server:
            args.append("--det_model_dir")
            args.append("inference/ch_ppocr_server_v2.0_det/")
        case .mobile:
            args.append("--det_model_dir")
            args.append("inference/ch_ppocr_mobile_v2.0_det/")
        }

        return args
    }

    /// Executes PaddleOCR with the given arguments
    private func executePaddleOCR(arguments: [String]) async throws -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executablePath)
        task.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        task.standardOutput = stdoutPipe
        task.standardError = stderrPipe

        do {
            try task.run()
            task.waitUntilExit()

            let stdoutHandle = stdoutPipe.fileHandleForReading
            let stderrHandle = stderrPipe.fileHandleForReading

            defer {
                stdoutHandle.closeFile()
                stderrHandle.closeFile()
            }

            let exitCode = task.terminationStatus

            if exitCode != 0 {
                let stderrData = stderrHandle.readDataToEndOfFile()
                let stderr = String(data: stderrData, encoding: .utf8) ?? "Unknown error"
                throw PaddleOCREngineError.recognitionFailed(underlying: stderr)
            }

            let stdoutData = stdoutHandle.readDataToEndOfFile()
            guard let output = String(data: stdoutData, encoding: .utf8) else {
                throw PaddleOCREngineError.invalidOutput
            }

            return output
        } catch let error as PaddleOCREngineError {
            throw error
        } catch {
            throw PaddleOCREngineError.recognitionFailed(underlying: error.localizedDescription)
        }
    }

    /// Parses PaddleOCR JSON output into OCRText observations
    private func parsePaddleOCROutput(_ output: String, imageSize: CGSize) throws -> [OCRText] {
        // PaddleOCR outputs multiple lines with format: "text [[x1,y1],[x2,y2],...] confidence"
        var observations: [OCRText] = []
        let lines = output.components(separatedBy: .newlines)

        for line in lines where !line.isEmpty {
            // Extract text, coordinates, and confidence using regex
            let pattern = #"^(.+?)\s+\[\[.+?\]\]\s+(\d+\.\d+)"#
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                  match.numberOfRanges >= 3 else {
                continue
            }

            // Extract text
            if let textRange = Range(match.range(at: 1), in: line) {
                let text = String(line[textRange]).trimmingCharacters(in: .whitespaces)

                // Extract confidence
                if let confidenceRange = Range(match.range(at: 2), in: line),
                   let confidence = Float(String(line[confidenceRange])) {
                    // Parse bounding box coordinates
                    if let bbox = parseBoundingBox(from: line, imageSize: imageSize) {
                        let observation = OCRText(
                            text: text,
                            boundingBox: bbox,
                            confidence: confidence / 100.0 // Convert from percentage to 0-1
                        )
                        observations.append(observation)
                    }
                }
            }
        }

        return observations
    }

    /// Parses bounding box coordinates from PaddleOCR output line
    private func parseBoundingBox(from line: String, imageSize: CGSize) -> CGRect? {
        // Extract coordinates: [[x1,y1],[x2,y2],[x3,y3],[x4,y4]]
        let coordPattern = #"\[\[.+?\]\]"#
        guard let coordRegex = try? NSRegularExpression(pattern: coordPattern),
              let coordMatch = coordRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let coordRange = Range(coordMatch.range, in: line) else {
            return nil
        }

        let coordString = String(line[coordRange])
        // Parse individual points
        let pointPattern = #"\[(\d+),(\d+)\]"#
        guard let pointRegex = try? NSRegularExpression(pattern: pointPattern) else {
            return nil
        }

        var points: [CGPoint] = []
        for match in pointRegex.matches(in: coordString, range: NSRange(coordString.startIndex..., in: coordString)) {
            if match.numberOfRanges >= 3,
               let xRange = Range(match.range(at: 1), in: coordString),
               let yRange = Range(match.range(at: 2), in: coordString),
               let x = Int(String(coordString[xRange])),
               let y = Int(String(coordString[yRange])) {
                points.append(CGPoint(x: x, y: y))
            }
        }

        guard points.count >= 4 else { return nil }

        // Calculate bounding box from points
        let xCoords = points.map(\.x)
        let yCoords = points.map(\.y)

        let minX = xCoords.min() ?? 0
        let maxX = xCoords.max() ?? 0
        let minY = yCoords.min() ?? 0
        let maxY = yCoords.max() ?? 0

        // Convert to normalized coordinates (0-1)
        return CGRect(
            x: CGFloat(minX) / imageSize.width,
            y: CGFloat(minY) / imageSize.height,
            width: CGFloat(maxX - minX) / imageSize.width,
            height: CGFloat(maxY - minY) / imageSize.height
        )
    }
}

// MARK: - PaddleOCR Engine Errors

/// Errors that can occur during PaddleOCR operations
enum PaddleOCREngineError: LocalizedError, Sendable {
    /// PaddleOCR is not installed
    case notInstalled

    /// OCR operation is already in progress
    case operationInProgress

    /// The provided image is invalid or empty
    case invalidImage

    /// Failed to save image to temporary file
    case failedToSaveImage

    /// Text recognition failed with an underlying error
    case recognitionFailed(underlying: String)

    /// Invalid output from PaddleOCR
    case invalidOutput

    var errorDescription: String? {
        switch self {
        case .notInstalled:
            return NSLocalizedString(
                "error.paddleocr.not.installed",
                comment: "PaddleOCR is not installed"
            )
        case .operationInProgress:
            return NSLocalizedString(
                "error.ocr.in.progress",
                comment: "OCR operation is already in progress"
            )
        case .invalidImage:
            return NSLocalizedString(
                "error.ocr.invalid.image",
                comment: "The provided image is invalid or empty"
            )
        case .failedToSaveImage:
            return NSLocalizedString(
                "error.paddleocr.save.image",
                comment: "Failed to save image for processing"
            )
        case .recognitionFailed:
            return NSLocalizedString(
                "error.ocr.recognition.failed",
                comment: "Text recognition failed"
            )
        case .invalidOutput:
            return NSLocalizedString(
                "error.paddleocr.invalid.output",
                comment: "Invalid output from PaddleOCR"
            )
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .notInstalled:
            return NSLocalizedString(
                "error.paddleocr.not.installed.recovery",
                comment: "Install PaddleOCR using: pip install paddleocr"
            )
        case .operationInProgress:
            return NSLocalizedString(
                "error.ocr.in.progress.recovery",
                comment: "Wait for the current operation to complete"
            )
        case .invalidImage:
            return NSLocalizedString(
                "error.ocr.invalid.image.recovery",
                comment: "Provide a valid image with non-zero dimensions"
            )
        case .failedToSaveImage:
            return NSLocalizedString(
                "error.paddleocr.save.image.recovery",
                comment: "Check disk space and permissions"
            )
        case .recognitionFailed(let message):
            return message
        case .invalidOutput:
            return NSLocalizedString(
                "error.paddleocr.invalid.output.recovery",
                comment: "Ensure PaddleOCR is correctly installed"
            )
        }
    }
}
