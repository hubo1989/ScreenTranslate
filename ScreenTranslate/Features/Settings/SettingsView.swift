import SwiftUI
import AppKit

/// Main settings view with all preference controls.
/// Organized into sections: General, Export, Keyboard Shortcuts, and Annotations.
struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            // Permissions Section
            Section {
                PermissionRow(viewModel: viewModel)
            } header: {
                Label("Permissions", systemImage: "lock.shield")
            }

            // General Settings Section
            Section {
                SaveLocationPicker(viewModel: viewModel)
            } header: {
                Label("General", systemImage: "gearshape")
            }

            // Engine Settings Section
            Section {
                OCREnginePicker(viewModel: viewModel)
                TranslationEnginePicker(viewModel: viewModel)
                TranslationModePicker(viewModel: viewModel)
            } header: {
                Label("Engines", systemImage: "engine.combustion")
            }

            // Language Settings Section
            Section {
                SourceLanguagePicker(viewModel: viewModel)
                TargetLanguagePicker(viewModel: viewModel)
            } header: {
                Label("Languages", systemImage: "globe")
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
                Label("Export", systemImage: "square.and.arrow.up")
            }

            // Keyboard Shortcuts Section
            Section {
                ShortcutRecorder(
                    label: "Full Screen Capture",
                    shortcut: viewModel.fullScreenShortcut,
                    isRecording: viewModel.isRecordingFullScreenShortcut,
                    onRecord: { viewModel.startRecordingFullScreenShortcut() },
                    onReset: { viewModel.resetFullScreenShortcut() }
                )

                ShortcutRecorder(
                    label: "Selection Capture",
                    shortcut: viewModel.selectionShortcut,
                    isRecording: viewModel.isRecordingSelectionShortcut,
                    onRecord: { viewModel.startRecordingSelectionShortcut() },
                    onReset: { viewModel.resetSelectionShortcut() }
                )
            } header: {
                Label("Keyboard Shortcuts", systemImage: "keyboard")
            }

            // Annotation Settings Section
            Section {
                StrokeColorPicker(viewModel: viewModel)
                StrokeWidthSlider(viewModel: viewModel)
                TextSizeSlider(viewModel: viewModel)
            } header: {
                Label("Annotations", systemImage: "pencil.tip.crop.circle")
            }

            // Reset Section
            Section {
                Button(role: .destructive) {
                    viewModel.resetAllToDefaults()
                } label: {
                    Label("Reset All to Defaults", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 450, minHeight: 500)
        .alert("Error", isPresented: $viewModel.showErrorAlert) {
            Button("OK") {
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
                title: "Screen Recording",
                hint: "Required to capture screenshots",
                isGranted: viewModel.hasScreenRecordingPermission,
                isChecking: viewModel.isCheckingPermissions,
                onGrant: { viewModel.requestScreenRecordingPermission() }
            )

            Divider()

            // Folder Access permission
            PermissionItem(
                icon: "folder",
                title: "Save Location Access",
                hint: "Required to save screenshots to the selected folder",
                isGranted: viewModel.hasFolderAccessPermission,
                isChecking: viewModel.isCheckingPermissions,
                onGrant: { viewModel.requestFolderAccess() }
            )

            HStack {
                Spacer()
                Button {
                    viewModel.checkPermissions()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }
        }
        .onAppear {
            viewModel.checkPermissions()
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
                            Text("Granted")
                                .foregroundStyle(.secondary)
                        } else {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)

                            Button {
                                onGrant()
                            } label: {
                                Text("Grant Access")
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
        .accessibilityLabel(Text("\(title): \(isGranted ? "Granted" : "Not Granted")"))
    }
}

// MARK: - Save Location Picker

/// Picker for selecting the default save location.
private struct SaveLocationPicker: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Save Location")
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
                Text("Choose...")
            }

            Button {
                viewModel.revealSaveLocation()
            } label: {
                Image(systemName: "folder")
            }
            .help("Show in Finder")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Save Location: \(viewModel.saveLocationPath)"))
    }
}

// MARK: - Export Format Picker

/// Picker for selecting the default export format (PNG/JPEG).
private struct ExportFormatPicker: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Picker("Default Format", selection: $viewModel.defaultFormat) {
            Text("PNG").tag(ExportFormat.png)
            Text("JPEG").tag(ExportFormat.jpeg)
            Text("HEIC").tag(ExportFormat.heic)
        }
        .pickerStyle(.segmented)
        .accessibilityLabel(Text("Export Format"))
    }
}

// MARK: - JPEG Quality Slider

/// Slider for adjusting JPEG compression quality.
private struct JPEGQualitySlider: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("JPEG Quality")
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
                Text("JPEG Quality")
            } minimumValueLabel: {
                Text("10%")
                    .font(.caption)
            } maximumValueLabel: {
                Text("100%")
                    .font(.caption)
            }
            .accessibilityValue(Text("\(Int(viewModel.jpegQualityPercentage)) percent"))

            Text("Higher quality results in larger file sizes")
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
                Text("HEIC Quality")
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
                Text("HEIC Quality")
            } minimumValueLabel: {
                Text("10%")
                    .font(.caption)
            } maximumValueLabel: {
                Text("100%")
                    .font(.caption)
            }
            .accessibilityValue(Text("\(Int(viewModel.heicQualityPercentage)) percent"))

            Text("HEIC offers better compression than JPEG at similar quality")
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
                Text("Press keys...")
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
            .help("Reset to default")
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
            Text("Stroke Color")

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
        .accessibilityLabel(Text("Stroke Color"))
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
        case .red: return "Red"
        case .orange: return "Orange"
        case .yellow: return "Yellow"
        case .green: return "Green"
        case .blue: return "Blue"
        case .purple: return "Purple"
        case .pink: return "Pink"
        case .white: return "White"
        case .black: return "Black"
        default: return "Custom"
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
                Text("Stroke Width")
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
                    Text("Stroke Width")
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
                Text("Text Size")
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
                    Text("Text Size")
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
        Picker("OCR Engine", selection: $viewModel.ocrEngine) {
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
            if !newValue.isAvailable {
                viewModel.ocrEngine = .vision
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
        Picker("Translation Engine", selection: $viewModel.translationEngine) {
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
        Picker("Translation Mode", selection: $viewModel.translationMode) {
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
        Picker("Source Language", selection: $viewModel.translationSourceLanguage) {
            ForEach(viewModel.availableSourceLanguages, id: \.rawValue) { language in
                Text(language.localizedName)
                    .tag(language)
            }
        }
        .pickerStyle(.menu)
        .help("The language of the text you want to translate")
    }
}

// MARK: - Target Language Picker

/// Picker for selecting the target language for translation.
private struct TargetLanguagePicker: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        HStack {
            Text("Target Language")

            Spacer()

            Menu {
                Button {
                    viewModel.translationTargetLanguage = nil
                } label: {
                    HStack {
                        Text("Follow System")
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
        .help("The language to translate the text into")
    }

    private var targetLanguageDisplay: String {
        if let targetLanguage = viewModel.translationTargetLanguage {
            return targetLanguage.localizedName
        }
        return NSLocalizedString("translation.language.follow.system", comment: "Follow System")
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    SettingsView(viewModel: SettingsViewModel())
        .frame(width: 500, height: 600)
}
#endif
