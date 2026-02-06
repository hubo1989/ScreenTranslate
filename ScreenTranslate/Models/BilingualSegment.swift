//
//  BilingualSegment.swift
//  ScreenTranslate
//
//  Created for US-010: 创建 TranslationService 编排层
//

import Foundation

/// Represents a bilingual text segment with source and translated text
struct BilingualSegment: Sendable, Equatable, Identifiable {
    let id: UUID
    let sourceText: String
    let translatedText: String
    let sourceLanguage: String?
    let targetLanguage: String
    
    init(
        id: UUID = UUID(),
        sourceText: String,
        translatedText: String,
        sourceLanguage: String? = nil,
        targetLanguage: String
    ) {
        self.id = id
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
    }
    
    init(from result: TranslationResult) {
        self.id = UUID()
        self.sourceText = result.sourceText
        self.translatedText = result.translatedText
        self.sourceLanguage = result.sourceLanguage
        self.targetLanguage = result.targetLanguage
    }
}
