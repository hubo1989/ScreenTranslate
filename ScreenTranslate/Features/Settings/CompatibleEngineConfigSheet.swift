//
//  CompatibleEngineConfigSheet.swift
//  ScreenTranslate
//
//  Configuration sheet for OpenAI-compatible translation engines
//

import SwiftUI

struct CompatibleEngineConfigSheet: View {
    let config: CompatibleTranslationProvider.CompatibleConfig
    let index: Int
    let isNew: Bool
    let onSave: (CompatibleTranslationProvider.CompatibleConfig) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showAPIKey = false
    @State private var apiKey: String = ""
    @State private var displayName: String = ""
    @State private var baseURL: String = ""
    @State private var modelName: String = ""
    @State private var hasAPIKey: Bool = true
    @State private var isEnabled: Bool = true
    @State private var isTesting = false
    @State private var testResult: String?
    @State private var testSuccess = false

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "gearshape.2")
                    .font(.title2)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading) {
                    Text(isNew ? localized("engine.compatible.new") : displayName)
                        .font(.headline)
                    Text(localized("engine.compatible.description"))
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
                    Toggle(isOn: $isEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(localized("engine.config.enabled"))
                                .font(.subheadline)
                            Text(localized("engine.config.enabled.description"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)

                    Divider()

                    // Display Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text(localized("engine.compatible.displayName"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        TextField(localized("engine.compatible.displayName.placeholder"), text: $displayName)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Base URL
                    VStack(alignment: .leading, spacing: 8) {
                        Text(localized("engine.config.baseURL"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        TextField("http://localhost:8000/v1", text: $baseURL)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Model Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text(localized("engine.config.model"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        TextField("gpt-4o-mini", text: $modelName)
                            .textFieldStyle(.roundedBorder)
                    }

                    // API Key Toggle
                    Toggle(isOn: $hasAPIKey) {
                        Text(localized("engine.compatible.requireApiKey"))
                    }
                    .toggleStyle(.switch)

                    // API Key (if required)
                    if hasAPIKey {
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
                .disabled(displayName.isEmpty || baseURL.isEmpty || modelName.isEmpty)
            }
        }
        .padding()
        .frame(width: 500, height: 480)
        .onAppear {
            loadConfig()
        }
    }

    // MARK: - Computed Properties

    private var canTest: Bool {
        !displayName.isEmpty && !baseURL.isEmpty && !modelName.isEmpty && (!hasAPIKey || !apiKey.isEmpty)
    }

    // MARK: - Actions

    private func loadConfig() {
        displayName = config.displayName
        baseURL = config.baseURL
        modelName = config.modelName
        hasAPIKey = config.hasAPIKey
        isEnabled = config.isEnabled

        // Load credentials from keychain
        Task {
            let compositeId = config.keychainId
            if let credentials = try? await KeychainService.shared.getCredentials(forCompatibleId: compositeId) {
                await MainActor.run {
                    apiKey = credentials.apiKey
                }
            }
        }
    }

    private func saveConfig() {
        // For new engines, generate a new ID; for existing, keep the original
        let configId = isNew ? UUID() : config.id

        let savedConfig = CompatibleTranslationProvider.CompatibleConfig(
            id: configId,
            displayName: displayName,
            baseURL: baseURL,
            modelName: modelName,
            hasAPIKey: hasAPIKey,
            isEnabled: isEnabled
        )

        onSave(savedConfig)

        // Save credentials to keychain
        Task {
            let compositeId = savedConfig.keychainId
            if hasAPIKey && !apiKey.isEmpty {
                try? await KeychainService.shared.saveCredentials(apiKey: apiKey, forCompatibleId: compositeId)
            } else {
                try? await KeychainService.shared.deleteCredentials(forCompatibleId: compositeId)
            }
        }
    }

    private func testConnection() async {
        isTesting = true
        testResult = nil

        do {
            // Save credentials temporarily for testing
            if hasAPIKey {
                let compositeId = config.keychainId
                try await KeychainService.shared.saveCredentials(apiKey: apiKey, forCompatibleId: compositeId)
            }

            // Create a temporary config for testing
            let tempConfig = CompatibleTranslationProvider.CompatibleConfig(
                id: config.id,
                displayName: displayName,
                baseURL: baseURL,
                modelName: modelName,
                hasAPIKey: hasAPIKey,
                isEnabled: isEnabled
            )

            // Test by creating a provider and calling checkConnection
            let engineConfig = TranslationEngineConfig.default(for: .custom)
            let provider = try await CompatibleTranslationProvider(
                config: engineConfig,
                compatibleConfig: tempConfig,
                instanceIndex: index,
                keychain: KeychainService.shared
            )

            let success = await provider.checkConnection()

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
