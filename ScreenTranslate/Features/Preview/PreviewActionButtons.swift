import SwiftUI

struct PreviewActionButtons: View {
    @Bindable var viewModel: PreviewViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            cropButton
            
            Divider()
                .frame(height: 16)
                .accessibilityHidden(true)

            undoRedoButtons

            Divider()
                .frame(height: 16)
                .accessibilityHidden(true)

            copyAndSaveButtons

            Divider()
                .frame(height: 16)
                .accessibilityHidden(true)

            ocrAndTranslationButtons

            Divider()
                .frame(height: 16)
                .accessibilityHidden(true)

            dismissButton
        }
        .buttonStyle(.accessoryBar)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Screenshot actions"))
    }

    private var cropButton: some View {
        Button {
            viewModel.toggleCropMode()
        } label: {
            Image(systemName: "crop")
        }
        .buttonStyle(.accessoryBar)
        .background(
            viewModel.isCropMode
                ? Color.accentColor.opacity(0.2)
                : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .help(String(localized: "preview.tooltip.crop"))
        .accessibilityLabel(Text("preview.crop"))
        .accessibilityHint(Text("Press C to toggle"))
    }

    private var undoRedoButtons: some View {
        Group {
            Button {
                viewModel.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(!viewModel.canUndo)
            .help(String(localized: "preview.tooltip.undo"))
            .accessibilityLabel(Text("action.undo"))
            .accessibilityHint(Text("Command Z"))

            Button {
                viewModel.redo()
            } label: {
                Image(systemName: "arrow.uturn.forward")
            }
            .disabled(!viewModel.canRedo)
            .help(String(localized: "preview.tooltip.redo"))
            .accessibilityLabel(Text("action.redo"))
            .accessibilityHint(Text("Command Shift Z"))
        }
    }

    private var copyAndSaveButtons: some View {
        Group {
            Button {
                viewModel.copyToClipboard()
                viewModel.dismiss()
            } label: {
                if viewModel.isCopying {
                    loadingIndicator
                } else {
                    Image(systemName: "doc.on.doc")
                }
            }
            .disabled(viewModel.isCopying)
            .help(String(localized: "preview.tooltip.copy"))
            .accessibilityLabel(Text(viewModel.isCopying ? "Copying to clipboard" : "Copy to clipboard"))
            .accessibilityHint(Text("Command C"))

            Button {
                viewModel.saveScreenshot()
            } label: {
                if viewModel.isSaving {
                    loadingIndicator
                } else {
                    Image(systemName: "square.and.arrow.down")
                }
            }
            .disabled(viewModel.isSaving)
            .help(String(localized: "preview.tooltip.save"))
            .accessibilityLabel(Text(viewModel.isSaving ? "Saving screenshot" : "Save screenshot"))
            .accessibilityHint(Text("Command S or Enter"))
        }
    }

    private var ocrAndTranslationButtons: some View {
        Group {
            Button {
                viewModel.performOCR()
            } label: {
                if viewModel.isPerformingOCR {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: "text.viewfinder")
                }
            }
            .disabled(viewModel.isPerformingOCR)
            .help(String(localized: "preview.tooltip.ocr"))

            Button {
                viewModel.performTranslation()
            } label: {
                if viewModel.isPerformingTranslation || viewModel.isPerformingOCRThenTranslation {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: "character")
                }
            }
            .disabled(viewModel.isPerformingTranslation || viewModel.isPerformingOCRThenTranslation)
            .help(viewModel.isPerformingOCRThenTranslation
                ? String(localized: "preview.tooltip.ocr.then.translate")
                : String(localized: "preview.tooltip.translate"))

            Button {
                viewModel.toggleTranslationOverlay()
            } label: {
                Image(systemName: viewModel.isTranslationOverlayVisible ? "eye.slash" : "eye")
            }
            .disabled(!viewModel.hasTranslationResults)
            .help(viewModel.isTranslationOverlayVisible
                ? String(localized: "preview.tooltip.hide.translation")
                : String(localized: "preview.tooltip.show.translation"))

            Button {
                viewModel.saveWithTranslations()
            } label: {
                if viewModel.isSavingWithTranslations {
                    loadingIndicator
                } else {
                    Image(systemName: "photo.badge.arrow.down")
                }
            }
            .disabled(!viewModel.hasTranslationResults || viewModel.isSavingWithTranslations)
            .help(String(localized: "preview.tooltip.save.with.translations"))
            .accessibilityLabel(Text(
                viewModel.isSavingWithTranslations ? "Saving translated image" : "Save image with translations"
            ))

            Button {
                viewModel.copyWithTranslations()
            } label: {
                if viewModel.isCopyingWithTranslations {
                    loadingIndicator
                } else {
                    Image(systemName: "photo.on.rectangle")
                }
            }
            .disabled(!viewModel.hasTranslationResults || viewModel.isCopyingWithTranslations)
            .help(String(localized: "preview.tooltip.copy.with.translations"))
            .accessibilityLabel(Text(
                viewModel.isCopyingWithTranslations ? "Copying translated image" : "Copy image with translations"
            ))
        }
    }

    private var dismissButton: some View {
        Button {
            viewModel.dismiss()
        } label: {
            Image(systemName: "xmark")
        }
        .help(String(localized: "preview.tooltip.dismiss"))
        .accessibilityLabel(Text("Dismiss preview"))
        .accessibilityHint(Text("Escape key"))
    }

    @ViewBuilder
    private var loadingIndicator: some View {
        if reduceMotion {
            Image(systemName: "ellipsis")
                .frame(width: 16, height: 16)
        } else {
            ProgressView()
                .controlSize(.small)
                .frame(width: 16, height: 16)
        }
    }
}
