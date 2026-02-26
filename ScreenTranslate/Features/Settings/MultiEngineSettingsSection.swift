//
//  MultiEngineSettingsSection.swift
//  ScreenTranslate
//
//  Multi-engine configuration section for settings
//

import SwiftUI

struct MultiEngineSettingsSection: View {
    @Bindable var viewModel: SettingsViewModel
    @State private var selectedEngine: TranslationEngineType?
    @State private var showingConfigSheet = false
    @State private var editingConfig: TranslationEngineConfig?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Selection Mode
            selectionModeSection

            Divider()

            // Available Engines
            enginesSection

            // Dynamic configuration based on mode
            if viewModel.settings.engineSelectionMode == .parallel {
                parallelEnginesSection
            } else if viewModel.settings.engineSelectionMode == .sceneBinding {
                sceneBindingSection
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - Selection Mode Section

    @ViewBuilder
    private var selectionModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localized("engine.selection.mode.title"))
                .font(.headline)

            Picker("", selection: Binding(
                get: { viewModel.settings.engineSelectionMode },
                set: { viewModel.settings.engineSelectionMode = $0 }
            )) {
                ForEach(EngineSelectionMode.allCases) { mode in
                    HStack {
                        Image(systemName: mode.iconName)
                        VStack(alignment: .leading) {
                            Text(mode.localizedName)
                            Text(mode.modeDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(mode)
                }
            }
            .pickerStyle(.radioGroup)
            .frame(maxWidth: 500)
        }
    }

    // MARK: - Engines Section

    @ViewBuilder
    private var enginesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(localized("engine.available.title"))
                    .font(.headline)
                Spacer()
            }

            // Group engines by category
            ForEach(EngineCategory.allCases, id: \.self) { category in
                let enginesInCategory = TranslationEngineType.allCases.filter { $0.category == category }
                if !enginesInCategory.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(category.localizedName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            ForEach(enginesInCategory, id: \.self) { engine in
                                engineCard(engine)
                            }
                        }
                    }
                }
            }
        }
        .sheet(item: $editingConfig) { config in
            let engine = config.id
            EngineConfigSheet(
                engine: engine,
                config: Binding(
                    get: { viewModel.settings.engineConfigs[engine] ?? .default(for: engine) },
                    set: { viewModel.settings.engineConfigs[engine] = $0 }
                )
            )
        }
    }

    @ViewBuilder
    private func engineCard(_ engine: TranslationEngineType) -> some View {
        let config = viewModel.settings.engineConfigs[engine] ?? .default(for: engine)
        // Built-in engines and Ollama are always "ready", others need configuration
        let isConfigured = !engine.requiresAPIKey

        Button {
            editingConfig = config
        } label: {
            HStack(spacing: 8) {
                Image(systemName: engineIcon(engine))
                    .font(.body)
                    .foregroundStyle(config.isEnabled ? Color.accentColor : Color.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(engine.localizedName)
                        .font(.subheadline)
                        .lineLimit(1)

                    // Show status for all engines
                    HStack(spacing: 4) {
                        Circle()
                            .fill(isConfigured ? Color.green : Color.orange)
                            .frame(width: 6, height: 6)
                        Text(isConfigured ? localized("engine.status.configured") : localized("engine.status.unconfigured"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if config.isEnabled {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            .padding(8)
            .background(config.isEnabled ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(config.isEnabled ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Parallel Engines Section

    @ViewBuilder
    private var parallelEnginesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localized("engine.parallel.title"))
                .font(.headline)

            Text(localized("engine.parallel.description"))
                .font(.caption)
                .foregroundStyle(.secondary)

            // List of enabled engines to select for parallel mode
            let enabledEngines = viewModel.settings.engineConfigs.values.filter { $0.isEnabled }

            ForEach(enabledEngines, id: \.id) { config in
                HStack {
                    Image(systemName: engineIcon(config.id))
                    Text(config.id.localizedName)

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { viewModel.settings.parallelEngines.contains(config.id) },
                        set: { isOn in
                            if isOn {
                                if !viewModel.settings.parallelEngines.contains(config.id) {
                                    viewModel.settings.parallelEngines.append(config.id)
                                }
                            } else {
                                viewModel.settings.parallelEngines.removeAll { $0 == config.id }
                            }
                        }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }
            }
        }
    }

    // MARK: - Scene Binding Section

    @ViewBuilder
    private var sceneBindingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localized("engine.scene.binding.title"))
                .font(.headline)

            Text(localized("engine.scene.binding.description"))
                .font(.caption)
                .foregroundStyle(.secondary)

            let enabledEngines = viewModel.settings.engineConfigs.values.filter { $0.isEnabled }

            ForEach(TranslationScene.allCases) { scene in
                HStack {
                    Image(systemName: scene.iconName)
                        .frame(width: 24)
                    Text(scene.localizedName)
                        .frame(width: 120, alignment: .leading)

                    Spacer()

                    // Primary engine picker
                    Picker("", selection: Binding(
                        get: { viewModel.settings.sceneBindings[scene]?.primaryEngine ?? .apple },
                        set: { newValue in
                            var binding = viewModel.settings.sceneBindings[scene] ?? .default(for: scene)
                            binding.primaryEngine = newValue
                            viewModel.settings.sceneBindings[scene] = binding
                        }
                    )) {
                        ForEach(enabledEngines, id: \.id) { config in
                            Text(config.id.localizedName).tag(config.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 150)

                    // Fallback toggle
                    Toggle("", isOn: Binding(
                        get: { viewModel.settings.sceneBindings[scene]?.fallbackEnabled ?? true },
                        set: { newValue in
                            var binding = viewModel.settings.sceneBindings[scene] ?? .default(for: scene)
                            binding.fallbackEnabled = newValue
                            viewModel.settings.sceneBindings[scene] = binding
                        }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .help(localized("engine.scene.fallback.tooltip"))
                }
            }
        }
    }

    // MARK: - Helpers

    private func engineIcon(_ engine: TranslationEngineType) -> String {
        switch engine {
        case .apple: return "apple.logo"
        case .mtranServer: return "server.rack"
        case .openai: return "brain.head.profile"
        case .claude: return "bubble.left.and.bubble.right"
        case .ollama: return "cpu"
        case .google: return "globe"
        case .deepl: return "character.bubble"
        case .baidu: return "network"
        case .custom: return "gearshape.2"
        }
    }
}
