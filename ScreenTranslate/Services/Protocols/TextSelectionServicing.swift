//
//  TextSelectionServicing.swift
//  ScreenTranslate
//
//  Protocol abstraction for TextSelectionService to enable testing
//

import Foundation

/// Protocol for text selection service operations.
/// Provides abstraction for testing and dependency injection.
protocol TextSelectionServicing: Sendable {
    /// Captures the currently selected text from the active application
    /// - Returns: The captured text selection result
    /// - Throws: CaptureError if capture fails
    func captureSelectedText() async throws -> TextSelectionResult
}

// MARK: - TextSelectionService Conformance

extension TextSelectionService: TextSelectionServicing {}
