import Combine
import Foundation

/// Where typed text goes. The extension writes through `UITextDocumentProxy`
/// into whatever app the user is in; the practice pad writes into its own
/// buffer. The keyboard UI itself doesn't care which.
protocol TextSink: AnyObject {
    /// Text immediately before the cursor, used to derive the prediction prefix.
    /// Secure fields return nil.
    var contextBeforeInput: String? { get }
    /// What the field being typed into asks for: its capitalization,
    /// correction and punctuation traits, its keyboard and return key types.
    var traits: InputTraits { get }
    func insertText(_ text: String)
    func deleteBackward()
    /// The system key click, for sinks that have one.
    func playKeyClick()
}

extension TextSink {
    /// True in password fields, where prediction must stand down (FR-9).
    var isSecureEntry: Bool { traits.isSecure }
    func playKeyClick() {}
}

/// An in-app text buffer, for the practice pad.
final class BufferTextSink: ObservableObject, TextSink {

    @Published var text: String = ""

    /// What this buffer asks for. A plain text view by default: sentences
    /// capitalized, every other trait deferring to the user's switches.
    let traits: InputTraits

    init(traits: InputTraits = .standard) {
        self.traits = traits
    }

    var contextBeforeInput: String? { text }

    func insertText(_ string: String) {
        text.append(string)
    }

    func deleteBackward() {
        guard !text.isEmpty else { return }
        text.removeLast()
    }
}
