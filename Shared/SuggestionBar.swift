import SwiftUI

/// The word suggestions above the keys (US-004).
///
/// Styled like the iOS prediction row: plain text on the tray, separated by
/// hairlines, with no chip fills, rounded rectangles or shadows, and about
/// the same height. The press highlight is the only fill, and it only exists
/// while a finger is down.
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

    /// Set by `KeyboardSurface` from the appearance setting; light by default.
    @Environment(\.keyboardPalette) private var palette

    /// The height of a word's slice, sized to the stock prediction row.
    /// Measured on iOS 26 at 3x: the system's rules are 24pt tall and its
    /// first key row starts 52pt below the top of the pane; this view starts
    /// about 17pt below that edge, so 32pt here puts the panel toolbar where
    /// the stock keys begin. Below the 44pt touch minimum on purpose — the
    /// words are the full width of a third of the row, which is what makes
    /// them hittable.
    private let rowHeight: CGFloat = 32
    private let perPage = 3
    /// Wide enough for most words at 17pt, and the cell scales text down from
    /// there. Scrolling needs a real width — `maxWidth: .infinity` collapses
    /// inside a horizontal ScrollView.
    private let scrollCellWidth: CGFloat = 112
    /// The full row, so each rule runs from the top edge down to the panel
    /// toolbar and the words sit in columns rather than floating in a band.
    private var ruleHeight: CGFloat { rowHeight }

    var body: some View {
        Group {
            if suggestions.isEmpty {
                Text(areNextWord ? "Keep typing" : "No suggestions")
                    .font(.system(size: 14))
                    .foregroundStyle(palette.keyLabelMuted)
                    .frame(maxWidth: .infinity, minHeight: rowHeight)
            } else {
                switch browsing {
                case .scroll: scrollingRow
                case .paginate: pagedRow
                }
            }
        }
        .padding(.horizontal, 4)
        // No vertical padding at all: iOS already leaves a strip of its own
        // pane above the keyboard, so an inset above stacked on top of that,
        // and the 44pt cells leave enough air around the words below.
        .background(palette.tray)
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
                arrow(
                    "chevron.left", label: "Previous suggestions",
                    identifier: "suggestions-previous", enabled: page > 0
                ) {
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
                arrow(
                    "chevron.right", label: "More suggestions",
                    identifier: "suggestions-next", enabled: page < pageCount - 1
                ) {
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
                .foregroundStyle(rank == 0 ? emphasis : palette.keyLabel)
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
                .foregroundStyle(enabled ? palette.keyLabel : palette.keyLabelMuted.opacity(0.5))
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
            .fill(palette.isDark ? Color.white.opacity(0.18) : Theme.keyTrayRule)
            .frame(width: 1, height: ruleHeight)
    }

    /// The top word's colour. `brandDark` disappears into a near-black tray,
    /// so dark borrows the lighter accent the keys use for their ring.
    private var emphasis: Color {
        palette.isDark ? palette.accentStroke : Theme.brandDark
    }
}

/// No resting background at all; a soft rounded wash only while pressed, which
/// is what the system row does. Also restores the full-rectangle hit area that
/// a transparent label would otherwise lose.
private struct FlatSuggestionStyle: ButtonStyle {
    @Environment(\.keyboardPalette) private var palette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(palette.keyFace.opacity(configuration.isPressed ? 0.9 : 0))
            )
    }
}
