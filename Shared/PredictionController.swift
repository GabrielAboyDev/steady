import Combine
import Foundation
import PredictiveEngine

/// Drives the keyboard's reshaping: turns the text before the cursor into
/// per-key scales and word suggestions. All on-device.
final class PredictionController: ObservableObject {

    /// Scale per letter. 0 means the key is hidden.
    @Published private(set) var keyScales: [Character: KeyScale] = [:]
    /// Up to three chips: completions mid-word, next-word predictions after a space.
    @Published private(set) var suggestions: [String] = []
    /// True when the chips are next-word predictions rather than completions.
    @Published private(set) var suggestionsAreNextWord = false
    /// True in a secure field, where the layout falls back to a static QWERTY.
    @Published private(set) var isStaticFallback = false
    /// The word fragment currently being predicted against.
    @Published private(set) var currentPrefix = ""
    /// Whether the shift key should be up for the next letter, from the
    /// field's autocapitalization and the text before the cursor.
    @Published private(set) var autoShift = false
    /// Bumped on every refresh, so the surface can re-apply `autoShift` even
    /// when its value did not change — a manual shift is reset by typing,
    /// not only by crossing a sentence boundary.
    @Published private(set) var revision = 0

    /// What the keyboard does in the current field: the field's traits
    /// crossed with the user's settings. Set by `refresh`.
    private(set) var rules: TypingRules = .standard

    /// The user's text replacements and contact names. Names show up as
    /// completions, so a contact is one tap however it is spelled.
    var lexicon: [LexiconEntry] = []
    /// Offers guesses for a word the dictionary does not know. Nil skips
    /// spelling suggestions entirely.
    var spellChecker: SpellChecking? = SystemSpellChecker()

    /// The largest scale currently assigned, used to pick out the single
    /// most-likely key for emphasis.
    private(set) var topScale: Double = 1.0

    /// How many words to ask the engine for: three pages of three. Past that
    /// the ranking is weak enough that paging further is not worth the tap.
    static let suggestionLimit = 9

    private let engine: PredictiveEngine?
    private var settings: KeyboardSettings

    init(settings: KeyboardSettings = .default) {
        self.settings = settings
        self.engine = try? PredictiveEngine.loadBundled()
        resetToUniform()
    }

    /// True when the bundled lexicon failed to load — the keyboard still types,
    /// it just stops reshaping.
    var isEngineAvailable: Bool { engine != nil }

    func update(settings newSettings: KeyboardSettings) {
        settings = newSettings
    }

    /// Recompute for a plain text field. Settings previews and tests.
    func refresh(context: String?, isSecure: Bool) {
        var traits = InputTraits.standard
        traits.isSecure = isSecure
        refresh(context: context, traits: traits)
    }

    /// Recompute from the text before the cursor and the field's traits.
    func refresh(context: String?, traits: InputTraits) {
        rules = TypingRules(traits: traits, settings: settings)
        defer { revision += 1 }
        autoShift = rules.wantsCapital(after: context)

        guard !traits.isSecure else {
            isStaticFallback = true
            suggestions = []
            suggestionsAreNextWord = false
            currentPrefix = ""
            resetToUniform()
            return
        }
        isStaticFallback = false

        let context = context ?? ""
        let prefix = PredictionController.trailingPrefix(of: context)
        currentPrefix = prefix

        guard let engine else {
            suggestions = []
            resetToUniform()
            return
        }

        // Key scales. An empty prefix still resizes by first-letter frequency.
        let scales = engine.keyScales(forPrefix: prefix, config: resizeConfig)
        keyScales = scales
        topScale = scales.values.filter(\.isPossible).map(\.scale).max() ?? 1.0

        // Chips. More than fit on screen: the bar shows three at a time and
        // the rest are a swipe or an arrow-tap away.
        if prefix.isEmpty {
            suggestionsAreNextWord = true
            let previous = PredictionController.lastCompletedWord(in: context)
            let nextWords =
                previous.isEmpty
                ? []
                : engine.predictNextWord(after: previous, limit: PredictionController.suggestionLimit)
            if nextWords.isEmpty {
                suggestions = engine.completions(
                    forPrefix: "", limit: PredictionController.suggestionLimit
                ).map(\.word)
            } else {
                suggestions = nextWords.map(\.word)
            }
        } else {
            suggestionsAreNextWord = false
            suggestions = completions(forPrefix: prefix, engine: engine)
        }
    }

    /// Completions for a word in progress: the user's own names and
    /// replacements first, then the engine, then — when those run short and
    /// the fragment is not a word — the spell checker's guesses.
    private func completions(forPrefix prefix: String, engine: PredictiveEngine) -> [String] {
        let limit = PredictionController.suggestionLimit
        var words: [String] = []
        var seen: Set<String> = []

        func add(_ word: String) {
            let key = word.lowercased()
            guard !key.isEmpty, !seen.contains(key) else { return }
            seen.insert(key)
            words.append(word)
        }

        if rules.textReplacements {
            for entry in lexicon where words.count < 2 {
                let matches =
                    entry.userInput.lowercased().hasPrefix(prefix)
                    || entry.documentText.lowercased().hasPrefix(prefix)
                if matches { add(entry.documentText) }
            }
        }
        for completion in engine.completions(forPrefix: prefix, limit: limit) {
            add(completion.word)
        }
        if rules.spellingSuggestions, words.count < 3, prefix.count >= 3,
            let checker = spellChecker, checker.isMisspelled(prefix)
        {
            for guess in checker.guesses(for: prefix).prefix(3) {
                add(guess)
            }
        }
        return Array(words.prefix(limit))
    }

    /// Settings translated into the engine's resize knobs.
    var resizeConfig: KeyResizeConfig {
        switch settings.resizeStrength {
        case .off:
            // Uniform: nothing grows, nothing hides, nothing shrinks.
            return KeyResizeConfig(
                aggressiveness: 0, hideImpossibleKeys: false, minScale: 1.0, maxScale: 1.0
            )
        case .medium:
            return KeyResizeConfig(
                aggressiveness: 0.5,
                hideImpossibleKeys: settings.hideImpossibleKeys,
                minScale: 0.5,
                maxScale: settings.enlargeLikelyKeys ? 1.35 : 1.0
            )
        case .aggressive:
            return KeyResizeConfig(
                aggressiveness: 0.9,
                hideImpossibleKeys: settings.hideImpossibleKeys,
                minScale: 0.5,
                maxScale: settings.enlargeLikelyKeys ? 1.9 : 1.0
            )
        }
    }

    private func resetToUniform() {
        keyScales = Dictionary(
            uniqueKeysWithValues: KeyLayout.allLetters.map {
                ($0, KeyScale(key: $0, scale: 1.0, isPossible: true))
            })
        topScale = 1.0
    }

    // MARK: Context parsing

    /// The run of word characters immediately before the cursor. A curly
    /// apostrophe, which smart quotes type, counts the same as a straight one.
    static func trailingPrefix(of context: String) -> String {
        let allowed: (Character) -> Bool = { $0.isLetter || $0 == "'" || $0 == "\u{2019}" }
        return String(context.reversed().prefix(while: allowed).reversed())
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .lowercased()
    }

    /// The last finished word before the cursor, for next-word prediction.
    static func lastCompletedWord(in context: String) -> String {
        let tokens =
            context
            .split(whereSeparator: { $0.isWhitespace })
            .map { token in
                String(token).trimmingCharacters(
                    in: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "'\u{2019}")).inverted)
            }
            .filter { !$0.isEmpty }
        // If the context ends mid-word, that fragment isn't a completed word.
        if let last = context.last, last.isLetter || last == "'" || last == "\u{2019}" {
            return tokens.dropLast().last?.lowercased() ?? ""
        }
        return tokens.last?.lowercased() ?? ""
    }
}
