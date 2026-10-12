import Foundation

/// On-device predictive text engine backed by a compiled, memory-mapped
/// dictionary (`.sdict`): a frequency-weighted byte trie plus a next-word
/// (bigram) table. Fully offline — no network, no "Full Access" required when
/// embedded in a keyboard extension.
///
/// The bundled dictionary is never parsed into Swift objects. Opening it maps
/// the file; each query touches only the pages it walks, so memory stays flat
/// no matter how large the word list grows.
public final class PredictiveEngine: Sendable {

    private let dictionary: MappedDictionary

    /// Build an engine from a lexicon of `(word, frequency)` pairs.
    ///
    /// Compiles the lexicon in memory through the same format the bundled
    /// dictionary uses, so callers and tests exercise the real read path.
    public init(lexicon: [(word: String, frequency: Double)], bigrams: BigramModel = BigramModel()) {
        let data = DictionaryBuilder.build(lexicon: lexicon, bigrams: bigrams)
        // The builder's output is valid by construction.
        self.dictionary = try! MappedDictionary(data: data)
    }

    /// Open a compiled `.sdict` from raw bytes. Throws if the header is not valid.
    public init(data: Data) throws {
        self.dictionary = try MappedDictionary(data: data)
    }

    /// Memory-map a compiled `.sdict` file.
    public convenience init(contentsOf url: URL) throws {
        try self.init(data: try Data(contentsOf: url, options: .mappedIfSafe))
    }

    // MARK: Completions

    /// Top word completions for a prefix, best first.
    /// An empty prefix returns the globally most frequent words.
    public func completions(forPrefix prefix: String, limit: Int = 5) -> [WordScore] {
        dictionary.completions(forPrefix: prefix, limit: limit)
    }

    // MARK: Next-letter prediction (drives key resizing)

    /// Raw weight for each letter that can legally follow `prefix`.
    /// The weight is the aggregate frequency of all words continuing through that letter.
    public func nextLetterWeights(forPrefix prefix: String) -> [Character: Double] {
        dictionary.nextLetterWeights(forPrefix: prefix)
    }

    /// Convenience: go straight from a prefix to per-key display scales.
    public func keyScales(
        forPrefix prefix: String,
        keys: [Character] = KeyLayout.allLetters,
        config: KeyResizeConfig = .motorAccessibility
    ) -> [Character: KeyScale] {
        let weights = nextLetterWeights(forPrefix: prefix)
        return KeyLayout.keyScales(weights: weights, keys: keys, config: config)
    }

    // MARK: Next-word prediction

    /// Likely next words after a completed word (used right after a space).
    public func predictNextWord(after previousWord: String, limit: Int = 3) -> [WordScore] {
        dictionary.predictNextWord(after: previousWord, limit: limit)
    }

    // MARK: Loading

    public enum LoadError: Error { case resourceMissing }

    /// Name of the dictionary resource bundled with the package.
    public static let bundledDictionaryName = "en"

    /// Open the dictionary bundled in the package's Resources (built offline by
    /// `sdict-compile`; see `scripts/build-dictionary.sh`).
    public static func loadBundled() throws -> PredictiveEngine {
        guard let url = Bundle.module.url(forResource: bundledDictionaryName, withExtension: "sdict") else {
            throw LoadError.resourceMissing
        }
        return try PredictiveEngine(contentsOf: url)
    }
}
