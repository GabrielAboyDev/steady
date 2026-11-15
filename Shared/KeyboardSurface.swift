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

/// Replaces the return key's default "insert a newline" behaviour and label.
/// Used by the Practice tool's text-to-speech toggle to turn Return into a
/// play/pause control; `nil` everywhere else keeps today's behaviour.
struct ReturnKeyOverride {
    let symbol: String
    let accessibilityLabel: String
    var isEnabled: Bool = true
    let action: () -> Void
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
    /// Applies the typing rules — autocorrect, smart punctuation and the
    /// rest — between the keys and the sink.
    @ObservedObject var composer: TextComposer

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
    /// When set, replaces the return key's default behaviour — see
    /// `ReturnKeyOverride`.
    var returnKeyOverride: ReturnKeyOverride?
    /// Whether speech can be heard here. The practice pad always can; the
    /// extension only once the user has granted Allow Full Access, since iOS
    /// lets no keyboard start an audio session without it. While Blind mode
    /// is on and this is false, the top row says so instead of showing
    /// suggestions — the synthesizer would otherwise fail without a sound.
    var canPlayAudio: Bool = true

    /// Measured against the system backdrop on iOS 26: its corner fits a
    /// ~29pt circle and this view starts ~19pt below its top, so ~10pt is the
    /// concentric radius; a touch more reads as rounded rather than chamfered.
    static let topCornerRadius: CGFloat = 12

    @State private var panel: KeyboardPanel = .keyboard
    /// The shift key. Autocapitalization sets it after every refresh; the key
    /// itself overrides it until the next letter.
    @State private var isShifted = false
    @State private var isCapsLocked = false
    @State private var phraseSession: PhraseFillSession?
    /// Non-nil while the user types a free-text value for a phrase blank.
    @State private var freeTextSlot: PhraseSlot?
    @StateObject private var freeTextBuffer = BufferTextSink(traits: .phraseBlank)
    @StateObject private var speaker = KeySpeaker()
    @StateObject private var haptics = KeyHaptics()
    /// Blind mode: whatever is under the exploring finger — a key, a
    /// suggestion, a phrase, a name, a toolbar segment — and what Submit
    /// will act on.
    @State private var hoveredTarget: KeyID?
    /// Read-before-return: the text that was last read aloud start to finish.
    /// Return only sends while the field still holds exactly this; any edit
    /// changes the text and so reopens the gate, with no bookkeeping.
    @State private var lastFullyReadSentence: String?

    /// In the extension this is the host app's appearance, which is what the
    /// `system` appearance setting follows.
    @Environment(\.colorScheme) private var hostColorScheme

    /// The host's appearance, unless the field itself asks for a light or a
    /// dark keyboard — a trait a field can set, and the stock keyboard obeys.
    private var hostScheme: ColorScheme {
        switch activeSink.traits.appearance {
        case .dark: return .dark
        case .light: return .light
        default: return hostColorScheme
        }
    }

    private var palette: KeyboardPalette {
        seated(store.settings.keyboardAppearance.palette(for: hostScheme))
    }

    /// `base` with its tray cleared whenever the system pane can be the tray.
    ///
    /// On the pane the surface fills it instead of painting a slab of its own
    /// on top: the pane becomes the tray, and the strip of it above the
    /// suggestions or the panel is then simply more tray rather than something
    /// showing from behind. That only works while the pane's tone agrees with
    /// what sits on it — the pane follows the host app, so a keyboard forced
    /// to the opposite appearance keeps its own tray.
    private func seated(_ base: KeyboardPalette) -> KeyboardPalette {
        let paneMatches = base.isDark == (hostScheme == .dark)
        return sitsOnSystemBackdrop && paneMatches ? base.onSystemBackdrop : base
    }

    var body: some View {
        VStack(spacing: 0) {
            // The top row is the suggestions — or, while a phrase blank is
            // being typed, the draft of it. It shows whichever panel is open,
            // so the toolbar under it stays put when the panel changes.
            if freeTextSlot != nil {
                freeTextDraftBar
            } else if store.settings.blindMode && !canPlayAudio {
                // Same slot and height as the suggestions, so the extension's
                // fixed height still fits the keys below.
                speechUnavailableBar
            } else if store.settings.showSuggestionChips {
                SuggestionBar(
                    suggestions: controller.suggestions,
                    areNextWord: controller.suggestionsAreNextWord,
                    // Blind mode's touch layer takes every touch, so the row
                    // cannot be swiped: it is stepped with the arrows instead,
                    // which are hover targets like any other.
                    browsing: store.settings.blindMode ? .paginate : store.settings.suggestionBrowsing,
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
                    QuickInsertPanel(
                        categories: store.categories, onInsert: insertQuickEntry,
                        onInsertVariable: store.isEditingPhraseTemplate ? insertVariable : nil
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                case .phrases:
                    phrasesPanel
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                // The panels have no keys, so in blind mode they carry the
                // Submit key themselves, where the keyboard's would be.
                if panel != .keyboard, store.settings.blindMode {
                    panelSubmitRow
                }
            }
            // The panels claim the full height whatever they hold. With
            // nothing saved, "No names yet" is a few lines tall, and without
            // this the surface shrank around it — the one state every new
            // install starts in.
        }
        .overlayPreferenceValue(BlindTargetsPreferenceKey.self) { targets in
            if store.settings.blindMode {
                GeometryReader { proxy in
                    BlindModeTouchOverlay(
                        frames: targets.mapValues { proxy[$0.anchor] },
                        onHover: { id in
                            hoveredTarget = id
                            if let id, let target = targets[id] { speak(target.spokenName) }
                        },
                        onSubmitHovered: { speak("submit") },
                        onSubmit: {
                            guard let id = hoveredTarget, let target = targets[id] else {
                                speak("nothing selected")
                                return
                            }
                            if let said = target.action() { speak(said) }
                        }
                    )
                }
            }
        }
        .environment(\.blindHoveredTarget, hoveredTarget)
        .onChange(of: store.settings.blindMode) { isOn in
            if !isOn { hoveredTarget = nil }
        }
        .background(palette.tray)
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
        // Every refresh — a key here, or the host moving the cursor — re-reads
        // autocapitalization. A manual shift lasts until the next letter, and
        // caps lock until it is tapped off.
        .onChange(of: controller.revision) { _ in
            guard !isCapsLocked else { return }
            isShifted = controller.autoShift
        }
    }

    /// Blind mode is on but nothing can be heard: the keyboard has not been
    /// granted Allow Full Access. Read by VoiceOver too, so a user who cannot
    /// see the row still learns why the keys are silent.
    private var speechUnavailableBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "speaker.slash")
                .font(.system(size: 13, weight: .semibold))
            Text("To hear keys, allow Full Access in Settings › Keyboards › Steady")
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(palette.keyLabel)
        .frame(maxWidth: .infinity)
        .frame(height: SuggestionBar.rowHeight)
        .padding(.horizontal, 12)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("speech-unavailable")
    }

    /// The Submit key under a Names or Phrases panel in blind mode, at the
    /// right edge with the keyboard's own insets, so the finger that found it
    /// under the keys finds it here too.
    private var panelSubmitRow: some View {
        HStack {
            Spacer(minLength: 0)
            BlindSubmitKey()
        }
        .padding(.horizontal, 5)
        .padding(.bottom, 6)
        .background(palette.tray)
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
                .blindTarget(.item("next-keyboard"), spokenName: "next keyboard", cornerRadius: 8) {
                    onNextKeyboard()
                    return nil
                }
            }
            panelTrack
        }
        .padding(.horizontal, 10)
        // Padding above only. Below, the keys' own growth headroom and the
        // panels' insets already hold them off the track.
        .padding(.top, 4)
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
                    _ = switchPanel(to: item)
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
                .blindTarget(
                    .item("panel-\(item.rawValue)"),
                    spokenName: segmentSpokenName(for: item, isSelected: isSelected),
                    cornerRadius: 7
                ) {
                    switchPanel(to: item)
                }
            }
        }
        .padding(2)
        .background(palette.segmentTrack)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    /// What a toolbar segment does when tapped or submitted, and what blind
    /// mode says about it. The segment already showing hides the keyboard
    /// where that is possible, and does nothing where it is not.
    private func switchPanel(to item: KeyboardPanel) -> String? {
        let isSelected = panel == item && freeTextSlot == nil
        if isSelected {
            onCollapse?()
            return nil
        }
        freeTextSlot = nil
        panel = item
        if item != .phrases { phraseSession = nil }
        refresh()
        return item.title
    }

    private func segmentSpokenName(for item: KeyboardPanel, isSelected: Bool) -> String {
        guard isSelected else { return item.title }
        return onCollapse == nil
            ? "\(item.title), showing" : "\(item.title), showing. Submit hides the keyboard"
    }

    // MARK: Keyboard

    private var keyboardStack: some View {
        let traits = activeSink.traits
        let returnEnabled =
            returnKeyOverride?.isEnabled
            ?? !(traits.enablesReturnKeyAutomatically && (activeSink.contextBeforeInput ?? "").isEmpty)
        // While the message still needs reading, Return wears a speaker and
        // says so, and its commit stays silent so the reading is not cut off.
        let needsReadback = self.needsReadback
        return DynamicKeyboardView(
            keyScales: controller.keyScales,
            topScale: controller.topScale,
            isStaticFallback: controller.isStaticFallback,
            colorVision: store.settings.colorVision,
            highlightNextLetter: store.settings.nextLetterHighlight,
            traits: traits,
            capsLockEnabled: controller.rules.capsLock,
            returnEnabled: returnEnabled,
            returnKeySymbolOverride: needsReadback ? "speaker.wave.2.fill" : returnKeyOverride?.symbol,
            returnKeyAccessibilityLabel: needsReadback
                ? "Read message aloud" : returnKeyOverride?.accessibilityLabel,
            returnKeyAnnouncesOnCommit: !needsReadback,
            blindMode: store.settings.blindMode,
            isShifted: $isShifted,
            isCapsLocked: $isCapsLocked,
            onInsert: insert,
            onDelete: deleteBackward,
            onReturn: tapReturn,
            onMoveCursor: moveCursor,
            onDeleteWord: deleteWordBackward
        )
    }

    // MARK: Read before return

    /// The message as far as the keyboard can see it. In the extension this
    /// is the text before the caret — a window, not always the whole field —
    /// which is the best proxy there is for "what is about to be sent".
    private var sentenceBeforeReturn: String {
        activeSink.contextBeforeInput ?? ""
    }

    /// Blind mode's read-before-return gate: on, something to read, and not
    /// yet read start to finish in its current form. Never while the Practice
    /// tool has made Return a play/pause control of its own.
    private var needsReadback: Bool {
        returnKeyOverride == nil && store.settings.blindMode && store.settings.readBeforeReturn
            && !sentenceBeforeReturn.isEmpty && lastFullyReadSentence != sentenceBeforeReturn
    }

    /// Return: the override's action, or a newline — unless the message has
    /// yet to be heard, in which case it is read instead. Only a reading that
    /// plays to the end satisfies the gate; a hover elsewhere cuts it off,
    /// and the synthesizer then reports a cancellation, not a finish.
    private func tapReturn() {
        if let override = returnKeyOverride {
            override.action()
            return
        }
        guard needsReadback else {
            insert("\n")
            return
        }
        let sentence = sentenceBeforeReturn
        speaker.speak(sentence, voiceIdentifier: store.settings.ttsVoiceIdentifier) {
            lastFullyReadSentence = sentence
        }
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
                    let session = PhraseFillSession(template: template, categories: store.categories)
                    // A phrase with no blanks has nothing to ask; it goes in
                    // on the tap, the same as one whose last blank was just
                    // answered.
                    if session.isFinished {
                        insertPhrase(session.assembledText)
                        return session.assembledText
                    }
                    phraseSession = session
                    return session.currentSlot.map { "Choose \($0.name)" }
                }
            }
        }
    }

    /// The bar shown while typing a free-text value into a phrase blank.
    private var freeTextDraftBar: some View {
        let slotName = freeTextSlot?.name ?? ""
        let draft = freeTextBuffer.text
        let spokenDraft = draft.isEmpty ? "Typing \(slotName), nothing yet" : "Typing \(slotName): \(draft)"
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Typing \(slotName)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.keyLabelMuted)
                Text(draft.isEmpty ? "…" : draft)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(palette.keyLabel)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Hover to hear what has been typed so far; Submit reads it again.
            .blindTarget(.item("free-text-draft"), spokenName: spokenDraft, cornerRadius: 8) { spokenDraft }

            Button {
                _ = cancelFreeText()
            } label: {
                Text("Cancel")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.segmentLabel)
                    .frame(minWidth: 72, minHeight: 44)
                    .background(palette.keyFace)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .blindTarget(.item("free-text-cancel"), spokenName: "cancel", cornerRadius: 10) {
                cancelFreeText()
            }

            Button {
                _ = finishFreeText()
            } label: {
                Text("Done")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 72, minHeight: 44)
                    .background(palette.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .blindTarget(.item("free-text-done"), spokenName: "done", cornerRadius: 10) {
                finishFreeText()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(palette.draftBar)
    }

    /// Drops the free-text draft and returns to the blank it was for. Returns
    /// what blind mode says about it.
    private func cancelFreeText() -> String? {
        freeTextSlot = nil
        freeTextBuffer.text = ""
        refresh()
        return phraseSession?.currentSlot.map { "Choose \($0.name)" }
    }

    /// Takes the free-text draft as the blank's value. Back to the remaining
    /// blanks — or, when this was the last one, straight into the host and
    /// the keyboard, exactly as a tapped name would have done. Returns what
    /// blind mode says about it.
    private func finishFreeText() -> String? {
        let value = freeTextBuffer.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty { phraseSession?.select(value) }
        freeTextSlot = nil
        freeTextBuffer.text = ""
        if let session = phraseSession, session.isFinished {
            insertPhrase(session.assembledText)
            return session.assembledText
        }
        refresh()
        let next = phraseSession?.currentSlot.map { "Choose \($0.name)" } ?? "Ready to insert"
        return value.isEmpty ? next : "\(value). \(next)"
    }

    // MARK: Text routing

    /// Keys type into the phrase draft when one is open, otherwise into the host.
    private var activeSink: TextSink {
        freeTextSlot != nil ? freeTextBuffer : sink
    }

    /// What every key that puts something in does first: the iOS click, which
    /// follows the system's Keyboard Clicks switch, and Steady's own haptic,
    /// which follows the setting. Cursor moves stay silent and still.
    private func keyFeedback(into target: TextSink) {
        target.playKeyClick()
        if store.settings.keyHaptics {
            haptics.tap()
        }
    }

    private func insert(_ text: String) {
        keyFeedback(into: activeSink)
        composer.type(text, rules: controller.rules, into: activeSink)
        refresh()
    }

    private func deleteBackward() {
        keyFeedback(into: activeSink)
        composer.deleteBackward(into: activeSink)
        refresh()
    }

    /// The space-bar trackpad drag. No key click — the stock keyboard's own
    /// trackpad is silent, and a click per character would be noisy.
    private func moveCursor(by characterOffset: Int) {
        composer.moveCursor(by: characterOffset, into: activeSink)
        refresh()
    }

    /// One tick of holding the delete key.
    private func deleteWordBackward() {
        keyFeedback(into: activeSink)
        composer.deleteWordBackward(into: activeSink)
        refresh()
    }

    /// Blind mode reading a key name aloud, in the voice chosen in Settings.
    private func speak(_ text: String) {
        speaker.speak(text, voiceIdentifier: store.settings.ttsVoiceIdentifier)
    }

    /// A name is one tap: it goes in and the keys come back, because the next
    /// thing the user wants is almost always to carry on typing.
    private func insertQuickEntry(_ entry: QuickInsertEntry) {
        keyFeedback(into: activeSink)
        composer.insertEntry(entry.text, rules: controller.rules, into: activeSink)
        panel = .keyboard
        refresh()
    }

    /// Writing a phrase template in the app: the blank for a category goes in
    /// where a name would, spaced the same way, and the keys come back.
    private func insertVariable(_ category: QuickInsertCategory) {
        keyFeedback(into: activeSink)
        composer.insertEntry(
            QuickInsertCategory.blankMarker(for: category), rules: controller.rules, into: activeSink)
        panel = .keyboard
        refresh()
    }

    /// The finished sentence goes to the host — never into a phrase draft, so
    /// this writes to `sink` rather than `activeSink` — and the keys come back.
    private func insertPhrase(_ sentence: String) {
        keyFeedback(into: sink)
        composer.insert(
            sentence, rules: TypingRules(traits: sink.traits, settings: store.settings), into: sink)
        phraseSession = nil
        panel = .keyboard
        refresh()
    }

    /// Chips replace the fragment already typed (completions) or just append
    /// (next-word predictions). Both leave a trailing space. A completion
    /// keeps the casing of the fragment it replaces — "Th" becomes "The" —
    /// and a prediction follows the shift key, so a word picked at the start
    /// of a sentence is capital.
    private func pickSuggestion(_ word: String) {
        keyFeedback(into: activeSink)
        let capitalization: Capitalization
        if controller.suggestionsAreNextWord {
            capitalization = isCapsLocked ? .all : isShifted ? .first : .none
        } else {
            let typed = TextComposer.trailingWord(in: activeSink.contextBeforeInput ?? "")
            let letters = typed.filter(\.isLetter)
            if letters.count > 1, letters == letters.uppercased() {
                capitalization = .all
            } else if letters.first?.isUppercase == true {
                capitalization = .first
            } else {
                capitalization = .none
            }
        }
        composer.insertWord(
            word,
            replacingPrefix: controller.suggestionsAreNextWord ? 0 : controller.currentPrefix.count,
            capitalization: capitalization,
            rules: controller.rules,
            into: activeSink
        )
        refresh()
    }

    private func refresh() {
        controller.update(settings: store.settings)
        controller.refresh(context: activeSink.contextBeforeInput, traits: activeSink.traits)
        // A saved name is spelled the way its owner spells it.
        composer.knownWords = Set(
            store.allQuickInsertTexts.flatMap { $0.split(separator: " ") }.map { $0.lowercased() })
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
