import SwiftUI

/// Which panel the toolbar is showing.
///
/// Declared in the order the toolbar shows them, which `allCases` follows:
/// Phrases and Names first, the keyboard at the right end.
enum KeyboardPanel: String, CaseIterable, Identifiable {
    case phrases
    case names
    case keyboard

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
    ///
    /// The keyboard's symbol is the system's hide-keyboard glyph: tapping the
    /// segment that is already selected collapses the keyboard, and that is
    /// the icon iOS uses to say so.
    var symbol: String {
        switch self {
        case .keyboard: return "keyboard.chevron.compact.down"
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
    /// Hide the keyboard entirely, by tapping the panel segment that is
    /// already selected. Only the extension can do this, so when it is nil —
    /// in the practice pad — that tap does nothing and says nothing.
    var onCollapse: (() -> Void)?
    /// True in the extension, where iOS draws its own rounded pane behind the
    /// keyboard and starts this view a little below the pane's top edge. The
    /// practice pad has no such pane and paints its own tray.
    var sitsOnSystemBackdrop: Bool = false

    /// Measured against the system backdrop on iOS 26: its corner fits a
    /// ~29pt circle and this view starts ~19pt below its top, so ~10pt is the
    /// concentric radius; a touch more reads as rounded rather than chamfered.
    static let topCornerRadius: CGFloat = 12

    @State private var panel: KeyboardPanel = .keyboard
    @State private var phraseSession: PhraseFillSession?
    /// Non-nil while the user types a free-text value for a phrase blank.
    @State private var freeTextSlot: PhraseSlot?
    @StateObject private var freeTextBuffer = BufferTextSink()

    /// In the extension this is the host app's appearance, which is what the
    /// `system` appearance setting follows.
    @Environment(\.colorScheme) private var hostColorScheme

    private var palette: KeyboardPalette {
        seated(store.settings.keyboardAppearance.palette(for: hostColorScheme))
    }

    /// What the Names and Phrases panels draw with. They are always light (see
    /// `LightPanel`), so they sit on the pane exactly when the host is light.
    private var panelPalette: KeyboardPalette {
        seated(.light)
    }

    /// `base` with its tray cleared whenever the system pane can be the tray.
    ///
    /// On the pane the surface fills it instead of painting a slab of its own
    /// on top: the pane becomes the tray, and the strip of it above the
    /// suggestions or the panel is then simply more tray rather than something
    /// showing from behind. That only works while the pane's tone agrees with
    /// what sits on it — the pane follows the host app, so a keyboard forced
    /// to the opposite appearance, or a light panel in a dark host, keeps its
    /// own tray.
    private func seated(_ base: KeyboardPalette) -> KeyboardPalette {
        let paneMatches = base.isDark == (hostColorScheme == .dark)
        return sitsOnSystemBackdrop && paneMatches ? base.onSystemBackdrop : base
    }

    var body: some View {
        VStack(spacing: 0) {
            // The top row is the suggestions — or, while a phrase blank is
            // being typed, the draft of it. It shows whichever panel is open,
            // so the toolbar under it stays put when the panel changes.
            if freeTextSlot != nil {
                freeTextDraftBar
            } else if store.settings.showSuggestionChips {
                SuggestionBar(
                    suggestions: controller.suggestions,
                    areNextWord: controller.suggestionsAreNextWord,
                    browsing: store.settings.suggestionBrowsing,
                    onPick: pickSuggestion
                )
            }

            // Phrases / Names / Keyboard sit directly under the suggestions,
            // above whichever of the three is open.
            toolbar

            if freeTextSlot != nil {
                keyboardStack
            } else {
                switch panel {
                case .keyboard:
                    keyboardStack
                case .names:
                    QuickInsertPanel(categories: store.categories, onInsert: insertQuickEntry)
                        .modifier(LightPanel(palette: panelPalette))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                case .phrases:
                    phrasesPanel
                        .modifier(LightPanel(palette: panelPalette))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
            // The panels claim the full height whatever they hold. With
            // nothing saved, "No names yet" is a few lines tall, and without
            // this the surface shrank around it — the one state every new
            // install starts in.
        }
        .background(surfaceBackground)
        // iOS draws its own rounded, lighter backdrop behind every keyboard
        // and places this view a short way below its top edge — outside the
        // view, with no safe-area inset to read. Whenever the surface does
        // paint a tray (the practice pad, a light panel in a dark host, a
        // forced appearance), square top corners sit inside that curve and the
        // backdrop shows past them as a strip of a different shape; rounding
        // them concentrically lets the surface nest in it instead.
        .clipShape(TopRoundedRectangle(radius: Self.topCornerRadius))
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
    /// strip under itself — and clears with them, so the pane shows through.
    private var surfaceBackground: Color {
        isShowingLightPanel ? panelPalette.tray : palette.tray
    }

    // MARK: Toolbar

    /// One inset track of equal thirds, which is the shape iOS already uses
    /// for switching mode. The capsules it replaced were unequal and left a
    /// gap on the right, so they read as filters rather than as a switch.
    ///
    /// It sits on the key tray rather than on a pale chrome bar: between the
    /// suggestions and the keys, sharing the tray colour keeps it part of the
    /// keyboard instead of reading as a second, competing row of keys.
    ///
    /// Tapping the panel that is already showing collapses the keyboard — it
    /// keeps the affordance where the tap already is instead of spending
    /// width on a fourth button, and the keyboard segment carries the
    /// system's hide-keyboard glyph to say so.
    private var toolbar: some View {
        HStack(spacing: 10) {
            if showsNextKeyboardKey {
                // The globe at the left end of the row, with the panel switch
                // beside it. It used to be a key inside the letter rows'
                // bottom line, which is not where a thumb that has learned
                // the stock keyboard goes looking.
                Button(action: onNextKeyboard) {
                    Image(systemName: "globe")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(palette.keyLabel)
                        .frame(width: 44, height: 38)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("next-keyboard")
                .accessibilityLabel("Next keyboard")
            }
            panelTrack
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        // The toolbar is keyboard chrome, so it follows the appearance setting
        // even while a (always-light) panel is showing below it. It takes the
        // tray's own colour rather than `toolbarBar`: a lighter bar between
        // the suggestions and the keys reads as a second, competing row.
        .background(palette.tray)
    }

    /// The segmented switch between the three panels.
    private var panelTrack: some View {
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
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(isSelected ? .white : palette.segmentLabel)
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .background(isSelected ? palette.accent : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .shadow(
                        color: isSelected ? Theme.brandDark.opacity(0.28) : .clear,
                        radius: 1, y: 1)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("panel-\(item.rawValue)")
                .accessibilityLabel(item.title)
                .accessibilityHint(
                    isSelected && onCollapse != nil ? "Tap again to hide the keyboard" : ""
                )
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(2)
        .background(palette.segmentTrack)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    // MARK: Keyboard

    private var keyboardStack: some View {
        DynamicKeyboardView(
            keyScales: controller.keyScales,
            topScale: controller.topScale,
            isStaticFallback: controller.isStaticFallback,
            colorVision: store.settings.colorVision,
            onInsert: insert,
            onDelete: deleteBackward,
            onReturn: { insert("\n") }
        )
    }

    // MARK: Phrases

    private var phrasesPanel: some View {
        Group {
            if let session = phraseSession {
                PhraseFillView(
                    session: session,
                    onInsert: insertPhrase,
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
                    let session = PhraseFillSession(template: template, names: store.allQuickInsertEntries)
                    // A phrase with no blanks has nothing to ask; it goes in
                    // on the tap, the same as one whose last blank was just
                    // answered.
                    if session.isFinished {
                        insertPhrase(session.assembledText)
                    } else {
                        phraseSession = session
                    }
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
                // Back to the remaining blanks — or, when this was the last
                // one, straight into the host and the keyboard, exactly as a
                // tapped name would have done.
                if let session = phraseSession, session.isFinished {
                    insertPhrase(session.assembledText)
                } else {
                    refresh()
                }
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

    /// A name is one tap: it goes in and the keys come back, because the next
    /// thing the user wants is almost always to carry on typing.
    private func insertQuickEntry(_ entry: QuickInsertEntry) {
        activeSink.insertText(entry.text + (entry.appendsSpace ? " " : ""))
        panel = .keyboard
        refresh()
    }

    /// The finished sentence goes to the host — never into a phrase draft, so
    /// this writes to `sink` rather than `activeSink` — and the keys come back.
    private func insertPhrase(_ sentence: String) {
        sink.insertText(sentence)
        phraseSession = nil
        panel = .keyboard
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
///
/// `palette` is the light palette, with or without its tray: the panels read
/// their slab from it, so they can sit on the system pane the way the keys do.
private struct LightPanel: ViewModifier {
    let palette: KeyboardPalette

    func body(content: Content) -> some View {
        content
            .environment(\.keyboardPalette, palette)
            .environment(\.colorScheme, .light)
    }
}

/// A rectangle rounded on its top two corners only.
///
/// `UnevenRoundedRectangle` is iOS 16.4, and the deployment target is 16.0,
/// so the earlier releases get the same corners from UIKit's path.
private struct TopRoundedRectangle: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        if #available(iOS 16.4, *) {
            return UnevenRoundedRectangle(
                topLeadingRadius: radius,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: radius,
                style: .continuous
            ).path(in: rect)
        }
        return Path(
            UIBezierPath(
                roundedRect: rect,
                byRoundingCorners: [.topLeft, .topRight],
                cornerRadii: CGSize(width: radius, height: radius)
            ).cgPath)
    }
}
