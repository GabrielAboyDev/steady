import Foundation
import Testing

@testable import PredictiveEngine

// A small deterministic lexicon so assertions don't depend on the bundled file.
private func makeEngine() -> PredictiveEngine {
    let lexicon: [(word: String, frequency: Double)] = [
        ("the", 100), ("that", 80), ("this", 60), ("they", 40), ("there", 30),
        ("then", 20), ("thing", 10), ("think", 8),
        ("to", 90), ("time", 15),
        ("and", 85), ("an", 25), ("any", 12),
        ("a", 95),
        ("what", 18), ("where", 9), ("when", 14), ("who", 22),
    ]
    return PredictiveEngine(lexicon: lexicon)
}

@Test func completionsRankByFrequency() {
    let engine = makeEngine()
    let words = engine.completions(forPrefix: "th", limit: 3).map(\.word)
    #expect(words == ["the", "that", "this"])
}

@Test func emptyPrefixReturnsMostFrequentGlobally() {
    let engine = makeEngine()
    let top = engine.completions(forPrefix: "", limit: 1).first?.word
    #expect(top == "the")  // "the" at frequency 100 is the global maximum
}

@Test func unknownPrefixReturnsNothing() {
    let engine = makeEngine()
    #expect(engine.completions(forPrefix: "zzz").isEmpty)
    #expect(engine.nextLetterWeights(forPrefix: "zzz").isEmpty)
}

@Test func nextLetterWeightsFavorLikelyContinuations() {
    let engine = makeEngine()
    let weights = engine.nextLetterWeights(forPrefix: "th")
    // After "th": 'e' (the/there/then...) should outweigh 'i' (thing/think).
    #expect((weights["e"] ?? 0) > (weights["i"] ?? 0))
    // 'x' can't follow "th" in this lexicon.
    #expect(weights["x"] == nil)
}

@Test func impossibleKeysAreHiddenUnderMotorConfig() {
    let engine = makeEngine()
    let scales = engine.keyScales(forPrefix: "th", config: .motorAccessibility)
    // 'z' can't follow "th" -> hidden.
    #expect(scales["z"]?.isPossible == false)
    #expect(scales["z"]?.scale == 0.0)
    // 'e' is the most likely continuation -> enlarged above neutral.
    #expect((scales["e"]?.scale ?? 0) > 1.0)
    #expect(scales["e"]?.isPossible == true)
}

@Test func keysGrowAsPrefixNarrowsOptions() {
    let engine = makeEngine()
    // "the" -> only "there"/"then"/... continue; the winning next key should be
    // at least as enlarged as the best key one step earlier at "th".
    let atTH = engine.keyScales(forPrefix: "th")
    let atTHE = engine.keyScales(forPrefix: "the")
    let bestTH = atTH.values.filter(\.isPossible).map(\.scale).max() ?? 0
    let bestTHE = atTHE.values.filter(\.isPossible).map(\.scale).max() ?? 0
    #expect(bestTHE >= bestTH * 0.9)  // narrower context keeps targets large
}

@Test func generalConfigKeepsAllKeysVisible() {
    let engine = makeEngine()
    let scales = engine.keyScales(forPrefix: "th", config: .general)
    // Impossible keys shrink but are not hidden under the general profile.
    #expect(scales["z"]?.scale ?? 0 > 0)
}

@Test func bundledLexiconLoadsAndPredicts() throws {
    let engine = try PredictiveEngine.loadBundled()
    let words = engine.completions(forPrefix: "th", limit: 5).map(\.word)
    #expect(words.contains("the"))
    #expect(!words.isEmpty)
}

@Test func nextWordPredictionUsesBigrams() throws {
    let engine = try PredictiveEngine.loadBundled()
    let next = engine.predictNextWord(after: "thank", limit: 1).first?.word
    #expect(next == "you")
}

// MARK: - Compiled dictionary format

private let fixture: [(word: String, frequency: Double)] = [
    ("the", 100), ("that", 80), ("this", 60), ("they", 40), ("there", 30),
    ("then", 20), ("thing", 10), ("think", 8),
    ("to", 90), ("time", 15),
    ("and", 85), ("an", 25), ("any", 12),
    ("a", 95),
    ("what", 18), ("where", 9), ("when", 14), ("who", 22),
]

/// Brute-force top-k over the fixture, the answer the best-first search must match.
private func bruteForce(prefix: String, limit: Int) -> [String] {
    fixture.filter { $0.word.hasPrefix(prefix) }
        .sorted { $0.frequency > $1.frequency }
        .prefix(limit).map(\.word)
}

@Test func compiledBytesRoundTripThroughTheReader() throws {
    let bigrams = BigramModel()
    bigrams.add(previous: "thank", next: "you", count: 5)
    bigrams.add(previous: "thank", next: "god", count: 2)
    let data = DictionaryBuilder.build(lexicon: fixture, bigrams: bigrams)
    let engine = try PredictiveEngine(data: data)

    #expect(engine.completions(forPrefix: "th", limit: 3).map(\.word) == ["the", "that", "this"])
    #expect(engine.completions(forPrefix: "", limit: 1).first?.word == "the")
    #expect(engine.completions(forPrefix: "", limit: 1).first?.score == 1.0)  // normalized to the top word
    #expect(engine.nextLetterWeights(forPrefix: "zzz").isEmpty)
    #expect(engine.predictNextWord(after: "thank", limit: 2).map(\.word) == ["you", "god"])
    #expect(engine.predictNextWord(after: "Thank", limit: 2).map(\.word) == ["you", "god"])
    #expect(engine.predictNextWord(after: "nope").isEmpty)
}

@Test func bestFirstSearchMatchesBruteForce() {
    let engine = PredictiveEngine(lexicon: fixture)
    for prefix in ["", "t", "th", "the", "a", "w", "an"] {
        for limit in [1, 2, 3, 5, 50] {
            let got = engine.completions(forPrefix: prefix, limit: limit).map(\.word)
            #expect(got == bruteForce(prefix: prefix, limit: limit), "prefix \(prefix) limit \(limit)")
        }
    }
    #expect(engine.completions(forPrefix: "th", limit: 0).isEmpty)
}

@Test func apostrophesAndNonASCIIWordsResolve() {
    let engine = PredictiveEngine(lexicon: [("i'm", 10), ("i", 50), ("café", 3), ("cafe", 4), ("naïve", 1)])
    #expect(engine.completions(forPrefix: "i'", limit: 1).first?.word == "i'm")
    #expect(engine.completions(forPrefix: "caf", limit: 2).map(\.word) == ["cafe", "café"])
    #expect(engine.completions(forPrefix: "café", limit: 1).first?.word == "café")
    #expect(engine.completions(forPrefix: "CAFÉ", limit: 1).first?.word == "café")
    // After "caf": 'e' is a real key; the UTF-8 lead byte of "é" is not a key and is skipped.
    let weights = engine.nextLetterWeights(forPrefix: "caf")
    #expect(weights.keys.sorted() == ["e"])
    #expect(engine.nextLetterWeights(forPrefix: "na").isEmpty)
}

@Test func duplicateWordsAccumulateFrequency() {
    let engine = PredictiveEngine(lexicon: [("cat", 1), ("car", 3), ("Cat", 3)])
    #expect(engine.completions(forPrefix: "ca", limit: 2).map(\.word) == ["cat", "car"])
}

@Test func corruptDataIsRejected() {
    let data = DictionaryBuilder.build(lexicon: fixture)
    #expect(throws: MappedDictionary.LoadError.truncated) { try PredictiveEngine(data: Data()) }
    #expect(throws: MappedDictionary.LoadError.truncated) { try PredictiveEngine(data: data.prefix(100)) }
    var badMagic = data
    badMagic[0] = 0
    #expect(throws: MappedDictionary.LoadError.badMagic) { try PredictiveEngine(data: badMagic) }
    var badVersion = data
    badVersion[4] = 99
    #expect(throws: MappedDictionary.LoadError.unsupportedVersion(99)) { try PredictiveEngine(data: badVersion) }
}

@Test func bundledDictionaryHasRealVocabulary() throws {
    let engine = try PredictiveEngine.loadBundled()
    #expect(engine.completions(forPrefix: "", limit: 3).map(\.word).contains("you"))
    #expect(engine.completions(forPrefix: "keyb", limit: 5).map(\.word).contains("keyboard"))
    // The UI test relies on q and z being impossible after "th".
    let afterTH = engine.keyScales(forPrefix: "th", config: .motorAccessibility)
    #expect(afterTH["q"]?.isPossible == false)
    #expect(afterTH["z"]?.isPossible == false)
    #expect(afterTH["e"]?.isPossible == true)
    // A head that is not in the hand-picked seed table comes from the corpus.
    #expect(!engine.predictNextWord(after: "good", limit: 3).isEmpty)
}

@Test func bundledQueriesAreFast() throws {
    let engine = try PredictiveEngine.loadBundled()
    _ = engine.completions(forPrefix: "", limit: 3)  // warm the pages
    let clock = ContinuousClock()
    let elapsed = clock.measure {
        for _ in 0..<100 {
            _ = engine.completions(forPrefix: "", limit: 3)
            _ = engine.completions(forPrefix: "t", limit: 3)
            _ = engine.keyScales(forPrefix: "th")
        }
    }
    // 300 queries; generous ceiling so the test is a tripwire, not a benchmark.
    #expect(elapsed < .milliseconds(500), "\(elapsed)")
}
