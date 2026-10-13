import Foundation
import UIKit

/// One entry of the user's text replacements and address book, as iOS hands
/// them to a keyboard through `requestSupplementaryLexicon`.
///
/// A replacement is `omw` → `On my way!`; a contact is `Gabriel` → `Gabriel`,
/// which still matters because it says the word is a name and not a typo.
/// Available without Full Access.
struct LexiconEntry: Equatable {
    let userInput: String
    let documentText: String

    /// True when typing `userInput` should turn into `documentText`.
    var isReplacement: Bool { userInput != documentText }

    func matches(_ word: String) -> Bool {
        userInput.caseInsensitiveCompare(word) == .orderedSame
            || documentText.caseInsensitiveCompare(word) == .orderedSame
    }
}

/// The spelling questions the composer and the suggestion row ask.
protocol SpellChecking: AnyObject {
    func isMisspelled(_ word: String) -> Bool
    func guesses(for word: String) -> [String]
}

/// The system spell checker, which is the same dictionary the stock keyboard
/// consults, and works inside a keyboard extension without Full Access.
final class SystemSpellChecker: SpellChecking {

    private let checker = UITextChecker()
    /// The user's first preferred language the checker has a dictionary
    /// for, else English — the keyboard's declared primary language.
    private let language: String

    init() {
        let available = UITextChecker.availableLanguages
        let preferred = Locale.preferredLanguages.map { $0.replacingOccurrences(of: "-", with: "_") }
        language =
            preferred.first(where: { available.contains($0) })
            ?? preferred.compactMap { tag in available.first { $0.hasPrefix(tag.prefix(2)) } }.first
            ?? "en_US"
    }

    func isMisspelled(_ word: String) -> Bool {
        let range = checker.rangeOfMisspelledWord(
            in: word, range: NSRange(location: 0, length: word.utf16.count),
            startingAt: 0, wrap: false, language: language)
        return range.location != NSNotFound
    }

    func guesses(for word: String) -> [String] {
        checker.guesses(
            forWordRange: NSRange(location: 0, length: word.utf16.count),
            in: word, language: language) ?? []
    }
}

/// How an inserted word is cased, following the shift key.
enum Capitalization {
    case none
    case first
    case all

    func apply(to word: String) -> String {
        switch self {
        case .none: return word
        case .first: return word.prefix(1).uppercased() + word.dropFirst()
        case .all: return word.uppercased()
        }
    }
}

/// Turns key taps into text, applying what the stock keyboard would:
/// autocorrection, text replacements, smart quotes and dashes, the
/// double-space period, and a space before a word dropped in mid-sentence.
///
/// It sits between the keys and the `TextSink`, so the extension and the
/// practice pad get exactly the same behaviour. The rules come in with every
/// call because they belong to the field being typed into, not to the
/// composer; the composer keeps only what spans two taps — the last
/// correction, so backspace can undo it, and the time of the last space.
final class TextComposer: ObservableObject {

    /// Text replacements and contact names from iOS. Empty in the practice
    /// pad and until the extension's request comes back.
    var lexicon: [LexiconEntry] = []
    /// Words never to correct, lowercased: the names saved in Steady's own
    /// Names panel, which the spell checker has no way of knowing.
    var knownWords: Set<String> = []

    private let checker: SpellChecking

    private struct Correction {
        let original: String
        let replacement: String
        let separator: String
    }

    /// The last word the composer rewrote, until anything else is typed.
    private var lastCorrection: Correction?
    private var lastSpaceAt: Date?

    /// Two spaces this close together are a full stop — the stock timing.
    static let periodShortcutWindow: TimeInterval = 0.6

    init(checker: SpellChecking = SystemSpellChecker()) {
        self.checker = checker
    }

    // MARK: Keys

    /// A key tap. `key` is what the cap shows: a letter already cased by the
    /// shift state, a digit, a mark, a space or a newline.
    func type(_ key: String, rules: TypingRules, into sink: TextSink) {
        let context = sink.contextBeforeInput ?? ""
        lastCorrection = nil

        if key == " " {
            if rules.periodShortcut, isWithinPeriodShortcutWindow, endsWithSingleSpaceAfterWord(context) {
                sink.deleteBackward()
                sink.insertText(". ")
                lastSpaceAt = nil
                return
            }
            commitWord(in: context, separator: " ", rules: rules, into: sink)
            lastSpaceAt = Date()
            return
        }
        lastSpaceAt = nil

        if key == "\n" || (key.count == 1 && TextComposer.wordTerminators.contains(key)) {
            commitWord(in: context, separator: key, rules: rules, into: sink)
            return
        }
        if key == "\"", rules.smartQuotes {
            sink.insertText(TextComposer.opensQuote(after: context) ? "\u{201C}" : "\u{201D}")
            return
        }
        if key == "'", rules.smartQuotes {
            if let last = context.last, last.isLetter || last.isNumber {
                sink.insertText("\u{2019}")  // an apostrophe: don’t
            } else {
                sink.insertText(TextComposer.opensQuote(after: context) ? "\u{2018}" : "\u{2019}")
            }
            return
        }
        if key == "-", rules.smartDashes, context.last == "-" {
            sink.deleteBackward()
            sink.insertText("\u{2014}")
            return
        }
        sink.insertText(key)
    }

    /// Backspace. Straight after an autocorrection it puts the original word
    /// back instead, which is how the stock keyboard lets a correction be
    /// refused.
    func deleteBackward(into sink: TextSink) {
        lastSpaceAt = nil
        defer { lastCorrection = nil }
        if let correction = lastCorrection,
            let context = sink.contextBeforeInput,
            context.hasSuffix(correction.replacement + correction.separator)
        {
            for _ in 0..<(correction.replacement.count + correction.separator.count) {
                sink.deleteBackward()
            }
            sink.insertText(correction.original)
            return
        }
        sink.deleteBackward()
    }

    // MARK: Whole words

    /// A suggestion chip. Replaces the `prefixLength` characters already
    /// typed — zero for a next-word prediction — and leaves a trailing space.
    func insertWord(
        _ word: String,
        replacingPrefix prefixLength: Int,
        capitalization: Capitalization,
        rules: TypingRules,
        into sink: TextSink
    ) {
        lastCorrection = nil
        lastSpaceAt = nil
        for _ in 0..<prefixLength {
            sink.deleteBackward()
        }
        let context = sink.contextBeforeInput ?? ""
        let cased = capitalization.apply(to: word)
        let text = prefixLength == 0 && rules.smartInsertDelete && TextComposer.needsSpace(before: context)
            ? " " + cased : cased
        sink.insertText(text + " ")
    }

    /// A name or a finished phrase. A space goes in front when it lands
    /// against the end of a word, so "see you" does not become "seeyou".
    func insert(_ text: String, rules: TypingRules, into sink: TextSink) {
        lastCorrection = nil
        lastSpaceAt = nil
        let context = sink.contextBeforeInput ?? ""
        let leading = rules.smartInsertDelete && TextComposer.needsSpace(before: context) ? " " : ""
        sink.insertText(leading + text)
    }

    // MARK: Committing a word

    /// Space, return and punctuation finish the word before the cursor. That
    /// is the moment a text replacement expands or a misspelling is corrected.
    private func commitWord(in context: String, separator: String, rules: TypingRules, into sink: TextSink) {
        let word = TextComposer.trailingWord(in: context)
        guard !word.isEmpty else {
            sink.insertText(separator)
            return
        }

        if rules.textReplacements, let entry = lexicon.first(where: { $0.matches(word) }) {
            // A replacement expands; a plain contact name is already right,
            // and is not something the spell checker should second-guess.
            if entry.isReplacement || entry.documentText != word {
                replace(word, with: entry.documentText, separator: separator, into: sink)
            } else {
                sink.insertText(separator)
            }
            return
        }

        if rules.autocorrects, TextComposer.isCorrectable(word),
            !knownWords.contains(word.lowercased()),
            checker.isMisspelled(word),
            let guess = checker.guesses(for: word).first,
            TextComposer.isAcceptableCorrection(guess, for: word)
        {
            replace(word, with: guess, separator: separator, into: sink)
            lastCorrection = Correction(original: word, replacement: guess, separator: separator)
            return
        }

        sink.insertText(separator)
    }

    private func replace(_ word: String, with replacement: String, separator: String, into sink: TextSink) {
        for _ in 0..<word.count {
            sink.deleteBackward()
        }
        sink.insertText(replacement + separator)
    }

    // MARK: Text rules

    /// Marks that end a word, and so trigger a correction, besides space and
    /// return.
    static let wordTerminators: Set<String> = [".", ",", "!", "?", ";", ":"]

    /// The run of letters and apostrophes immediately before the cursor.
    static func trailingWord(in context: String) -> String {
        String(context.reversed().prefix(while: { $0.isLetter || $0 == "'" || $0 == "\u{2019}" }).reversed())
    }

    /// Only ordinary words get corrected: not acronyms, not mixed case, not
    /// anything with a digit, and nothing the user has deliberately shouted.
    static func isCorrectable(_ word: String) -> Bool {
        guard !word.isEmpty, word.allSatisfy({ $0.isLetter || $0 == "'" || $0 == "\u{2019}" }) else {
            return false
        }
        let letters = word.filter(\.isLetter)
        let lowercased = letters.lowercased()
        let capitalized = letters.prefix(1).uppercased() + letters.dropFirst().lowercased()
        return letters == lowercased || letters == capitalized
    }

    /// A guess that merely recases the word is still a correction (monday →
    /// Monday, i → I); one that is wildly longer is a guess, not a fix.
    static func isAcceptableCorrection(_ guess: String, for word: String) -> Bool {
        guard guess != word, !guess.isEmpty else { return false }
        return guess.count <= word.count + 3
    }

    /// A quote typed here opens: at the start, after whitespace, or after an
    /// opening bracket.
    static func opensQuote(after context: String) -> Bool {
        guard let last = context.last else { return true }
        return last.isWhitespace || "([{\u{201C}\u{2018}".contains(last)
    }

    /// An inserted word needs a space before it when the cursor is hard
    /// against the end of a word or a closing mark.
    static func needsSpace(before context: String) -> Bool {
        guard let last = context.last else { return false }
        if last.isWhitespace { return false }
        return !"([{\u{201C}\u{2018}\"'/@-\u{2014}".contains(last)
    }

    private var isWithinPeriodShortcutWindow: Bool {
        guard let at = lastSpaceAt else { return false }
        return Date().timeIntervalSince(at) < TextComposer.periodShortcutWindow
    }

    /// "word " — exactly one space after something that can end a sentence.
    private func endsWithSingleSpaceAfterWord(_ context: String) -> Bool {
        guard context.last == " " else { return false }
        guard let before = context.dropLast().last else { return false }
        return before.isLetter || before.isNumber || "\"')]}\u{201D}\u{2019}".contains(before)
    }
}

extension TypingRules {

    /// Whether the shift key should be up before the next letter, from the
    /// field's autocapitalization and what is already typed.
    func wantsCapital(after context: String?) -> Bool {
        let context = context ?? ""
        switch autocapitalization {
        case .none:
            return false
        case .allCharacters:
            return true
        case .words:
            guard let last = context.last else { return true }
            return last.isWhitespace
        case .sentences:
            guard let last = context.last else { return true }
            if last.isNewline { return true }
            guard last == " " else { return false }
            // Back over the spaces to whatever ended the previous sentence,
            // allowing a closing quote or bracket after the full stop.
            var rest = Substring(context.dropLast())
            while let tail = rest.last, tail == " " { rest = rest.dropLast() }
            while let tail = rest.last, "\"')]}\u{201D}\u{2019}".contains(tail) { rest = rest.dropLast() }
            guard let terminator = rest.last else { return true }
            return ".!?".contains(terminator)
        @unknown default:
            return false
        }
    }
}
