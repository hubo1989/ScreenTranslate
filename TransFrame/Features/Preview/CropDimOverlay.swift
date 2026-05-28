import SwiftUI

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
