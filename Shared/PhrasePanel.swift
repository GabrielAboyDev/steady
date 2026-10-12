import SwiftUI

/// Pick a saved phrase to start filling in (US-009).
struct PhrasePicker: View {

    let phrases: [PhraseTemplate]
    let onSelect: (PhraseTemplate) -> Void

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
                .frame(maxWidth: .infinity)
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
        .background(Theme.keyTray)
    }
}

/// The guided fill flow: one blank at a time, large chips, progress indicator,
/// and the assembled sentence inserted when every required blank is answered.
struct PhraseFillView: View {

    @ObservedObject var session: PhraseFillSession

    let onInsert: (String) -> Void
    let onRequestFreeText: (PhraseSlot) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            preview
            Divider().overlay(Theme.ruleHairline)
            if let slot = session.currentSlot {
                prompt(for: slot)
            } else {
                readyState
            }
            controls
        }
        .background(Theme.keyTray)
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 8) {
            // The sentence so far, with the blank being asked about highlighted.
            Text(attributedPreview)
                .font(.system(size: 17))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            if !session.progressLabel.isEmpty {
                Text(session.currentSlot == nil ? "All blanks filled" : session.progressLabel)
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

            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 92), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(session.currentOptions, id: \.self) { option in
                        Button {
                            session.select(option)
                        } label: {
                            Text(option)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .background(Theme.keyFace)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Fill \(slot.name) with \(option)")
                    }

                    if slot.allowsFreeText {
                        Button {
                            onRequestFreeText(slot)
                        } label: {
                            Text("Type…")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Theme.brandDark)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .background(Theme.brandSoft)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Type a value for \(slot.name)")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }
        }
    }

    private var readyState: some View {
        Text("Review the sentence, then insert it.")
            .font(.system(size: 14))
            .foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
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
