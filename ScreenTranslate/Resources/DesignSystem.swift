import SwiftUI

/// macOS 26 "Liquid Glass" Design System
enum DesignSystem {
    enum Colors {
        static let meshColors: [Color] = [
            Color(red: 0.1, green: 0.2, blue: 0.45), // Deep Ocean
            Color(red: 0.3, green: 0.1, blue: 0.4),  // Royal Purple
            Color(red: 0.05, green: 0.25, blue: 0.25), // Emerald Teal
            Color(red: 0.15, green: 0.15, blue: 0.3)  // Midnight
        ]
        
        static let glassBorder = Color.white.opacity(0.18)
        static let liquidHighlight = Color.white.opacity(0.3)
    }
    
    enum Radii {
        static let window: CGFloat = 32
        static let card: CGFloat = 24
        static let control: CGFloat = 12
    }
}

/// A dynamic, flowing mesh gradient for the window background
struct MeshGradientView: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            // Base layer
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.1, blue: 0.15), Color(red: 0.03, green: 0.05, blue: 0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Flowing blobs
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    
                    for index in 0..<4 {
                        let x = size.width * (0.5 + 0.3 * sin(time * 0.5 + Double(index)))
                        let y = size.height * (0.5 + 0.3 * cos(time * 0.4 + Double(index) * 1.5))
                        let radius = max(size.width, size.height) * 0.6
                        
                        context.fill(
                            Circle().path(
                                in: CGRect(x: x - radius / 2, y: y - radius / 2, width: radius, height: radius)
                            ),
                            with: .radialGradient(
                                Gradient(colors: [DesignSystem.Colors.meshColors[index].opacity(0.4), .clear]),
                                center: CGPoint(x: x, y: y),
                                startRadius: 0,
                                endRadius: radius / 2
                            )
                        )
                    }
                }
            }
            .blur(radius: 60)
        }
        .ignoresSafeArea()
    }
}

extension View {
    /// Applies the advanced macOS 26 Liquid Glass effect
    func macos26LiquidGlass(cornerRadius: CGFloat = DesignSystem.Radii.card) -> some View {
        self
            .padding(20)
            .background {
                ZStack {
                    // Deep Glass Material
                    VisualEffectView(material: .selection, blendingMode: .withinWindow)
                        .opacity(0.4)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    
                    // Specular Highlight (Inner edge)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.4), .clear, .white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                    
                    // Iridescent Refraction (Center edge)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            AngularGradient(
                                colors: [
                                    .blue.opacity(0.2),
                                    .purple.opacity(0.2),
                                    .cyan.opacity(0.2),
                                    .blue.opacity(0.2)
                                ],
                                center: .center
                            ),
                            lineWidth: 0.5
                        )
                }
            }
            .shadow(color: .black.opacity(0.25), radius: 25, x: 0, y: 12)
    }
    
    /// Icon glow for macOS 26
    func macos26IconGlow(color: Color = .blue) -> some View {
        self
            .padding(8)
            .background {
                Circle()
                    .fill(color.opacity(0.12))
                    .blur(radius: 6)
                    .overlay {
                        Circle()
                            .stroke(color.opacity(0.3), lineWidth: 0.5)
                    }
            }
            .foregroundStyle(color)
    }
}

/// Bridge to NSVisualEffectView for SwiftUI
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
