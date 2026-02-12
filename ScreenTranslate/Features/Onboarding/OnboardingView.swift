import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: OnboardingViewModel

    init(viewModel: OnboardingViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            progressIndicator

            Divider()

            Group {
                switch viewModel.currentStep {
                case 0:
                    OnboardingWelcomeStepView(
                        onContinue: { viewModel.goToNextStep() },
                        canGoNext: viewModel.canGoNext
                    )
                case 1:
                    OnboardingPermissionsStepView(
                        hasScreenRecordingPermission: viewModel.hasScreenRecordingPermission,
                        hasAccessibilityPermission: viewModel.hasAccessibilityPermission,
                        canGoPrevious: viewModel.canGoPrevious,
                        canGoNext: viewModel.canGoNext,
                        isLastStep: viewModel.isLastStep,
                        onRequestScreenRecording: { viewModel.requestScreenRecordingPermission() },
                        onOpenScreenRecordingSettings: { viewModel.openScreenRecordingSettings() },
                        onRequestAccessibility: { viewModel.requestAccessibilityPermission() },
                        onOpenAccessibilitySettings: { viewModel.openAccessibilitySettings() },
                        onPrevious: { viewModel.goToPreviousStep() },
                        onNext: { viewModel.goToNextStep() }
                    )
                case 2:
                    OnboardingConfigurationStepView(viewModel: viewModel)
                case 3:
                    OnboardingCompleteStepView(onStart: { viewModel.goToNextStep() })
                default:
                    OnboardingWelcomeStepView(
                        onContinue: { viewModel.goToNextStep() },
                        canGoNext: viewModel.canGoNext
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 600, height: 620)
        .onReceive(NotificationCenter.default.publisher(for: .onboardingCompleted)) { _ in
            dismiss()
        }
    }

    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<viewModel.totalSteps, id: \.self) { index in
                if index < viewModel.currentStep {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else if index == viewModel.currentStep {
                    Image(systemName: index == viewModel.totalSteps - 1 && viewModel.canGoNext
                          ? "checkmark.circle.fill" : "circle.fill")
                        .foregroundStyle(.blue)
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

#Preview {
    OnboardingView(viewModel: OnboardingViewModel())
}
