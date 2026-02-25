//
//  PromptSettingsView.swift
//  ScreenTranslate
//
//  Prompt configuration view for translation engines
//

import SwiftUI

struct PromptSettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    @State private var editingTarget: PromptEditTarget?
    @State private var editingPrompt: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Engine Prompts Section
            enginePromptsSection

            Divider()

            // Scene Prompts Section
            scenePromptsSection

            // Default Prompt Preview
            defaultPromptSection
        }
        .padding()
        .sheet(item: $editingTarget) { target in
            PromptEditorSheet(
                target: target,
                prompt: $editingPrompt,
                onSave: {
                    savePrompt(for: target, prompt: editingPrompt)
                }
            )
        }
    }

    // MARK: - Engine Prompts Section

    @ViewBuilder
    private var enginePromptsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localized("prompt.engine.title"))
                .font(.headline)

            Text(localized("prompt.engine.description"))
                .font(.caption)
                .foregroundStyle(.secondary)

            // LLM Engines that support custom prompts
            let llmEngines: [TranslationEngineType] = [.openai, .claude, .ollama, .custom]

            ForEach(llmEngines, id: \.self) { engine in
                HStack {
                    Image(systemName: engineIcon(engine))
                        .frame(width: 24)

                    Text(engine.localizedName)

                    Spacer()

                    // Show if custom prompt is set
                    if let prompt = viewModel.settings.promptConfig.enginePrompts[engine], !prompt.isEmpty {
                        Image(systemName: "pencil.circle.fill")
                            .foregroundStyle(.tint)
                    }

                    Button(localized("prompt.button.edit")) {
                        editingTarget = .engine(engine)
                        editingPrompt = viewModel.settings.promptConfig.enginePrompts[engine] ?? ""
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - Scene Prompts Section

    @ViewBuilder
    private var scenePromptsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localized("prompt.scene.title"))
                .font(.headline)

            Text(localized("prompt.scene.description"))
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(TranslationScene.allCases) { scene in
                HStack {
                    Image(systemName: scene.iconName)
                        .frame(width: 24)

                    Text(scene.localizedName)

                    Spacer()

                    // Show if custom prompt is set
                    if let prompt = viewModel.settings.promptConfig.scenePrompts[scene], !prompt.isEmpty {
                        Image(systemName: "pencil.circle.fill")
                            .foregroundStyle(.tint)
                    }

                    Button(localized("prompt.button.edit")) {
                        editingTarget = .scene(scene)
                        editingPrompt = viewModel.settings.promptConfig.scenePrompts[scene] ?? ""
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - Default Prompt Section

    @ViewBuilder
    private var defaultPromptSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localized("prompt.default.title"))
                .font(.headline)

            Text(localized("prompt.default.description"))
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView {
                Text(TranslationPromptConfig.defaultPrompt)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(8)
            }
            .frame(height: 150)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - Actions

    private func savePrompt(for target: PromptEditTarget, prompt: String) {
        var config = viewModel.settings.promptConfig

        switch target {
        case .engine(let engine):
            if prompt.isEmpty {
                config.enginePrompts.removeValue(forKey: engine)
            } else {
                config.enginePrompts[engine] = prompt
            }
        case .scene(let scene):
            if prompt.isEmpty {
                config.scenePrompts.removeValue(forKey: scene)
            } else {
                config.scenePrompts[scene] = prompt
            }
        }

        viewModel.settings.promptConfig = config
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

// MARK: - Prompt Edit Target

enum PromptEditTarget: Identifiable {
    case engine(TranslationEngineType)
    case scene(TranslationScene)

    var id: String {
        switch self {
        case .engine(let engine):
            return "engine-\(engine.rawValue)"
        case .scene(let scene):
            return "scene-\(scene.rawValue)"
        }
    }

    var title: String {
        switch self {
        case .engine(let engine):
            return engine.localizedName
        case .scene(let scene):
            return scene.localizedName
        }
    }
}

// MARK: - Prompt Editor Sheet

struct PromptEditorSheet: View {
    let target: PromptEditTarget
    @Binding var prompt: String
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var localPrompt: String = ""

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text(localized("prompt.editor.title"))
                    .font(.headline)
                Spacer()
                Text(target.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Editor
            TextEditor(text: $localPrompt)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 200)
                .padding(4)
                .background(Color(.textBackgroundColor))
                .cornerRadius(8)

            // Variable Hints
            VStack(alignment: .leading, spacing: 8) {
                Text(localized("prompt.editor.variables"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(TranslationPromptConfig.templateVariables) { variable in
                        Button {
                            insertVariable(variable.name)
                        } label: {
                            Text(variable.name)
                                .font(.system(.caption, design: .monospaced))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help(variable.description)
                    }
                }
            }

            Divider()

            // Footer
            HStack {
                Button(localized("prompt.button.reset")) {
                    localPrompt = ""
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(localized("button.cancel")) {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button(localized("button.save")) {
                    prompt = localPrompt
                    onSave()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 600, height: 400)
        .onAppear {
            localPrompt = prompt
        }
    }

    private func insertVariable(_ variable: String) {
        localPrompt += variable
    }
}
