import UIKit

/// What the text field being typed into says about itself.
///
/// This is the one part of the native keyboard's behaviour a custom keyboard
/// can inherit. iOS never lets an extension read Settings > General > Keyboard
/// — the global Auto-Correction, Smart Punctuation and the rest live in a
/// preference domain the sandbox hides — but every text field carries its own
/// copy of those switches as `UITextInputTraits`, and the document proxy
/// exposes them. A field that says "no autocorrect" (a username box, a code
/// editor) is obeyed outright; a field that says "default" defers to the
/// user's own choice, which `KeyboardSettings` mirrors because the real one
/// is unreadable.
struct InputTraits: Equatable {

    /// A three-way field trait: the field has an opinion, or it defers.
    enum Preference: Equatable {
        case `default`
        case on
        case off

        init(_ type: UITextAutocorrectionType?) {
            switch type {
            case .yes: self = .on
            case .no: self = .off
            default: self = .default
            }
        }

        init(_ type: UITextSpellCheckingType?) {
            switch type {
            case .yes: self = .on
            case .no: self = .off
            default: self = .default
            }
        }

        init(_ type: UITextSmartQuotesType?) {
            switch type {
            case .yes: self = .on
            case .no: self = .off
            default: self = .default
            }
        }

        init(_ type: UITextSmartDashesType?) {
            switch type {
            case .yes: self = .on
            case .no: self = .off
            default: self = .default
            }
        }

        init(_ type: UITextSmartInsertDeleteType?) {
            switch type {
            case .yes: self = .on
            case .no: self = .off
            default: self = .default
            }
        }

        /// The field's answer, or the user's when the field defers.
        func resolved(userChoice: Bool) -> Bool {
            switch self {
            case .on: return true
            case .off: return false
            case .default: return userChoice
            }
        }
    }

    var autocapitalization: UITextAutocapitalizationType = .sentences
    var autocorrection: Preference = .default
    var spellChecking: Preference = .default
    var smartQuotes: Preference = .default
    var smartDashes: Preference = .default
    var smartInsertDelete: Preference = .default
    var keyboardType: UIKeyboardType = .default
    var returnKeyType: UIReturnKeyType = .default
    /// The field wants the return key dead until it holds some text.
    var enablesReturnKeyAutomatically = false
    var appearance: UIKeyboardAppearance = .default
    /// A password field. Prediction and resizing stand down (FR-9).
    var isSecure = false

    /// What a plain text view asks for, and what the practice pad types into.
    static let standard = InputTraits()

    /// A value typed into a phrase blank. It lands mid-sentence, so no
    /// capital at the start, and it is as often a name as a word, so no
    /// autocorrect either.
    static let phraseBlank: InputTraits = {
        var traits = InputTraits()
        traits.autocapitalization = .none
        traits.autocorrection = .off
        return traits
    }()

    init() {}

    /// Every requirement of `UITextInputTraits` is optional, so each one is
    /// read as such and falls back to UIKit's documented default.
    init(_ traits: UITextInputTraits) {
        autocapitalization = traits.autocapitalizationType ?? .sentences
        autocorrection = Preference(traits.autocorrectionType)
        spellChecking = Preference(traits.spellCheckingType)
        smartQuotes = Preference(traits.smartQuotesType)
        smartDashes = Preference(traits.smartDashesType)
        smartInsertDelete = Preference(traits.smartInsertDeleteType)
        keyboardType = traits.keyboardType ?? .default
        returnKeyType = traits.returnKeyType ?? .default
        enablesReturnKeyAutomatically = traits.enablesReturnKeyAutomatically ?? false
        appearance = traits.keyboardAppearance ?? .default
        isSecure = traits.isSecureTextEntry ?? false
    }

    // MARK: Layout the field asks for

    /// Numeric fields open on the number plane rather than the letters.
    var opensOnNumbers: Bool {
        switch keyboardType {
        case .numberPad, .phonePad, .decimalPad, .asciiCapableNumberPad, .numbersAndPunctuation:
            return true
        default:
            return false
        }
    }

    /// Characters the field will certainly need, given keys of their own next
    /// to the space bar — what the stock keyboard does for an address.
    var extraBottomKeys: [String] {
        switch keyboardType {
        case .emailAddress: return ["@", "."]
        case .URL, .webSearch: return [".", "/"]
        default: return []
        }
    }

    /// What the return key says. The stock labels, lowercased the way the
    /// stock keyboard draws them.
    var returnKeyLabel: String {
        switch returnKeyType {
        case .go: return "go"
        case .google, .search, .yahoo: return "search"
        case .join: return "join"
        case .next: return "next"
        case .route: return "route"
        case .send: return "send"
        case .done: return "done"
        case .emergencyCall: return "emergency"
        case .continue: return "continue"
        default: return "return"
        }
    }

    /// A field that asks for a Go, Search or Send key is asking for an action
    /// — the stock keyboard paints those in the accent colour.
    var returnKeyIsAction: Bool {
        switch returnKeyType {
        case .default, .next, .continue: return false
        default: return true
        }
    }
}

/// `InputTraits` crossed with the user's own switches: what the keyboard
/// actually does in this field.
///
/// Each field trait resolves to the field's answer when it has one, and to
/// the mirrored setting when it defers. Autocapitalization is the one trait
/// with no "default" case, so there the user's switch can only turn it off.
struct TypingRules: Equatable {

    var autocapitalization: UITextAutocapitalizationType
    var autocorrects: Bool
    var spellingSuggestions: Bool
    var smartQuotes: Bool
    var smartDashes: Bool
    var smartInsertDelete: Bool
    var periodShortcut: Bool
    var capsLock: Bool
    var textReplacements: Bool
    var isSecure: Bool

    init(traits: InputTraits, settings: KeyboardSettings) {
        autocapitalization = settings.autoCapitalization ? traits.autocapitalization : .none
        autocorrects = traits.autocorrection.resolved(userChoice: settings.autoCorrection)
        spellingSuggestions = traits.spellChecking.resolved(userChoice: settings.spellingSuggestions)
        smartQuotes = traits.smartQuotes.resolved(userChoice: settings.smartPunctuation)
        smartDashes = traits.smartDashes.resolved(userChoice: settings.smartPunctuation)
        smartInsertDelete = traits.smartInsertDelete.resolved(userChoice: true)
        periodShortcut = settings.periodShortcut
        capsLock = settings.enableCapsLock
        textReplacements = settings.textReplacement
        isSecure = traits.isSecure

        // A password is not prose: nothing rewrites what was typed, whatever
        // the user's switches say, and nothing guesses at it.
        if traits.isSecure {
            autocorrects = false
            smartQuotes = false
            smartDashes = false
            periodShortcut = false
            textReplacements = false
            spellingSuggestions = false
        }
    }

    static let standard = TypingRules(traits: .standard, settings: .default)
}
