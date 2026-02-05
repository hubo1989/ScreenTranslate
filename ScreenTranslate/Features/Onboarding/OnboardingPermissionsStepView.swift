import SwiftUI

struct OnboardingPermissionsStepView: View {
    let hasScreenRecordingPermission: Bool
    let hasAccessibilityPermission: Bool
    let canGoPrevious: Bool
    let canGoNext: Bool
    let isLastStep: Bool
    let onRequestScreenRecording: () -> Void
    let onOpenScreenRecordingSettings: () -> Void
    let onRequestAccessibility: () -> Void
    let onOpenAccessibilitySettings: () -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void

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
                    isGranted: hasScreenRecordingPermission,
                    requestAction: onRequestScreenRecording,
                    openSettingsAction: onOpenScreenRecordingSettings
                )

                OnboardingPermissionRow(
                    icon: "command.square.fill",
                    title: NSLocalizedString("onboarding.permission.accessibility", comment: ""),
                    isGranted: hasAccessibilityPermission,
                    requestAction: onRequestAccessibility,
                    openSettingsAction: onOpenAccessibilitySettings
                )
            }

            Spacer()

            Text(NSLocalizedString("onboarding.permissions.hint", comment: ""))
                .font(.caption)
                .foregroundStyle(.secondary)

            OnboardingNavigationButtons(
                canGoPrevious: canGoPrevious,
                canGoNext: canGoNext,
                isLastStep: isLastStep,
                onPrevious: onPrevious,
                onNext: onNext
            )
        }
        .padding(32)
    }
}
