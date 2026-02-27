import SwiftUI
import Sparkle
import Combine

struct AboutView: View {
    @State private var showingAcknowledgements = false
    @State private var isCheckingUpdates = false
    @State private var updateStatus: String?
    @State private var updateAvailable = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            infoSection
            Divider()
            updateStatusSection
            Divider()
            buttonSection
        }
        .frame(width: 400)
        .background(VisualEffectView(material: .windowBackground, blendingMode: .behindWindow))
        .sheet(isPresented: $showingAcknowledgements) {
            AcknowledgementsView()
        }
        // Sparkle 2.x uses delegate methods, not notifications
        // We reset checking state after a delay since Sparkle handles the UI
        .onChange(of: isCheckingUpdates) { _, newValue in
            if newValue {
                // Reset after delay - Sparkle shows its own update UI
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    await MainActor.run {
                        if isCheckingUpdates {
                            isCheckingUpdates = false
                        }
                    }
                }
            }
        }
    }

    private var headerSection: some View {
        HStack(spacing: 16) {
            Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                .resizable()
                .frame(width: 80, height: 80)

            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey("about.app.name"))
                    .font(.title)
                    .fontWeight(.semibold)

                Text(String(
                    format: NSLocalizedString("about.version.format", comment: ""),
                    appVersion, buildNumber
                ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(24)
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            infoRow(
                icon: "character.book.closed",
                label: NSLocalizedString("about.copyright", comment: "Copyright"),
                value: NSLocalizedString("about.copyright.value", comment: "")
            )

            infoRow(
                icon: "doc.text",
                label: NSLocalizedString("about.license", comment: "License"),
                value: NSLocalizedString("about.license.value", comment: "")
            )

            Link(destination: URL(string: "https://github.com/hubo1989/ScreenTranslate")!) {
                HStack(spacing: 8) {
                    Image(systemName: "link")
                        .frame(width: 20)
                        .foregroundStyle(.secondary)

                    Text(LocalizedStringKey("about.github.link"))
                        .font(.subheadline)
                        .foregroundStyle(.link)

                    Spacer()
                }
            }
            .buttonStyle(.plain)
        }
        .padding(24)
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(.secondary)

            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline)

            Spacer()
        }
    }

    private var updateStatusSection: some View {
        HStack(spacing: 8) {
            if isCheckingUpdates {
                ProgressView()
                    .controlSize(.small)
                Text(LocalizedStringKey("about.update.checking"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if let status = updateStatus {
                Image(systemName: updateAvailable ? "arrow.down.circle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(updateAvailable ? .blue : .green)
                Text(status)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    private var buttonSection: some View {
        HStack(spacing: 12) {
            Button {
                isCheckingUpdates = true
                // Trigger Sparkle update check
                NotificationCenter.default.post(name: .checkForUpdates, object: nil)
            } label: {
                if isCheckingUpdates {
                    HStack(spacing: 4) {
                        ProgressView()
                            .controlSize(.small)
                        Text(LocalizedStringKey("about.update.checking"))
                    }
                } else {
                    Label(
                        NSLocalizedString("about.check.for.updates", comment: "Check for Updates"),
                        systemImage: "arrow.clockwise"
                    )
                }
            }
            .disabled(isCheckingUpdates)

            Button {
                showingAcknowledgements = true
            } label: {
                Label(
                    NSLocalizedString("about.acknowledgements", comment: "Acknowledgements"),
                    systemImage: "heart.fill"
                )
            }

            Spacer()
        }
        .padding(24)
    }
}

extension Notification.Name {
    static let checkForUpdates = Notification.Name("checkForUpdates")
}

#Preview {
    AboutView()
}
