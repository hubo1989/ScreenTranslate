import Foundation
import SwiftUI
import os

/// User preferences persisted across sessions via UserDefaults.
/// All properties automatically sync to UserDefaults with the `ScreenCapture.` prefix.
@MainActor
@Observable
final class AppSettings {
    // MARK: - Singleton

    /// Shared settings instance
    static let shared = AppSettings()

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let prefix = "ScreenCapture."
        static let saveLocation = prefix + "saveLocation"
        static let defaultFormat = prefix + "defaultFormat"
        static let jpegQuality = prefix + "jpegQuality"
        static let heicQuality = prefix + "heicQuality"
        static let fullScreenShortcut = prefix + "fullScreenShortcut"
        static let selectionShortcut = prefix + "selectionShortcut"
        static let translationModeShortcut = prefix + "translationModeShortcut"
        static let strokeColor = prefix + "strokeColor"
        static let strokeWidth = prefix + "strokeWidth"
        static let textSize = prefix + "textSize"
        static let rectangleFilled = prefix + "rectangleFilled"
        static let recentCaptures = prefix + "recentCaptures"
        static let translationTargetLanguage = prefix + "translationTargetLanguage"
        static let translationSourceLanguage = prefix + "translationSourceLanguage"
        static let translationAutoDetect = prefix + "translationAutoDetect"
        static let ocrEngine = prefix + "ocrEngine"
        static let translationEngine = prefix + "translationEngine"
        static let translationMode = prefix + "translationMode"
        static let onboardingCompleted = prefix + "onboardingCompleted"
        static let paddleOCRServerAddress = prefix + "paddleOCRServerAddress"
        static let mtranServerHost = prefix + "mtranServerHost"
        static let mtranServerPort = prefix + "mtranServerPort"
        // VLM Configuration
        static let vlmProvider = prefix + "vlmProvider"
        static let vlmAPIKey = prefix + "vlmAPIKey"
        static let vlmBaseURL = prefix + "vlmBaseURL"
        static let vlmModelName = prefix + "vlmModelName"
        // Translation Workflow Configuration
        static let preferredTranslationEngine = prefix + "preferredTranslationEngine"
        static let mtranServerURL = prefix + "mtranServerURL"
        static let translationFallbackEnabled = prefix + "translationFallbackEnabled"
    }

    // MARK: - Properties

    /// Default save directory
    var saveLocation: URL {
        didSet { save(saveLocation.path, forKey: Keys.saveLocation) }
    }

    /// Default export format (PNG or JPEG)
    var defaultFormat: ExportFormat {
        didSet { save(defaultFormat.rawValue, forKey: Keys.defaultFormat) }
    }

    /// JPEG compression quality (0.0-1.0)
    var jpegQuality: Double {
        didSet { save(jpegQuality, forKey: Keys.jpegQuality) }
    }

    /// HEIC compression quality (0.0-1.0)
    var heicQuality: Double {
        didSet { save(heicQuality, forKey: Keys.heicQuality) }
    }

    /// Global hotkey for full screen capture
    var fullScreenShortcut: KeyboardShortcut {
        didSet { saveShortcut(fullScreenShortcut, forKey: Keys.fullScreenShortcut) }
    }

    /// Global hotkey for selection capture
    var selectionShortcut: KeyboardShortcut {
        didSet { saveShortcut(selectionShortcut, forKey: Keys.selectionShortcut) }
    }

    /// Global hotkey for translation mode
    var translationModeShortcut: KeyboardShortcut {
        didSet { saveShortcut(translationModeShortcut, forKey: Keys.translationModeShortcut) }
    }

    /// Default annotation stroke color
    var strokeColor: CodableColor {
        didSet { saveColor(strokeColor, forKey: Keys.strokeColor) }
    }

    /// Default annotation stroke width
    var strokeWidth: CGFloat {
        didSet { save(Double(strokeWidth), forKey: Keys.strokeWidth) }
    }

    /// Default text annotation font size
    var textSize: CGFloat {
        didSet { save(Double(textSize), forKey: Keys.textSize) }
    }

    /// Whether rectangles are filled (solid) by default
    var rectangleFilled: Bool {
        didSet { save(rectangleFilled, forKey: Keys.rectangleFilled) }
    }

    /// Last 5 saved captures
    var recentCaptures: [RecentCapture] {
        didSet { saveRecentCaptures() }
    }

    /// Translation target language (nil = use system default)
    var translationTargetLanguage: TranslationLanguage? {
        didSet {
            if let language = translationTargetLanguage {
                save(language.rawValue, forKey: Keys.translationTargetLanguage)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.translationTargetLanguage)
            }
        }
    }

    /// Translation source language (.auto for automatic detection)
    var translationSourceLanguage: TranslationLanguage {
        didSet { save(translationSourceLanguage.rawValue, forKey: Keys.translationSourceLanguage) }
    }

    /// Whether to automatically detect source language
    var translationAutoDetect: Bool {
        didSet { save(translationAutoDetect, forKey: Keys.translationAutoDetect) }
    }

    /// OCR engine type
    var ocrEngine: OCREngineType {
        didSet { save(ocrEngine.rawValue, forKey: Keys.ocrEngine) }
    }

    /// Translation engine type
    var translationEngine: TranslationEngineType {
        didSet { save(translationEngine.rawValue, forKey: Keys.translationEngine) }
    }

    /// Translation display mode
    var translationMode: TranslationMode {
        didSet { save(translationMode.rawValue, forKey: Keys.translationMode) }
    }

    /// Whether the user has completed the first launch onboarding
    var onboardingCompleted: Bool {
        didSet { save(onboardingCompleted, forKey: Keys.onboardingCompleted) }
    }

    var paddleOCRServerAddress: String {
        didSet { save(paddleOCRServerAddress, forKey: Keys.paddleOCRServerAddress) }
    }

    var mtranServerHost: String {
        didSet { save(mtranServerHost, forKey: Keys.mtranServerHost) }
    }

    var mtranServerPort: Int {
        didSet { save(mtranServerPort, forKey: Keys.mtranServerPort) }
    }

    // MARK: - VLM Configuration

    var vlmProvider: VLMProviderType {
        didSet { save(vlmProvider.rawValue, forKey: Keys.vlmProvider) }
    }

    var vlmAPIKey: String {
        didSet { save(vlmAPIKey, forKey: Keys.vlmAPIKey) }
    }

    var vlmBaseURL: String {
        didSet { save(vlmBaseURL, forKey: Keys.vlmBaseURL) }
    }

    var vlmModelName: String {
        didSet { save(vlmModelName, forKey: Keys.vlmModelName) }
    }

    // MARK: - Translation Workflow Configuration

    var preferredTranslationEngine: PreferredTranslationEngine {
        didSet { save(preferredTranslationEngine.rawValue, forKey: Keys.preferredTranslationEngine) }
    }

    var mtranServerURL: String {
        didSet { save(mtranServerURL, forKey: Keys.mtranServerURL) }
    }

    var translationFallbackEnabled: Bool {
        didSet { save(translationFallbackEnabled, forKey: Keys.translationFallbackEnabled) }
    }

    // MARK: - Initialization

    private init() {
        let defaults = UserDefaults.standard

        // Load save location from bookmark first, then path, or use Desktop
        let loadedLocation: URL
        if let bookmarkData = defaults.data(forKey: "SaveLocationBookmark"),
           let url = Self.resolveBookmark(bookmarkData) {
            loadedLocation = url
        } else if let path = defaults.string(forKey: Keys.saveLocation) {
            loadedLocation = URL(fileURLWithPath: path)
        } else {
            loadedLocation = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory())
        }
        saveLocation = loadedLocation

        // Load format
        if let formatRaw = defaults.string(forKey: Keys.defaultFormat),
           let format = ExportFormat(rawValue: formatRaw) {
            defaultFormat = format
        } else {
            defaultFormat = .png
        }

        // Load JPEG quality
        jpegQuality = defaults.object(forKey: Keys.jpegQuality) as? Double ?? 0.9

        // Load HEIC quality
        heicQuality = defaults.object(forKey: Keys.heicQuality) as? Double ?? 0.9

        // Load shortcuts
        fullScreenShortcut = Self.loadShortcut(forKey: Keys.fullScreenShortcut)
            ?? KeyboardShortcut.fullScreenDefault
        selectionShortcut = Self.loadShortcut(forKey: Keys.selectionShortcut)
            ?? KeyboardShortcut.selectionDefault
        translationModeShortcut = Self.loadShortcut(forKey: Keys.translationModeShortcut)
            ?? KeyboardShortcut.translationModeDefault

        // Load annotation defaults
        strokeColor = Self.loadColor(forKey: Keys.strokeColor) ?? .red
        strokeWidth = CGFloat(defaults.object(forKey: Keys.strokeWidth) as? Double ?? 2.0)
        textSize = CGFloat(defaults.object(forKey: Keys.textSize) as? Double ?? 14.0)
        rectangleFilled = defaults.object(forKey: Keys.rectangleFilled) as? Bool ?? false

        // Load recent captures
        recentCaptures = Self.loadRecentCaptures()

        // Load translation settings
        translationTargetLanguage = defaults.string(forKey: Keys.translationTargetLanguage)
            .flatMap { TranslationLanguage(rawValue: $0) }
        translationSourceLanguage = defaults.string(forKey: Keys.translationSourceLanguage)
            .flatMap { TranslationLanguage(rawValue: $0) } ?? .auto
        translationAutoDetect = defaults.object(forKey: Keys.translationAutoDetect) as? Bool ?? true

        // Load engine settings
        ocrEngine = defaults.string(forKey: Keys.ocrEngine)
            .flatMap { OCREngineType(rawValue: $0) } ?? .vision
        translationEngine = defaults.string(forKey: Keys.translationEngine)
            .flatMap { TranslationEngineType(rawValue: $0) } ?? .apple
        translationMode = defaults.string(forKey: Keys.translationMode)
            .flatMap { TranslationMode(rawValue: $0) } ?? .below
        onboardingCompleted = defaults.object(forKey: Keys.onboardingCompleted) as? Bool ?? false
        paddleOCRServerAddress = defaults.string(forKey: Keys.paddleOCRServerAddress) ?? ""
        mtranServerHost = defaults.string(forKey: Keys.mtranServerHost) ?? "localhost"
        mtranServerPort = defaults.object(forKey: Keys.mtranServerPort) as? Int ?? 8989

        vlmProvider = defaults.string(forKey: Keys.vlmProvider)
            .flatMap { VLMProviderType(rawValue: $0) } ?? .openai
        vlmAPIKey = defaults.string(forKey: Keys.vlmAPIKey) ?? ""
        vlmBaseURL = defaults.string(forKey: Keys.vlmBaseURL) ?? VLMProviderType.openai.defaultBaseURL
        vlmModelName = defaults.string(forKey: Keys.vlmModelName) ?? VLMProviderType.openai.defaultModelName

        preferredTranslationEngine = defaults.string(forKey: Keys.preferredTranslationEngine)
            .flatMap { PreferredTranslationEngine(rawValue: $0) } ?? .apple
        mtranServerURL = defaults.string(forKey: Keys.mtranServerURL) ?? "http://localhost:8989"
        translationFallbackEnabled = defaults.object(forKey: Keys.translationFallbackEnabled) as? Bool ?? true

        Logger.settings.info("ScreenCapture launched - settings loaded from: \(loadedLocation.path)")
    }

    // MARK: - Computed Properties

    /// Default stroke style based on current settings
    var defaultStrokeStyle: StrokeStyle {
        StrokeStyle(color: strokeColor, lineWidth: strokeWidth)
    }

    /// Default text style based on current settings
    var defaultTextStyle: TextStyle {
        TextStyle(color: strokeColor, fontSize: textSize, fontName: ".AppleSystemUIFont")
    }

    // MARK: - Recent Captures Management

    /// Adds a capture to the recent list (maintains max 5, FIFO)
    func addRecentCapture(_ capture: RecentCapture) {
        recentCaptures.insert(capture, at: 0)
        if recentCaptures.count > 5 {
            recentCaptures = Array(recentCaptures.prefix(5))
        }
    }

    /// Clears all recent captures
    func clearRecentCaptures() {
        recentCaptures = []
    }

    // MARK: - Reset

    /// Resets all settings to defaults
    func resetToDefaults() {
        saveLocation = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
        defaultFormat = .png
        jpegQuality = 0.9
        heicQuality = 0.9
        fullScreenShortcut = .fullScreenDefault
        selectionShortcut = .selectionDefault
        translationModeShortcut = .translationModeDefault
        strokeColor = .red
        strokeWidth = 2.0
        textSize = 14.0
        rectangleFilled = false
        recentCaptures = []
        translationTargetLanguage = nil
        translationSourceLanguage = .auto
        translationAutoDetect = true
        ocrEngine = .vision
        translationEngine = .apple
        translationMode = .below
        onboardingCompleted = false
    }

    // MARK: - Private Persistence Helpers

    private func save(_ value: Any, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }

    private func saveShortcut(_ shortcut: KeyboardShortcut, forKey key: String) {
        let data: [String: UInt32] = [
            "keyCode": shortcut.keyCode,
            "modifiers": shortcut.modifiers
        ]
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func loadShortcut(forKey key: String) -> KeyboardShortcut? {
        guard let data = UserDefaults.standard.dictionary(forKey: key) as? [String: UInt32],
              let keyCode = data["keyCode"],
              let modifiers = data["modifiers"] else {
            return nil
        }
        return KeyboardShortcut(keyCode: keyCode, modifiers: modifiers)
    }

    private func saveColor(_ color: CodableColor, forKey key: String) {
        if let data = try? JSONEncoder().encode(color) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private static func loadColor(forKey key: String) -> CodableColor? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(CodableColor.self, from: data)
    }

    private func saveRecentCaptures() {
        if let data = try? JSONEncoder().encode(recentCaptures) {
            UserDefaults.standard.set(data, forKey: Keys.recentCaptures)
        }
    }

    private static func loadRecentCaptures() -> [RecentCapture] {
        guard let data = UserDefaults.standard.data(forKey: Keys.recentCaptures) else {
            return []
        }
        return (try? JSONDecoder().decode([RecentCapture].self, from: data)) ?? []
    }

    /// Resolves a security-scoped bookmark to a URL
    private static func resolveBookmark(_ bookmarkData: Data) -> URL? {
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            // Start accessing the security-scoped resource
            if url.startAccessingSecurityScopedResource() {
                // Note: We don't call stopAccessingSecurityScopedResource()
                // because we need ongoing access throughout the app's lifetime
                return url
            }
            return url
        } catch {
            Logger.settings.error("Failed to resolve bookmark: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Recent Capture

/// Entry in the recent captures list.
struct RecentCapture: Identifiable, Codable, Sendable {
    /// Unique identifier
    let id: UUID

    /// Location of saved file
    let filePath: URL

    /// When the screenshot was captured
    let captureDate: Date

    /// JPEG thumbnail data (max 10KB, 128px on longest edge)
    let thumbnailData: Data?

    init(id: UUID = UUID(), filePath: URL, captureDate: Date = Date(), thumbnailData: Data? = nil) {
        self.id = id
        self.filePath = filePath
        self.captureDate = captureDate
        self.thumbnailData = thumbnailData
    }

    /// The filename without path
    var filename: String {
        filePath.lastPathComponent
    }

    /// Whether the file still exists on disk
    var fileExists: Bool {
        FileManager.default.fileExists(atPath: filePath.path)
    }
}
