import SwiftUI

struct AcknowledgementsView: View {
    @Environment(\.dismiss) private var dismiss

    private let acknowledgements: [(name: String, license: String, url: String)] = [
        ("Sparkle", "MIT", "https://github.com/sparkle-project/Sparkle"),
    ]

    private let upstreamProject: (name: String, author: String, url: String) = (
        "ScreenCapture",
        "sadopc",
        "https://github.com/sadopc/ScreenCapture"
    )

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            listView
            Divider()
            footerView
        }
        .frame(width: 450, height: 450)
        .background(VisualEffectView(material: .windowBackground, blendingMode: .behindWindow))
    }

    private var headerView: some View {
        HStack {
            Text(NSLocalizedString("about.acknowledgements.title", comment: "Acknowledgements"))
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
    }

    private var listView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Upstream project section
                upstreamSection

                Divider()

                Text(NSLocalizedString("about.acknowledgements.intro", comment: "This software uses the following open source libraries:"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ForEach(acknowledgements, id: \.name) { item in
                    acknowledgementCard(item)
                }
            }
            .padding(20)
        }
    }

    private var upstreamSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("about.acknowledgements.upstream", comment: "Based on"))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(upstreamProject.name)
                        .font(.headline)

                    Spacer()

                    Text(String(format: NSLocalizedString("about.acknowledgements.author.format", comment: ""), upstreamProject.author))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let url = URL(string: upstreamProject.url) {
                    Link(destination: url) {
                        Text(upstreamProject.url)
                            .font(.caption)
                            .foregroundStyle(.link)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(Color.accentColor.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
            )
        }
    }

    private func acknowledgementCard(_ item: (name: String, license: String, url: String)) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.name)
                    .font(.headline)

                Spacer()

                Text(item.license)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(Capsule())
            }

            if let url = URL(string: item.url) {
                Link(destination: url) {
                    Text(item.url)
                        .font(.caption)
                        .foregroundStyle(.link)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .buttonStyle(.plain)
            } else {
                Text(item.url)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(12)
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var footerView: some View {
        HStack {
            Spacer()
            Button(NSLocalizedString("about.close", comment: "Close")) {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(20)
    }
}

#Preview {
    AcknowledgementsView()
}
