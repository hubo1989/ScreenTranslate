import SwiftUI

struct OnboardingCompleteStepView: View {
    let onStart: () -> Void
    let hasSkippedPermissions: Bool

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
                    icon: "menubar.rectangle",
                    text: NSLocalizedString("onboarding.complete.menubar.hint", comment: "")
                )

                Divider()

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

            if hasSkippedPermissions {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(NSLocalizedString("onboarding.complete.permissions.warning", comment: ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(.rect(cornerRadius: 8))
            }

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
