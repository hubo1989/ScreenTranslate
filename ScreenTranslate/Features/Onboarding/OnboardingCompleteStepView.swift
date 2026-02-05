import SwiftUI

struct OnboardingCompleteStepView: View {
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            VStack(spacing: 12) {
                Text(NSLocalizedString("onboarding.complete.title", comment: ""))
                    .font(.largeTitle)
                    .fontWeight(.semibold)

                Text(NSLocalizedString("onboarding.complete.message", comment: ""))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 12) {
                OnboardingInfoRow(
                    icon: "command",
                    text: NSLocalizedString("onboarding.complete.shortcuts", comment: "")
                )
                OnboardingInfoRow(
                    icon: "rectangle.and.hand.point.up.and.hand.point.down",
                    text: NSLocalizedString("onboarding.complete.selection", comment: "")
                )
                OnboardingInfoRow(
                    icon: "gear",
                    text: NSLocalizedString("onboarding.complete.settings", comment: "")
                )
            }
            .padding(.vertical, 8)

            Spacer()

            Button {
                onStart()
            } label: {
                Text(NSLocalizedString("onboarding.complete.start", comment: ""))
                    .frame(minWidth: 150)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
    }
}
