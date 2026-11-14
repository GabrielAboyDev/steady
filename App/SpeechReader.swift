import AVFoundation
import Foundation

/// Reads typed text aloud for the Practice tool, tracking which word is
/// currently being spoken so the UI can highlight it and scrub through it.
///
/// Scoped to the app's Practice pad, not the real keyboard extension: a
/// `UITextDocumentProxy` only exposes a window of text around the caret, not
/// the full sentence, so reliable read-aloud needs the practice pad's own
/// full-text buffer.
final class SpeechReader: NSObject, ObservableObject {

    enum State: Equatable {
        case idle
        case reading
        case paused
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var currentWordRange: Range<String.Index>?

    private let synthesizer = AVSpeechSynthesizer()
    private var fullText = ""
    private var wordRanges: [Range<String.Index>] = []
    /// Which `wordRanges` entry the utterance currently playing started from.
    private var baseWordIndex = 0
    /// Which `wordRanges` entry is being spoken right now, kept in step with
    /// the synthesizer's own word-boundary callbacks.
    private var wordCursor = 0

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    var currentWordIndex: Int? {
        state == .idle ? nil : wordCursor
    }

    func start(text: String, voiceIdentifier: String?) {
        guard !text.isEmpty else { return }
        fullText = text
        wordRanges = Self.wordRanges(in: text)
        speak(fromWordIndex: 0, voiceIdentifier: voiceIdentifier)
    }

    func pause() {
        guard state == .reading else { return }
        synthesizer.pauseSpeaking(at: .word)
        state = .paused
    }

    func resume() {
        guard state == .paused else { return }
        synthesizer.continueSpeaking()
        state = .reading
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        state = .idle
        currentWordRange = nil
    }

    /// Jumps playback to start at `wordIndex` — used for press-and-hold-drag
    /// scrubbing. `AVSpeechSynthesizer` has no native seek, so this stops the
    /// current utterance and starts a fresh one from that word.
    func seek(toWordIndex wordIndex: Int, voiceIdentifier: String?) {
        guard !wordRanges.isEmpty else { return }
        let clamped = max(0, min(wordIndex, wordRanges.count - 1))
        synthesizer.stopSpeaking(at: .immediate)
        speak(fromWordIndex: clamped, voiceIdentifier: voiceIdentifier)
    }

    private func speak(fromWordIndex index: Int, voiceIdentifier: String?) {
        guard index < wordRanges.count else {
            stop()
            return
        }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)

        baseWordIndex = index
        wordCursor = index
        currentWordRange = wordRanges[index]

        let utterance = AVSpeechUtterance(string: String(fullText[wordRanges[index].lowerBound...]))
        utterance.voice = Self.voice(identifier: voiceIdentifier)
        synthesizer.speak(utterance)
        state = .reading
    }

    private static func voice(identifier: String?) -> AVSpeechSynthesisVoice? {
        AVSpeechSynthesisVoice.preferred(identifier: identifier)
    }

    private static func wordRanges(in text: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .byWords) { _, range, _, _ in
            ranges.append(range)
        }
        return ranges
    }
}

extension SpeechReader: AVSpeechSynthesizerDelegate {

    /// The one authoritative source for "which word is being spoken right
    /// now": map the range into `utterance.speechString` back onto the full
    /// text by offsetting from the word this utterance started at, rather
    /// than trusting our own `.byWords` split to agree with the
    /// synthesizer's — that keeps the highlight from drifting.
    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        let speechString = utterance.speechString
        guard let utteranceRange = Range(characterRange, in: speechString),
            baseWordIndex < wordRanges.count
        else { return }

        let offset = speechString.distance(from: speechString.startIndex, to: utteranceRange.lowerBound)
        let length = speechString.distance(from: utteranceRange.lowerBound, to: utteranceRange.upperBound)
        let base = wordRanges[baseWordIndex].lowerBound
        guard let start = fullText.index(base, offsetBy: offset, limitedBy: fullText.endIndex),
            let end = fullText.index(start, offsetBy: length, limitedBy: fullText.endIndex)
        else { return }

        let range = start..<end
        let matchedIndex = wordRanges.firstIndex { $0.lowerBound == start }

        DispatchQueue.main.async {
            self.currentWordRange = range
            if let matchedIndex { self.wordCursor = matchedIndex }
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.state = .idle
            self.currentWordRange = nil
        }
    }
}
