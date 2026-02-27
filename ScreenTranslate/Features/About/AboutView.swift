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
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SUUpdaterDidStartCheckingForUpdates"))) { _ in
            isCheckingUpdates = true
            updateStatus = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SUUpdaterDidFinishCheckingForUpdates"))) { _ in
            isCheckingUpdates = false
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SUUpdaterDidUpdateStatus"))) { _ in
            isCheckingUpdates = false
            updateAvailable = true
            updateStatus = NSLocalizedString("about.update.available", comment: "Update available")
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SUUpdaterNoUpdateAvailable"))) { _ in
            isCheckingUpdates = false
            updateAvailable = false
            updateStatus = NSLocalizedString("about.update.uptodate", comment: "You're up to date")
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SUUpdaterDidFailToCheckForUpdates"))) { _ in
            isCheckingUpdates = false
            updateStatus = NSLocalizedString("about.update.failed", comment: "Check failed")
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
                updateStatus = nil
                // Check for updates action - will be connected to Sparkle
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
