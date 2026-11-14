import SwiftUI

/// A safe place to get used to the keyboard before using it everywhere (US-007).
///
/// This types into its own buffer using the same shared surface the extension
/// uses, so the resizing behaviour on show here is the real thing.
struct PracticePadView: View {

    @EnvironmentObject private var store: SharedStore
    @StateObject private var buffer = BufferTextSink()
    @StateObject private var controller = PredictionController()
    @StateObject private var composer = TextComposer()
    @StateObject private var reader = SpeechReader()
    /// Turns the return key into a play/pause control for reading the pad's
    /// text aloud. Local to this screen, not a persisted preference.
    @State private var ttsEnabled = false
    /// How much of a press-and-hold-drag's cumulative translation has already
    /// been turned into a word scrub, mirroring the space bar trackpad's own
    /// bookkeeping in `DynamicKeyboardView`.
    @State private var scrubConsumed: CGFloat = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                pad
                Spacer(minLength: 0)
                KeyboardSurface(
                    store: store, controller: controller, composer: composer, sink: buffer,
                    returnKeyOverride: ttsEnabled ? returnKeyOverride : nil
                )
            }
            .background(Theme.surfaceBase)
            .navigationTitle("Practice")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        ttsEnabled.toggle()
                        if !ttsEnabled { reader.stop() }
                    } label: {
                        Image(systemName: ttsEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    }
                    .accessibilityLabel(ttsEnabled ? "Text to speech on" : "Text to speech off")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        buffer.text = ""
                        controller.refresh(context: "", isSecure: false)
                    }
                    .disabled(buffer.text.isEmpty)
                }
            }
        }
        // Editing mid-read would desync the highlight from what's actually
        // being spoken, so any change to the text stops playback outright.
        .onChange(of: buffer.text) { _ in reader.stop() }
    }

    /// What the return key does and shows while text-to-speech is on, built
    /// from the reader's current state.
    private var returnKeyOverride: ReturnKeyOverride {
        switch reader.state {
        case .idle:
            return ReturnKeyOverride(
                symbol: "play.fill", accessibilityLabel: "Read aloud",
                isEnabled: !buffer.text.isEmpty
            ) {
                reader.start(text: buffer.text, voiceIdentifier: store.settings.ttsVoiceIdentifier)
            }
        case .reading:
            return ReturnKeyOverride(symbol: "pause.fill", accessibilityLabel: "Pause") {
                reader.pause()
            }
        case .paused:
            return ReturnKeyOverride(symbol: "play.fill", accessibilityLabel: "Resume") {
                reader.resume()
            }
        }
    }

    private var pad: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Type freely — watch the keys grow and shrink.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)

            HStack(alignment: .bottom, spacing: 0) {
                if buffer.text.isEmpty {
                    Text("Start typing…")
                        .font(.system(size: 19))
                        .foregroundStyle(Theme.textMuted)
                } else if reader.state != .idle {
                    // Reading: the caret gives way to a highlight over
                    // whichever word is being spoken right now.
                    Text(highlightedText)
                        .font(.system(size: 19))
                } else {
                    // Split on the real caret — not just appended at the end
                    // — so the space bar's press-and-drag trackpad has
                    // somewhere visible to move it to.
                    let offset = min(max(buffer.cursorOffset, 0), buffer.text.count)
                    let splitIndex = buffer.text.index(buffer.text.startIndex, offsetBy: offset)
                    Text(buffer.text[..<splitIndex])
                        .font(.system(size: 19))
                        .foregroundStyle(Theme.textPrimary)
                    Rectangle()
                        .fill(Theme.brand)
                        .frame(width: 2, height: 21)
                    Text(buffer.text[splitIndex...])
                        .font(.system(size: 19))
                        .foregroundStyle(Theme.textPrimary)
                }
                Spacer(minLength: 0)
            }
            .fixedSize(horizontal: false, vertical: true)
            // One static-text element with the plain, caret-free string —
            // matching what a single `Text` exposed before this view split
            // into two (one each side of the caret) — rather than the three
            // children (before, caret, after) SwiftUI would otherwise hand
            // VoiceOver and the UI tests that key off this identifier.
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isStaticText)
            .accessibilityLabel(buffer.text.isEmpty ? "Start typing…" : buffer.text)
            .accessibilityIdentifier("practicePadText")
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
            .background(Theme.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius)
                    .strokeBorder(Theme.ruleHairline, lineWidth: 1)
            )
            // Press and hold the word being read, then drag, to rewind or
            // skip ahead — a no-op whenever nothing is currently playing.
            .gesture(scrubGesture)

            if !controller.isEngineAvailable {
                Text("The bundled word list didn't load, so the keys won't resize.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.negative)
            }
        }
        .padding(16)
    }

    /// `buffer.text`, with the word `reader` is currently speaking picked out.
    private var highlightedText: AttributedString {
        var attributed = AttributedString(buffer.text)
        if let wordRange = reader.currentWordRange,
            let attributedRange = Range(wordRange, in: attributed)
        {
            attributed[attributedRange].foregroundColor = .white
            attributed[attributedRange].backgroundColor = Theme.brand
        }
        return attributed
    }

    /// How far a drag has to travel, in points, before it counts as one word
    /// stepped through — the same technique as the space bar's trackpad in
    /// `DynamicKeyboardView`, just measured in words instead of characters.
    private let scrubStep: CGFloat = 24

    /// Press and hold the currently-highlighted word, then drag horizontally
    /// to scrub playback backward or forward by whole words.
    private var scrubGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
            .onChanged { value in
                guard reader.state != .idle, case .second(true, let drag?) = value else { return }
                let unconsumed = drag.translation.width - scrubConsumed
                let steps = Int(unconsumed / scrubStep)
                guard steps != 0 else { return }
                reader.seek(
                    toWordIndex: (reader.currentWordIndex ?? 0) + steps,
                    voiceIdentifier: store.settings.ttsVoiceIdentifier
                )
                scrubConsumed += CGFloat(steps) * scrubStep
            }
            .onEnded { _ in scrubConsumed = 0 }
    }
}
