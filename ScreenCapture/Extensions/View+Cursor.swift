import SwiftUI
import AppKit

/// Extension to add cursor support to SwiftUI views
extension View {
    /// Sets the cursor to use when hovering over this view
    /// - Parameter cursor: The NSCursor to display
    /// - Returns: A view that changes the cursor on hover
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { isHovering in
            if isHovering {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
