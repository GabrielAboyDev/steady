import Foundation

/// A minimal next-word model: given the previous word, suggest likely following words.
///
/// Phase 1 seeds this with a small hand-picked table so completions have somewhere
/// to start after a space. Swap in counts derived from a real corpus later — the
/// API stays the same.
public final class BigramModel {
    private var followers: [String: [WordScore]] = [:]

    public init() {}

    /// Record that `next` was observed following `previous`, accumulating counts.
    public func add(previous: String, next: String, count: Double = 1) {
        let key = previous.lowercased()
        var list = followers[key] ?? []
        if let index = list.firstIndex(where: { $0.word == next }) {
            list[index] = WordScore(word: next, score: list[index].score + count)
        } else {
            list.append(WordScore(word: next, score: count))
        }
        followers[key] = list
    }

    /// Most likely words to follow `previous`, best first.
    public func predict(after previous: String, limit: Int = 3) -> [WordScore] {
        let list = followers[previous.lowercased()] ?? []
        return Array(list.sorted { $0.score > $1.score }.prefix(limit))
    }
}
