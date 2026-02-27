import SwiftUI

struct AboutView: View {
    @State private var showingAcknowledgements = false

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
            buttonSection
        }
        .frame(width: 400)
        .background(VisualEffectView(material: .windowBackground, blendingMode: .behindWindow))
        .sheet(isPresented: $showingAcknowledgements) {
            AcknowledgementsView()
        }
    }

    private var headerSection: some View {
        HStack(spacing: 16) {
            Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                .resizable()
                .frame(width: 80, height: 80)

            VStack(alignment: .leading, spacing: 4) {
                Text("ScreenTranslate")
                    .font(.title)
                    .fontWeight(.semibold)

                Text("Version \(appVersion) (\(buildNumber))")
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
                value: "© 2026 All rights reserved"
            )

            infoRow(
                icon: "doc.text",
                label: NSLocalizedString("about.license", comment: "License"),
                value: "MIT License"
            )

            Link(destination: URL(string: "https://github.com/hubo1989/ScreenTranslate")!) {
                HStack(spacing: 8) {
                    Image(systemName: "link")
                        .frame(width: 20)
                        .foregroundStyle(.secondary)

                    Text("GitHub: hubo1989/ScreenTranslate")
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

    private var buttonSection: some View {
        HStack(spacing: 12) {
            Button {
                // Check for updates action - will be connected to Sparkle
                NotificationCenter.default.post(name: .checkForUpdates, object: nil)
            } label: {
                Label(
                    NSLocalizedString("about.check.for.updates", comment: "Check for Updates"),
                    systemImage: "arrow.clockwise"
                )
            }

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
