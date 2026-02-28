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

        /// OCR mode: fast (ocr command) or precise (doc_parser VL-1.5)
        var mode: PaddleOCRMode

        /// Whether to use cloud API
        var useCloud: Bool

        /// Cloud API base URL
        var cloudBaseURL: String

        /// Cloud API key
        var cloudAPIKey: String

        /// Whether to use MLX-VLM inference framework (Apple Silicon optimization)
        var useMLXVLM: Bool

        /// MLX-VLM server URL
        var mlxVLMServerURL: String

        /// MLX-VLM model name
        var mlxVLMModelName: String

        /// Local VL model directory (for native backend)
        var localVLModelDir: String

        static let `default` = Configuration(
            languages: [.chinese, .english],
            minimumConfidence: 0.0,
            useGPU: false,
            useDirectionClassify: true,
            detectionModel: .default,
            mode: .fast,
            useCloud: false,
            cloudBaseURL: "",
            cloudAPIKey: "",
            useMLXVLM: false,
            mlxVLMServerURL: "http://localhost:8111",
            mlxVLMModelName: "PaddlePaddle/PaddleOCR-VL-1.5",
            localVLModelDir: ""
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
        let observations = try parsePaddleOCROutput(result, imageSize: CGSize(width: image.width, height: image.height), mode: config.mode)

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
        switch config.mode {
        case .fast:
            // Fast mode: use ocr command (~1s)
            let langCode = config.languages.contains(.chinese) ? "ch" : "en"
            return [
                "ocr",
                "-i", imagePath,
                "--lang", langCode,
                "--use_angle_cls", config.useDirectionClassify ? "true" : "false"
            ]
        case .precise:
            // Precise mode: use doc_parser with VL-1.5
            var args = [
                "doc_parser",
                "-i", imagePath,
                "--pipeline_version", "v1.5",
                "--device", config.useGPU ? "gpu" : "cpu"
            ]

            // Choose backend: MLX-VLM server or native (local model)
            if config.useMLXVLM {
                args += [
                    "--vl_rec_backend", "mlx-vlm-server",
                    "--vl_rec_server_url", config.mlxVLMServerURL,
                    "--vl_rec_api_model_name", config.mlxVLMModelName
                ]
            } else if !config.localVLModelDir.isEmpty {
                // Use native backend with local model
                args += [
                    "--vl_rec_backend", "native",
                    "--vl_rec_model_dir", config.localVLModelDir
                ]
            }

            return args
        }
    }

    /// Executes PaddleOCR with the given arguments
    private func executePaddleOCR(arguments: [String]) async throws -> String {
        let fullCommand = "\(executablePath) \(arguments.joined(separator: " "))"
        Logger.ocr.info("Executing: \(fullCommand)")
        
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
            Logger.ocr.debug("Process started, waiting...")
            task.waitUntilExit()
            Logger.ocr.debug("Process finished with exit code: \(task.terminationStatus)")

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
                    let ansiPattern = "\u{001B}\\[[0-9;]*m"
                    stdout = stdout.replacingOccurrences(of: ansiPattern, with: "", options: .regularExpression)
                    Logger.ocr.debug("Extracted result from stderr")
                }
            }
            
            Logger.ocr.debug("output length: \(stdout.count)")
            Logger.ocr.debug("output: \(stdout.prefix(1000))")

            let exitCode = task.terminationStatus
            if exitCode != 0 {
                let errorMsg = stderr.isEmpty ? "Exit code \(exitCode)" : stderr
                throw PaddleOCREngineError.recognitionFailed(underlying: errorMsg)
            }

            guard !stdout.isEmpty else {
                Logger.ocr.error("No result found in output")
                throw PaddleOCREngineError.invalidOutput
            }

            return stdout
        } catch let error as PaddleOCREngineError {
            throw error
        } catch {
            Logger.ocr.error("Error: \(error.localizedDescription)")
            throw PaddleOCREngineError.recognitionFailed(underlying: error.localizedDescription)
        }
    }
    
    private func findMatchingBrace(in string: String) -> Int? {
        var depth = 0
        for (index, char) in string.enumerated() {
            if char == "{" {
                depth += 1
            } else if char == "}" {
                depth -= 1
                if depth == 0 { return index }
            }
        }
        return nil
    }

    /// Parses PaddleOCR output into OCRText observations
    private func parsePaddleOCROutput(_ output: String, imageSize: CGSize, mode: PaddleOCRMode) throws -> [OCRText] {
        var observations: [OCRText] = []

        guard let startIndex = output.firstIndex(of: "{"),
              let endIndex = output.lastIndex(of: "}") else {
            Logger.ocr.debug("No JSON found in output")
            return observations
        }

        let jsonLike = String(output[startIndex...endIndex])
        let cleanedJson = convertPythonDictToJson(jsonLike)

        Logger.ocr.debug("Cleaned JSON: \(cleanedJson.prefix(500))")

        guard let jsonData = cleanedJson.data(using: .utf8) else {
            Logger.ocr.error("Failed to convert cleaned JSON to data")
            return observations
        }

        // Try to parse JSON and log detailed error
        var json: [String: Any]?
        do {
            json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        } catch {
            Logger.ocr.error("JSON parse error: \(error.localizedDescription)")
            // Log the problematic JSON (last 1000 chars to find the issue)
            if let jsonStr = String(data: jsonData, encoding: .utf8) {
                Logger.ocr.error("JSON end portion: ...\(jsonStr.suffix(500))")
            }
            return observations
        }

        guard let json = json else {
            Logger.ocr.error("Failed to parse JSON as dictionary")
            return observations
        }

        guard let res = json["res"] as? [String: Any] else {
            Logger.ocr.error("No 'res' key in JSON. Keys: \(json.keys.joined(separator: ", "))")
            return observations
        }

        switch mode {
        case .fast:
            // Fast mode: parse rec_texts format
            observations = try parseFastModeOutput(res: res, imageSize: imageSize)
        case .precise:
            // Precise mode: parse doc_parser output format: parsing_res_list
            observations = try parsePreciseModeOutput(res: res, imageSize: imageSize)
        }

        return observations
    }

    /// Parse fast mode output (ocr command)
    private func parseFastModeOutput(res: [String: Any], imageSize: CGSize) throws -> [OCRText] {
        var observations: [OCRText] = []

        // Fast mode output has parallel arrays: rec_texts, rec_scores, rec_boxes
        guard let recTexts = res["rec_texts"] as? [String] else {
            Logger.ocr.error("No rec_texts found in fast mode output. Keys: \(res.keys.joined(separator: ", "))")
            return observations
        }

        // Get rec_boxes and rec_scores (optional)
        let recBoxes = res["rec_boxes"] as? [[Double]]
        let recScores = res["rec_scores"] as? [Double]

        Logger.ocr.info("Found \(recTexts.count) text blocks from fast mode")

        for (index, text) in recTexts.enumerated() {
            guard !text.isEmpty else { continue }

            // Get bounding box from rec_boxes (format: [[x1, y1, x2, y2], ...])
            var boundingBox: CGRect
            if let boxes = recBoxes, index < boxes.count {
                let box = boxes[index]
                if box.count >= 4 {
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
            } else {
                // Fallback: stack vertically
                boundingBox = CGRect(x: 0, y: CGFloat(index) * 0.1, width: 1, height: 0.1)
            }

            // Get confidence from rec_scores
            let confidence: Float
            if let scores = recScores, index < scores.count {
                confidence = Float(scores[index])
            } else {
                confidence = 0.9
            }

            let observation = OCRText(
                text: text,
                boundingBox: boundingBox,
                confidence: confidence
            )
            observations.append(observation)
            Logger.ocr.debug("Fast mode block: '\(text)', box: \(String(describing: boundingBox))")
        }

        return observations
    }

    /// Parse precise mode output (doc_parser VL-1.5)
    private func parsePreciseModeOutput(res: [String: Any], imageSize: CGSize) throws -> [OCRText] {
        var observations: [OCRText] = []

        // Log all keys in res for debugging
        Logger.ocr.info("Precise mode res keys: \(res.keys.joined(separator: ", "))")

        guard let parsingResList = res["parsing_res_list"] as? [[String: Any]] else {
            Logger.ocr.error("No parsing_res_list found in res. Available keys: \(res.keys.joined(separator: ", "))")
            // Try to log the raw res for debugging
            if let resData = try? JSONSerialization.data(withJSONObject: res),
               let resStr = String(data: resData, encoding: .utf8) {
                Logger.ocr.debug("Raw res content: \(resStr.prefix(1000))")
            }
            return observations
        }

        Logger.ocr.info("Found \(parsingResList.count) blocks from doc_parser")

        for (index, block) in parsingResList.enumerated() {
            guard let text = block["block_content"] as? String else {
                continue
            }

            // Skip non-text blocks (charts, seals, images, etc.)
            if let label = block["block_label"] as? String {
                let skipLabels = ["chart", "seal", "image", "table", "figure"]
                if skipLabels.contains(where: { label.lowercased().contains($0) }) {
                    Logger.ocr.debug("Skipping non-text block: \(label)")
                    continue
                }
            }

            var boundingBox: CGRect
            if let bbox = block["block_bbox"] as? [Double], bbox.count >= 4 {
                let x = CGFloat(bbox[0])
                let y = CGFloat(bbox[1])
                let x2 = CGFloat(bbox[2])
                let y2 = CGFloat(bbox[3])
                boundingBox = CGRect(
                    x: x / imageSize.width,
                    y: y / imageSize.height,
                    width: (x2 - x) / imageSize.width,
                    height: (y2 - y) / imageSize.height
                )
            } else {
                boundingBox = CGRect(x: 0, y: CGFloat(index) * 0.1, width: 1, height: 0.1)
            }

            // doc_parser doesn't provide confidence scores per block, use default
            let confidence: Float = 0.9

            let observation = OCRText(
                text: text,
                boundingBox: boundingBox,
                confidence: confidence
            )
            observations.append(observation)
            Logger.ocr.debug("Block: '\(text)', box: \(String(describing: boundingBox))")
        }

        return observations
    }

    private func convertPythonDictToJson(_ pythonDict: String) -> String {
        var result = pythonDict
        result = result.replacingOccurrences(of: "None", with: "null")
        result = result.replacingOccurrences(of: "True", with: "true")
        result = result.replacingOccurrences(of: "False", with: "false")
        result = result.replacingOccurrences(of: "'", with: "\"")

        result = convertNumpyArraysToJson(result)

        // Fix float format: "8." -> "8.0", "-5." -> "-5.0" (valid JSON)
        let floatPattern = #"(-?\d+)\.\s*([,\]\}])"#
        if let regex = try? NSRegularExpression(pattern: floatPattern) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "$1.0$2")
        }

        return result
    }
    
    private func convertNumpyArraysToJson(_ input: String) -> String {
        var result = input
        var searchStart = result.startIndex
        
        while let arrayStart = result.range(of: "array(", range: searchStart..<result.endIndex) {
            var depth = 1
            var current = arrayStart.upperBound
            
            while current < result.endIndex && depth > 0 {
                let char = result[current]
                if char == "(" {
                    depth += 1
                } else if char == ")" {
                    depth -= 1
                }
                current = result.index(after: current)
            }
            
            guard depth == 0 else {
                searchStart = arrayStart.upperBound
                continue
            }
            
            let arrayContent = String(result[arrayStart.upperBound..<result.index(before: current)])
            let extracted = extractArrayContent(from: arrayContent)
            
            result.replaceSubrange(arrayStart.lowerBound..<current, with: extracted)
            searchStart = result.index(arrayStart.lowerBound, offsetBy: extracted.count, limitedBy: result.endIndex) ?? result.endIndex
        }
        
        return result
    }
    
    private func extractArrayContent(from arrayContent: String) -> String {
        var content = arrayContent

        // Remove shape and dtype info
        if let shapeRange = content.range(of: ", shape=") {
            content = String(content[..<shapeRange.lowerBound])
        }
        if let dtypeRange = content.range(of: ", dtype=") {
            content = String(content[..<dtypeRange.lowerBound])
        }

        content = content.trimmingCharacters(in: .whitespacesAndNewlines)

        if content.hasPrefix("[") {
            // Remove ellipsis (numpy truncation indicator)
            content = content.replacingOccurrences(of: "...", with: "")
            // Remove newlines and extra spaces
            content = content.replacingOccurrences(of: "\n", with: "")
            content = content.replacingOccurrences(of: " ", with: "")
            // Clean up multiple commas and brackets
            while content.contains(",,") {
                content = content.replacingOccurrences(of: ",,", with: ",")
            }
            content = content.replacingOccurrences(of: "[,", with: "[")
            content = content.replacingOccurrences(of: ",]", with: "]")
            // Handle edge case of empty nested arrays
            content = content.replacingOccurrences(of: "[]", with: "[]")
            return content
        }

        return "[]"
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
                "error.ocr.failed",
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
