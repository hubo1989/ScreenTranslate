import SwiftUI

struct OnboardingFeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

struct OnboardingInfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)
            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

struct OnboardingNavigationButtons: View {
    let canGoPrevious: Bool
    let canGoNext: Bool
    let isLastStep: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            if canGoPrevious {
                Button {
                    onPrevious()
                } label: {
                    Text(NSLocalizedString("onboarding.back", comment: ""))
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            if canGoNext && !isLastStep {
                Button {
                    onNext()
                } label: {
                    Text(NSLocalizedString("onboarding.continue", comment: ""))
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

import SwiftUI
import PermissionFlow

struct OnboardingPermissionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let isGranted: Bool
    let pane: PermissionFlowPane
    let requestAction: () -> Void

    @StateObject private var controller = PermissionFlowController()
    @State private var buttonFrame: CGRect = .zero

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(isGranted ? .green : .orange)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(isGranted
                     ? NSLocalizedString("onboarding.permission.granted", comment: "")
                     : NSLocalizedString("onboarding.permission.not.granted", comment: ""))
                    .font(.caption)
                    .foregroundStyle(isGranted ? .green : .secondary)
            }

            Spacer()

            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title2)
            } else {
                Button {
                    let screenRect = convertToScreen(buttonFrame)
                    controller.authorize(
                        pane: pane,
                        suggestedAppURLs: [Bundle.main.bundleURL],
                        sourceFrameInScreen: screenRect
                    )
                    requestAction()
                } label: {
                    Text(NSLocalizedString("onboarding.permission.grant", comment: ""))
                }
                .buttonStyle(.borderedProminent)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear {
                                buttonFrame = geo.frame(in: .global)
                            }
                            .onChange(of: geo.frame(in: .global)) { _, newValue in
                                buttonFrame = newValue
                            }
                    }
                )
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(.rect(cornerRadius: 8))
        .onChange(of: isGranted) { _, newValue in
            if newValue {
                controller.closePanel()
            }
        }
    }

    private func convertToScreen(_ rect: CGRect) -> CGRect {
        guard let window = NSApp.keyWindow else { return rect }
        return window.convertToScreen(rect)
    }
}
