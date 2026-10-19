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
    /// Moves the caret without touching the text — positive steps right,
    /// negative left — the way holding the space bar and dragging does on
    /// the stock keyboard.
    func moveCursor(by characterOffset: Int)
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
    /// The caret as a character count from the start. Tracked separately
    /// from `text` so the space-bar trackpad gesture has somewhere real to
    /// move — code that resets `text` (the Clear button, a cancelled phrase
    /// blank) doesn't also touch this, so every read clamps it to the
    /// current length instead of trusting it stays in range.
    @Published private(set) var cursorOffset: Int = 0

    /// What this buffer asks for. A plain text view by default: sentences
    /// capitalized, every other trait deferring to the user's switches.
    let traits: InputTraits

    init(traits: InputTraits = .standard) {
        self.traits = traits
    }

    var contextBeforeInput: String? { String(text.prefix(clampedOffset)) }

    func insertText(_ string: String) {
        let offset = clampedOffset
        let index = text.index(text.startIndex, offsetBy: offset)
        text.insert(contentsOf: string, at: index)
        cursorOffset = offset + string.count
    }

    func deleteBackward() {
        let offset = clampedOffset
        guard offset > 0 else { return }
        let index = text.index(text.startIndex, offsetBy: offset - 1)
        text.remove(at: index)
        cursorOffset = offset - 1
    }

    func moveCursor(by characterOffset: Int) {
        cursorOffset = min(max(clampedOffset + characterOffset, 0), text.count)
    }

    private var clampedOffset: Int { min(max(cursorOffset, 0), text.count) }
}
