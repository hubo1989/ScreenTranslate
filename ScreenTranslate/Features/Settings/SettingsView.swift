import SwiftUI
import AppKit

/// Main settings view with all preference controls.
/// Organized into sections: General, Export, Keyboard Shortcuts, and Annotations.
struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    @State private var refreshID = UUID()

    var body: some View {
        Form {
            // Permissions Section
            Section {
                PermissionRow(viewModel: viewModel)
            } header: {
                Label(L("settings.section.permissions"), systemImage: "lock.shield")
            }

            // General Settings Section
            Section {
                AppLanguagePicker()
                SaveLocationPicker(viewModel: viewModel)
            } header: {
                Label(L("settings.section.general"), systemImage: "gearshape")
            }

            // Engine Settings Section
            Section {
                OCREnginePicker(viewModel: viewModel)
                TranslationEnginePicker(viewModel: viewModel)
                TranslationModePicker(viewModel: viewModel)
            } header: {
                Label(L("settings.section.engines"), systemImage: "engine.combustion")
            }

            // Language Settings Section
            Section {
                SourceLanguagePicker(viewModel: viewModel)
                TargetLanguagePicker(viewModel: viewModel)
            } header: {
                Label(L("settings.section.languages"), systemImage: "globe")
            }

            // Export Settings Section
            Section {
                ExportFormatPicker(viewModel: viewModel)
                if viewModel.defaultFormat == .jpeg {
                    JPEGQualitySlider(viewModel: viewModel)
                } else if viewModel.defaultFormat == .heic {
                    HEICQualitySlider(viewModel: viewModel)
                }
            } header: {
                Label(L("settings.section.export"), systemImage: "square.and.arrow.up")
            }

            // Keyboard Shortcuts Section
            Section {
                ShortcutRecorder(
                    label: L("settings.shortcut.fullscreen"),
                    shortcut: viewModel.fullScreenShortcut,
                    isRecording: viewModel.isRecordingFullScreenShortcut,
                    onRecord: { viewModel.startRecordingFullScreenShortcut() },
                    onReset: { viewModel.resetFullScreenShortcut() }
                )

                ShortcutRecorder(
                    label: L("settings.shortcut.selection"),
                    shortcut: viewModel.selectionShortcut,
                    isRecording: viewModel.isRecordingSelectionShortcut,
                    onRecord: { viewModel.startRecordingSelectionShortcut() },
                    onReset: { viewModel.resetSelectionShortcut() }
                )
            } header: {
                Label(L("settings.section.shortcuts"), systemImage: "keyboard")
            }

            // Annotation Settings Section
            Section {
                StrokeColorPicker(viewModel: viewModel)
                StrokeWidthSlider(viewModel: viewModel)
                TextSizeSlider(viewModel: viewModel)
            } header: {
                Label(L("settings.section.annotations"), systemImage: "pencil.tip.crop.circle")
            }

            // Reset Section
            Section {
                Button(role: .destructive) {
                    viewModel.resetAllToDefaults()
                } label: {
                    Label(L("settings.reset.all"), systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 450, minHeight: 500)
        .id(refreshID)
        .onReceive(NotificationCenter.default.publisher(for: LanguageManager.languageDidChangeNotification)) { _ in
            refreshID = UUID()
        }
        .alert(L("error.title"), isPresented: $viewModel.showErrorAlert) {
            Button(L("button.ok")) {
                viewModel.errorMessage = nil
            }
        } message: {
            if let message = viewModel.errorMessage {
                Text(message)
            }
        }
    }
}

// MARK: - Permission Row

/// Row showing permission status with action button.
private struct PermissionRow: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Screen Recording permission
            PermissionItem(
                icon: "record.circle",
                title: L("settings.permission.screen.recording"),
                hint: L("settings.permission.screen.recording.hint"),
                isGranted: viewModel.hasScreenRecordingPermission,
                isChecking: viewModel.isCheckingPermissions,
                onGrant: { viewModel.requestScreenRecordingPermission() }
            )

            Divider()

            // Folder Access permission
            PermissionItem(
                icon: "folder",
                title: L("settings.save.location"),
                hint: L("settings.save.location.message"),
                isGranted: viewModel.hasFolderAccessPermission,
                isChecking: viewModel.isCheckingPermissions,
                onGrant: { viewModel.requestFolderAccess() }
            )

            HStack {
                Spacer()
                Button {
                    viewModel.checkPermissions()
                } label: {
                    Label(L("action.reset"), systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

/// Individual permission item row
private struct PermissionItem: View {
    let icon: String
    let title: String
    let hint: String
    let isGranted: Bool
    let isChecking: Bool
    let onGrant: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    Text(title)
                }

                Spacer()

                if isChecking {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    HStack(spacing: 8) {
                        if isGranted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(L("settings.permission.granted"))
                                .foregroundStyle(.secondary)
                        } else {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)

                            Button {
                                onGrant()
                            } label: {
                                Text(L("settings.permission.grant"))
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                }
            }

            if !isGranted && !isChecking {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(title): \(isGranted ? L("settings.permission.granted") : L("settings.permission.not.granted"))"))
    }
}

// MARK: - Save Location Picker

/// Picker for selecting the default save location.
private struct SaveLocationPicker: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(L("settings.save.location"))
                    .font(.headline)
                Text(viewModel.saveLocationPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Button {
                viewModel.selectSaveLocation()
            } label: {
                Text(L("settings.save.location.choose"))
            }

            Button {
                viewModel.revealSaveLocation()
            } label: {
                Image(systemName: "folder")
            }
            .help(L("settings.save.location.reveal"))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(L("settings.save.location")): \(viewModel.saveLocationPath)"))
    }
}

// MARK: - Export Format Picker

/// Picker for selecting the default export format (PNG/JPEG).
private struct ExportFormatPicker: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Picker(L("settings.format"), selection: $viewModel.defaultFormat) {
            Text(L("settings.format.png")).tag(ExportFormat.png)
            Text(L("settings.format.jpeg")).tag(ExportFormat.jpeg)
            Text(L("settings.format.heic")).tag(ExportFormat.heic)
        }
        .pickerStyle(.segmented)
        .accessibilityLabel(Text(L("settings.format")))
    }
}

// MARK: - JPEG Quality Slider

/// Slider for adjusting JPEG compression quality.
private struct JPEGQualitySlider: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L("settings.jpeg.quality"))
                Spacer()
                Text("\(Int(viewModel.jpegQualityPercentage))%")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Slider(
                value: $viewModel.jpegQuality,
                in: SettingsViewModel.jpegQualityRange,
                step: 0.05
            ) {
                Text(L("settings.jpeg.quality"))
            } minimumValueLabel: {
                Text("10%")
                    .font(.caption)
            } maximumValueLabel: {
                Text("100%")
                    .font(.caption)
            }
            .accessibilityValue(Text("\(Int(viewModel.jpegQualityPercentage)) percent"))

            Text(L("settings.jpeg.quality.hint"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - HEIC Quality Slider

/// Slider for adjusting HEIC compression quality.
private struct HEICQualitySlider: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L("settings.heic.quality"))
                Spacer()
                Text("\(Int(viewModel.heicQualityPercentage))%")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Slider(
                value: $viewModel.heicQuality,
                in: SettingsViewModel.heicQualityRange,
                step: 0.05
            ) {
                Text(L("settings.heic.quality"))
            } minimumValueLabel: {
                Text("10%")
                    .font(.caption)
            } maximumValueLabel: {
                Text("100%")
                    .font(.caption)
            }
            .accessibilityValue(Text("\(Int(viewModel.heicQualityPercentage)) percent"))

            Text(L("settings.heic.quality.hint"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Shortcut Recorder

/// A control for recording keyboard shortcuts.
private struct ShortcutRecorder: View {
    let label: String
    let shortcut: KeyboardShortcut
    let isRecording: Bool
    let onRecord: () -> Void
    let onReset: () -> Void

    var body: some View {
        HStack {
            Text(label)

            Spacer()

            if isRecording {
                Text(L("settings.shortcut.recording"))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Button {
                    onRecord()
                } label: {
                    Text(shortcut.displayString)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }

            Button {
                onReset()
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(.borderless)
            .help(L("settings.shortcut.reset"))
            .disabled(isRecording)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(label): \(shortcut.displayString)"))
    }
}

// MARK: - Stroke Color Picker

/// Color picker for annotation stroke color.
private struct StrokeColorPicker: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        HStack {
            Text(L("settings.stroke.color"))

            Spacer()

            // Preset color buttons
            HStack(spacing: 4) {
                ForEach(SettingsViewModel.presetColors, id: \.self) { color in
                    Button {
                        viewModel.strokeColor = color
                    } label: {
                        Circle()
                            .fill(color)
                            .frame(width: 20, height: 20)
                            .overlay {
                                if colorsAreEqual(viewModel.strokeColor, color) {
                                    Circle()
                                        .stroke(Color.primary, lineWidth: 2)
                                }
                            }
                            .overlay {
                                // Add border for light colors
                                if color == .white || color == .yellow {
                                    Circle()
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(colorName(for: color)))
                }
            }

            // Custom color picker
            ColorPicker("", selection: $viewModel.strokeColor, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 30)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(L("settings.stroke.color")))
    }

    /// Compare colors approximately
    private func colorsAreEqual(_ a: Color, _ b: Color) -> Bool {
        // Convert to NSColor for comparison
        let nsA = NSColor(a).usingColorSpace(.deviceRGB)
        let nsB = NSColor(b).usingColorSpace(.deviceRGB)
        guard let colorA = nsA, let colorB = nsB else { return false }

        let tolerance: CGFloat = 0.01
        return abs(colorA.redComponent - colorB.redComponent) < tolerance &&
               abs(colorA.greenComponent - colorB.greenComponent) < tolerance &&
               abs(colorA.blueComponent - colorB.blueComponent) < tolerance
    }

    /// Get accessible color name
    private func colorName(for color: Color) -> String {
        switch color {
        case .red: return L("color.red")
        case .orange: return L("color.orange")
        case .yellow: return L("color.yellow")
        case .green: return L("color.green")
        case .blue: return L("color.blue")
        case .purple: return L("color.purple")
        case .pink: return L("color.pink")
        case .white: return L("color.white")
        case .black: return L("color.black")
        default: return L("color.custom")
        }
    }
}

// MARK: - Stroke Width Slider

/// Slider for adjusting annotation stroke width.
private struct StrokeWidthSlider: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L("settings.stroke.width"))
                Spacer()
                Text("\(viewModel.strokeWidth, specifier: "%.1f") pt")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            HStack(spacing: 12) {
                Slider(
                    value: $viewModel.strokeWidth,
                    in: SettingsViewModel.strokeWidthRange,
                    step: 0.5
                ) {
                    Text(L("settings.stroke.width"))
                }
                .accessibilityValue(Text("\(viewModel.strokeWidth, specifier: "%.1f") points"))

                // Preview of stroke width
                RoundedRectangle(cornerRadius: viewModel.strokeWidth / 2)
                    .fill(viewModel.strokeColor)
                    .frame(width: 40, height: viewModel.strokeWidth)
            }
        }
    }
}

// MARK: - Text Size Slider

/// Slider for adjusting text annotation font size.
private struct TextSizeSlider: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L("settings.text.size"))
                Spacer()
                Text("\(Int(viewModel.textSize)) pt")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            HStack(spacing: 12) {
                Slider(
                    value: $viewModel.textSize,
                    in: SettingsViewModel.textSizeRange,
                    step: 1
                ) {
                    Text(L("settings.text.size"))
                }
                .accessibilityValue(Text("\(Int(viewModel.textSize)) points"))

                // Preview of text size
                Text("Aa")
                    .font(.system(size: min(viewModel.textSize, 24)))
                    .foregroundStyle(viewModel.strokeColor)
                    .frame(width: 40)
            }
        }
    }
}

// MARK: - OCR Engine Picker

/// Picker for selecting the OCR engine.
private struct OCREnginePicker: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Picker(L("settings.ocr.engine"), selection: $viewModel.ocrEngine) {
            ForEach(OCREngineType.allCases, id: \.self) { engine in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(engine.localizedName)
                        if !engine.isAvailable && engine == .paddleOCR {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                                .font(.caption)
                        }
                    }
                    Text(engine.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .tag(engine)
                .if(!engine.isAvailable && engine == .paddleOCR) { view in
                    view.foregroundStyle(.secondary)
                }
            }
        }
        .pickerStyle(.inline)
        .onChange(of: viewModel.ocrEngine) { _, newValue in
            // If user selects an unavailable engine, show warning and revert to Vision
            // Use Task to avoid setting value during update
            if !newValue.isAvailable {
                Task { @MainActor in
                    viewModel.ocrEngine = .vision
                }
            }
        }
    }
}

// MARK: - View Conditional Modifier

extension View {
    /// Applies a transform to the view conditionally
    @ViewBuilder
    func `if`<Content: View>(
        _ condition: Bool,
        transform: (Self) -> Content
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Translation Engine Picker

/// Picker for selecting the translation engine.
private struct TranslationEnginePicker: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Picker(L("settings.translation.engine"), selection: $viewModel.translationEngine) {
            ForEach(TranslationEngineType.allCases, id: \.self) { engine in
                VStack(alignment: .leading, spacing: 4) {
                    Text(engine.localizedName)
                    Text(engine.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .tag(engine)
            }
        }
        .pickerStyle(.inline)
        .disabled(!TranslationEngineType.mtranServer.isAvailable)
    }
}

// MARK: - Translation Mode Picker

/// Picker for selecting the translation display mode.
private struct TranslationModePicker: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Picker(L("settings.translation.mode"), selection: $viewModel.translationMode) {
            ForEach(TranslationMode.allCases, id: \.self) { mode in
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.localizedName)
                    Text(mode.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .tag(mode)
            }
        }
        .pickerStyle(.inline)
    }
}

// MARK: - Source Language Picker

/// Picker for selecting the source language for translation.
private struct SourceLanguagePicker: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Picker(L("translation.language.source"), selection: $viewModel.translationSourceLanguage) {
            ForEach(viewModel.availableSourceLanguages, id: \.rawValue) { language in
                Text(language.localizedName)
                    .tag(language)
            }
        }
        .pickerStyle(.menu)
        .help(L("translation.language.source.hint"))
    }
}

// MARK: - Target Language Picker

/// Picker for selecting the target language for translation.
private struct TargetLanguagePicker: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        HStack {
            Text(L("translation.language.target"))

            Spacer()

            Menu {
                Button {
                    viewModel.translationTargetLanguage = nil
                } label: {
                    HStack {
                        Text(L("translation.language.follow.system"))
                        if viewModel.translationTargetLanguage == nil {
                            Image(systemName: "checkmark")
                        }
                    }
                }

                Divider()

                ForEach(viewModel.availableTargetLanguages, id: \.rawValue) { language in
                    Button {
                        viewModel.translationTargetLanguage = language
                    } label: {
                        HStack {
                            Text(language.localizedName)
                            if viewModel.translationTargetLanguage == language {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(targetLanguageDisplay)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .help(L("translation.language.target.hint"))
    }

    private var targetLanguageDisplay: String {
        if let targetLanguage = viewModel.translationTargetLanguage {
            return targetLanguage.localizedName
        }
        return L("translation.language.follow.system")
    }
}

// MARK: - App Language Picker

/// Picker for selecting the application display language.
private struct AppLanguagePicker: View {
    @State private var selectedLanguage: AppLanguage = .system
    @State private var isInitialized = false
    
    var body: some View {
        HStack {
            Text(L("settings.language"))
            
            Spacer()
            
            Picker("", selection: $selectedLanguage) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.displayName)
                        .tag(language)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(minWidth: 120)
            .onChange(of: selectedLanguage) { _, newValue in
                guard isInitialized else { return }
                Task { @MainActor in
                    LanguageManager.shared.currentLanguage = newValue
                }
            }
        }
        .onAppear {
            selectedLanguage = LanguageManager.shared.currentLanguage
            isInitialized = true
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    SettingsView(viewModel: SettingsViewModel())
        .frame(width: 500, height: 600)
}
#endif
