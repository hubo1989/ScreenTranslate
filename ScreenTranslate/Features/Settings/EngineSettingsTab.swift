import SwiftUI

struct EngineSettingsContent: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // VLM Configuration (for image analysis)
                VLMConfigurationSection(viewModel: viewModel)

                // Multi-Engine Translation Configuration
                MultiEngineSettingsSection(viewModel: viewModel)
            }
            .padding()
        }
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
                    .frame(maxWidth: 400)
                }
            }

            // PaddleOCR specific section
            if viewModel.vlmProvider == .paddleocr {
                PaddleOCRStatusSection(viewModel: viewModel)
            } else {
                // Standard VLM configuration for API-based providers
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
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

                // Test API Connection Button
                HStack {
                    Button {
                        viewModel.testVLMAPI()
                    } label: {
                        HStack(spacing: 6) {
                            if viewModel.isTestingVLM {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Image(systemName: "bolt.fill")
                            Text(localized("settings.vlm.test.button"))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(viewModel.isTestingVLM)

                    Spacer()

                    if let result = viewModel.vlmTestResult {
                        HStack(spacing: 4) {
                            Image(systemName: viewModel.vlmTestSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(viewModel.vlmTestSuccess ? Color.green : Color.red)
                            Text(result)
                                .font(.caption)
                                .foregroundStyle(viewModel.vlmTestSuccess ? .secondary : Color.red)
                                .lineLimit(2)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - PaddleOCR Status Section

struct PaddleOCRStatusSection: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status
            HStack {
                Image(systemName: viewModel.isPaddleOCRInstalled ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(viewModel.isPaddleOCRInstalled ? .green : .orange)

                if viewModel.isPaddleOCRInstalled {
                    Text(localized("settings.paddleocr.ready"))
                        .foregroundStyle(.secondary)
                    if let version = viewModel.paddleOCRVersion, !version.isEmpty {
                        Text("(\(version))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                } else {
                    Text(localized("settings.paddleocr.not.installed.message"))
                        .foregroundStyle(.secondary)
                }
            }

            // Mode selection
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                GridRow {
                    Text(localized("settings.paddleocr.mode"))
                        .foregroundStyle(.secondary)
                        .gridColumnAlignment(.trailing)
                    Picker("", selection: $viewModel.paddleOCRMode) {
                        ForEach(PaddleOCRMode.allCases, id: \.self) { mode in
                            VStack(alignment: .leading) {
                                Text(mode.localizedName)
                            }.tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 300)
                }

                // Mode description
                GridRow {
                    Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                    Text(viewModel.paddleOCRMode.description)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                // Cloud API toggle
                GridRow {
                    Text(localized("settings.paddleocr.useCloud"))
                        .foregroundStyle(.secondary)
                        .gridColumnAlignment(.trailing)
                    Toggle("", isOn: $viewModel.paddleOCRUseCloud)
                        .toggleStyle(.checkbox)
                }

                // Cloud API settings (only show when useCloud is true)
                if viewModel.paddleOCRUseCloud {
                    GridRow {
                        Text(localized("settings.paddleocr.cloudBaseURL"))
                            .foregroundStyle(.secondary)
                            .gridColumnAlignment(.trailing)
                        TextField("", text: $viewModel.paddleOCRCloudBaseURL)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 300)
                    }

                    GridRow {
                        Text(localized("settings.paddleocr.cloudAPIKey"))
                            .foregroundStyle(.secondary)
                            .gridColumnAlignment(.trailing)
                        SecureField("", text: $viewModel.paddleOCRCloudAPIKey)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 300)
                    }
                }

                // MLX-VLM settings (only show when mode is precise and not using cloud)
                if viewModel.paddleOCRMode == .precise && !viewModel.paddleOCRUseCloud {
                    Divider()
                        .gridCellUnsizedAxes(.horizontal)

                    GridRow {
                        Text(localized("settings.paddleocr.useMLXVLM"))
                            .foregroundStyle(.secondary)
                            .gridColumnAlignment(.trailing)
                        Toggle("", isOn: $viewModel.paddleOCRUseMLXVLM)
                            .toggleStyle(.checkbox)
                            .onChange(of: viewModel.paddleOCRUseMLXVLM) { _, newValue in
                                if newValue {
                                    viewModel.checkMLXVLMServerStatus()
                                }
                            }
                    }

                    if viewModel.paddleOCRUseMLXVLM {
                        // MLX-VLM server status
                        GridRow {
                            Text(localized("settings.paddleocr.mlxVLMStatus"))
                                .foregroundStyle(.secondary)
                                .gridColumnAlignment(.trailing)
                            HStack {
                                if viewModel.isCheckingMLXVLMServer {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text(localized("settings.paddleocr.mlxVLMChecking"))
                                        .foregroundStyle(.secondary)
                                } else {
                                    Image(systemName: viewModel.isMLXVLMServerRunning ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(viewModel.isMLXVLMServerRunning ? .green : .red)
                                    Text(viewModel.isMLXVLMServerRunning
                                        ? localized("settings.paddleocr.mlxVLMRunning")
                                        : localized("settings.paddleocr.mlxVLMNotRunning"))
                                        .foregroundStyle(.secondary)
                                }

                                Button {
                                    viewModel.checkMLXVLMServerStatus()
                                } label: {
                                    Image(systemName: "arrow.clockwise")
                                }
                                .buttonStyle(.borderless)
                                .controlSize(.small)
                            }
                        }

                        GridRow {
                            Text(localized("settings.paddleocr.mlxVLMServerURL"))
                                .foregroundStyle(.secondary)
                                .gridColumnAlignment(.trailing)
                            TextField("", text: $viewModel.paddleOCRMLXVLMServerURL)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 300)
                        }

                        GridRow {
                            Text(localized("settings.paddleocr.mlxVLMModelName"))
                                .foregroundStyle(.secondary)
                                .gridColumnAlignment(.trailing)
                            TextField("", text: $viewModel.paddleOCRMLXVLMModelName)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 300)
                        }
                    }
                }
            }

            // Description
            Text(localized("settings.paddleocr.description"))
                .font(.caption)
                .foregroundStyle(.tertiary)

            // Install instructions or button
            if !viewModel.isPaddleOCRInstalled {
                VStack(alignment: .leading, spacing: 8) {
                    if viewModel.isInstallingPaddleOCR {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text(localized("settings.paddleocr.installing"))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        HStack(spacing: 12) {
                            Button(localized("settings.paddleocr.install.button")) {
                                viewModel.installPaddleOCR()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button(localized("settings.paddleocr.copy.command.button")) {
                                viewModel.copyPaddleOCRInstallCommand()
                            }
                            .buttonStyle(.borderless)
                            .controlSize(.small)
                        }

                        if let error = viewModel.paddleOCRInstallError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
        }
        .padding(.top, 8)
    }
}
