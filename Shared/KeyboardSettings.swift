import Foundation

/// How hard the keyboard reshapes itself. Mirrors the three-way control in the
/// settings mock (Off / Medium / Aggressive).
enum ResizeStrength: String, Codable, CaseIterable, Identifiable {
    case off
    case medium
    case aggressive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: return "Off"
        case .medium: return "Medium"
        case .aggressive: return "Aggressive"
        }
    }

    var explanation: String {
        switch self {
        case .off: return "Every key stays the same size."
        case .medium: return "Unlikely letters shrink and fade, but stay reachable."
        case .aggressive: return "Letters that can't continue a word are removed."
        }
    }
}

/// How the user reaches the suggestions that don't fit on screen.
///
/// Three chips fit across a phone, but the engine can offer more than three
/// words. These are the two ways to get at the rest.
enum SuggestionBrowsing: String, Codable, CaseIterable, Identifiable {
    /// Swipe the row sideways; every suggestion is on one long strip.
    case scroll
    /// Arrows step a whole page of three at a time, so nothing has to be
    /// dragged — the point of the app is people who can't place a finger
    /// precisely, and a tap is easier to land than a swipe.
    case paginate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .scroll: return "Scroll"
        case .paginate: return "Arrows"
        }
    }

    var explanation: String {
        switch self {
        case .scroll: return "Swipe the row of words sideways to see more."
        case .paginate: return "Tap the arrows to step through three words at a time."
        }
    }
}

/// User-tunable keyboard behaviour, persisted to the app group.
struct KeyboardSettings: Codable, Equatable {

    var resizeStrength: ResizeStrength = .aggressive
    /// Remove impossible letters outright instead of shrinking them.
    var hideImpossibleKeys: Bool = true
    /// Grow the most probable next letters above neutral size.
    var enlargeLikelyKeys: Bool = true
    /// Show the three large word-completion chips above the keys.
    var showSuggestionChips: Bool = true
    /// How to reach the suggestions past the first three.
    var suggestionBrowsing: SuggestionBrowsing = .paginate

    static let `default` = KeyboardSettings()

    init() {}

    /// Every key is optional on the way in, falling back to the property's
    /// default.
    ///
    /// The synthesized decoder ignores those defaults and throws on a missing
    /// key, and `SharedStore` reads this as `decode(...) ?? .default` — so one
    /// key added in a later build would quietly reset every other setting the
    /// user had chosen. Adding a field must stay a safe thing to do.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = KeyboardSettings()
        resizeStrength = try container.decodeIfPresent(
            ResizeStrength.self, forKey: .resizeStrength) ?? fallback.resizeStrength
        hideImpossibleKeys = try container.decodeIfPresent(
            Bool.self, forKey: .hideImpossibleKeys) ?? fallback.hideImpossibleKeys
        enlargeLikelyKeys = try container.decodeIfPresent(
            Bool.self, forKey: .enlargeLikelyKeys) ?? fallback.enlargeLikelyKeys
        showSuggestionChips = try container.decodeIfPresent(
            Bool.self, forKey: .showSuggestionChips) ?? fallback.showSuggestionChips
        suggestionBrowsing = try container.decodeIfPresent(
            SuggestionBrowsing.self, forKey: .suggestionBrowsing) ?? fallback.suggestionBrowsing
    }
}
