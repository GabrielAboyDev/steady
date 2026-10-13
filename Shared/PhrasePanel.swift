import SwiftUI

/// Pick a saved phrase to start filling in (US-009).
struct PhrasePicker: View {

    let phrases: [PhraseTemplate]
    let onSelect: (PhraseTemplate) -> Void

    /// Only the tray is read from here; see `QuickInsertPanel`.
    @Environment(\.keyboardPalette) private var palette

    var body: some View {
        Group {
            if phrases.isEmpty {
                VStack(spacing: 6) {
                    Text("No phrases yet")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Create phrases in the Steady app, using {braces} for the blanks.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(phrases) { phrase in
                            Button {
                                onSelect(phrase)
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(phrase.title)
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(Theme.textPrimary)
                                    Text(phrase.template)
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.textSecondary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(Theme.keyFace)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Use phrase \(phrase.title)")
                        }
                    }
                    .padding(10)
                }
            }
        }
        .background(palette.tray)
    }
}

/// The guided fill flow: one blank at a time, the Names-panel tiles as the
/// choices, a progress indicator, and the assembled sentence inserted the
/// moment the last blank is answered. There is no review step: for the people
/// this keyboard is for, a second "insert" tap is one more thing to hit.
struct PhraseFillView: View {

    @ObservedObject var session: PhraseFillSession

    let onInsert: (String) -> Void
    let onRequestFreeText: (PhraseSlot) -> Void
    let onCancel: () -> Void

    /// Only the tray is read from here; see `QuickInsertPanel`.
    @Environment(\.keyboardPalette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            preview
            Divider().overlay(Theme.ruleHairline)
            if let slot = session.currentSlot {
                prompt(for: slot)
            }
            controls
        }
        .background(palette.tray)
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 8) {
            // The sentence so far, with the blank being asked about highlighted.
            Text(attributedPreview)
                .font(.system(size: 17))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            if !session.progressLabel.isEmpty {
                Text(session.progressLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.brandDark)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.brandSoft)
                    .clipShape(Capsule())
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surfaceRaised)
    }

    /// Builds the preview text, tinting filled values and the active blank.
    private var attributedPreview: AttributedString {
        var result = AttributedString()
        for segment in session.segments {
            var piece = AttributedString(segment.text)
            switch segment.kind {
            case .literal:
                piece.foregroundColor = Theme.textPrimary
            case .filled:
                piece.foregroundColor = Theme.brandDark
                piece.inlinePresentationIntent = .stronglyEmphasized
            case .current:
                piece.foregroundColor = Theme.brand
                piece.inlinePresentationIntent = .stronglyEmphasized
                piece.underlineStyle = .single
            case .pending:
                piece.foregroundColor = Theme.textMuted
            }
            result.append(piece)
        }
        return result
    }

    private func prompt(for slot: PhraseSlot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Choose \(slot.name):")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.top, 10)

            if session.currentChoices.isEmpty && !slot.allowsFreeText {
                Text("No names yet — add some in the Steady app.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textMuted)
                    .padding(.horizontal, 12)
            }

            ScrollView {
                // The Names panel's own grid and tiles, so a name offered here
                // is the same tap it was over there.
                LazyVGrid(columns: quickInsertGridColumns, spacing: 10) {
                    ForEach(session.currentChoices) { choice in
                        Button {
                            answer(with: choice.text)
                        } label: {
                            QuickInsertTile(text: choice.text, note: choice.note)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Fill \(slot.name) with \(choice.text)")
                    }

                    if slot.allowsFreeText {
                        Button {
                            onRequestFreeText(slot)
                        } label: {
                            Text("Type…")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Theme.brandDark)
                                .frame(maxWidth: .infinity, minHeight: 60)
                                .background(Theme.brandSoft)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Type a value for \(slot.name)")
                    }
                }
                .padding(10)
            }
        }
    }

    /// Fill the current blank; when it was the last one, the sentence goes
    /// straight in rather than waiting for a second tap.
    private func answer(with value: String) {
        session.select(value)
        if session.isFinished {
            onInsert(session.assembledText)
        }
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button {
                if session.canGoBack {
                    session.back()
                } else {
                    onCancel()
                }
            } label: {
                Text(session.canGoBack ? "‹ Back" : "Cancel")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(minWidth: 88, minHeight: 48)
                    .background(Theme.keyFace)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            // Only ever enabled while the blanks still to come are optional:
            // it is how the user skips them. A required last blank inserts on
            // its own.
            Button {
                onInsert(session.assembledText)
            } label: {
                Text("Insert sentence")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(session.isComplete ? Theme.brand : Theme.textMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("insertSentence")
            .disabled(!session.isComplete)
            .accessibilityHint(session.isComplete ? "" : "Fill every blank first")
        }
        .padding(10)
    }
}
