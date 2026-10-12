import Foundation

/// A node in the prefix trie.
///
/// `aggregateFrequency` is the sum of the frequency of every word stored in
/// this node's subtree (including the word that may terminate at this node).
/// Keeping it precomputed lets us answer "how likely is each next letter?"
/// in O(number of children) instead of walking the whole subtree each keypress.
final class TrieNode {
    var children: [Character: TrieNode] = [:]
    var isTerminal = false
    /// Frequency weight of the word that terminates exactly at this node (0 if none).
    var wordFrequency: Double = 0
    /// Sum of `wordFrequency` for every word in this subtree.
    var aggregateFrequency: Double = 0
    /// The full word, cached on terminal nodes so completions don't rebuild strings.
    var word: String?
}

/// A frequency-weighted prefix trie.
public final class Trie {
    let root = TrieNode()

    public init() {}

    /// Insert a word with an associated frequency weight (higher = more common).
    public func insert(_ word: String, frequency: Double) {
        var node = root
        node.aggregateFrequency += frequency
        for character in word {
            let child: TrieNode
            if let existing = node.children[character] {
                child = existing
            } else {
                child = TrieNode()
                node.children[character] = child
            }
            child.aggregateFrequency += frequency
            node = child
        }
        node.isTerminal = true
        node.wordFrequency += frequency
        node.word = word
    }

    /// The node reached by following `prefix`, or nil if the prefix is not in the trie.
    func node(forPrefix prefix: String) -> TrieNode? {
        var node = root
        for character in prefix {
            guard let next = node.children[character] else { return nil }
            node = next
        }
        return node
    }
}
