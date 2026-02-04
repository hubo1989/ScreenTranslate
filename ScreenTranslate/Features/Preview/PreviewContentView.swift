import SwiftUI
import AppKit

/// SwiftUI view for the screenshot preview content.
/// Displays the captured image with an info bar showing dimensions and file size.
struct PreviewContentView: View {
    // MARK: - Properties

    /// The view model driving this view
    @Bindable var viewModel: PreviewViewModel

    /// State for tracking the image display size and scale
    @State private var imageDisplaySize: CGSize = .zero
    @State private var imageScale: CGFloat = 1.0
    @State private var imageOffset: CGPoint = .zero

    /// Focus state for the text input field
    @FocusState private var isTextFieldFocused: Bool

    /// Environment variable for Reduce Motion preference
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Main image view with annotation canvas
            annotatedImageView
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Info bar
            infoBar
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.bar)

            if viewModel.hasOCRResults || viewModel.hasTranslationResults {
                Divider()
                resultsPanel
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.bar)
            }
        }
        .alert(
            String(localized: "error.title"),
            isPresented: .constant(viewModel.errorMessage != nil),
            presenting: viewModel.errorMessage
        ) { _ in
            Button(String(localized: "button.ok")) {
                viewModel.errorMessage = nil
            }
        } message: { message in
            Text(message)
        }
    }

    // MARK: - Subviews

    /// The main image display area with annotation overlay
    @ViewBuilder
    private var annotatedImageView: some View {
        GeometryReader { geometry in
            let imageSize = CGSize(
                width: CGFloat(viewModel.image.width),
                height: CGFloat(viewModel.image.height)
            )
            let displayInfo = calculateDisplayInfo(
                imageSize: imageSize,
                containerSize: geometry.size
            )

            ZStack {
                // Background
                Color(nsColor: .windowBackgroundColor)

                // Image and annotations centered
                VStack {
                    Spacer()
                    HStack {
                        Spacer()

                        ZStack(alignment: .topLeading) {
                            // Base image
                            Image(viewModel.image, scale: 1.0, label: Text("preview.screenshot"))
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(
                                    width: displayInfo.displaySize.width,
                                    height: displayInfo.displaySize.height
                                )
                                .accessibilityLabel(Text("Screenshot preview, \(viewModel.dimensionsText), from \(viewModel.displayName)"))

                            // Annotation canvas overlay
                            AnnotationCanvas(
                                annotations: viewModel.annotations,
                                currentAnnotation: viewModel.currentAnnotation,
                                canvasSize: imageSize,
                                scale: displayInfo.scale,
                                selectedIndex: viewModel.selectedAnnotationIndex
                            )
                            .frame(
                                width: displayInfo.displaySize.width,
                                height: displayInfo.displaySize.height
                            )

                            // Text input field overlay (when text tool is active)
                            if viewModel.isWaitingForTextInput,
                               let inputPosition = viewModel.textInputPosition {
                                textInputField(
                                    at: inputPosition,
                                    scale: displayInfo.scale
                                )
                            }

                            // Drawing gesture overlay
                            if viewModel.selectedTool != nil {
                                drawingGestureOverlay(
                                    displaySize: displayInfo.displaySize,
                                    scale: displayInfo.scale
                                )
                            }

                            // Selection/editing gesture overlay (when no tool and no crop mode)
                            if viewModel.selectedTool == nil && !viewModel.isCropMode {
                                selectionGestureOverlay(
                                    displaySize: displayInfo.displaySize,
                                    scale: displayInfo.scale
                                )
                            }

                            // Crop overlay
                            if viewModel.isCropMode {
                                cropOverlay(
                                    displaySize: displayInfo.displaySize,
                                    scale: displayInfo.scale
                                )
                            }
                        }
                        .overlay(alignment: .topLeading) {
                            // Active tool indicator
                            if let tool = viewModel.selectedTool {
                                activeToolIndicator(tool: tool)
                                    .padding(8)
                            } else if viewModel.isCropMode {
                                cropModeIndicator
                                    .padding(8)
                            }
                        }
                        .overlay(alignment: .bottom) {
                            // Crop action buttons
                            if viewModel.cropRect != nil && !viewModel.isCropSelecting {
                                cropActionButtons
                                    .padding(12)
                            }
                        }

                        Spacer()
                    }
                    Spacer()
                }
            }
            .onAppear {
                imageDisplaySize = displayInfo.displaySize
                imageScale = displayInfo.scale
            }
            .onChange(of: geometry.size) { _, newSize in
                let newInfo = calculateDisplayInfo(
                    imageSize: imageSize,
                    containerSize: newSize
                )
                imageDisplaySize = newInfo.displaySize
                imageScale = newInfo.scale
            }
        }
        .contentShape(Rectangle())
        .cursor(cursorForCurrentTool)
    }

    /// Calculates the display size and scale for fitting the image in the container
    private func calculateDisplayInfo(
        imageSize: CGSize,
        containerSize: CGSize
    ) -> (displaySize: CGSize, scale: CGFloat) {
        let widthScale = containerSize.width / imageSize.width
        let heightScale = containerSize.height / imageSize.height

        // For large images, scale down to fit. For small images, scale up to fill
        // at least 50% of the container (but cap at 4x to avoid excessive pixelation)
        let fitScale = min(widthScale, heightScale)
        let scale: CGFloat
        if fitScale > 1.0 {
            // Image is smaller than container - scale up but cap at 4x
            scale = min(fitScale, 4.0)
        } else {
            // Image is larger than container - scale down to fit
            scale = fitScale
        }

        let displaySize = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )

        return (displaySize, scale)
    }

    /// The cursor to use based on the current tool
    private var cursorForCurrentTool: NSCursor {
        if viewModel.isCropMode {
            return .crosshair
        }

        guard let tool = viewModel.selectedTool else {
            // No tool selected - show move cursor if dragging annotation
            if viewModel.isDraggingAnnotation {
                return .closedHand
            } else if viewModel.selectedAnnotationIndex != nil {
                return .openHand
            }
            return .arrow
        }

        switch tool {
        case .rectangle, .freehand, .arrow:
            return .crosshair
        case .text:
            return .iBeam
        }
    }

    /// Overlay for capturing drawing gestures
    private func drawingGestureOverlay(
        displaySize: CGSize,
        scale: CGFloat
    ) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let point = convertToImageCoordinates(
                            value.location,
                            scale: scale
                        )

                        if value.translation == .zero {
                            // First point - begin drawing
                            viewModel.beginDrawing(at: point)
                        } else {
                            // Subsequent points - continue drawing
                            viewModel.continueDrawing(to: point)
                        }
                    }
                    .onEnded { value in
                        let point = convertToImageCoordinates(
                            value.location,
                            scale: scale
                        )
                        viewModel.endDrawing(at: point)
                    }
            )
    }

    /// Converts view coordinates to image coordinates
    private func convertToImageCoordinates(
        _ point: CGPoint,
        scale: CGFloat
    ) -> CGPoint {
        CGPoint(
            x: point.x / scale,
            y: point.y / scale
        )
    }

    /// Overlay for selecting and dragging annotations
    private func selectionGestureOverlay(
        displaySize: CGSize,
        scale: CGFloat
    ) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let point = convertToImageCoordinates(
                            value.location,
                            scale: scale
                        )

                        if value.translation == .zero {
                            // First tap - check for hit
                            if let hitIndex = viewModel.hitTest(at: point) {
                                // Hit an annotation - select it and prepare for dragging
                                viewModel.selectAnnotation(at: hitIndex)
                                viewModel.beginDraggingAnnotation(at: point)
                            } else {
                                // Clicked on empty space - deselect
                                viewModel.deselectAnnotation()
                            }
                        } else if viewModel.isDraggingAnnotation {
                            // Dragging a selected annotation
                            viewModel.continueDraggingAnnotation(to: point)
                        }
                    }
                    .onEnded { _ in
                        viewModel.endDraggingAnnotation()
                    }
            )
    }

    /// Text input field for text annotations
    private func textInputField(
        at position: CGPoint,
        scale: CGFloat
    ) -> some View {
        let scaledPosition = CGPoint(
            x: position.x * scale,
            y: position.y * scale
        )

        return TextField(String(localized: "preview.enter.text"), text: $viewModel.textInputContent)
            .textFieldStyle(.plain)
            .font(.system(size: 14 * scale))
            .foregroundColor(AppSettings.shared.strokeColor.color)
            .padding(4)
            .background(Color.white.opacity(0.9))
            .cornerRadius(4)
            .frame(minWidth: 100, maxWidth: 300)
            .position(x: scaledPosition.x + 50, y: scaledPosition.y + 10)
            .focused($isTextFieldFocused)
            .onAppear {
                isTextFieldFocused = true
            }
            .onSubmit {
                viewModel.commitTextInput()
                isTextFieldFocused = false
            }
            .onExitCommand {
                viewModel.cancelCurrentDrawing()
                isTextFieldFocused = false
            }
    }

    /// Active tool indicator badge
    private func activeToolIndicator(tool: AnnotationToolType) -> some View {
        HStack(spacing: 4) {
            Image(systemName: tool.systemImage)
            Text(tool.displayName)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .cornerRadius(6)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(String(localized: "preview.active.tool")): \(tool.displayName)"))
    }

    /// Crop mode indicator badge
    private var cropModeIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: "crop")
            Text("preview.crop")
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .cornerRadius(6)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("preview.crop.mode.active"))
    }

    /// Overlay for capturing crop selection gestures
    private func cropOverlay(
        displaySize: CGSize,
        scale: CGFloat
    ) -> some View {
        ZStack {
            // Dim overlay outside crop area
            if let cropRect = viewModel.cropRect, cropRect.width > 0, cropRect.height > 0 {
                let scaledRect = CGRect(
                    x: cropRect.origin.x * scale,
                    y: cropRect.origin.y * scale,
                    width: cropRect.width * scale,
                    height: cropRect.height * scale
                )

                // Create a shape that covers everything except the crop area
                CropDimOverlay(cropRect: scaledRect)
                    .fill(Color.black.opacity(0.5))
                    .allowsHitTesting(false)
                    .transaction { $0.animation = nil }

                // Crop selection border
                Rectangle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: scaledRect.width, height: scaledRect.height)
                    .position(x: scaledRect.midX, y: scaledRect.midY)
                    .allowsHitTesting(false)

                // Corner handles
                ForEach(0..<4, id: \.self) { corner in
                    let position = cornerPosition(for: corner, in: scaledRect)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white)
                        .frame(width: 10, height: 10)
                        .position(position)
                        .allowsHitTesting(false)
                }

                // Crop dimensions label
                cropDimensionsLabel(for: cropRect, scaledRect: scaledRect)
            }

            // Gesture capture layer
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let point = convertToImageCoordinates(value.location, scale: scale)
                            if value.translation == .zero {
                                viewModel.beginCropSelection(at: point)
                            } else {
                                viewModel.continueCropSelection(to: point)
                            }
                        }
                        .onEnded { value in
                            let point = convertToImageCoordinates(value.location, scale: scale)
                            viewModel.endCropSelection(at: point)
                        }
                )
        }
    }

    /// Gets the position for a corner handle
    private func cornerPosition(for corner: Int, in rect: CGRect) -> CGPoint {
        switch corner {
        case 0: return CGPoint(x: rect.minX, y: rect.minY) // Top-left
        case 1: return CGPoint(x: rect.maxX, y: rect.minY) // Top-right
        case 2: return CGPoint(x: rect.minX, y: rect.maxY) // Bottom-left
        case 3: return CGPoint(x: rect.maxX, y: rect.maxY) // Bottom-right
        default: return .zero
        }
    }

    /// Crop dimensions label
    private func cropDimensionsLabel(for cropRect: CGRect, scaledRect: CGRect) -> some View {
        let width = Int(cropRect.width)
        let height = Int(cropRect.height)

        return Text("\(width) × \(height)")
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.75))
            .cornerRadius(4)
            .position(
                x: scaledRect.midX,
                y: max(scaledRect.minY - 20, 15)
            )
            .allowsHitTesting(false)
    }

    /// Crop action buttons (Apply/Cancel)
    private var cropActionButtons: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.cancelCrop()
            } label: {
                Label(String(localized: "action.cancel"), systemImage: "xmark")
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.escape, modifiers: [])

            Button {
                viewModel.applyCrop()
            } label: {
                Label(String(localized: "preview.crop.apply"), systemImage: "checkmark")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
    }

    /// The info bar at the bottom showing dimensions and file size
    private var infoBar: some View {
        HStack(spacing: 12) {
            // Left side: Image info (compact)
            HStack(spacing: 8) {
                Text(viewModel.dimensionsText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .help(String(localized: "preview.image.dimensions"))

                Text("•")
                    .foregroundStyle(.tertiary)

                Text(viewModel.fileSizeText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .help(String(localized: "preview.estimated.size"))
            }
            .fixedSize()

            Divider()
                .frame(height: 16)

            // Center: Scrollable toolbar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    toolBar
                }
                .padding(.horizontal, 4)
            }
            .frame(minWidth: 100)

            Divider()
                .frame(height: 16)

            // Right side: Action buttons (fixed)
            actionButtons
                .fixedSize()
        }
    }

    /// Tool selection buttons
    private var toolBar: some View {
        HStack(spacing: 4) {
            ForEach(AnnotationToolType.allCases) { tool in
                let isSelected = viewModel.selectedTool == tool
                Button {
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

            // Show customization options when a tool is selected OR an annotation is selected
            if viewModel.selectedTool != nil || viewModel.selectedAnnotationIndex != nil {
                Divider()
                    .frame(height: 16)

                styleCustomizationBar
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Annotation tools"))
    }

    /// Style customization bar for color and stroke width
    @ViewBuilder
    private var styleCustomizationBar: some View {
        let isEditingAnnotation = viewModel.selectedAnnotationIndex != nil
        let effectiveToolType = isEditingAnnotation ? viewModel.selectedAnnotationType : viewModel.selectedTool

        HStack(spacing: 8) {
            // Show "Editing" label when modifying existing annotation
            if isEditingAnnotation {
                Text("preview.edit.label")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Color picker with preset colors
            HStack(spacing: 2) {
                ForEach(presetColors, id: \.self) { color in
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

                ColorPicker("", selection: Binding(
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
                ), supportsOpacity: false)
                .labelsHidden()
                .frame(width: 24)
            }

            Divider()
                .frame(height: 16)

            // Rectangle fill toggle (for rectangle only)
            if effectiveToolType == .rectangle {
                let isFilled = isEditingAnnotation
                    ? (viewModel.selectedAnnotationIsFilled ?? false)
                    : AppSettings.shared.rectangleFilled

                Button {
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

                Divider()
                    .frame(height: 16)
            }

            // Stroke width control (for rectangle/freehand/arrow - only show for hollow rectangles)
            if effectiveToolType == .freehand || effectiveToolType == .arrow ||
               (effectiveToolType == .rectangle && !(isEditingAnnotation ? (viewModel.selectedAnnotationIsFilled ?? false) : AppSettings.shared.rectangleFilled)) {
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

            // Text size control
            if effectiveToolType == .text {
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

            // Delete button for selected annotation
            if isEditingAnnotation {
                Divider()
                    .frame(height: 16)

                Button {
                    viewModel.deleteSelectedAnnotation()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help(String(localized: "preview.tooltip.delete"))
            }
        }
    }

    /// Preset colors for quick selection (reduced set to save space)
    private var presetColors: [Color] {
        [.red, .yellow, .green, .blue, .black]
    }

    /// Compare colors approximately
    private func colorsAreEqual(_ a: Color, _ b: Color) -> Bool {
        let nsA = NSColor(a).usingColorSpace(.deviceRGB)
        let nsB = NSColor(b).usingColorSpace(.deviceRGB)
        guard let colorA = nsA, let colorB = nsB else { return false }

        let tolerance: CGFloat = 0.01
        return abs(colorA.redComponent - colorB.redComponent) < tolerance &&
               abs(colorA.greenComponent - colorB.greenComponent) < tolerance &&
               abs(colorA.blueComponent - colorB.blueComponent) < tolerance
    }

    /// Get accessible color name
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

    private var resultsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.hasOCRResults {
                VStack(alignment: .leading, spacing: 4) {
                    Text("preview.recognized.text")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(viewModel.combinedOCRText)
                        .font(.body)
                        .lineLimit(3)
                }
            }

            if viewModel.hasTranslationResults {
                VStack(alignment: .leading, spacing: 4) {
                    Text("preview.translation")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(viewModel.combinedTranslatedText)
                        .font(.body)
                        .lineLimit(3)
                }
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            // Crop button
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

            Divider()
                .frame(height: 16)
                .accessibilityHidden(true)

            // Undo/Redo
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

            Divider()
                .frame(height: 16)
                .accessibilityHidden(true)

            // Copy to clipboard and dismiss
            Button {
                viewModel.copyToClipboard()
                viewModel.dismiss()
            } label: {
                if viewModel.isCopying {
                    if reduceMotion {
                        Image(systemName: "ellipsis")
                            .frame(width: 16, height: 16)
                    } else {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 16, height: 16)
                    }
                } else {
                    Image(systemName: "doc.on.doc")
                }
            }
            .disabled(viewModel.isCopying)
            .help(String(localized: "preview.tooltip.copy"))
            .accessibilityLabel(Text(viewModel.isCopying ? "Copying to clipboard" : "Copy to clipboard"))
            .accessibilityHint(Text("Command C"))

            // Save
            Button {
                viewModel.saveScreenshot()
            } label: {
                if viewModel.isSaving {
                    if reduceMotion {
                        Image(systemName: "ellipsis")
                            .frame(width: 16, height: 16)
                    } else {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 16, height: 16)
                    }
                } else {
                    Image(systemName: "square.and.arrow.down")
                }
            }
            .disabled(viewModel.isSaving)
            .help(String(localized: "preview.tooltip.save"))
            .accessibilityLabel(Text(viewModel.isSaving ? "Saving screenshot" : "Save screenshot"))
            .accessibilityHint(Text("Command S or Enter"))

            Divider()
                .frame(height: 16)
                .accessibilityHidden(true)

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
                if viewModel.isPerformingTranslation {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: "character")
                }
            }
            .disabled(viewModel.isPerformingTranslation)
            .help(String(localized: "preview.tooltip.translate"))

            Divider()
                .frame(height: 16)
                .accessibilityHidden(true)

            // Dismiss
            Button {
                viewModel.dismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .help(String(localized: "preview.tooltip.dismiss"))
            .accessibilityLabel(Text("Dismiss preview"))
            .accessibilityHint(Text("Escape key"))
        }
        .buttonStyle(.accessoryBar)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Screenshot actions"))
    }
}

// MARK: - Crop Dim Overlay Shape

/// A shape that covers everything except a rectangular cutout
struct CropDimOverlay: Shape {
    var cropRect: CGRect

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get {
            AnimatablePair(
                AnimatablePair(cropRect.origin.x, cropRect.origin.y),
                AnimatablePair(cropRect.width, cropRect.height)
            )
        }
        set {
            cropRect = CGRect(
                x: newValue.first.first,
                y: newValue.first.second,
                width: newValue.second.first,
                height: newValue.second.second
            )
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        path.addRect(cropRect)
        return path
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    // Create a simple test image for preview
    let testImage: CGImage = {
        let width = 800
        let height = 600
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!

        // Fill with a gradient
        context.setFillColor(NSColor.systemBlue.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        return context.makeImage()!
    }()

    let display = DisplayInfo(
        id: 1,
        name: "Built-in Display",
        frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
        scaleFactor: 2.0,
        isPrimary: true
    )

    let screenshot = Screenshot(
        image: testImage,
        sourceDisplay: display
    )

    let viewModel = PreviewViewModel(screenshot: screenshot)

    return PreviewContentView(viewModel: viewModel)
        .frame(width: 600, height: 400)
}
#endif
