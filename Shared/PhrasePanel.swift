import SwiftUI

/// Pick a saved phrase to start filling in (US-009).
struct PhrasePicker: View {

    let phrases: [PhraseTemplate]
    /// Takes the phrase, and returns what blind mode should say about it: the
    /// sentence that went in, or the first blank now being asked.
    let onSelect: (PhraseTemplate) -> String?

    /// Follows the same palette as the keys and toolbar, so the panel matches
    /// the keyboard's own light/dark appearance.
    @Environment(\.keyboardPalette) private var palette

    var body: some View {
        Group {
            if phrases.isEmpty {
                let title = "No phrases yet"
                let detail = "Create phrases in the Steady app, using {braces} for the blanks."
                VStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(palette.keyLabel)
                    Text(detail)
                        .font(.system(size: 13))
                        .foregroundStyle(palette.segmentLabel)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .blindTarget(.item("phrases-empty"), spokenName: "\(title). \(detail)", cornerRadius: 12) {
                    nil
                }
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(phrases) { phrase in
                            Button {
                                _ = onSelect(phrase)
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(phrase.title)
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(palette.keyLabel)
                                    Text(phrase.template)
                                        .font(.system(size: 13))
                                        .foregroundStyle(palette.segmentLabel)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(palette.keyFace)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Use phrase \(phrase.title)")
                            .blindTarget(
                                .item("phrase-\(phrase.id)"), spokenName: phrase.title, cornerRadius: 12
                            ) {
                                onSelect(phrase)
                            }
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

    /// Follows the same palette as the keys and toolbar, so the panel matches
    /// the keyboard's own light/dark appearance.
    @Environment(\.keyboardPalette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            preview
            Divider().overlay(palette.divider)
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
                    .foregroundStyle(palette.highlightLabel)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(palette.highlightFill)
                    .clipShape(Capsule())
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.draftBar)
        // The sentence so far, read with each blank named; submitting it
        // simply reads it again.
        .blindTarget(.item("phrase-preview"), spokenName: spokenPreview, cornerRadius: 8) { spokenPreview }
    }

    /// The preview as blind mode reads it: filled blanks as their values,
    /// open ones as "blank for name".
    private var spokenPreview: String {
        session.segments.map { segment -> String in
            switch segment.kind {
            case .literal, .filled:
                return segment.text
            case .current, .pending:
                let name = segment.text.trimmingCharacters(in: CharacterSet(charactersIn: "{}"))
                return " blank for \(name) "
            }
        }
        .joined()
        .replacingOccurrences(of: "  ", with: " ")
    }

    /// What blind mode says once a blank is answered: the next one to fill,
    /// or that the sentence is ready.
    private var nextPrompt: String {
        session.currentSlot.map { "Choose \($0.name)" } ?? "Ready to insert"
    }

    /// Builds the preview text, tinting filled values and the active blank.
    private var attributedPreview: AttributedString {
        var result = AttributedString()
        for segment in session.segments {
            var piece = AttributedString(segment.text)
            switch segment.kind {
            case .literal:
                piece.foregroundColor = palette.keyLabel
            case .filled:
                piece.foregroundColor = palette.highlightLabel
                piece.inlinePresentationIntent = .stronglyEmphasized
            case .current:
                piece.foregroundColor = palette.accent
                piece.inlinePresentationIntent = .stronglyEmphasized
                piece.underlineStyle = .single
            case .pending:
                piece.foregroundColor = palette.keyLabelMuted
            }
            result.append(piece)
        }
        return result
    }

    private func prompt(for slot: PhraseSlot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Choose \(slot.name):")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.segmentLabel)
                .padding(.horizontal, 12)
                .padding(.top, 10)

            if session.currentChoices.isEmpty && !slot.allowsFreeText {
                Text("No names yet — add some in the Steady app.")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.keyLabelMuted)
                    .padding(.horizontal, 12)
            }

            ScrollView {
                // The Names panel's own grid and tiles, so a name offered here
                // is the same tap it was over there.
                LazyVGrid(columns: quickInsertGridColumns, spacing: 10) {
                    ForEach(session.currentChoices) { choice in
                        Button {
                            _ = answer(with: choice.text)
                        } label: {
                            QuickInsertTile(text: choice.text)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Fill \(slot.name) with \(choice.text)")
                        .blindTarget(.item("choice-\(choice.id)"), spokenName: choice.text, cornerRadius: 12)
                        {
                            answer(with: choice.text)
                        }
                    }

                    if slot.allowsFreeText {
                        Button {
                            onRequestFreeText(slot)
                        } label: {
                            Text("Type…")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(palette.highlightLabel)
                                .frame(maxWidth: .infinity, minHeight: 60)
                                .background(palette.highlightFill)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Type a value for \(slot.name)")
                        .blindTarget(.item("phrase-type"), spokenName: "type \(slot.name)", cornerRadius: 12)
                        {
                            onRequestFreeText(slot)
                            return "Typing \(slot.name)"
                        }
                    }
                }
                .padding(10)
            }
        }
    }

    /// Fill the current blank; when it was the last one, the sentence goes
    /// straight in rather than waiting for a second tap. Returns what blind
    /// mode says about it: the sentence that went in, or the value and the
    /// next blank.
    private func answer(with value: String) -> String? {
        session.select(value)
        if session.isFinished {
            onInsert(session.assembledText)
            return session.assembledText
        }
        return "\(value). \(nextPrompt)"
    }

    /// The Back / Cancel button's work, with what blind mode says about it.
    private func stepBack() -> String? {
        if session.canGoBack {
            session.back()
            return nextPrompt
        }
        onCancel()
        return "Phrases"
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button {
                _ = stepBack()
            } label: {
                Text(session.canGoBack ? "‹ Back" : "Cancel")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.segmentLabel)
                    .frame(minWidth: 88, minHeight: 48)
                    .background(palette.keyFace)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .blindTarget(
                .item("phrase-back"), spokenName: session.canGoBack ? "back" : "cancel", cornerRadius: 12
            ) {
                stepBack()
            }

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
                    .background(session.isComplete ? palette.accent : palette.keyLabelMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("insertSentence")
            .disabled(!session.isComplete)
            .accessibilityHint(session.isComplete ? "" : "Fill every blank first")
            .blindTarget(
                .item("insertSentence"),
                spokenName: session.isComplete
                    ? "insert sentence" : "insert sentence. Fill every blank first",
                cornerRadius: 12
            ) {
                guard session.isComplete else { return "Fill every blank first" }
                onInsert(session.assembledText)
                return session.assembledText
            }
        }
        .padding(10)
    }
}
