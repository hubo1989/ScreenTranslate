import SwiftUI

struct LanguageSettingsContent: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Global Translation Languages
            VStack(alignment: .leading, spacing: 8) {
                Text(localized("settings.section.languages"))
                    .font(.headline)
                HStack(spacing: 16) {
                    VStack(alignment: .leading) {
                        Text(localized("translation.language.source"))
                            .font(.caption).foregroundStyle(.secondary)
                        SourceLanguagePicker(viewModel: viewModel)
                    }
                    Image(systemName: "arrow.right.circle.fill").font(.title2).foregroundStyle(
                        .secondary.opacity(0.5))
                    VStack(alignment: .leading) {
                        Text(localized("translation.language.target"))
                            .font(.caption).foregroundStyle(.secondary)
                        TargetLanguagePicker(viewModel: viewModel)
                    }
                }
            }

            Divider().opacity(0.3)

            // Translate and Insert Languages
            VStack(alignment: .leading, spacing: 8) {
                Text(localized("settings.translateAndInsert.language.section"))
                    .font(.headline)
                HStack(spacing: 16) {
                    VStack(alignment: .leading) {
                        Text(localized("settings.translateAndInsert.language.source"))
                            .font(.caption).foregroundStyle(.secondary)
                        TranslateAndInsertSourceLanguagePicker(viewModel: viewModel)
                    }
                    Image(systemName: "arrow.right.circle.fill").font(.title2).foregroundStyle(
                        .secondary.opacity(0.5))
                    VStack(alignment: .leading) {
                        Text(localized("settings.translateAndInsert.language.target"))
                            .font(.caption).foregroundStyle(.secondary)
                        TranslateAndInsertTargetLanguagePicker(viewModel: viewModel)
                    }
                }
            }
        }
        .macos26LiquidGlass()
    }
}

struct SourceLanguagePicker: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Picker(localized("translation.language.source"), selection: $viewModel.translationSourceLanguage) {
            ForEach(viewModel.availableSourceLanguages, id: \.rawValue) { language in
                Text(language.localizedName)
                    .tag(language)
            }
        }
        .pickerStyle(.menu)
        .help(localized("translation.language.source.hint"))
    }
}

struct TargetLanguagePicker: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        HStack {
            Text(localized("translation.language.target"))

            Spacer()

            Menu {
                Button {
                    viewModel.translationTargetLanguage = nil
                } label: {
                    HStack {
                        Text(localized("translation.language.follow.system"))
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
        .help(localized("translation.language.target.hint"))
    }

    private var targetLanguageDisplay: String {
        if let targetLanguage = viewModel.translationTargetLanguage {
            return targetLanguage.localizedName
        }
        return localized("translation.language.follow.system")
    }
}

// MARK: - Translate and Insert Language Pickers

struct TranslateAndInsertSourceLanguagePicker: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Picker(localized("settings.translateAndInsert.language.source"), selection: $viewModel.translateAndInsertSourceLanguage) {
            ForEach(viewModel.availableSourceLanguages, id: \.rawValue) { language in
                Text(language.localizedName)
                    .tag(language)
            }
        }
        .pickerStyle(.menu)
    }
}

struct TranslateAndInsertTargetLanguagePicker: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        HStack {
            Text(localized("settings.translateAndInsert.language.target"))

            Spacer()

            Menu {
                Button {
                    viewModel.translateAndInsertTargetLanguage = nil
                } label: {
                    HStack {
                        Text(localized("translation.language.follow.system"))
                        if viewModel.translateAndInsertTargetLanguage == nil {
                            Image(systemName: "checkmark")
                        }
                    }
                }

                Divider()

                ForEach(viewModel.availableTargetLanguages, id: \.rawValue) { language in
                    Button {
                        viewModel.translateAndInsertTargetLanguage = language
                    } label: {
                        HStack {
                            Text(language.localizedName)
                            if viewModel.translateAndInsertTargetLanguage == language {
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
    }

    private var targetLanguageDisplay: String {
        if let targetLanguage = viewModel.translateAndInsertTargetLanguage {
            return targetLanguage.localizedName
        }
        return localized("translation.language.follow.system")
    }
}
