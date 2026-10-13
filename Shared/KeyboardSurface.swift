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

    /// In the extension this is the host app's appearance, which is what the
    /// `system` appearance setting follows.
    @Environment(\.colorScheme) private var hostColorScheme

    private var palette: KeyboardPalette {
        store.settings.keyboardAppearance.palette(for: hostColorScheme)
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            if freeTextSlot != nil {
                freeTextDraftBar
                keyboardStack
            } else {
                switch panel {
                case .keyboard:
                    keyboardStack
                case .names:
                    QuickInsertPanel(categories: store.categories, onInsert: insertQuickEntry)
                        .modifier(LightPanel())
                case .phrases:
                    phrasesPanel
                        .modifier(LightPanel())
                }
            }
        }
        .background(surfaceBackground)
        .environment(\.keyboardPalette, palette)
        // Drives the few things SwiftUI colours for itself (dividers, the odd
        // default-tinted control) inside the keys and chips.
        .environment(\.colorScheme, palette.isDark ? .dark : .light)
        .onAppear(perform: refresh)
    }

    /// True while a panel that must stay light is on screen.
    private var isShowingLightPanel: Bool {
        freeTextSlot == nil && panel != .keyboard
    }

    /// Whatever the panels don't paint themselves. It follows the light panels
    /// rather than the keyboard, so a short Names list doesn't leave a dark
    /// strip under itself.
    private var surfaceBackground: Color {
        isShowingLightPanel ? KeyboardPalette.light.tray : palette.tray
    }

    // MARK: Toolbar

    /// One inset track of equal thirds, which is the shape iOS already uses
    /// for switching mode. The capsules it replaced were unequal and left a
    /// gap on the right, so they read as filters rather than as a switch.
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
                    .foregroundStyle(isSelected ? .white : palette.segmentLabel)
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .background(isSelected ? palette.accent : .clear)
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
        .background(palette.segmentTrack)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        // The toolbar is keyboard chrome, so it follows the appearance setting
        // even while a (always-light) panel is showing below it.
        .background(palette.toolbarBar)
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
                    .foregroundStyle(palette.keyLabelMuted)
                Text(freeTextBuffer.text.isEmpty ? "…" : freeTextBuffer.text)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(palette.keyLabel)
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
                    .foregroundStyle(palette.segmentLabel)
                    .frame(minWidth: 72, minHeight: 44)
                    .background(palette.keyFace)
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
                    .background(palette.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(palette.draftBar)
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

/// Names and Phrases stay light whatever the keyboard appearance is — that is
/// a stated requirement, not an oversight.
///
/// Pinning the two panel subtrees is also what makes a dark keyboard possible
/// at all: the alternative, pinning the whole input view with
/// `overrideUserInterfaceStyle = .light`, would force the keys light too.
private struct LightPanel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .environment(\.keyboardPalette, .light)
            .environment(\.colorScheme, .light)
    }
}
