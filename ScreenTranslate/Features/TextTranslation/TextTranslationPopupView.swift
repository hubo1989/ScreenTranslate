//
//  TextTranslationPopupView.swift
//  ScreenTranslate
//
//  Created for US-004: Create TextTranslationPopup window for showing translation results
//  Updated: Standard window style with title bar, content, and toolbar
//

import SwiftUI
import AppKit

// MARK: - SwiftUI Content View

struct TextTranslationPopupContentView: View {
    let originalText: String
    let translatedText: String
    let sourceLanguage: String
    let targetLanguage: String
    let onCopy: () -> Void

    @State private var showCopySuccess = false

    private var isOriginalRTL: Bool {
        Self.isRTLLanguage(sourceLanguage) || Self.containsRTLText(originalText)
    }

    private var isTranslatedRTL: Bool {
        Self.isRTLLanguage(targetLanguage) || Self.containsRTLText(translatedText)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Content area
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Original text section
                    VStack(alignment: isOriginalRTL ? .trailing : .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "text.bubble")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text(sourceLanguage.uppercased())
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.tertiary)
                                .tracking(0.5)
                            Spacer()
                        }

                        Text(originalText)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(isOriginalRTL ? .trailing : .leading)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: isOriginalRTL ? .trailing : .leading)
                    }
                    .padding(14)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    // Translated text section
                    VStack(alignment: isTranslatedRTL ? .trailing : .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.bubble")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.blue)
                            Text(targetLanguage.uppercased())
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.blue)
                                .tracking(0.5)
                            Spacer()
                        }

                        Text(translatedText)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(isTranslatedRTL ? .trailing : .leading)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: isTranslatedRTL ? .trailing : .leading)
                    }
                    .padding(14)
                    .background(Color.blue.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.blue.opacity(0.15), lineWidth: 0.5)
                    )
                }
                .padding(16)
            }
            .frame(maxHeight: 350)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Toolbar
            toolbar
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.bar)
        }
        .frame(minWidth: 380, idealWidth: 420, maxWidth: 520, minHeight: 200)
        .onKeyPress(.escape) {
            NSApp.keyWindow?.close()
            return .handled
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            // Character count info
            Text("\(originalText.count) → \(translatedText.count)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)

            Divider()
                .frame(height: 16)

            Spacer()

            Button(action: {
                onCopy()
                showCopySuccess = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showCopySuccess = false
                }
            }) {
                Label(
                    showCopySuccess ? String(localized: "common.copied") : String(localized: "common.copy"),
                    systemImage: showCopySuccess ? "checkmark" : "doc.on.clipboard"
                )
            }
            .buttonStyle(.bordered)
            .disabled(showCopySuccess)
            .foregroundColor(showCopySuccess ? .green : nil)
        }
    }

    // MARK: - RTL Detection

    private static func isRTLLanguage(_ languageName: String) -> Bool {
        let rtlLanguageIndicators = [
            "ARABIC", "HEBREW", "PERSIAN", "FARSI", "URDU",
            "阿拉伯语", "希伯来语", "波斯语", "乌尔都语"
        ]
        let uppercasedName = languageName.uppercased()
        return rtlLanguageIndicators.contains { uppercasedName.contains($0) }
    }

    private static func containsRTLText(_ text: String) -> Bool {
        var rtlCount = 0
        var ltrCount = 0

        for scalar in text.unicodeScalars {
            let value = scalar.value
            if (value >= 0x590 && value <= 0x5FF) ||
               (value >= 0x600 && value <= 0x6FF) ||
               (value >= 0x750 && value <= 0x77F) ||
               (value >= 0xFB50 && value <= 0xFDFF) ||
               (value >= 0xFE70 && value <= 0xFEFF) {
                rtlCount += 1
            } else if (value >= 0x41 && value <= 0x5A) || (value >= 0x61 && value <= 0x7A) {
                ltrCount += 1
            }
        }

        return rtlCount > 0 && (ltrCount == 0 || Double(rtlCount) / Double(rtlCount + ltrCount) > 0.3)
    }
}

// MARK: - Preview

#Preview {
    TextTranslationPopupContentView(
        originalText: "Hello, how are you today?",
        translatedText: "你好，今天怎么样？",
        sourceLanguage: "English",
        targetLanguage: "Chinese",
        onCopy: {}
    )
    .frame(width: 420, height: 280)
}
