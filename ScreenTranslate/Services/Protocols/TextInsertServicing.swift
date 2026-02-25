//
//  TextInsertServicing.swift
//  ScreenTranslate
//
//  Protocol abstraction for TextInsertService to enable testing
//

import Foundation

/// Protocol for text insertion service operations.
/// Provides abstraction for testing and dependency injection.
protocol TextInsertServicing: Sendable {
    /// Inserts text at the current cursor position
    /// - Parameter text: The text to insert
    /// - Throws: InsertError if insertion fails
    func insertText(_ text: String) async throws

    /// Deletes the current selection and inserts text at that position
    /// - Parameter text: The text to insert after deletion
    /// - Throws: InsertError if the operation fails
    func deleteSelectionAndInsert(_ text: String) async throws
}

// MARK: - TextInsertService Conformance

extension TextInsertService: TextInsertServicing {}
