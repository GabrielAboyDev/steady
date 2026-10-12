import Foundation

/// A candidate word paired with a relative score (higher = more likely).
public struct WordScore: Equatable, Sendable {
    public let word: String
    public let score: Double

    public init(word: String, score: Double) {
        self.word = word
        self.score = score
    }
}

/// The computed display scale for a single key.
public struct KeyScale: Equatable, Sendable {
    public let key: Character
    /// Multiplier applied to the key's base size. 0 means "hide this key".
    public let scale: Double
    /// Whether any real word can follow the current prefix through this key.
    public let isPossible: Bool

    public init(key: Character, scale: Double, isPossible: Bool) {
        self.key = key
        self.scale = scale
        self.isPossible = isPossible
    }
}

/// Tunables for how aggressively the keyboard reshapes itself.
///
/// Defaults are tuned for motor accessibility: large size range, impossible
/// keys removed entirely so they can't be mis-hit.
public struct KeyResizeConfig: Sendable {
    /// 0 = uniform keys (no resizing). 1 = full size range applied.
    public var aggressiveness: Double
    /// If true, keys that can't lead to a real word get scale 0 (hidden).
    /// If false, they shrink to `minScale` instead.
    public var hideImpossibleKeys: Bool
    /// Smallest multiplier for a possible-but-unlikely key.
    public var minScale: Double
    /// Largest multiplier for the single most likely key.
    public var maxScale: Double

    public init(
        aggressiveness: Double = 0.85,
        hideImpossibleKeys: Bool = true,
        minScale: Double = 0.55,
        maxScale: Double = 1.9
    ) {
        self.aggressiveness = aggressiveness
        self.hideImpossibleKeys = hideImpossibleKeys
        self.minScale = minScale
        self.maxScale = maxScale
    }

    public static let motorAccessibility = KeyResizeConfig()
    public static let general = KeyResizeConfig(
        aggressiveness: 0.4, hideImpossibleKeys: false, minScale: 0.8, maxScale: 1.35
    )
}
