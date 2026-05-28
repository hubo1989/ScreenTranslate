import SwiftUI

struct OnboardingWelcomeStepView: View {
    let onContinue: () -> Void
    let canGoNext: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "hand.wave.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            VStack(spacing: 12) {
                Text(NSLocalizedString("onboarding.welcome.title", comment: ""))
                    .font(.largeTitle)
                    .fontWeight(.semibold)

                Text(NSLocalizedString("onboarding.welcome.message", comment: ""))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 16) {
                OnboardingFeatureRow(
                    icon: "cpu",
                    title: NSLocalizedString("onboarding.feature.local.ocr.title", comment: ""),
                    description: NSLocalizedString("onboarding.feature.local.ocr.description", comment: "")
                )

                OnboardingFeatureRow(
                    icon: "globe",
                    title: NSLocalizedString("onboarding.feature.local.translation.title", comment: ""),
                    description: NSLocalizedString("onboarding.feature.local.translation.description", comment: "")
                )

                OnboardingFeatureRow(
                    icon: "command",
                    title: NSLocalizedString("onboarding.feature.shortcuts.title", comment: ""),
                    description: NSLocalizedString("onboarding.feature.shortcuts.description", comment: "")
                )
            }
            .padding(.vertical, 8)

            Spacer()

            OnboardingNavigationButtons(
                canGoPrevious: false,
                canGoNext: canGoNext,
                isLastStep: false,
                onPrevious: {},
                onNext: onContinue
            )
        }
        .padding(32)
    }
}
