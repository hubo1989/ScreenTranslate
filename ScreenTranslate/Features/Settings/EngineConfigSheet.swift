//
//  EngineConfigSheet.swift
//  ScreenTranslate
//
//  Configuration sheet for individual translation engines
//

import SwiftUI

struct EngineConfigSheet: View {
    let engine: TranslationEngineType
    @Binding var config: TranslationEngineConfig

    @Environment(\.dismiss) private var dismiss
    @State private var showAPIKey = false
    @State private var apiKey: String = ""
    @State private var appID: String = ""
    @State private var secretKey: String = ""
    @State private var baseURL: String = ""
    @State private var modelName: String = ""
    @State private var isTesting = false
    @State private var testResult: String?
    @State private var testSuccess = false

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: engineIcon)
                    .font(.title2)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading) {
                    Text(engine.localizedName)
                        .font(.headline)
                    Text(engine.engineDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider()

            // Configuration Form
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Enable Toggle
                    Toggle(isOn: $config.isEnabled) {
                        Text(localized("engine.config.enabled"))
                    }
                    .toggleStyle(.switch)

                    // API Key (if required)
                    if engine.requiresAPIKey {
                        if engine == .baidu {
                            // Baidu requires AppID and Secret Key
                            baiduCredentialsSection
                        } else {
                            apiKeySection
                        }
                    }

                    // MTranServer URL configuration
                    if engine == .mtranServer {
                        mtranServerURLSection
                    }

                    // Base URL (if applicable)
                    if engine.defaultBaseURL != nil || engine == .custom {
                        baseURLSection
                    }

                    // Model Name (for LLM engines)
                    if engine.defaultModelName != nil || engine == .custom {
                        modelNameSection
                    }
                }
                .padding()
            }

            Divider()

            // Footer
            HStack {
                // Test Button
                Button {
                    Task { await testConnection() }
                } label: {
                    HStack(spacing: 6) {
                        if isTesting {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Image(systemName: "bolt.fill")
                        Text(localized("engine.config.test"))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(isTesting || !canTest)

                if let result = testResult {
                    HStack(spacing: 4) {
                        Image(systemName: testSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(testSuccess ? Color.green : Color.red)
                        Text(result)
                            .font(.caption)
                            .foregroundStyle(testSuccess ? .secondary : Color.red)
                            .lineLimit(2)
                    }
                }

                Spacer()

                Button(localized("button.cancel")) {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button(localized("button.save")) {
                    saveConfig()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!config.isEnabled && !hasValidConfig)
            }
        }
        .padding()
        .frame(width: 500, height: 450)
        .onAppear {
            loadConfig()
        }
    }

    // MARK: - View Components

    @ViewBuilder
    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localized("engine.config.apiKey"))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                if showAPIKey {
                    TextField(localized("engine.config.apiKey.placeholder"), text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                } else {
                    SecureField(localized("engine.config.apiKey.placeholder"), text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                }
                Button {
                    showAPIKey.toggle()
                } label: {
                    Image(systemName: showAPIKey ? "eye.slash" : "eye")
                }
                .buttonStyle(.borderless)
            }
        }
    }

    @ViewBuilder
    private var baiduCredentialsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localized("engine.config.baidu.credentials"))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text(localized("engine.config.baidu.appID"))
                        .gridColumnAlignment(.trailing)
                    TextField("App ID", text: $appID)
                        .textFieldStyle(.roundedBorder)
                }

                GridRow {
                    Text(localized("engine.config.baidu.secretKey"))
                        .gridColumnAlignment(.trailing)
                    SecureField("Secret Key", text: $secretKey)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }

    @ViewBuilder
    private var mtranServerURLSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localized("engine.config.mtran.url"))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("http://localhost:8989", text: $baseURL)
                .textFieldStyle(.roundedBorder)
        }
    }

    @ViewBuilder
    private var baseURLSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localized("engine.config.baseURL"))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField(engine.defaultBaseURL ?? "", text: $baseURL)
                .textFieldStyle(.roundedBorder)
        }
    }

    @ViewBuilder
    private var modelNameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localized("engine.config.model"))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField(engine.defaultModelName ?? "", text: $modelName)
                .textFieldStyle(.roundedBorder)
        }
    }

    // MARK: - Computed Properties

    private var engineIcon: String {
        switch engine {
        case .apple: return "apple.logo"
        case .mtranServer: return "server.rack"
        case .openai: return "brain.head.profile"
        case .claude: return "bubble.left.and.bubble.right"
        case .gemini: return "sparkles"
        case .ollama: return "cpu"
        case .google: return "globe"
        case .deepl: return "character.bubble"
        case .baidu: return "network"
        case .custom: return "gearshape.2"
        }
    }

    private var canTest: Bool {
        if !config.isEnabled { return false }
        if engine.requiresAPIKey {
            if engine == .baidu {
                return !appID.isEmpty && !secretKey.isEmpty
            }
            return !apiKey.isEmpty
        }
        return true
    }

    private var hasValidConfig: Bool {
        if engine.requiresAPIKey {
            if engine == .baidu {
                return !appID.isEmpty && !secretKey.isEmpty
            }
            return !apiKey.isEmpty
        }
        return true
    }

    // MARK: - Actions

    private func loadConfig() {
        baseURL = config.options?.baseURL ?? engine.defaultBaseURL ?? ""
        modelName = config.options?.modelName ?? engine.defaultModelName ?? ""

        // Load credentials from keychain
        Task {
            if let credentials = try? await KeychainService.shared.getCredentials(for: engine) {
                apiKey = credentials.apiKey
                appID = credentials.appID ?? ""
                secretKey = credentials.additional?["secretKey"] ?? ""
            }
        }
    }

    private func saveConfig() {
        // Update options
        var options = config.options ?? EngineOptions.default(for: engine) ?? EngineOptions()
        if !baseURL.isEmpty {
            options.baseURL = baseURL
        }
        if !modelName.isEmpty {
            options.modelName = modelName
        }
        config.options = options

        // Save credentials to keychain
        Task {
            do {
                if engine == .baidu {
                    try await KeychainService.shared.saveCredentials(
                        apiKey: secretKey,
                        for: engine,
                        additionalData: ["appID": appID, "secretKey": secretKey]
                    )
                } else if engine.requiresAPIKey && !apiKey.isEmpty {
                    try await KeychainService.shared.saveCredentials(
                        apiKey: apiKey,
                        for: engine
                    )
                }
            } catch {
                print("Failed to save credentials: \(error)")
            }
        }
    }

    private func testConnection() async {
        isTesting = true
        testResult = nil

        do {
            // Save credentials temporarily for testing
            if engine.requiresAPIKey {
                if engine == .baidu {
                    try await KeychainService.shared.saveCredentials(
                        apiKey: secretKey,
                        for: engine,
                        additionalData: ["appID": appID, "secretKey": secretKey]
                    )
                } else {
                    try await KeychainService.shared.saveCredentials(
                        apiKey: apiKey,
                        for: engine
                    )
                }
            }

            // Test connection
            let success = await TranslationService.shared.testConnection(for: engine)

            await MainActor.run {
                testSuccess = success
                testResult = success
                    ? localized("engine.config.test.success")
                    : localized("engine.config.test.failed")
                isTesting = false
            }
        } catch {
            await MainActor.run {
                testSuccess = false
                testResult = error.localizedDescription
                isTesting = false
            }
        }
    }
}
