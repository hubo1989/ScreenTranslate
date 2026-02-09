import SwiftUI
import AppKit

struct BilingualResultView: View {
    @Bindable var viewModel: BilingualResultViewModel
    @State private var imageScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    Image(decorative: viewModel.image, scale: 1.0)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(viewModel.scale)
                        .frame(
                            width: CGFloat(viewModel.imageWidth) * viewModel.scale,
                            height: CGFloat(viewModel.imageHeight) * viewModel.scale
                        )
                        .onScrollWheelZoom { delta in
                            if delta > 0 {
                                viewModel.zoomIn()
                            } else {
                                viewModel.zoomOut()
                            }
                        }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))

                if viewModel.isLoading {
                    loadingOverlay
                }
            }

            Divider()

            toolBar
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.bar)
        }
        .onKeyPress(.escape) {
            BilingualResultWindowController.shared.close()
            return .handled
        }
        .overlay(alignment: .top) {
            if let message = viewModel.copySuccessMessage {
                successToast(message: message, icon: "doc.on.clipboard.fill")
            }
            if let message = viewModel.saveSuccessMessage {
                successToast(message: message, icon: "checkmark.circle.fill")
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

    private var toolBar: some View {
        HStack(spacing: 12) {
            Text(viewModel.dimensionsText)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)

            Divider()
                .frame(height: 16)

            HStack(spacing: 4) {
                Button(action: viewModel.zoomOut) {
                    Image(systemName: "minus.magnifyingglass")
                }
                .buttonStyle(.borderless)
                .help(String(localized: "bilingualResult.zoomOut"))

                Button(action: viewModel.resetZoom) {
                    Text("\(Int(viewModel.scale * 100))%")
                        .font(.system(.caption, design: .monospaced))
                        .frame(minWidth: 45)
                }
                .buttonStyle(.borderless)
                .help(String(localized: "bilingualResult.resetZoom"))

                Button(action: viewModel.zoomIn) {
                    Image(systemName: "plus.magnifyingglass")
                }
                .buttonStyle(.borderless)
                .help(String(localized: "bilingualResult.zoomIn"))
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: viewModel.copyToClipboard) {
                    Label(String(localized: "bilingualResult.copy"), systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.bordered)

                Button(action: viewModel.saveImage) {
                    Label(String(localized: "bilingualResult.save"), systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func successToast(message: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.green)
            Text(message)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
        .shadow(radius: 4)
        .padding(.top, 20)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.3), value: message)
    }

    private var loadingOverlay: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text(viewModel.loadingMessage)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.3))
    }
}

#if DEBUG
#Preview {
    let testImage: CGImage = {
        let width = 800
        let height = 400
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ),
              let image = context.makeImage() else {
            fatalError("Unable to create test image")
        }
        context.setFillColor(NSColor.systemBlue.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return image
    }()

    let viewModel = BilingualResultViewModel(image: testImage)
    return BilingualResultView(viewModel: viewModel)
        .frame(width: 600, height: 400)
}
#endif
