import Foundation

/// An in-memory next-word model: given the previous word, suggest likely following words.
///
/// This is the *authoring* representation. The dictionary compiler serializes it
/// into the bigram section of an `.sdict` file, and at runtime the engine reads
/// that section in place (see `MappedDictionary`). Tests and small programs can
/// still build an engine straight from one of these.
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

    /// Every head with its followers, best first. Used by the builder.
    var entries: [(previous: String, followers: [WordScore])] {
        followers.map { key, list in
            (previous: key, followers: list.sorted { $0.score > $1.score })
        }
    }
}
