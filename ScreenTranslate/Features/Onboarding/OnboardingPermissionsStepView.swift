import SwiftUI

struct OnboardingPermissionsStepView: View {
    let hasScreenRecordingPermission: Bool
    let hasAccessibilityPermission: Bool
    let canGoPrevious: Bool
    let canGoNext: Bool
    let isLastStep: Bool
    let permissionCheckTimedOut: Bool
    let onRequestScreenRecording: () -> Void
    let onOpenScreenRecordingSettings: () -> Void
    let onRequestAccessibility: () -> Void
    let onOpenAccessibilitySettings: () -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 50))
                .foregroundStyle(.orange)

            VStack(spacing: 12) {
                Text(NSLocalizedString("onboarding.permissions.title", comment: ""))
                    .font(.largeTitle)
                    .fontWeight(.semibold)

                Text(NSLocalizedString("onboarding.permissions.message", comment: ""))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 16) {
                OnboardingPermissionRow(
                    icon: "video.fill",
                    title: NSLocalizedString("onboarding.permission.screen.recording", comment: ""),
                    subtitle: NSLocalizedString("onboarding.permission.screen.recording.subtitle", comment: ""),
                    isGranted: hasScreenRecordingPermission,
                    requestAction: onRequestScreenRecording,
                    openSettingsAction: onOpenScreenRecordingSettings
                )

                OnboardingPermissionRow(
                    icon: "command.square.fill",
                    title: NSLocalizedString("onboarding.permission.accessibility", comment: ""),
                    subtitle: NSLocalizedString("onboarding.permission.accessibility.subtitle", comment: ""),
                    isGranted: hasAccessibilityPermission,
                    requestAction: onRequestAccessibility,
                    openSettingsAction: onOpenAccessibilitySettings
                )
            }

            if permissionCheckTimedOut {
                Text(NSLocalizedString("onboarding.permissions.timeout.hint", comment: ""))
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Text(NSLocalizedString("onboarding.permissions.hint", comment: ""))
                .font(.caption)
                .foregroundStyle(.secondary)

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

                Button {
                    onSkip()
                } label: {
                    Text(NSLocalizedString("onboarding.skip.permissions", comment: ""))
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
                .disabled(canGoNext)

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
        .padding(32)
    }
}
