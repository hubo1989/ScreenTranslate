//
//  MultiEngineSettingsSection.swift
//  ScreenTranslate
//
//  Multi-engine configuration section for settings
//

import SwiftUI
import os.log

struct MultiEngineSettingsSection: View {
    @Bindable var viewModel: SettingsViewModel
    @State private var selectedEngine: TranslationEngineType?
    @State private var showingConfigSheet = false
    @State private var editingConfig: TranslationEngineConfig?
    @State private var compatibleSheetState: CompatibleSheetState?

    // Sheet state for compatible engine configuration
    struct CompatibleSheetState: Identifiable {
        let id = UUID()
        let config: CompatibleTranslationProvider.CompatibleConfig
        let index: Int
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Selection Mode (horizontal layout)
            selectionModeSection

            // Mode-specific configuration
            modeSpecificSection

            Divider()

            // Available Engines
            enginesSection
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - Selection Mode Section (Horizontal)

    @ViewBuilder
    private var selectionModeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localized("engine.config.title"))
                .font(.headline)

            // Horizontal button group
            HStack(spacing: 4) {
                ForEach(EngineSelectionMode.allCases) { mode in
                    Button {
                        viewModel.settings.engineSelectionMode = mode
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: mode.iconName)
                                .font(.caption)
                            Text(mode.localizedName)
                                .font(.subheadline)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(viewModel.settings.engineSelectionMode == mode ? Color.accentColor : Color.clear)
                        .foregroundStyle(viewModel.settings.engineSelectionMode == mode ? .white : .primary)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help(mode.modeDescription)
                }
            }
            .padding(4)
            .background(Color(.controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)
        }
    }

    // MARK: - Mode Specific Section

    @ViewBuilder
    private var modeSpecificSection: some View {
        switch viewModel.settings.engineSelectionMode {
        case .primaryWithFallback:
            primaryFallbackSection
        case .parallel:
            parallelEnginesSection
        case .quickSwitch:
            quickSwitchSection
        case .sceneBinding:
            sceneBindingSection
        }
    }

    // MARK: - Primary/Fallback Section

    @ViewBuilder
    private var primaryFallbackSection: some View {
        let allEngines = allEnabledEngines

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 24) {
                // Primary Engine
                VStack(alignment: .leading, spacing: 4) {
                    Text(localized("engine.config.primary"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: Binding(
                        get: { viewModel.settings.parallelEngines.first ?? .standard(.apple) },
                        set: { newValue in
                            if viewModel.settings.parallelEngines.isEmpty {
                                viewModel.settings.parallelEngines = [newValue]
                            } else {
                                viewModel.settings.parallelEngines[0] = newValue
                            }
                        }
                    )) {
                        ForEach(allEngines, id: \.id) { engine in
                            Text(engineDisplayName(engine)).tag(engine)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 140)
                }

                // Fallback Engine
                VStack(alignment: .leading, spacing: 4) {
                    Text(localized("engine.config.fallback"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: Binding(
                        get: { viewModel.settings.parallelEngines.count > 1 ? viewModel.settings.parallelEngines[1] : (allEngines.first ?? .standard(.apple)) },
                        set: { newValue in
                            if viewModel.settings.parallelEngines.count > 1 {
                                viewModel.settings.parallelEngines[1] = newValue
                            } else {
                                viewModel.settings.parallelEngines.append(newValue)
                            }
                        }
                    )) {
                        ForEach(allEngines, id: \.id) { engine in
                            Text(engineDisplayName(engine)).tag(engine)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 140)
                }
            }
        }
    }

    // MARK: - Quick Switch Section

    @ViewBuilder
    private var quickSwitchSection: some View {
        let allEngines = allEnabledEngines

        VStack(alignment: .leading, spacing: 8) {
            Text(localized("engine.config.switch.order"))
                .font(.caption)
                .foregroundStyle(.secondary)

            // Engine order list
            ForEach(Array(viewModel.settings.parallelEngines.enumerated()), id: \.offset) { index, engine in
                HStack(spacing: 8) {
                    // Order number
                    Text("\(index + 1)")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Color.accentColor)
                        .cornerRadius(9)

                    // Engine name
                    Text(engineDisplayName(engine))
                        .font(.subheadline)

                    Spacer()

                    // Replace button
                    Menu {
                        ForEach(allEngines, id: \.id) { engineOpt in
                            Button(engineDisplayName(engineOpt)) {
                                viewModel.settings.parallelEngines[index] = engineOpt
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                    .help(localized("engine.config.replace"))

                    // Remove button (if more than 1)
                    if viewModel.settings.parallelEngines.count > 1 {
                        Button {
                            viewModel.settings.parallelEngines.remove(at: index)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .help(localized("engine.config.remove"))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(6)
            }

            // Add engine button if less than enabled engines
            if viewModel.settings.parallelEngines.count < allEngines.count {
                Menu {
                    ForEach(allEngines, id: \.id) { engine in
                        if !viewModel.settings.parallelEngines.contains(engine) {
                            Button {
                                viewModel.settings.parallelEngines.append(engine)
                            } label: {
                                HStack {
                                    Image(systemName: engineIcon(for: engine))
                                    Text(engineDisplayName(engine))
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle")
                        Text(localized("engine.config.add"))
                    }
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                }
                .menuStyle(.borderlessButton)
            }
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
                if category == .compatible {
                    // Special handling for compatible engines - dynamic cards
                    compatibleEnginesSection
                } else {
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
        .sheet(item: $compatibleSheetState) { state in
            CompatibleEngineConfigSheet(
                config: state.config,
                index: state.index,
                isNew: state.index >= viewModel.settings.compatibleProviderConfigs.count,
                onSave: { savedConfig in
                    if state.index >= viewModel.settings.compatibleProviderConfigs.count {
                        viewModel.settings.compatibleProviderConfigs.append(savedConfig)
                    } else {
                        viewModel.settings.compatibleProviderConfigs[state.index] = savedConfig
                    }
                }
            )
        }
    }

    // MARK: - Compatible Engines Section

    @ViewBuilder
    private var compatibleEnginesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(EngineCategory.compatible.localizedName)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Dynamic compatible engine cards
            ForEach(Array(viewModel.settings.compatibleProviderConfigs.enumerated()), id: \.element.id) { index, config in
                compatibleEngineCard(config: config, index: index)
            }

            // Add button (max 5 engines)
            if viewModel.settings.compatibleProviderConfigs.count < 5 {
                addCompatibleEngineButton
            } else {
                Text(localized("engine.compatible.max.reached"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func compatibleEngineCard(config: CompatibleTranslationProvider.CompatibleConfig, index: Int) -> some View {
        Button {
            compatibleSheetState = CompatibleSheetState(config: config, index: index)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "gearshape.2")
                    .font(.body)
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(config.displayName)
                        .font(.subheadline)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Circle()
                            .fill(config.hasAPIKey ? Color.green : Color.orange)
                            .frame(width: 6, height: 6)
                        Text(config.hasAPIKey ? localized("engine.status.configured") : localized("engine.status.unconfigured"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Delete button
                Button {
                    deleteCompatibleEngine(at: index)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help(localized("engine.compatible.delete"))
            }
            .padding(8)
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.accentColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var addCompatibleEngineButton: some View {
        Button {
            compatibleSheetState = CompatibleSheetState(
                config: CompatibleTranslationProvider.CompatibleConfig.default,
                index: viewModel.settings.compatibleProviderConfigs.count
            )
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle")
                    .font(.body)
                Text(localized("engine.compatible.add"))
                    .font(.subheadline)
            }
            .foregroundStyle(Color.accentColor)
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(style: SwiftUI.StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(Color.gray.opacity(0.3))
            )
        }
        .buttonStyle(.plain)
    }

    private func deleteCompatibleEngine(at index: Int) {
        Task {
            do {
                let compositeId = "custom:\(index)"
                try await KeychainService.shared.deleteCredentials(forCompatibleId: compositeId)

                // Shift credentials for remaining engines
                for i in (index + 1)..<viewModel.settings.compatibleProviderConfigs.count {
                    let oldId = "custom:\(i)"
                    let newId = "custom:\(i - 1)"
                    if let creds = try? await KeychainService.shared.getCredentials(forCompatibleId: oldId) {
                        try await KeychainService.shared.saveCredentials(apiKey: creds.apiKey, forCompatibleId: newId)
                        try await KeychainService.shared.deleteCredentials(forCompatibleId: oldId)
                    }
                }

                // Clear cached provider for this engine
                await TranslationEngineRegistry.shared.removeCompatibleProvider(for: compositeId)

                await MainActor.run {
                    viewModel.settings.compatibleProviderConfigs.remove(at: index)
                }
            } catch {
                // Log error but don't remove config if credential migration fails
                Logger.settings.error("Failed to delete compatible engine: \(error.localizedDescription)")
                // Optionally show alert to user
            }
        }
    }

    @ViewBuilder
    private func engineCard(_ engine: TranslationEngineType) -> some View {
        let config = viewModel.settings.engineConfigs[engine] ?? .default(for: engine)
        // Built-in engines (apple, mtranServer) and Ollama don't need API keys
        // For others, we check if they require API key (simplified check - in real use would check keychain)
        let isConfigured = !engine.requiresAPIKey || config.isEnabled

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

    // MARK: - Parallel Engines Section (Select which engines to run)

    @ViewBuilder
    private var parallelEnginesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localized("engine.config.parallel.select"))
                .font(.caption)
                .foregroundStyle(.secondary)

            FlowLayout(spacing: 8) {
                ForEach(allEnabledEngines, id: \.id) { identifier in
                    engineChip(identifier)
                }
            }
        }
    }

    @ViewBuilder
    private func engineChip(_ identifier: EngineIdentifier) -> some View {
        HStack(spacing: 4) {
            Image(systemName: engineIcon(for: identifier))
                .font(.caption)
            Text(engineDisplayName(identifier))
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(viewModel.settings.parallelEngines.contains(identifier) ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(viewModel.settings.parallelEngines.contains(identifier) ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 1)
        )
        .onTapGesture {
            if viewModel.settings.parallelEngines.contains(identifier) {
                viewModel.settings.parallelEngines.removeAll { $0 == identifier }
            } else {
                viewModel.settings.parallelEngines.append(identifier)
            }
        }
    }

    // MARK: - Scene Binding Section

    @ViewBuilder
    private var sceneBindingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            let enabledEngines = viewModel.settings.engineConfigs.values.filter { $0.isEnabled }

            ForEach(TranslationScene.allCases) { scene in
                HStack {
                    Image(systemName: scene.iconName)
                        .frame(width: 20)
                    Text(scene.localizedName)
                        .frame(width: 100, alignment: .leading)

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
                    .frame(width: 130)
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
        case .gemini: return "sparkles"
        case .ollama: return "cpu"
        case .google: return "globe"
        case .deepl: return "character.bubble"
        case .baidu: return "network"
        case .custom: return "gearshape.2"
        }
    }

    private func engineIcon(for identifier: EngineIdentifier) -> String {
        switch identifier {
        case .standard(let type):
            return engineIcon(type)
        case .compatible:
            return "gearshape.2"
        }
    }

    // MARK: - Engine Helpers

    private var allEnabledEngines: [EngineIdentifier] {
        var engines: [EngineIdentifier] = []

        // Add enabled standard engines
        for config in viewModel.settings.engineConfigs.values where config.isEnabled {
            engines.append(.standard(config.id))
        }

        // Add enabled compatible engines
        for config in viewModel.settings.compatibleProviderConfigs where config.isEnabled {
            engines.append(.compatible(config.id))
        }

        return engines
    }

    private func engineDisplayName(_ identifier: EngineIdentifier) -> String {
        switch identifier {
        case .standard(let type):
            return type.localizedName
        case .compatible(let uuid):
            if let config = viewModel.settings.compatibleProviderConfigs.first(where: { $0.id == uuid }) {
                return config.displayName
            }
            return "Custom"
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height + spacing } - spacing
        return CGSize(width: proposal.width ?? 0, height: height > 0 ? height : 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for item in row.items {
                subviews[item.index].place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += item.size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var currentRow = Row()
        var currentX: CGFloat = 0
        let maxWidth = proposal.width ?? .infinity

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth, !currentRow.items.isEmpty {
                rows.append(currentRow)
                currentRow = Row()
                currentX = 0
            }

            currentRow.items.append(RowItem(index: index, size: size))
            currentRow.height = max(currentRow.height, size.height)
            currentX += size.width + spacing
        }

        if !currentRow.items.isEmpty {
            rows.append(currentRow)
        }

        return rows
    }

    struct Row {
        var items: [RowItem] = []
        var height: CGFloat = 0
    }

    struct RowItem {
        let index: Int
        let size: CGSize
    }
}
