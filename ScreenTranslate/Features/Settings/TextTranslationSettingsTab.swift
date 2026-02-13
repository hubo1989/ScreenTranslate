import SwiftUI

struct TextTranslationSettingsContent: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        VStack(spacing: 16) {
            ShortcutRecorder(
                label: localized("settings.shortcut.text.selection.translation"),
                shortcut: viewModel.textSelectionTranslationShortcut,
                isRecording: viewModel.isRecordingTextSelectionTranslationShortcut,
                onRecord: { viewModel.startRecordingTextSelectionTranslationShortcut() },
                onReset: { viewModel.resetTextSelectionTranslationShortcut() }
            )
            Divider().opacity(0.1)
            ShortcutRecorder(
                label: localized("settings.shortcut.translate.and.insert"),
                shortcut: viewModel.translateAndInsertShortcut,
                isRecording: viewModel.isRecordingTranslateAndInsertShortcut,
                onRecord: { viewModel.startRecordingTranslateAndInsertShortcut() },
                onReset: { viewModel.resetTranslateAndInsertShortcut() }
            )
        }
        .macos26LiquidGlass()
    }
}

#if DEBUG
    #Preview {
        TextTranslationSettingsContent(viewModel: SettingsViewModel())
            .padding()
}
#endif
