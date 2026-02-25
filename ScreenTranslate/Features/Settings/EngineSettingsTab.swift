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

                // Legacy Translation Workflow (for backward compatibility)
                TranslationWorkflowSection(viewModel: viewModel)
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
        .padding()
        .background(Color(.controlBackgroundColor))
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
                        TextField("localhost:8989", text: $viewModel.mtranServerURL)
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

            // Test Connection Button (only for MTranServer)
            if viewModel.preferredTranslationEngine == .mtranServer {
                HStack {
                    Button {
                        viewModel.testMTranServerConnection()
                    } label: {
                        HStack(spacing: 6) {
                            if viewModel.isTestingMTranServer {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Image(systemName: "bolt.fill")
                            Text(localized("settings.translation.mtran.test.button"))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(viewModel.isTestingMTranServer)

                    Spacer()

                    if let result = viewModel.mtranTestResult {
                        HStack(spacing: 4) {
                            Image(systemName: viewModel.mtranTestSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(viewModel.mtranTestSuccess ? Color.green : Color.red)
                            Text(result)
                                .font(.caption)
                                .foregroundStyle(viewModel.mtranTestSuccess ? .secondary : Color.red)
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
