import Foundation
import Combine

/// Where typed text goes. The extension writes through `UITextDocumentProxy`
/// into whatever app the user is in; the practice pad writes into its own
/// buffer. The keyboard UI itself doesn't care which.
protocol TextSink: AnyObject {
    /// Text immediately before the cursor, used to derive the prediction prefix.
    /// Secure fields return nil.
    var contextBeforeInput: String? { get }
    /// True in password fields, where prediction must stand down (FR-9).
    var isSecureEntry: Bool { get }
    func insertText(_ text: String)
    func deleteBackward()
}

/// An in-app text buffer, for the practice pad.
final class BufferTextSink: ObservableObject, TextSink {

    @Published var text: String = ""

    var contextBeforeInput: String? { text }
    var isSecureEntry: Bool { false }

    func insertText(_ string: String) {
        text.append(string)
    }

    func deleteBackward() {
        guard !text.isEmpty else { return }
        text.removeLast()
    }
}
