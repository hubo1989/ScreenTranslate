import Foundation
import os

/// OCR engine types supported by the application
enum OCREngineType: String, CaseIterable, Sendable, Codable {
    /// macOS native Vision framework (local, default)
    case vision = "vision"

    /// PaddleOCR (optional, external)
    case paddleOCR = "paddleocr"

    /// Localized display name
    var localizedName: String {
        switch self {
        case .vision:
            return NSLocalizedString("ocr.engine.vision", comment: "Vision (Local)")
        case .paddleOCR:
            return NSLocalizedString("ocr.engine.paddleocr", comment: "PaddleOCR")
        }
    }

    /// Description of the engine
    var description: String {
        switch self {
        case .vision:
            return NSLocalizedString(
                "ocr.engine.vision.description",
                comment: "Built-in macOS engine, no setup required"
            )
        case .paddleOCR:
            return NSLocalizedString(
                "ocr.engine.paddleocr.description",
                comment: "External OCR engine for enhanced accuracy"
            )
        }
    }

    /// Whether this engine is available
    /// Vision is always available; PaddleOCR requires external setup
    var isAvailable: Bool {
        switch self {
        case .vision:
            return true
        case .paddleOCR:
            return PaddleOCRChecker.isAvailable
        }
    }
}

// MARK: - PaddleOCR Availability Checker

/// Helper to check if PaddleOCR is available on the system
enum PaddleOCRChecker {
    private nonisolated(unsafe) static var _isAvailable: Bool = false
    private nonisolated(unsafe) static var _executablePath: String?
    private nonisolated(unsafe) static var _version: String?
    private nonisolated(unsafe) static var _checkCompleted: Bool = false

    static var isAvailable: Bool { _isAvailable }
    static var executablePath: String? { _executablePath }
    static var version: String? { _version }
    static var checkCompleted: Bool { _checkCompleted }

    static func checkAvailabilityAsync() {
        Task.detached(priority: .userInitiated) {
            let result = await performFullCheck()
            _isAvailable = result.available
            _executablePath = result.path
            _version = result.version
            _checkCompleted = true
        }
    }

    private static func performFullCheck() async -> (available: Bool, path: String?, version: String?) {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let possiblePaths = [
                    "\(NSHomeDirectory())/.pyenv/shims/paddleocr",
                    "/usr/local/bin/paddleocr",
                    "/opt/homebrew/bin/paddleocr",
                    "\(NSHomeDirectory())/.local/bin/paddleocr"
                ]
                
                Logger.ocr.debug("[PaddleOCRChecker] Checking paths: \(possiblePaths)")
                
                for path in possiblePaths where FileManager.default.isExecutableFile(atPath: path) {
                    Logger.ocr.debug("[PaddleOCRChecker] Found executable at: \(path)")
                        
                        let task = Process()
                        task.executableURL = URL(fileURLWithPath: path)
                        task.arguments = ["--version"]
                        task.environment = [
                            "PATH": "\(NSHomeDirectory())/.pyenv/shims:/usr/local/bin:/usr/bin:/bin",
                            "HOME": NSHomeDirectory(),
                            "PYENV_ROOT": "\(NSHomeDirectory())/.pyenv",
                            "PADDLE_PDX_DISABLE_MODEL_SOURCE_CHECK": "True"
                        ]
                        
                        let pipe = Pipe()
                        task.standardOutput = pipe
                        task.standardError = pipe
                        
                        do {
                            try task.run()
                            task.waitUntilExit()
                            
                            let data = pipe.fileHandleForReading.readDataToEndOfFile()
                            let output = String(data: data, encoding: .utf8) ?? ""
                            Logger.ocr.debug("Version output: \(output)")
                            
                            let versionLine = output.components(separatedBy: .newlines)
                                .first { $0.contains("paddleocr") }?
                                .trimmingCharacters(in: .whitespaces)
                            
                            Logger.ocr.info("Found: path=\(path), version=\(versionLine ?? "unknown")")
                            continuation.resume(returning: (true, path, versionLine))
                            return
                        } catch {
                            Logger.ocr.error("Error running \(path): \(error.localizedDescription)")
                        }
                }
                
                Logger.ocr.info("Not found in any known path")
                continuation.resume(returning: (false, nil, nil))
            }
        }
    }

    static func resetCache() {
        _isAvailable = false
        _executablePath = nil
        _version = nil
        _checkCompleted = false
    }
}
