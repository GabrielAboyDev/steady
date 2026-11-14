import AVFoundation
import Foundation

extension AVSpeechSynthesisVoice {
    /// The saved voice, or the system default for the current language.
    static func preferred(identifier: String?) -> AVSpeechSynthesisVoice? {
        if let identifier, let voice = AVSpeechSynthesisVoice(identifier: identifier) {
            return voice
        }
        return AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
    }
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
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = .preferred(identifier: voiceIdentifier)
        utterance.rate = text.count <= 1 ? 0.58 : AVSpeechUtteranceDefaultSpeechRate
        utterance.preUtteranceDelay = 0
        utterance.postUtteranceDelay = 0
        synthesizer.speak(utterance)
    }
}
