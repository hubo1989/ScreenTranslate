import Foundation

extension URL {
    /// Automatically resolves localhost to 127.0.0.1 to avoid IPv6 resolution issues (connection refused ::1)
    var resolvingLocalhost: URL {
        guard let host = self.host, host.lowercased() == "localhost" else {
            return self
        }
        var components = URLComponents(url: self, resolvingAgainstBaseURL: true)
        components?.host = "127.0.0.1"
        return components?.url ?? self
    }
}
