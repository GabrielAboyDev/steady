import SwiftUI

/// Which panel the toolbar is showing.
enum KeyboardPanel: String, CaseIterable, Identifiable {
    case keyboard
    case names
    case phrases

    var id: String { rawValue }

    var title: String {
        switch self {
        case .keyboard: return "Keyboard"
        case .names: return "Names"
        case .phrases: return "Phrases"
        }
    }

    /// SF Symbols rather than emoji: they take the segment's tint, so the
    /// selected one reads white on brand instead of staying full-colour.
    var symbol: String {
        switch self {
        case .keyboard: return "keyboard"
        case .names: return "person"
        case .phrases: return "text.bubble"
        }
    }
}

/// The whole keyboard surface: panel toolbar, suggestion chips, the reshaping
/// keyboard, and the Names / Phrases panels.
///
/// Used by both the keyboard extension (typing into another app) and the
/// practice pad in the container app (typing into its own buffer), which is why
/// it writes through `TextSink` rather than touching a text proxy directly.
struct KeyboardSurface: View {

    @ObservedObject var store: SharedStore
    @ObservedObject var controller: PredictionController

    /// Where typed text lands.
    let sink: TextSink
    /// Show the globe key (only the real extension needs one).
    var showsNextKeyboardKey: Bool = false
    var onNextKeyboard: () -> Void = {}
    /// Hide the keyboard entirely. Only the extension can do this, so when it
    /// is nil — in the practice pad — the toolbar drops the affordance rather
    /// than offering a tap that would do nothing.
    var onCollapse: (() -> Void)?

    @State private var panel: KeyboardPanel = .keyboard
    @State private var phraseSession: PhraseFillSession?
    /// Non-nil while the user types a free-text value for a phrase blank.
    @State private var freeTextSlot: PhraseSlot?
    @StateObject private var freeTextBuffer = BufferTextSink()

    var body: some View {
        VStack(spacing: 0) {
            if freeTextSlot != nil {
                freeTextDraftBar
                keyboardStack
            } else {
                switch panel {
                case .keyboard:
                    keyboardStack
                case .names:
                    QuickInsertPanel(categories: store.categories, onInsert: insertQuickEntry)
                case .phrases:
                    phrasesPanel
                }
            }

            // Last, so it sits where iOS puts the globe/mic row: against the
            // bottom edge, under the thumbs, in the same place whichever panel
            // is showing.
            toolbar
        }
        .background(Theme.keyTray)
        .onAppear(perform: refresh)
    }

    // MARK: Toolbar

    /// One inset track of equal thirds, which is the shape iOS already uses
    /// for switching mode. The capsules it replaced were unequal and left a
    /// gap on the right, so they read as filters rather than as a switch.
    ///
    /// It sits on the key tray rather than on a pale chrome bar, because at the
    /// bottom of the surface it is directly under the keyboard's own bottom row
    /// — sharing the tray colour keeps it part of the keyboard instead of
    /// reading as a second, competing row of keys.
    ///
    /// Tapping the panel that is already showing collapses the keyboard, and
    /// the chevron on that segment is what says so — it keeps the affordance
    /// where the tap already is instead of spending width on a fourth button.
    private var toolbar: some View {
        HStack(spacing: 2) {
            ForEach(KeyboardPanel.allCases) { item in
                let isSelected = panel == item && freeTextSlot == nil
                Button {
                    if isSelected {
                        onCollapse?()
                    } else {
                        freeTextSlot = nil
                        panel = item
                        if item != .phrases { phraseSession = nil }
                        refresh()
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: item.symbol).font(.system(size: 14))
                        Text(item.title).font(.system(size: 14, weight: .semibold))
                        if isSelected, onCollapse != nil {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                                .opacity(0.9)
                        }
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(isSelected ? .white : Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .background(isSelected ? Theme.brand : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .shadow(color: isSelected ? Theme.brandDark.opacity(0.28) : .clear,
                            radius: 1, y: 1)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("panel-\(item.rawValue)")
                .accessibilityLabel(item.title)
                .accessibilityHint(
                    isSelected && onCollapse != nil ? "Tap again to hide the keyboard" : "")
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(2)
        .background(Theme.segmentTrack)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.keyTray)
    }

    // MARK: Keyboard

    private var keyboardStack: some View {
        VStack(spacing: 0) {
            if store.settings.showSuggestionChips && freeTextSlot == nil {
                SuggestionBar(
                    suggestions: controller.suggestions,
                    areNextWord: controller.suggestionsAreNextWord,
                    browsing: store.settings.suggestionBrowsing,
                    onPick: pickSuggestion
                )
            }

            DynamicKeyboardView(
                keyScales: controller.keyScales,
                topScale: controller.topScale,
                isStaticFallback: controller.isStaticFallback,
                showsNextKeyboardKey: showsNextKeyboardKey,
                onInsert: insert,
                onDelete: deleteBackward,
                onReturn: { insert("\n") },
                onNextKeyboard: onNextKeyboard
            )
        }
    }

    // MARK: Phrases

    private var phrasesPanel: some View {
        Group {
            if let session = phraseSession {
                PhraseFillView(
                    session: session,
                    onInsert: { sentence in
                        activeSink.insertText(sentence)
                        phraseSession = nil
                        panel = .keyboard
                        refresh()
                    },
                    onRequestFreeText: { slot in
                        freeTextBuffer.text = ""
                        freeTextSlot = slot
                        refresh()
                    },
                    onCancel: {
                        phraseSession = nil
                        refresh()
                    }
                )
            } else {
                PhrasePicker(phrases: store.phrases) { template in
                    phraseSession = PhraseFillSession(
                        template: template,
                        nameOptions: store.allQuickInsertTexts
                    )
                }
            }
        }
    }

    /// The bar shown while typing a free-text value into a phrase blank.
    private var freeTextDraftBar: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Typing \(freeTextSlot?.name ?? "")")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
                Text(freeTextBuffer.text.isEmpty ? "…" : freeTextBuffer.text)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)

            Button {
                freeTextSlot = nil
                freeTextBuffer.text = ""
                refresh()
            } label: {
                Text("Cancel")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(minWidth: 72, minHeight: 44)
                    .background(Theme.keyFace)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            Button {
                let value = freeTextBuffer.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty { phraseSession?.select(value) }
                freeTextSlot = nil
                freeTextBuffer.text = ""
                refresh()
            } label: {
                Text("Done")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 72, minHeight: 44)
                    .background(Theme.brand)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.surfaceRaised)
    }

    // MARK: Text routing

    /// Keys type into the phrase draft when one is open, otherwise into the host.
    private var activeSink: TextSink {
        freeTextSlot != nil ? freeTextBuffer : sink
    }

    private func insert(_ text: String) {
        activeSink.insertText(text)
        refresh()
    }

    private func deleteBackward() {
        activeSink.deleteBackward()
        refresh()
    }

    private func insertQuickEntry(_ entry: QuickInsertEntry) {
        activeSink.insertText(entry.text + (entry.appendsSpace ? " " : ""))
        refresh()
    }

    /// Chips replace the fragment already typed (completions) or just append
    /// (next-word predictions). Both leave a trailing space.
    private func pickSuggestion(_ word: String) {
        if !controller.suggestionsAreNextWord {
            for _ in 0..<controller.currentPrefix.count {
                activeSink.deleteBackward()
            }
        }
        activeSink.insertText(word + " ")
        refresh()
    }

    private func refresh() {
        controller.update(settings: store.settings)
        controller.refresh(
            context: activeSink.contextBeforeInput,
            isSecure: activeSink.isSecureEntry
        )
    }
}
