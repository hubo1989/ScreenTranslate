import SwiftUI

struct LanguageSettingsContent: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
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
