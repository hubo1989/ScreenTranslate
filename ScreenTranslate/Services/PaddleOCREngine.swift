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

    /// Get executable path from checker
    private var executablePath: String {
        PaddleOCRChecker.executablePath ?? "/usr/local/bin/paddleocr"
    }

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
            "ocr",
            "-i", imagePath,
            "--lang", "ch"
        ]

        if config.useGPU {
            args.append("--device")
            args.append("gpu")
        }

        return args
    }

    /// Executes PaddleOCR with the given arguments
    private func executePaddleOCR(arguments: [String]) async throws -> String {
        let fullCommand = "\(executablePath) \(arguments.joined(separator: " "))"
        print("[PaddleOCREngine] Executing: \(fullCommand)")
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-c", fullCommand]
        
        task.environment = [
            "PATH": "\(NSHomeDirectory())/.pyenv/shims:\(NSHomeDirectory())/.pyenv/bin:/usr/local/bin:/usr/bin:/bin",
            "HOME": NSHomeDirectory(),
            "PYENV_ROOT": "\(NSHomeDirectory())/.pyenv",
            "PADDLE_PDX_DISABLE_MODEL_SOURCE_CHECK": "True"
        ]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        task.standardOutput = stdoutPipe
        task.standardError = stderrPipe

        do {
            try task.run()
            print("[PaddleOCREngine] Process started, waiting...")
            task.waitUntilExit()
            print("[PaddleOCREngine] Process finished with exit code: \(task.terminationStatus)")

            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            var stdout = String(data: stdoutData, encoding: .utf8) ?? ""
            let stderr = String(data: stderrData, encoding: .utf8) ?? ""
            
            // PaddleOCR outputs result to stderr, extract JSON from it
            if stdout.isEmpty, let resultRange = stderr.range(of: "{'res':") {
                let resultStart = stderr[resultRange.lowerBound...]
                // Find the matching closing brace
                if let jsonEnd = findMatchingBrace(in: String(resultStart)) {
                    stdout = String(resultStart.prefix(jsonEnd + 1))
                    // Remove ANSI color codes
                    stdout = stdout.replacingOccurrences(of: "\u{001B}\\[[0-9;]*m", with: "", options: .regularExpression)
                    print("[PaddleOCREngine] Extracted result from stderr")
                }
            }
            
            print("[PaddleOCREngine] output length: \(stdout.count)")
            print("[PaddleOCREngine] output: \(stdout.prefix(1000))")

            let exitCode = task.terminationStatus
            if exitCode != 0 {
                throw PaddleOCREngineError.recognitionFailed(underlying: stderr.isEmpty ? "Exit code \(exitCode)" : stderr)
            }

            guard !stdout.isEmpty else {
                print("[PaddleOCREngine] No result found in output")
                throw PaddleOCREngineError.invalidOutput
            }

            return stdout
        } catch let error as PaddleOCREngineError {
            throw error
        } catch {
            print("[PaddleOCREngine] Error: \(error)")
            throw PaddleOCREngineError.recognitionFailed(underlying: error.localizedDescription)
        }
    }
    
    private func findMatchingBrace(in string: String) -> Int? {
        var depth = 0
        for (index, char) in string.enumerated() {
            if char == "{" { depth += 1 }
            else if char == "}" { 
                depth -= 1 
                if depth == 0 { return index }
            }
        }
        return nil
    }

    /// Parses PaddleOCR JSON output into OCRText observations
    private func parsePaddleOCROutput(_ output: String, imageSize: CGSize) throws -> [OCRText] {
        var observations: [OCRText] = []

        guard let startIndex = output.firstIndex(of: "{"),
              let endIndex = output.lastIndex(of: "}") else {
            print("[PaddleOCREngine] No JSON found in output")
            return observations
        }

        let jsonLike = String(output[startIndex...endIndex])
        let cleanedJson = convertPythonDictToJson(jsonLike)
        
        print("[PaddleOCREngine] Cleaned JSON: \(cleanedJson.prefix(500))")

        guard let jsonData = cleanedJson.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let res = json["res"] as? [String: Any] else {
            print("[PaddleOCREngine] Failed to parse JSON")
            return observations
        }

        guard let recTexts = res["rec_texts"] as? [String] else {
            print("[PaddleOCREngine] No rec_texts found")
            return observations
        }
        
        let recScores = res["rec_scores"] as? [Double] ?? []
        let recBoxes = res["rec_boxes"] as? [[Int]] ?? []
        
        print("[PaddleOCREngine] Found \(recTexts.count) texts, \(recBoxes.count) boxes")

        for (index, text) in recTexts.enumerated() {
            let confidence = index < recScores.count ? Float(recScores[index]) : 0.5
            
            var boundingBox: CGRect
            if index < recBoxes.count && recBoxes[index].count >= 4 {
                let box = recBoxes[index]
                let x = CGFloat(box[0])
                let y = CGFloat(box[1])
                let x2 = CGFloat(box[2])
                let y2 = CGFloat(box[3])
                boundingBox = CGRect(
                    x: x / imageSize.width,
                    y: y / imageSize.height,
                    width: (x2 - x) / imageSize.width,
                    height: (y2 - y) / imageSize.height
                )
            } else {
                boundingBox = CGRect(x: 0, y: CGFloat(index) * 0.1, width: 1, height: 0.1)
            }
            
            let observation = OCRText(
                text: text,
                boundingBox: boundingBox,
                confidence: confidence
            )
            observations.append(observation)
            print("[PaddleOCREngine] Text: '\(text)', box: \(boundingBox), confidence: \(confidence)")
        }

        return observations
    }

    private func convertPythonDictToJson(_ pythonDict: String) -> String {
        var result = pythonDict
        result = result.replacingOccurrences(of: "None", with: "null")
        result = result.replacingOccurrences(of: "True", with: "true")
        result = result.replacingOccurrences(of: "False", with: "false")
        result = result.replacingOccurrences(of: "'", with: "\"")

        let arrayPattern = #"array\([^)]*\)[^,}\]]*"#
        if let regex = try? NSRegularExpression(pattern: arrayPattern, options: [.dotMatchesLineSeparators]) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "[]")
        }
        
        let dtypePattern = #",?\s*dtype=[^\)]+\)"#
        if let regex = try? NSRegularExpression(pattern: dtypePattern) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }
        
        let shapePattern = #",?\s*shape=\([^\)]+\)"#
        if let regex = try? NSRegularExpression(pattern: shapePattern) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }

        return result
    }

    private func parseBoundingBox(from line: String, imageSize: CGSize) -> CGRect? {
        nil
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
