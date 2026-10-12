import Foundation

/// On-device predictive text engine backed by a frequency-weighted prefix trie
/// plus a small next-word (bigram) model. Fully offline — no network, no
/// "Full Access" required when embedded in a keyboard extension.
public final class PredictiveEngine {

    private let trie = Trie()
    private let bigrams: BigramModel

    /// Build an engine from a lexicon of `(word, frequency)` pairs.
    public init(lexicon: [(word: String, frequency: Double)], bigrams: BigramModel = BigramModel()) {
        self.bigrams = bigrams
        for entry in lexicon {
            trie.insert(entry.word.lowercased(), frequency: entry.frequency)
        }
    }

    // MARK: Completions

    /// Top word completions for a prefix, best first.
    /// An empty prefix returns the globally most frequent words.
    public func completions(forPrefix prefix: String, limit: Int = 5) -> [WordScore] {
        let normalized = prefix.lowercased()
        guard let start = trie.node(forPrefix: normalized) else { return [] }

        var results: [WordScore] = []
        var stack: [TrieNode] = [start]
        while let node = stack.popLast() {
            if node.isTerminal, let word = node.word {
                results.append(WordScore(word: word, score: node.wordFrequency))
            }
            for child in node.children.values { stack.append(child) }
        }
        return Array(results.sorted { $0.score > $1.score }.prefix(limit))
    }

    // MARK: Next-letter prediction (drives key resizing)

    /// Raw weight for each letter that can legally follow `prefix`.
    /// The weight is the aggregate frequency of all words continuing through that letter.
    public func nextLetterWeights(forPrefix prefix: String) -> [Character: Double] {
        let normalized = prefix.lowercased()
        guard let node = trie.node(forPrefix: normalized) else { return [:] }
        var weights: [Character: Double] = [:]
        for (character, child) in node.children {
            weights[character] = child.aggregateFrequency
        }
        return weights
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
        bigrams.predict(after: previousWord, limit: limit)
    }

    // MARK: Loading

    enum LoadError: Error { case resourceMissing }

    /// Build an engine from the lexicon bundled in the package's Resources.
    /// Words are listed one per line in descending frequency; rank becomes a
    /// Zipf-style weight (1 / rank).
    public static func loadBundled() throws -> PredictiveEngine {
        guard let url = Bundle.module.url(forResource: "words", withExtension: "txt") else {
            throw LoadError.resourceMissing
        }
        let text = try String(contentsOf: url, encoding: .utf8)
        var lexicon: [(word: String, frequency: Double)] = []
        var rank = 0
        for rawLine in text.split(whereSeparator: \.isNewline) {
            let word = rawLine.trimmingCharacters(in: .whitespaces).lowercased()
            guard !word.isEmpty, !word.hasPrefix("#") else { continue }
            rank += 1
            lexicon.append((word, 1.0 / Double(rank)))
        }
        return PredictiveEngine(lexicon: lexicon, bigrams: seededBigrams())
    }

    /// A tiny seed table so next-word suggestions work in Phase 1.
    static func seededBigrams() -> BigramModel {
        let model = BigramModel()
        let seeds: [String: [String]] = [
            "i": ["am", "will", "have", "think", "was"],
            "the": ["same", "first", "other", "best", "way"],
            "how": ["are", "to", "do", "much", "many"],
            "what": ["is", "are", "do", "time", "about"],
            "thank": ["you"],
            "let": ["me", "us"],
            "see": ["you"],
            "i'm": ["going", "not", "just", "sorry"],
            "can": ["you", "i", "we"],
            "please": ["let", "call", "help"]
        ]
        for (previous, nexts) in seeds {
            for (index, next) in nexts.enumerated() {
                model.add(previous: previous, next: next, count: Double(nexts.count - index))
            }
        }
        return model
    }
}
