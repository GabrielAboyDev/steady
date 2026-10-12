import Foundation

/// Turns per-letter likelihood into per-key display scales.
public enum KeyLayout {

    /// The standard QWERTY letter rows.
    public static let qwertyRows: [[Character]] = [
        Array("qwertyuiop"),
        Array("asdfghjkl"),
        Array("zxcvbnm")
    ]

    public static let allLetters: [Character] = Array("abcdefghijklmnopqrstuvwxyz")

    /// Compute a scale for every key in `keys`, given raw next-letter weights.
    ///
    /// - Parameters:
    ///   - weights: raw (unnormalized) weight per possible next letter. A letter
    ///     absent from this map, or present with weight 0, is treated as impossible.
    ///   - keys: the keys currently on the keyboard.
    ///   - config: how aggressively to reshape.
    /// - Returns: a scale per key, keyed by the character.
    public static func keyScales(
        weights: [Character: Double],
        keys: [Character] = allLetters,
        config: KeyResizeConfig = .motorAccessibility
    ) -> [Character: KeyScale] {

        // Highest weight among keys actually on the keyboard.
        let maxWeight = keys.compactMap { weights[$0] }.max() ?? 0

        // No prediction signal (e.g. empty/unknown prefix): leave everything uniform.
        guard maxWeight > 0 else {
            return Dictionary(uniqueKeysWithValues: keys.map {
                ($0, KeyScale(key: $0, scale: 1.0, isPossible: true))
            })
        }

        var result: [Character: KeyScale] = [:]
        for key in keys {
            let weight = weights[key] ?? 0

            if weight <= 0 {
                let scale = config.hideImpossibleKeys ? 0.0 : config.minScale
                result[key] = KeyScale(key: key, scale: scale, isPossible: false)
                continue
            }

            // Normalize this key's weight into 0...1 across the possible keys,
            // then map onto [minScale, maxScale]. Using sqrt spreads the low end
            // so moderately-likely keys stay comfortably tappable.
            let normalized = (weight / maxWeight).squareRoot()
            let target = config.minScale + normalized * (config.maxScale - config.minScale)

            // Blend toward a neutral 1.0 by aggressiveness (0 = uniform, 1 = full range).
            let scale = (1 - config.aggressiveness) * 1.0 + config.aggressiveness * target
            result[key] = KeyScale(key: key, scale: scale, isPossible: true)
        }
        return result
    }
}
