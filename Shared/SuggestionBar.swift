import SwiftUI

/// The three large word chips above the keys (US-004).
///
/// Chips are 52pt tall — comfortably past the 44pt minimum touch target — so
/// they stay hittable for users who can't place a finger precisely.
struct SuggestionBar: View {

    let suggestions: [String]
    /// True when these are next-word predictions rather than completions.
    let areNextWord: Bool
    let onPick: (String) -> Void

    private let chipHeight: CGFloat = 52

    var body: some View {
        HStack(spacing: 8) {
            if suggestions.isEmpty {
                Text(areNextWord ? "Keep typing" : "No suggestions")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textMuted)
                    .frame(maxWidth: .infinity, minHeight: chipHeight)
            } else {
                ForEach(Array(suggestions.enumerated()), id: \.offset) { index, word in
                    Button {
                        onPick(word)
                    } label: {
                        Text(word)
                            .font(.system(size: 17, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(index == 0 ? .white : Theme.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: chipHeight)
                            .background(index == 0 ? Theme.brand : Theme.keyFace)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.18), radius: 0, x: 0, y: 1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("suggestion-\(index)")
                    .accessibilityLabel(areNextWord ? "Insert next word \(word)" : "Complete word as \(word)")
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(Theme.keyTray)
    }
}
