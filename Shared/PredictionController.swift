import Foundation
import Combine
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

    /// The largest scale currently assigned, used to pick out the single
    /// most-likely key for emphasis.
    private(set) var topScale: Double = 1.0

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

    /// Recompute from the text before the cursor.
    func refresh(context: String?, isSecure: Bool) {
        guard !isSecure else {
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

        // Chips.
        if prefix.isEmpty {
            suggestionsAreNextWord = true
            let previous = PredictionController.lastCompletedWord(in: context)
            let nextWords = previous.isEmpty ? [] : engine.predictNextWord(after: previous, limit: 3)
            if nextWords.isEmpty {
                suggestions = engine.completions(forPrefix: "", limit: 3).map(\.word)
            } else {
                suggestions = nextWords.map(\.word)
            }
        } else {
            suggestionsAreNextWord = false
            suggestions = engine.completions(forPrefix: prefix, limit: 3).map(\.word)
        }
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
        keyScales = Dictionary(uniqueKeysWithValues: KeyLayout.allLetters.map {
            ($0, KeyScale(key: $0, scale: 1.0, isPossible: true))
        })
        topScale = 1.0
    }

    // MARK: Context parsing

    /// The run of word characters immediately before the cursor.
    static func trailingPrefix(of context: String) -> String {
        let allowed: (Character) -> Bool = { $0.isLetter || $0 == "'" }
        return String(context.reversed().prefix(while: allowed).reversed()).lowercased()
    }

    /// The last finished word before the cursor, for next-word prediction.
    static func lastCompletedWord(in context: String) -> String {
        let tokens = context
            .split(whereSeparator: { $0.isWhitespace })
            .map { token in
                String(token).trimmingCharacters(in: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "'")).inverted)
            }
            .filter { !$0.isEmpty }
        // If the context ends mid-word, that fragment isn't a completed word.
        if let last = context.last, last.isLetter || last == "'" {
            return tokens.dropLast().last?.lowercased() ?? ""
        }
        return tokens.last?.lowercased() ?? ""
    }
}
