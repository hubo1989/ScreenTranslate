import Foundation

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
    /// Cached availability status (nonisolated(unsafe) for singleton cache)
    private nonisolated(unsafe) static var _isAvailable: Bool? = false

    /// Check if PaddleOCR command is available (returns cached value, never blocks)
    static var isAvailable: Bool {
        return _isAvailable ?? false
    }
    
    /// Async check and cache PaddleOCR availability
    static func checkAvailabilityAsync() {
        Task.detached(priority: .background) {
            let result = await checkPaddleOCRAsync()
            _isAvailable = result
        }
    }

    /// Perform actual check for PaddleOCR availability (async, off main thread)
    private static func checkPaddleOCRAsync() async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
                task.arguments = ["paddleocr"]

                let pipe = Pipe()
                task.standardOutput = pipe
                task.standardError = Pipe()

                do {
                    try task.run()
                    task.waitUntilExit()
                    continuation.resume(returning: task.terminationStatus == 0)
                } catch {
                    continuation.resume(returning: false)
                }
            }
        }
    }

    /// Reset the cached availability check
    static func resetCache() {
        _isAvailable = nil
    }

    /// Get the PaddleOCR version if available
    static var version: String? {
        guard isAvailable else { return nil }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/local/bin/paddleocr")
        task.arguments = ["--version"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()

            if task.terminationStatus == 0,
               let data = try? FileHandle(fileDescriptor: pipe.fileHandleForReading.fileDescriptor).readToEnd(),
               let output = String(data: data, encoding: .utf8) {
                return output.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {}

        return nil
    }
}
