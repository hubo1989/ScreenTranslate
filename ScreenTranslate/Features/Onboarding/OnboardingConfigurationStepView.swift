import SwiftUI

struct OnboardingConfigurationStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
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
                OnboardingPaddleOCRSection(viewModel: viewModel)

                Divider()

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

                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("onboarding.configuration.test", comment: ""))
                        .font(.headline)

                    if let result = viewModel.translationTestResult {
                        let imageName = viewModel.translationTestSuccess ? "checkmark.circle.fill" : "xmark.circle.fill"
                        HStack(spacing: 8) {
                            Image(systemName: imageName)
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
}

struct OnboardingPaddleOCRSection: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(NSLocalizedString("onboarding.paddleocr.title", comment: ""))
                    .font(.headline)

                Spacer()

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
                if let version = viewModel.paddleOCRVersion {
                    Text(String(format: NSLocalizedString("onboarding.paddleocr.version", comment: ""), version))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(.rect(cornerRadius: 8))
    }
}
