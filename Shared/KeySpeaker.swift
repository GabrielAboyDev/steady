import AVFoundation
import Foundation

extension AVSpeechSynthesisVoice {
    /// The saved voice, or the system default for the current language. A
    /// saved identifier that is no longer offered (a novelty voice picked
    /// before they were hidden, or one the user has since deleted) falls back
    /// to the default rather than speaking in it.
    static func preferred(identifier: String?) -> AVSpeechSynthesisVoice? {
        if let identifier, let voice = AVSpeechSynthesisVoice(identifier: identifier),
            voice.soundsHuman
        {
            return voice
        }
        return AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
    }

    /// Installed voices for the current language that read like a person.
    static func humanVoices() -> [AVSpeechSynthesisVoice] {
        let languageCode = Locale.current.language.languageCode?.identifier ?? "en"
        return speechVoices()
            .filter { $0.language.hasPrefix(languageCode) && $0.soundsHuman }
            .sorted { $0.name < $1.name }
    }

    /// Apple ships two families that are deliberately not human: the novelty
    /// set (Bubbles, Zarvox, Whisper, Bells, Cellos…) under the legacy
    /// `com.apple.speech.synthesis.voice.` prefix, and the Eloquence formant
    /// voices (Eddy, Flo, Grandma, Rocko…). The real ones live under
    /// `com.apple.voice.` and `com.apple.ttsbundle.`, plus Personal Voice.
    var soundsHuman: Bool {
        !Self.syntheticFamilies.contains { identifier.hasPrefix($0) }
    }

    private static let syntheticFamilies = [
        "com.apple.speech.synthesis.voice.",
        "com.apple.eloquence.",
    ]
}

/// Speaks short key names for blind mode, cutting off whatever it was saying.
final class KeySpeaker: ObservableObject {

    private let synthesizer = AVSpeechSynthesizer()

    init() {
        // The synthesizer brings up its own audio session: a keyboard
        // extension may not be allowed to configure the app-wide one.
        synthesizer.usesApplicationAudioSession = false
    }

    func speak(_ text: String, voiceIdentifier: String?) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(attributedString: Self.pronounced(text))
        utterance.voice = .preferred(identifier: voiceIdentifier)
        utterance.rate = text.count <= 1 ? 0.58 : AVSpeechUtteranceDefaultSpeechRate
        utterance.preUtteranceDelay = 0
        utterance.postUtteranceDelay = 0
        synthesizer.speak(utterance)
    }

    /// Letter names are spoken in lowercase so the voice does not add its own
    /// "capital" — but a lone lowercase "a" is read as the article. Pin that
    /// one word to the letter's name; every other letter already reads as
    /// itself. Voices without IPA support fall back to the plain text.
    static func pronounced(_ text: String) -> NSAttributedString {
        let result = NSMutableAttributedString(string: text)
        guard text.split(separator: " ").last == "a",
            let found = text.range(of: "a", options: .backwards)
        else { return result }
        let range = NSRange(found, in: text)
        result.addAttribute(
            NSAttributedString.Key(AVSpeechSynthesisIPANotationAttribute), value: "eɪ", range: range)
        return result
    }
}
