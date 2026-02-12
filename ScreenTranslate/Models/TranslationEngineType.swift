import Foundation
import os.log

/// Translation engine types supported by the application
enum TranslationEngineType: String, CaseIterable, Sendable, Codable {
    /// macOS native Translation API (local, default)
    case apple = "apple"

    /// MTranServer (optional, external)
    case mtranServer = "mtran"

    /// Localized display name
    var localizedName: String {
        switch self {
        case .apple:
            return NSLocalizedString("translation.engine.apple", comment: "Apple Translation (Local)")
        case .mtranServer:
            return NSLocalizedString("translation.engine.mtran", comment: "MTranServer")
        }
    }

    /// Description of the engine
    var description: String {
        switch self {
        case .apple:
            return NSLocalizedString(
                "translation.engine.apple.description",
                comment: "Built-in macOS translation, no setup required"
            )
        case .mtranServer:
            return NSLocalizedString(
                "translation.engine.mtran.description",
                comment: "Self-hosted translation server"
            )
        }
    }

    /// Whether this engine is available (local engines are always available)
    var isAvailable: Bool {
        switch self {
        case .apple:
            return true
        case .mtranServer:
            // MTranServer requires external setup
            return MTranServerChecker.isAvailable
        }
    }
}

// MARK: - MTranServer Availability Checker

/// Helper to check if MTranServer is available on the system
enum MTranServerChecker {
    /// Cached availability status (nonisolated(unsafe) for singleton cache)
    private nonisolated(unsafe) static var _isAvailable: Bool?

    /// Check if MTranServer is available
    static var isAvailable: Bool {
        if let cached = _isAvailable {
            return cached
        }

        let result = checkMTranServer()
        _isAvailable = result
        return result
    }

    private final class ResultBox: @unchecked Sendable {
        var value: Bool = false
    }

    private static func checkMTranServer() -> Bool {
        // Read settings directly from UserDefaults to avoid MainActor isolation issues
        let defaults = UserDefaults.standard
        let prefix = "ScreenTranslate."
        var host = defaults.string(forKey: prefix + "mtranServerHost") ?? "localhost"
        let port = defaults.object(forKey: prefix + "mtranServerPort") as? Int ?? 8989

        // Normalize localhost to 127.0.0.1 to avoid IPv6 resolution issues
        if host == "localhost" {
            host = "127.0.0.1"
        }

        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ScreenTranslate", category: "MTranServerChecker")
        logger.info("Checking MTranServer at \(host):\(port)")

        // Try multiple endpoints for health check
        let endpoints = ["/health", "/", "/translate"]
        var isAvailable = false

        for endpoint in endpoints {
            var components = URLComponents()
            components.scheme = "http"
            components.host = host
            components.port = port
            components.path = endpoint

            guard let url = components.url else { continue }

            var request = URLRequest(url: url)
            request.timeoutInterval = 2.0
            request.httpMethod = "GET"

            let semaphore = DispatchSemaphore(value: 0)
            let resultBox = ResultBox()

            let task = URLSession.shared.dataTask(with: request) { _, response, error in
                if let error = error {
                    logger.debug("MTranServer check \(endpoint) failed: \(error.localizedDescription)")
                }
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                logger.debug("MTranServer check \(endpoint): status \(statusCode)")
                // Accept any response that indicates server is running (not connection refused)
                resultBox.value = statusCode > 0
                semaphore.signal()
            }

            task.resume()
            _ = semaphore.wait(timeout: .now() + 2.5)

            if resultBox.value {
                isAvailable = true
                logger.info("MTranServer available via \(endpoint)")
                break
            }
        }

        logger.info("MTranServer final availability: \(isAvailable)")
        return isAvailable
    }

    /// Reset the cached availability check
    static func resetCache() {
        _isAvailable = nil
    }
}
