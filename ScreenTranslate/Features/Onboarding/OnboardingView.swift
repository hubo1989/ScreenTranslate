import SwiftUI

/// The first launch onboarding view that guides users through initial setup.
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: OnboardingViewModel

    init(viewModel: OnboardingViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            progressIndicator

            Divider()

            // Content based on current step
            Group {
                switch viewModel.currentStep {
                case 0:
                    welcomeStep
                case 1:
                    permissionsStep
                case 2:
                    configurationStep
                case 3:
                    completeStep
                default:
                    welcomeStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 600, height: 500)
        .onReceive(NotificationCenter.default.publisher(for: .onboardingCompleted)) { _ in
            dismiss()
        }
    }

    // MARK: - Progress Indicator

    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<viewModel.totalSteps, id: \.self) { index in
                if index < viewModel.currentStep {
                    // Completed step
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else if index == viewModel.currentStep {
                    // Current step
                    Image(systemName: index == viewModel.totalSteps - 1 && viewModel.canGoNext
                          ? "checkmark.circle.fill" : "circle.fill")
                        .foregroundStyle(.blue)
                } else {
                    // Future step
                    Image(systemName: "circle")
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Step 0: Welcome

    private var welcomeStep: some View {
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
                featureRow(
                    icon: "cpu",
                    title: NSLocalizedString("onboarding.feature.local.ocr.title", comment: ""),
                    description: NSLocalizedString("onboarding.feature.local.ocr.description", comment: "")
                )

                featureRow(
                    icon: "globe",
                    title: NSLocalizedString("onboarding.feature.local.translation.title", comment: ""),
                    description: NSLocalizedString("onboarding.feature.local.translation.description", comment: "")
                )

                featureRow(
                    icon: "command",
                    title: NSLocalizedString("onboarding.feature.shortcuts.title", comment: ""),
                    description: NSLocalizedString("onboarding.feature.shortcuts.description", comment: "")
                )
            }
            .padding(.vertical, 8)

            Spacer()

            navigationButtons
        }
        .padding(32)
    }

    private func featureRow(icon: String, title: String, description: String) -> some View {
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

    // MARK: - Step 1: Permissions

    private var permissionsStep: some View {
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
                permissionRow(
                    icon: "video.fill",
                    title: NSLocalizedString("onboarding.permission.screen.recording", comment: ""),
                    isGranted: viewModel.hasScreenRecordingPermission,
                    requestAction: {
                        viewModel.requestScreenRecordingPermission()
                    },
                    openSettingsAction: {
                        viewModel.openScreenRecordingSettings()
                    }
                )

                permissionRow(
                    icon: "command.square.fill",
                    title: NSLocalizedString("onboarding.permission.accessibility", comment: ""),
                    isGranted: viewModel.hasAccessibilityPermission,
                    requestAction: {
                        viewModel.requestAccessibilityPermission()
                    },
                    openSettingsAction: {
                        viewModel.openAccessibilitySettings()
                    }
                )
            }

            Spacer()

            Text(NSLocalizedString("onboarding.permissions.hint", comment: ""))
                .font(.caption)
                .foregroundStyle(.secondary)

            navigationButtons
        }
        .padding(32)
    }

    private func permissionRow(
        icon: String,
        title: String,
        isGranted: Bool,
        requestAction: @escaping () -> Void,
        openSettingsAction: @escaping () -> Void
    ) -> some View {
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
        .cornerRadius(8)
    }

    // MARK: - Step 2: Configuration

    private var configurationStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "gearshape.2.fill")
                .font(.system(size: 50))
                .foregroundStyle(.blue)

            VStack(spacing: 12) {
                Text(NSLocalizedString("onboarding.configuration.title", comment: ""))
                    .font(.largeTitle)
                    .fontWeight(.semibold)

                Text(NSLocalizedString("onboarding.configuration.message", comment: ""))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 16) {
                // PaddleOCR Installation Section
                paddleOCRConfigSection

                Divider()

                // MTran Server Section
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("onboarding.configuration.mtran", comment: ""))
                        .font(.headline)
                    Text(NSLocalizedString("onboarding.configuration.mtran.hint", comment: ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField(
                        NSLocalizedString("onboarding.configuration.placeholder.address", comment: ""),
                        text: $viewModel.mtranServerURL
                    )
                    .textFieldStyle(.roundedBorder)
                }

                // Translation Test Section
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("onboarding.configuration.test", comment: ""))
                        .font(.headline)

                    if let result = viewModel.translationTestResult {
                        HStack(spacing: 8) {
                            Image(systemName: viewModel.translationTestSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(viewModel.translationTestSuccess ? .green : .red)
                            Text(result)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        Task {
                            await viewModel.testTranslation()
                        }
                    } label: {
                        if viewModel.isTestingTranslation {
                            Text(NSLocalizedString("onboarding.configuration.testing", comment: ""))
                        } else {
                            Text(NSLocalizedString("onboarding.configuration.test.button", comment: ""))
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isTestingTranslation)
                }
            }
            .frame(maxWidth: 400)

            Spacer()

            HStack(spacing: 16) {
                Button {
                    viewModel.skipConfiguration()
                } label: {
                    Text(NSLocalizedString("onboarding.skip", comment: ""))
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .tint(.secondary)

                Spacer()

                Button {
                    viewModel.goToNextStep()
                } label: {
                    Text(NSLocalizedString("onboarding.complete", comment: ""))
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
    }

    // MARK: - PaddleOCR Configuration Section

    private var paddleOCRConfigSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(NSLocalizedString("onboarding.paddleocr.title", comment: ""))
                    .font(.headline)

                Spacer()

                // Installation status indicator
                if viewModel.isPaddleOCRInstalled {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(NSLocalizedString("onboarding.paddleocr.installed", comment: ""))
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                        Text(NSLocalizedString("onboarding.paddleocr.not.installed", comment: ""))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Text(NSLocalizedString("onboarding.paddleocr.description", comment: ""))
                .font(.caption)
                .foregroundStyle(.secondary)

            if !viewModel.isPaddleOCRInstalled {
                // Installation options
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("onboarding.paddleocr.install.hint", comment: ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Button {
                            viewModel.installPaddleOCR()
                        } label: {
                            if viewModel.isInstallingPaddleOCR {
                                ProgressView()
                                    .controlSize(.small)
                                    .frame(width: 16, height: 16)
                                Text(NSLocalizedString("onboarding.paddleocr.installing", comment: ""))
                            } else {
                                Image(systemName: "arrow.down.circle")
                                Text(NSLocalizedString("onboarding.paddleocr.install", comment: ""))
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isInstallingPaddleOCR)

                        Button {
                            viewModel.copyInstallCommand()
                        } label: {
                            Image(systemName: "doc.on.doc")
                            Text(NSLocalizedString("onboarding.paddleocr.copy.command", comment: ""))
                        }
                        .buttonStyle(.bordered)

                        Button {
                            viewModel.refreshPaddleOCRStatus()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.borderless)
                        .help(NSLocalizedString("onboarding.paddleocr.refresh", comment: ""))
                    }

                    if let error = viewModel.paddleOCRInstallError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            } else {
                // PaddleOCR is installed - show version
                if let version = viewModel.paddleOCRVersion {
                    Text(String(format: NSLocalizedString("onboarding.paddleocr.version", comment: ""), version))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - Step 3: Complete

    private var completeStep: some View {
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
                infoRow(
                    icon: "command",
                    text: NSLocalizedString("onboarding.complete.shortcuts", comment: "")
                )
                infoRow(
                    icon: "rectangle.and.hand.point.up.and.hand.point.down",
                    text: NSLocalizedString("onboarding.complete.selection", comment: "")
                )
                infoRow(
                    icon: "gear",
                    text: NSLocalizedString("onboarding.complete.settings", comment: "")
                )
            }
            .padding(.vertical, 8)

            Spacer()

            Button {
                viewModel.goToNextStep()
            } label: {
                Text(NSLocalizedString("onboarding.complete.start", comment: ""))
                    .frame(minWidth: 150)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
    }

    private func infoRow(icon: String, text: String) -> some View {
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

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack(spacing: 16) {
            if viewModel.canGoPrevious {
                Button {
                    viewModel.goToPreviousStep()
                } label: {
                    Text(NSLocalizedString("onboarding.back", comment: ""))
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            if viewModel.canGoNext && !viewModel.isLastStep {
                Button {
                    viewModel.goToNextStep()
                } label: {
                    Text(NSLocalizedString("onboarding.continue", comment: ""))
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

// Preview
#Preview {
    OnboardingView(viewModel: OnboardingViewModel())
}
