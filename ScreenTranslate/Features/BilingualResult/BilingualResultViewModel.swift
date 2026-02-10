import AppKit
import Observation

@MainActor
@Observable
final class BilingualResultViewModel {
    private(set) var image: CGImage
    private(set) var scale: CGFloat = 1.0
    var displayScaleFactor: CGFloat
    var isLoading: Bool = false
    var loadingMessage: String = ""
    var copySuccessMessage: String?
    var saveSuccessMessage: String?
    var errorMessage: String?

    private let minScale: CGFloat = 0.1
    private let maxScale: CGFloat = 5.0
    private let scaleStep: CGFloat = 0.1

    var imageWidth: Int { image.width }
    var imageHeight: Int { image.height }

    /// Image size in points (for display sizing)
    var imagePointWidth: CGFloat { CGFloat(image.width) / displayScaleFactor }
    var imagePointHeight: CGFloat { CGFloat(image.height) / displayScaleFactor }

    var dimensionsText: String {
        "\(imageWidth) × \(imageHeight)"
    }

    init(image: CGImage, displayScaleFactor: CGFloat = 1.0) {
        self.image = image
        self.displayScaleFactor = displayScaleFactor
    }

    func showLoading(originalImage: CGImage, message: String? = nil) {
        self.image = originalImage
        self.isLoading = true
        self.loadingMessage = message ?? String(localized: "bilingualResult.loading")
        self.errorMessage = nil
    }

    func showResult(image: CGImage, displayScaleFactor: CGFloat? = nil) {
        self.image = image
        if let sf = displayScaleFactor { self.displayScaleFactor = sf }
        self.isLoading = false
        self.loadingMessage = ""
        self.errorMessage = nil
        self.scale = 1.0
    }

    func showError(_ message: String) {
        self.isLoading = false
        self.errorMessage = message
    }

    func updateImage(_ newImage: CGImage, displayScaleFactor: CGFloat? = nil) {
        self.image = newImage
        if let sf = displayScaleFactor { self.displayScaleFactor = sf }
        self.errorMessage = nil
        self.scale = 1.0
    }

    func zoomIn() {
        let newScale = min(scale + scaleStep, maxScale)
        if newScale != scale {
            scale = newScale
        }
    }

    func zoomOut() {
        let newScale = max(scale - scaleStep, minScale)
        if newScale != scale {
            scale = newScale
        }
    }

    func resetZoom() {
        scale = 1.0
    }

    func copyToClipboard() {
        do {
            try ClipboardService.shared.copy(image)
            showCopySuccess()
        } catch {
            errorMessage = String(localized: "bilingualResult.copyFailed")
        }
    }

    func saveImage() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.nameFieldStringValue = ImageExporter.shared.generateFilename(format: .png)
        savePanel.canCreateDirectories = true

        guard savePanel.runModal() == .OK, let url = savePanel.url else {
            return
        }

        do {
            try ImageExporter.shared.save(image, annotations: [], to: url, format: .png, quality: 1.0)
            showSaveSuccess()
        } catch {
            errorMessage = String(localized: "bilingualResult.saveFailed")
        }
    }

    private func showCopySuccess() {
        copySuccessMessage = String(localized: "bilingualResult.copySuccess")
        Task {
            try? await Task.sleep(for: .seconds(2))
            copySuccessMessage = nil
        }
    }

    private func showSaveSuccess() {
        saveSuccessMessage = String(localized: "bilingualResult.saveSuccess")
        Task {
            try? await Task.sleep(for: .seconds(2))
            saveSuccessMessage = nil
        }
    }
}
