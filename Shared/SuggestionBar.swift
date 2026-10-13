import SwiftUI

/// The large word chips above the keys (US-004).
///
/// Three fit across a phone, but the engine offers more than three. The rest
/// are reached either by swiping the row or by stepping it with arrows,
/// whichever the user picked in settings.
///
/// Chips are 52pt tall — comfortably past the 44pt minimum touch target — so
/// they stay hittable for users who can't place a finger precisely.
struct SuggestionBar: View {

    let suggestions: [String]
    /// True when these are next-word predictions rather than completions.
    let areNextWord: Bool
    var browsing: SuggestionBrowsing = .paginate
    let onPick: (String) -> Void

    /// Which page of three is showing, in `.paginate`. Reset whenever the
    /// words change, because page 2 of the previous word's list has nothing
    /// to do with this one.
    @State private var page = 0

    private let chipHeight: CGFloat = 52
    private let perPage = 3
    /// Wide enough for most words at 17pt, and the chip scales text down from
    /// there. Scrolling needs a real width — `maxWidth: .infinity` collapses
    /// inside a horizontal ScrollView.
    private let scrollChipWidth: CGFloat = 112

    var body: some View {
        Group {
            if suggestions.isEmpty {
                Text(areNextWord ? "Keep typing" : "No suggestions")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textMuted)
                    .frame(maxWidth: .infinity, minHeight: chipHeight)
            } else {
                switch browsing {
                case .scroll: scrollingRow
                case .paginate: pagedRow
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(Theme.keyTray)
        .onChange(of: suggestions) { _ in page = 0 }
    }

    // MARK: Scroll

    private var scrollingRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(suggestions.enumerated()), id: \.offset) { index, word in
                    chip(word, rank: index, identifier: "suggestion-\(index)")
                        .frame(width: scrollChipWidth)
                }
            }
        }
        .frame(height: chipHeight)
    }

    // MARK: Paginate

    private var pagedRow: some View {
        HStack(spacing: 8) {
            if pageCount > 1 {
                arrow("chevron.left", label: "Previous suggestions",
                      identifier: "suggestions-previous", enabled: page > 0) {
                    page -= 1
                }
            }

            ForEach(Array(currentPage.enumerated()), id: \.offset) { slot, word in
                // Identified by slot, not by absolute rank: `suggestion-0` is
                // always the leftmost chip, whichever page is showing.
                chip(word, rank: pageStart + slot, identifier: "suggestion-\(slot)")
            }

            if pageCount > 1 {
                arrow("chevron.right", label: "More suggestions",
                      identifier: "suggestions-next", enabled: page < pageCount - 1) {
                    page += 1
                }
            }
        }
    }

    private var pageCount: Int {
        max(1, (suggestions.count + perPage - 1) / perPage)
    }

    /// Clamped rather than trusted: the list can shrink under a stale page.
    private var pageStart: Int {
        min(max(0, page), pageCount - 1) * perPage
    }

    private var currentPage: [String] {
        Array(suggestions[pageStart..<min(pageStart + perPage, suggestions.count)])
    }

    // MARK: Pieces

    /// `rank` is the word's position overall, so only the engine's top word
    /// takes the brand fill — paging forward does not crown a new best.
    private func chip(_ word: String, rank: Int, identifier: String) -> some View {
        Button {
            onPick(word)
        } label: {
            Text(word)
                .font(.system(size: 17, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(rank == 0 ? .white : Theme.textPrimary)
                .frame(maxWidth: .infinity, minHeight: chipHeight)
                .background(rank == 0 ? Theme.brand : Theme.keyFace)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.18), radius: 0, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(areNextWord ? "Insert next word \(word)" : "Complete word as \(word)")
    }

    private func arrow(
        _ symbol: String,
        label: String,
        identifier: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(enabled ? Theme.textPrimary : Theme.textMuted.opacity(0.5))
                // 44pt wide: the arrows are a touch target like any other key.
                .frame(width: 44, height: chipHeight)
                .background(Theme.keyFace.opacity(enabled ? 1 : 0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(enabled ? 0.18 : 0), radius: 0, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(label)
    }
}
