import SwiftUI

/// The word suggestions above the keys (US-004).
///
/// Styled like the iOS prediction row: plain text on the tray, separated by
/// hairlines, with no chip fills, rounded rectangles or shadows. What the row
/// does *not* copy from iOS is its height — each word still owns a 52pt slice,
/// comfortably past the 44pt minimum touch target, so the flat look costs the
/// user nothing in aim. The press highlight is the only fill, and it only
/// exists while a finger is down.
///
/// Three fit across a phone, but the engine offers more than three. The rest
/// are reached either by swiping the row or by stepping it with arrows,
/// whichever the user picked in settings.
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

    /// The tappable height of a word. Visually flat, physically full-size.
    private let rowHeight: CGFloat = 52
    private let perPage = 3
    /// Wide enough for most words at 17pt, and the cell scales text down from
    /// there. Scrolling needs a real width — `maxWidth: .infinity` collapses
    /// inside a horizontal ScrollView.
    private let scrollCellWidth: CGFloat = 112
    /// Shorter than the row, like the system's own: a full-bleed rule would
    /// read as a table, an inset one reads as a separator.
    private let ruleHeight: CGFloat = 30

    var body: some View {
        Group {
            if suggestions.isEmpty {
                Text(areNextWord ? "Keep typing" : "No suggestions")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textMuted)
                    .frame(maxWidth: .infinity, minHeight: rowHeight)
            } else {
                switch browsing {
                case .scroll: scrollingRow
                case .paginate: pagedRow
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 5)
        .background(Theme.keyTray)
        .onChange(of: suggestions) { _ in page = 0 }
    }

    // MARK: Scroll

    private var scrollingRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(suggestions.enumerated()), id: \.offset) { index, word in
                    if index > 0 { rule }
                    cell(word, rank: index, identifier: "suggestion-\(index)")
                        .frame(width: scrollCellWidth)
                }
            }
        }
        .frame(height: rowHeight)
    }

    // MARK: Paginate

    private var pagedRow: some View {
        HStack(spacing: 0) {
            if pageCount > 1 {
                arrow("chevron.left", label: "Previous suggestions",
                      identifier: "suggestions-previous", enabled: page > 0) {
                    page -= 1
                }
                rule
            }

            ForEach(Array(currentPage.enumerated()), id: \.offset) { slot, word in
                // Identified by slot, not by absolute rank: `suggestion-0` is
                // always the leftmost word, whichever page is showing.
                if slot > 0 { rule }
                cell(word, rank: pageStart + slot, identifier: "suggestion-\(slot)")
            }

            if pageCount > 1 {
                rule
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
    /// takes the emphasis — paging forward does not crown a new best.
    ///
    /// That emphasis is weight *and* colour rather than a fill: the top word is
    /// semibold in the dark brand green, the rest regular in the usual ink.
    /// Two channels, so it does not rely on colour alone.
    private func cell(_ word: String, rank: Int, identifier: String) -> some View {
        Button {
            onPick(word)
        } label: {
            Text(word)
                .font(.system(size: 17, weight: rank == 0 ? .semibold : .regular))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(rank == 0 ? Theme.brandDark : Theme.textPrimary)
                .frame(maxWidth: .infinity, minHeight: rowHeight)
        }
        .buttonStyle(FlatSuggestionStyle())
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(areNextWord ? "Insert next word \(word)" : "Complete word as \(word)")
        .accessibilityAddTraits(rank == 0 ? [.isSelected] : [])
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
                .foregroundStyle(enabled ? Theme.textSecondary : Theme.textMuted.opacity(0.45))
                // 44pt wide: the arrows are a touch target like any other key.
                .frame(width: 44, height: rowHeight)
        }
        .buttonStyle(FlatSuggestionStyle())
        .disabled(!enabled)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(label)
    }

    private var rule: some View {
        Rectangle()
            .fill(Theme.keyTrayRule)
            .frame(width: 1, height: ruleHeight)
    }
}

/// No resting background at all; a soft rounded wash only while pressed, which
/// is what the system row does. Also restores the full-rectangle hit area that
/// a transparent label would otherwise lose.
private struct FlatSuggestionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.keyFace.opacity(configuration.isPressed ? 0.9 : 0))
            )
    }
}
