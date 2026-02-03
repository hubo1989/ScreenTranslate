import Foundation

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

    /// Perform actual check for MTranServer availability
    private static func checkMTranServer() -> Bool {
        var components = URLComponents()
        components.scheme = "http"
        components.host = "localhost"
        components.port = 8989
        components.path = "/health"

        guard let url = components.url else {
            return false
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 2.0
        request.httpMethod = "GET"

        let semaphore = DispatchSemaphore(value: 0)
        let isSuccessBox = UnsafeMutablePointer<Bool>.allocate(capacity: 1)
        isSuccessBox.initialize(to: false)

        let task = URLSession.shared.dataTask(with: request) { _, response, _ in
            if let httpResponse = response as? HTTPURLResponse {
                isSuccessBox.pointee = httpResponse.statusCode == 200
            }
            semaphore.signal()
        }

        task.resume()
        _ = semaphore.wait(timeout: .now() + 2.5)

        let result = isSuccessBox.pointee
        isSuccessBox.deallocate()
        return result
    }

    /// Reset the cached availability check
    static func resetCache() {
        _isAvailable = nil
    }
}
