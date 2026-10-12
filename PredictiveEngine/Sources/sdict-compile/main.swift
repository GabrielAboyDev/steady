import Foundation
import PredictiveEngine

// sdict-compile: turn a word-frequency list and a bigram list into a `.sdict`
// file for PredictiveEngine. Run via scripts/build-dictionary.sh.
//
//   sdict-compile --words en_50k.txt [--bigrams count_2w.txt] --out en.sdict
//                 [--max-words 50000] [--followers-per-head 12]
//
// Words file: one `word count` per line (hermitdave/FrequencyWords format).
// Bigrams file: one `w1 w2<TAB>count` per line (Norvig count_2w.txt format).

struct Options {
    var words: String?
    var bigrams: String?
    var out: String?
    var maxWords = 50_000
    var followersPerHead = 12
}

func parseOptions() -> Options {
    var options = Options()
    var args = CommandLine.arguments.dropFirst().makeIterator()
    while let flag = args.next() {
        let value = args.next()
        switch (flag, value) {
        case ("--words", let v?): options.words = v
        case ("--bigrams", let v?): options.bigrams = v
        case ("--out", let v?): options.out = v
        case ("--max-words", let v?): options.maxWords = Int(v) ?? options.maxWords
        case ("--followers-per-head", let v?): options.followersPerHead = Int(v) ?? options.followersPerHead
        default:
            fail("unknown or incomplete argument: \(flag)")
        }
    }
    return options
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("sdict-compile: \(message)\n".utf8))
    exit(1)
}

/// Keep lowercase words made of letters and apostrophes. Single letters other
/// than "a" and "i" are noise, as are tokens that start with an apostrophe.
func isAcceptableWord(_ word: String) -> Bool {
    guard !word.isEmpty, word.count <= 40, !word.hasPrefix("'") else { return false }
    guard word.allSatisfy({ $0.isLetter || $0 == "'" }) else { return false }
    guard word.contains(where: \.isLetter) else { return false }
    if word.count == 1 { return word == "a" || word == "i" }
    return true
}

/// Hand-picked pairs kept as a floor so core phrases survive whatever the
/// corpus says (and so `thank → you` works even without a bigram file).
let seedBigrams: [String: [String]] = [
    "i": ["am", "will", "have", "think", "was"],
    "the": ["same", "first", "other", "best", "way"],
    "how": ["are", "to", "do", "much", "many"],
    "what": ["is", "are", "do", "time", "about"],
    "thank": ["you"],
    "let": ["me", "us"],
    "see": ["you"],
    "i'm": ["going", "not", "just", "sorry"],
    "can": ["you", "i", "we"],
    "please": ["let", "call", "help"],
]

let options = parseOptions()
guard let wordsPath = options.words, let outPath = options.out else {
    fail("usage: sdict-compile --words <file> [--bigrams <file>] --out <file> [--max-words N] [--followers-per-head N]")
}

// 1. Words.
var lexicon: [(word: String, frequency: Double)] = []
var vocabulary: Set<String> = []
do {
    let text = try String(contentsOfFile: wordsPath, encoding: .utf8)
    for line in text.split(whereSeparator: \.isNewline) {
        let parts = line.split(separator: " ", maxSplits: 1)
        guard parts.count == 2, let count = Double(parts[1]) else { continue }
        let word = parts[0].lowercased()
        guard isAcceptableWord(word), !vocabulary.contains(word) else { continue }
        vocabulary.insert(word)
        lexicon.append((word, count))
        if lexicon.count >= options.maxWords { break }
    }
} catch {
    fail("cannot read words file: \(error)")
}
guard !lexicon.isEmpty else { fail("no usable words in \(wordsPath)") }

// 2. Bigrams, restricted to the vocabulary, top N followers per head.
var followersByHead: [String: [(word: String, count: Double)]] = [:]
if let bigramsPath = options.bigrams {
    do {
        let text = try String(contentsOfFile: bigramsPath, encoding: .utf8)
        for line in text.split(whereSeparator: \.isNewline) {
            let columns = line.split(separator: "\t", maxSplits: 1)
            guard columns.count == 2, let count = Double(columns[1]) else { continue }
            let pair = columns[0].split(separator: " ")
            guard pair.count == 2 else { continue }
            let head = pair[0].lowercased(), next = pair[1].lowercased()
            guard vocabulary.contains(head), vocabulary.contains(next), head != next else { continue }
            followersByHead[head, default: []].append((next, count))
        }
    } catch {
        fail("cannot read bigrams file: \(error)")
    }
}
let bigrams = BigramModel()
var followerTotal = 0
for (head, list) in followersByHead {
    let kept = list.sorted { $0.count > $1.count }.prefix(options.followersPerHead)
    for entry in kept { bigrams.add(previous: head, next: entry.word, count: entry.count) }
    followerTotal += kept.count
}
for (head, nexts) in seedBigrams {
    let existing = bigrams.predict(after: head, limit: options.followersPerHead)
    let floor = existing.map(\.score).min() ?? 1
    for (index, next) in nexts.enumerated() where !existing.contains(where: { $0.word == next }) {
        bigrams.add(previous: head, next: next, count: floor * Double(nexts.count - index) / Double(nexts.count))
        followerTotal += 1
    }
}

// 3. Compile and write.
let data = DictionaryBuilder.build(lexicon: lexicon, bigrams: bigrams)
do {
    try data.write(to: URL(fileURLWithPath: outPath), options: .atomic)
} catch {
    fail("cannot write \(outPath): \(error)")
}
let nodeCount = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 8, as: UInt32.self) }
print("wrote \(outPath): \(lexicon.count) words, \(nodeCount) nodes, \(followersByHead.count + seedBigrams.count) bigram heads, \(followerTotal) followers, \(data.count) bytes")
