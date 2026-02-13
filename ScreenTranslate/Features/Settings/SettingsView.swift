import AppKit
import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    @State private var refreshID = UUID()
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        NavigationSplitView {
            List(SettingsTab.allCases, selection: $selectedTab) { tab in
                NavigationLink(value: tab) {
                    Label {
                        Text(tab.displayName)
                    } icon: {
                        Image(systemName: tab.icon)
                            .foregroundStyle(tab.color)
                    }
                }
                .padding(.vertical, 4)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            VStack(spacing: 0) {
                HStack {
                    Text(selectedTab.displayName)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Spacer()
                }
                .padding(.horizontal, 30)
                .padding(.top, 44)
                .padding(.bottom, 20)

                ScrollView {
                    VStack(spacing: 24) {
                        switch selectedTab {
                        case .general:
                            GeneralSettingsContent(viewModel: viewModel)
                        case .engines:
                            EngineSettingsContent(viewModel: viewModel)
                        case .languages:
                            LanguageSettingsContent(viewModel: viewModel)
                        case .shortcuts:
                            ShortcutSettingsContent(viewModel: viewModel)
                        case .textTranslation:
                            TextTranslationSettingsContent(viewModel: viewModel)
                        case .advanced:
                            AdvancedSettingsContent(viewModel: viewModel)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .background(Color(.windowBackgroundColor))
        }
        .frame(width: 800, height: 600)
        .background(Color(.windowBackgroundColor))
        .id(refreshID)
        .onReceive(
            NotificationCenter.default.publisher(for: LanguageManager.languageDidChangeNotification)
        ) { _ in
            refreshID = UUID()
        }
        .alert(localized("error.title"), isPresented: $viewModel.showErrorAlert) {
            Button(localized("button.ok")) {
                viewModel.errorMessage = nil
            }
        } message: {
            if let message = viewModel.errorMessage {
                Text(message)
            }
        }
    }
}

extension View {
    @ViewBuilder
    func `if`<Content: View>(
        _ condition: Bool,
        transform: (Self) -> Content
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

#if DEBUG
    #Preview {
        SettingsView(viewModel: SettingsViewModel())
            .frame(width: 500, height: 600)
    }
#endif
