import SwiftUI

/// The Names panel: tap a saved entry to insert it verbatim (US-008).
/// Entries are managed in the container app; this panel is read-only.
struct QuickInsertPanel: View {

    let categories: [QuickInsertCategory]
    let onInsert: (QuickInsertEntry) -> Void

    @State private var selectedCategoryID: UUID?

    private var selectedCategory: QuickInsertCategory? {
        categories.first { $0.id == selectedCategoryID } ?? categories.first
    }

    var body: some View {
        VStack(spacing: 0) {
            if categories.isEmpty {
                emptyState
            } else {
                categoryStrip
                entryGrid
            }
        }
        .background(Theme.keyTray)
    }

    private var categoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories) { category in
                    let isSelected = category.id == (selectedCategory?.id)
                    Button {
                        selectedCategoryID = category.id
                    } label: {
                        Text(category.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(isSelected ? .white : Theme.textSecondary)
                            .padding(.horizontal, 16)
                            .frame(height: 40)
                            .background(isSelected ? Theme.brand : Theme.keyFace)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }

    private var entryGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                ForEach(selectedCategory?.entries ?? []) { entry in
                    Button {
                        onInsert(entry)
                    } label: {
                        VStack(spacing: 2) {
                            Text(entry.text)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            if let note = entry.note, !note.isEmpty {
                                Text(note)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.textMuted)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .background(Theme.keyFace)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.14), radius: 0, x: 0, y: 1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Insert \(entry.text)")
                }
            }
            .padding(10)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("No names yet")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("Add names in the Steady app and they'll appear here.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}
