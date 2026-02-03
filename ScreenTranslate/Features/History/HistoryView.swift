import SwiftUI
import AppKit

/// Main view for browsing and managing translation history.
struct HistoryView: View {
    @ObservedObject var store: HistoryStore

    /// Currently selected entry for context menu
    @State private var contextMenuEntry: TranslationHistory?

    /// Scroll position for detecting load more
    @Namespace private var scrollNamespace

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            SearchBar(store: store)

            Divider()

            // History list
            if store.filteredEntries.isEmpty {
                EmptyStateView(store: store)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        // Load more trigger at top
                        if store.hasMoreEntries && store.searchQuery.isEmpty {
                            LoadMoreTrigger()
                                .onAppear {
                                    store.loadMore()
                                }
                        }

                        // History entries
                        ForEach(store.filteredEntries) { entry in
                            HistoryEntryRow(entry: entry, store: store)
                                .contextMenu {
                                    EntryContextMenu(
                                        entry: entry,
                                        store: store
                                    )
                                }
                        }
                    }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}

// MARK: - Search Bar

/// Search bar for filtering history entries.
private struct SearchBar: View {
    @ObservedObject var store: HistoryStore
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search history...", text: Binding(
                get: { store.searchQuery },
                set: { store.search($0) }
            ))
            .focused($isFocused)
            .textFieldStyle(.plain)
            .onExitCommand {
                isFocused = false
            }

            if !store.searchQuery.isEmpty {
                Button {
                    store.search("")
                    isFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Clear all button
            if !store.entries.isEmpty {
                Button {
                    showClearConfirmation()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear all history")
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func showClearConfirmation() {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString(
            "history.clear.alert.title",
            comment: "Clear History"
        )
        alert.informativeText = NSLocalizedString(
            "history.clear.alert.message",
            comment: "Are you sure you want to clear all translation history?"
        )
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("button.clear", comment: "Clear"))
        alert.addButton(withTitle: NSLocalizedString("button.cancel", comment: "Cancel"))

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            store.clear()
        }
    }
}

// MARK: - Empty State

/// View shown when no history entries exist.
private struct EmptyStateView: View {
    @ObservedObject var store: HistoryStore

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            if store.searchQuery.isEmpty {
                Text("No Translation History")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text("Your translated screenshots will appear here")
                    .font(.body)
                    .foregroundStyle(.tertiary)
            } else {
                Text("No Results")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text("No entries match your search")
                    .font(.body)
                    .foregroundStyle(.tertiary)

                Button {
                    store.search("")
                } label: {
                    Text("Clear Search")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Load More Trigger

/// Invisible view that triggers loading more entries when visible.
private struct LoadMoreTrigger: View {
    var body: some View {
        Color.clear
            .frame(height: 1)
    }
}

// MARK: - History Entry Row

/// Row displaying a single history entry.
private struct HistoryEntryRow: View {
    let entry: TranslationHistory
    @ObservedObject var store: HistoryStore

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Thumbnail
            ThumbnailView(entry: entry)

            // Content
            VStack(alignment: .leading, spacing: 6) {
                // Header with languages and timestamp
                HStack {
                    Text(entry.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(entry.formattedTimestamp)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                // Source text
                TextSection(
                    text: entry.sourcePreview,
                    isTruncated: entry.isSourceTruncated,
                    label: "Source"
                )

                // Arrow separator
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(.secondary.opacity(0.3))
                        .frame(width: 20, height: 1)

                    Image(systemName: "arrow.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Rectangle()
                        .fill(.secondary.opacity(0.3))
                        .frame(width: 20, height: 1)
                }
                .padding(.vertical, 2)

                // Translated text
                TextSection(
                    text: entry.translatedPreview,
                    isTruncated: entry.isTranslatedTruncated,
                    label: "Translation"
                )
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .contextMenu {
            EntryContextMenu(entry: entry, store: store)
        }
        .help(entry.fullDateString)
    }
}

// MARK: - Thumbnail View

/// Displays a thumbnail image from history entry.
private struct ThumbnailView: View {
    let entry: TranslationHistory

    var body: some View {
        Group {
            if entry.hasThumbnail, let data = entry.thumbnailData, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                // Placeholder when no thumbnail
                RoundedRectangle(cornerRadius: 8)
                    .fill(.secondary.opacity(0.1))
                    .frame(width: 64, height: 64)
                    .overlay {
                        Image(systemName: "doc.text")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
            }
        }
    }
}

// MARK: - Text Section

/// Displays a section of text with optional truncation indicator.
private struct TextSection: View {
    let text: String
    let isTruncated: Bool
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(text)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(4)
                .textSelection(.enabled)

            if isTruncated {
                HStack(spacing: 4) {
                    Image(systemName: "ellipsis")
                        .font(.caption2)
                    Text("truncated")
                        .font(.caption2)
                }
                .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Entry Context Menu

/// Context menu for history entries.
private struct EntryContextMenu: View {
    let entry: TranslationHistory
    @ObservedObject var store: HistoryStore

    var body: some View {
        Group {
            Button {
                store.copyTranslation(entry)
            } label: {
                Label("Copy Translation", systemImage: "doc.on.doc")
            }

            Button {
                store.copySource(entry)
            } label: {
                Label("Copy Source", systemImage: "doc.on.doc")
            }

            Button {
                store.copyBoth(entry)
            } label: {
                Label("Copy Both", systemImage: "doc.on.clipboard")
            }

            Divider()

            Button(role: .destructive) {
                store.remove(entry)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    HistoryView(store: HistoryStore())
        .frame(width: 700, height: 500)
}
#endif
