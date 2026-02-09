import SwiftUI

struct EngineSettingsContent: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 20) {
                GridRow {
                    Text(localized("settings.ocr.engine"))
                        .foregroundStyle(.secondary)
                    OCREnginePicker(viewModel: viewModel)
                }
                Divider().opacity(0.1)
                GridRow {
                    Text(localized("settings.translation.engine"))
                        .foregroundStyle(.secondary)
                    TranslationEnginePicker(viewModel: viewModel)
                }
                Divider().opacity(0.1)
                GridRow {
                    Text(localized("settings.translation.mode"))
                        .foregroundStyle(.secondary)
                    TranslationModePicker(viewModel: viewModel)
                }
            }
            .macos26LiquidGlass()

            VLMConfigurationSection(viewModel: viewModel)

            TranslationWorkflowSection(viewModel: viewModel)
        }
    }
}

struct OCREnginePicker: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Picker(localized("settings.ocr.engine"), selection: $viewModel.ocrEngine) {
                    ForEach(OCREngineType.allCases, id: \.self) { engine in
                        Text(engine.localizedName)
                            .tag(engine)
                    }
                }
                .pickerStyle(.segmented)

                if viewModel.ocrEngine == .paddleOCR && !viewModel.isPaddleOCRInstalled {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }

            if viewModel.ocrEngine == .paddleOCR {
                paddleOCRStatusView
            }
        }
    }

    private var paddleOCRStatusView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if viewModel.isPaddleOCRInstalled {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(localized("settings.paddleocr.installed"))
                        .foregroundStyle(.secondary)
                    if let version = viewModel.paddleOCRVersion {
                        Text("(\(version))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.orange)
                    Text(localized("settings.paddleocr.not.installed"))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    viewModel.refreshPaddleOCRStatus()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help(localized("settings.paddleocr.refresh"))
            }

            if !viewModel.isPaddleOCRInstalled {
                HStack(spacing: 8) {
                    Button {
                        viewModel.installPaddleOCR()
                    } label: {
                        if viewModel.isInstallingPaddleOCR {
                            ProgressView()
                                .controlSize(.small)
                            Text(localized("settings.paddleocr.installing"))
                        } else {
                            Image(systemName: "arrow.down.circle")
                            Text(localized("settings.paddleocr.install"))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(viewModel.isInstallingPaddleOCR)

                    Button {
                        viewModel.copyPaddleOCRInstallCommand()
                    } label: {
                        Image(systemName: "doc.on.doc")
                        Text(localized("settings.paddleocr.copy.command"))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if let error = viewModel.paddleOCRInstallError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(3)
                }

                Text(localized("settings.paddleocr.install.hint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct TranslationEnginePicker: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Picker(localized("settings.translation.engine"), selection: $viewModel.translationEngine) {
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

struct TranslationModePicker: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Picker(localized("settings.translation.mode"), selection: $viewModel.translationMode) {
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

struct VLMConfigurationSection: View {
    @Bindable var viewModel: SettingsViewModel
    @State private var showAPIKey = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(localized("settings.vlm.title"))
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                GridRow {
                    Text(localized("settings.vlm.provider"))
                        .foregroundStyle(.secondary)
                        .gridColumnAlignment(.trailing)
                    Picker("", selection: $viewModel.vlmProvider) {
                        ForEach(VLMProviderType.allCases) { provider in
                            Text(provider.localizedName).tag(provider)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 300)
                }

                GridRow {
                    Text(localized("settings.vlm.apiKey"))
                        .foregroundStyle(.secondary)
                        .gridColumnAlignment(.trailing)
                    HStack {
                        if showAPIKey {
                            TextField("", text: $viewModel.vlmAPIKey)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("", text: $viewModel.vlmAPIKey)
                                .textFieldStyle(.roundedBorder)
                        }
                        Button {
                            showAPIKey.toggle()
                        } label: {
                            Image(systemName: showAPIKey ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)
                    }
                    .frame(maxWidth: 300)
                }

                if !viewModel.vlmProvider.requiresAPIKey {
                    GridRow {
                        Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                        Text(localized("settings.vlm.apiKey.optional"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                GridRow {
                    Text(localized("settings.vlm.baseURL"))
                        .foregroundStyle(.secondary)
                        .gridColumnAlignment(.trailing)
                    TextField("", text: $viewModel.vlmBaseURL)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 300)
                }

                GridRow {
                    Text(localized("settings.vlm.model"))
                        .foregroundStyle(.secondary)
                        .gridColumnAlignment(.trailing)
                    TextField("", text: $viewModel.vlmModelName)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 300)
                }
            }

            Text(viewModel.vlmProvider.providerDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }
}

struct TranslationWorkflowSection: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(localized("settings.translation.workflow.title"))
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                GridRow {
                    Text(localized("settings.translation.preferred"))
                        .foregroundStyle(.secondary)
                        .gridColumnAlignment(.trailing)
                    Picker("", selection: $viewModel.preferredTranslationEngine) {
                        ForEach(PreferredTranslationEngine.allCases) { engine in
                            VStack(alignment: .leading) {
                                Text(engine.localizedName)
                                Text(engine.engineDescription)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(engine)
                        }
                    }
                    .pickerStyle(.inline)
                    .frame(maxWidth: 350)
                }

                if viewModel.preferredTranslationEngine == .mtranServer {
                    GridRow {
                        Text(localized("settings.translation.mtran.url"))
                            .foregroundStyle(.secondary)
                            .gridColumnAlignment(.trailing)
                        TextField("http://localhost:8989", text: $viewModel.mtranServerURL)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 300)
                    }
                }

                GridRow {
                    Text(localized("settings.translation.fallback"))
                        .foregroundStyle(.secondary)
                        .gridColumnAlignment(.trailing)
                    Toggle(isOn: $viewModel.translationFallbackEnabled) {
                        Text(localized("settings.translation.fallback.description"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .toggleStyle(.switch)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }
}
