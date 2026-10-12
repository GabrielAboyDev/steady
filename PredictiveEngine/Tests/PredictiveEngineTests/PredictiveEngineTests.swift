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
        ("what", 18), ("where", 9), ("when", 14), ("who", 22)
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
    #expect(top == "the") // "the" at frequency 100 is the global maximum
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
    #expect(bestTHE >= bestTH * 0.9) // narrower context keeps targets large
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
