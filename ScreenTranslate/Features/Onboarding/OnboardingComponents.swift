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

struct OnboardingPermissionRow: View {
    let icon: String
    let title: String
    let isGranted: Bool
    let requestAction: () -> Void
    let openSettingsAction: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(isGranted ? .green : .orange)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
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
                    openSettingsAction()
                    requestAction()
                } label: {
                    Text(NSLocalizedString("onboarding.permission.grant", comment: ""))
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(.rect(cornerRadius: 8))
    }
}
