import AVFoundation
import SwiftUI

/// Lists installed human-sounding voices for the current language, letting
/// the user pick which one the Practice tool and Blind mode speak in. Tapping
/// a row selects it and plays a short sample — the same "select and preview
/// in one tap" pattern ChatGPT's voice picker uses, rather than a separate
/// preview button. Novelty and formant voices are left out on purpose.
struct VoicePickerView: View {

    @Binding var selection: String?
    @StateObject private var preview = VoicePreviewPlayer()

    private let voices = AVSpeechSynthesisVoice.humanVoices()

    var body: some View {
        List {
            row(title: "System Default", isSelected: selection == nil) {
                selection = nil
                preview.play(sample: Self.sampleText, voiceIdentifier: nil)
            }

            ForEach(voices, id: \.identifier) { voice in
                row(title: voice.name, isSelected: selection == voice.identifier) {
                    selection = voice.identifier
                    preview.play(sample: Self.sampleText, voiceIdentifier: voice.identifier)
                }
            }
        }
        .navigationTitle("Voice")
    }

    private func row(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).foregroundStyle(Theme.textPrimary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Theme.brand)
                }
            }
        }
    }

    private static let sampleText = "This is how I'll sound when I read your text out loud."
}

/// A tiny, highlight-free speech player just for auditioning a voice from the
/// picker — `SpeechReader` tracks word ranges for the Practice tool's
/// highlight/scrub UI, which a one-shot preview doesn't need.
private final class VoicePreviewPlayer: NSObject, ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()

    func play(sample: String, voiceIdentifier: String?) {
        synthesizer.stopSpeaking(at: .immediate)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        let utterance = AVSpeechUtterance(string: sample)
        utterance.voice = .preferred(identifier: voiceIdentifier)
        synthesizer.speak(utterance)
    }
}
