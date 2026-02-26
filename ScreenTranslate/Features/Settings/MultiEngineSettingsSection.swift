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
        let enabledEngines = viewModel.settings.engineConfigs.values.filter { $0.isEnabled }

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 24) {
                // Primary Engine
                VStack(alignment: .leading, spacing: 4) {
                    Text(localized("engine.config.primary"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: Binding(
                        get: { viewModel.settings.parallelEngines.first ?? .apple },
                        set: { newValue in
                            if viewModel.settings.parallelEngines.isEmpty {
                                viewModel.settings.parallelEngines = [newValue]
                            } else {
                                viewModel.settings.parallelEngines[0] = newValue
                            }
                        }
                    )) {
                        ForEach(enabledEngines, id: \.id) { config in
                            Text(config.id.localizedName).tag(config.id)
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
                        get: { viewModel.settings.parallelEngines.count > 1 ? viewModel.settings.parallelEngines[1] : (enabledEngines.first?.id ?? .apple) },
                        set: { newValue in
                            if viewModel.settings.parallelEngines.count > 1 {
                                viewModel.settings.parallelEngines[1] = newValue
                            } else {
                                viewModel.settings.parallelEngines.append(newValue)
                            }
                        }
                    )) {
                        ForEach(enabledEngines, id: \.id) { config in
                            Text(config.id.localizedName).tag(config.id)
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
        let enabledEngines = viewModel.settings.engineConfigs.values.filter { $0.isEnabled }

        VStack(alignment: .leading, spacing: 8) {
            Text(localized("engine.config.switch.order"))
                .font(.caption)
                .foregroundStyle(.secondary)

            // Engine order list with drag-to-reorder
            ForEach(Array(viewModel.settings.parallelEngines.enumerated()), id: \.element) { index, engine in
                HStack(spacing: 8) {
                    // Order number
                    Text("\(index + 1)")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Color.accentColor)
                        .cornerRadius(9)

                    // Engine name
                    Text(engine.localizedName)
                        .font(.subheadline)

                    Spacer()

                    // Replace button
                    Menu {
                        ForEach(enabledEngines, id: \.id) { config in
                            Button(config.id.localizedName) {
                                viewModel.settings.parallelEngines[index] = config.id
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

                    // Drag handle
                    Image(systemName: "line.3.horizontal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .contentShape(Rectangle())
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(6)
                .moveDisabled(false)
            }
            .onMove { source, destination in
                viewModel.settings.parallelEngines.move(fromOffsets: source, toOffset: destination)
            }

            // Add engine button if less than enabled engines
            if viewModel.settings.parallelEngines.count < enabledEngines.count {
                Menu {
                    ForEach(enabledEngines, id: \.id) { config in
                        if !viewModel.settings.parallelEngines.contains(config.id) {
                            Button {
                                viewModel.settings.parallelEngines.append(config.id)
                            } label: {
                                HStack {
                                    Image(systemName: engineIcon(config.id))
                                    Text(config.id.localizedName)
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

    // MARK: - Parallel Engines Section (Select which engines to run)

    @ViewBuilder
    private var parallelEnginesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localized("engine.config.parallel.select"))
                .font(.caption)
                .foregroundStyle(.secondary)

            let enabledEngines = viewModel.settings.engineConfigs.values.filter { $0.isEnabled }

            FlowLayout(spacing: 8) {
                ForEach(enabledEngines, id: \.id) { config in
                    HStack(spacing: 4) {
                        Image(systemName: engineIcon(config.id))
                            .font(.caption)
                        Text(config.id.localizedName)
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(viewModel.settings.parallelEngines.contains(config.id) ? Color.accentColor.opacity(0.2) : Color.clear)
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(viewModel.settings.parallelEngines.contains(config.id) ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .onTapGesture {
                        if viewModel.settings.parallelEngines.contains(config.id) {
                            viewModel.settings.parallelEngines.removeAll { $0 == config.id }
                        } else {
                            viewModel.settings.parallelEngines.append(config.id)
                        }
                    }
                }
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
