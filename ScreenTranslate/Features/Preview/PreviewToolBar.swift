import SwiftUI
import AppKit

struct PreviewToolBar: View {
    @Bindable var viewModel: PreviewViewModel

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AnnotationToolType.allCases) { tool in
                toolButton(for: tool)
            }

            if viewModel.selectedTool != nil || viewModel.selectedAnnotationIndex != nil {
                Divider()
                    .frame(height: 16)

                PreviewStyleCustomizationBar(viewModel: viewModel)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Annotation tools"))
    }

    private func toolButton(for tool: AnnotationToolType) -> some View {
        let isSelected = viewModel.selectedTool == tool
        return Button {
            if isSelected {
                viewModel.selectTool(nil)
            } else {
                viewModel.selectTool(tool)
            }
        } label: {
            Image(systemName: tool.systemImage)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.accessoryBar)
        .background(
            isSelected
                ? Color.accentColor.opacity(0.2)
                : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .help("\(tool.displayName) (\(String(tool.keyboardShortcut).uppercased()))")
        .accessibilityLabel(Text(tool.displayName))
        .accessibilityHint(Text("Press \(String(tool.keyboardShortcut).uppercased()) to toggle"))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

struct PreviewStyleCustomizationBar: View {
    @Bindable var viewModel: PreviewViewModel

    private var isEditingAnnotation: Bool {
        viewModel.selectedAnnotationIndex != nil
    }

    private var effectiveToolType: AnnotationToolType? {
        isEditingAnnotation ? viewModel.selectedAnnotationType : viewModel.selectedTool
    }

    private var presetColors: [Color] {
        [.red, .yellow, .green, .blue, .black]
    }

    var body: some View {
        HStack(spacing: 8) {
            if isEditingAnnotation {
                Text("preview.edit.label")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            colorPicker

            Divider()
                .frame(height: 16)

            if effectiveToolType == .rectangle {
                rectangleFillToggle
                Divider()
                    .frame(height: 16)
            }

            if shouldShowStrokeWidth {
                strokeWidthControl
            }

            if effectiveToolType == .text {
                textSizeControl
            }

            if isEditingAnnotation {
                Divider()
                    .frame(height: 16)

                deleteButton
            }
        }
    }

    private var shouldShowStrokeWidth: Bool {
        if effectiveToolType == .freehand || effectiveToolType == .arrow {
            return true
        }
        
        if effectiveToolType == .rectangle {
            let isFilled = isEditingAnnotation
                ? (viewModel.selectedAnnotationIsFilled ?? false)
                : AppSettings.shared.rectangleFilled
            return !isFilled
        }
        
        return false
    }

    private var colorPicker: some View {
        HStack(spacing: 2) {
            ForEach(presetColors, id: \.self) { color in
                colorButton(for: color)
            }

            ColorPicker(
                "",
                selection: Binding(
                    get: {
                        if isEditingAnnotation {
                            return viewModel.selectedAnnotationColor?.color ?? .red
                        }
                        return AppSettings.shared.strokeColor.color
                    },
                    set: { newColor in
                        if isEditingAnnotation {
                            viewModel.updateSelectedAnnotationColor(CodableColor(newColor))
                        } else {
                            AppSettings.shared.strokeColor = CodableColor(newColor)
                        }
                    }
                ),
                supportsOpacity: false
            )
            .labelsHidden()
            .frame(width: 24)
        }
    }

    private func colorButton(for color: Color) -> some View {
        Button {
            if isEditingAnnotation {
                viewModel.updateSelectedAnnotationColor(CodableColor(color))
            } else {
                AppSettings.shared.strokeColor = CodableColor(color)
            }
        } label: {
            Circle()
                .fill(color)
                .frame(width: 16, height: 16)
                .overlay {
                    let currentColor = isEditingAnnotation
                        ? (viewModel.selectedAnnotationColor?.color ?? .clear)
                        : AppSettings.shared.strokeColor.color
                    if colorsAreEqual(currentColor, color) {
                        Circle()
                            .stroke(Color.primary, lineWidth: 2)
                    }
                }
                .overlay {
                    if color == .white || color == .yellow {
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
        .help(colorName(for: color))
    }

    private var rectangleFillToggle: some View {
        let isFilled = isEditingAnnotation
            ? (viewModel.selectedAnnotationIsFilled ?? false)
            : AppSettings.shared.rectangleFilled

        return Button {
            if isEditingAnnotation {
                viewModel.updateSelectedAnnotationFilled(!isFilled)
            } else {
                AppSettings.shared.rectangleFilled.toggle()
            }
        } label: {
            Image(systemName: isFilled ? "rectangle.fill" : "rectangle")
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.accessoryBar)
        .background(
            isFilled
                ? Color.accentColor.opacity(0.2)
                : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .help(isFilled ? String(localized: "preview.shape.filled") : String(localized: "preview.shape.hollow"))
    }

    private var strokeWidthControl: some View {
        HStack(spacing: 4) {
            Image(systemName: "lineweight")
                .font(.caption)
                .foregroundStyle(.secondary)

            Slider(
                value: Binding(
                    get: {
                        if isEditingAnnotation {
                            return viewModel.selectedAnnotationStrokeWidth ?? 3.0
                        }
                        return AppSettings.shared.strokeWidth
                    },
                    set: { newWidth in
                        if isEditingAnnotation {
                            viewModel.updateSelectedAnnotationStrokeWidth(newWidth)
                        } else {
                            AppSettings.shared.strokeWidth = newWidth
                        }
                    }
                ),
                in: 1.0...20.0,
                step: 0.5
            )
            .frame(width: 80)
            .help(String(localized: "settings.stroke.width"))

            let width = isEditingAnnotation
                ? Int(viewModel.selectedAnnotationStrokeWidth ?? 3)
                : Int(AppSettings.shared.strokeWidth)
            Text("\(width)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 20)
        }
    }

    private var textSizeControl: some View {
        HStack(spacing: 4) {
            Image(systemName: "textformat.size")
                .font(.caption)
                .foregroundStyle(.secondary)

            Slider(
                value: Binding(
                    get: {
                        if isEditingAnnotation {
                            return viewModel.selectedAnnotationFontSize ?? 16.0
                        }
                        return AppSettings.shared.textSize
                    },
                    set: { newSize in
                        if isEditingAnnotation {
                            viewModel.updateSelectedAnnotationFontSize(newSize)
                        } else {
                            AppSettings.shared.textSize = newSize
                        }
                    }
                ),
                in: 8.0...72.0,
                step: 1
            )
            .frame(width: 80)
            .help(String(localized: "settings.text.size"))

            let size = isEditingAnnotation
                ? Int(viewModel.selectedAnnotationFontSize ?? 16)
                : Int(AppSettings.shared.textSize)
            Text("\(size)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 20)
        }
    }

    private var deleteButton: some View {
        Button {
            viewModel.deleteSelectedAnnotation()
        } label: {
            Image(systemName: "trash")
                .foregroundStyle(.red)
        }
        .buttonStyle(.plain)
        .help(String(localized: "preview.tooltip.delete"))
    }

    private func colorsAreEqual(_ colorA: Color, _ colorB: Color) -> Bool {
        let nsColorA = NSColor(colorA).usingColorSpace(.deviceRGB)
        let nsColorB = NSColor(colorB).usingColorSpace(.deviceRGB)
        guard let convertedA = nsColorA, let convertedB = nsColorB else { return false }

        let tolerance: CGFloat = 0.01
        return abs(convertedA.redComponent - convertedB.redComponent) < tolerance &&
               abs(convertedA.greenComponent - convertedB.greenComponent) < tolerance &&
               abs(convertedA.blueComponent - convertedB.blueComponent) < tolerance
    }

    private func colorName(for color: Color) -> String {
        switch color {
        case .red: return String(localized: "color.red")
        case .orange: return String(localized: "color.orange")
        case .yellow: return String(localized: "color.yellow")
        case .green: return String(localized: "color.green")
        case .blue: return String(localized: "color.blue")
        case .purple: return String(localized: "color.purple")
        case .white: return String(localized: "color.white")
        case .black: return String(localized: "color.black")
        default: return String(localized: "color.custom")
        }
    }
}
