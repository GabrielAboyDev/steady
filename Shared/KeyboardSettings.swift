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

/// What the keyboard looks like.
///
/// The keyboard was light-only, which makes it a bright slab in a dark host
/// app. `system` follows whatever app the user is typing in; the other two pin
/// it for people who find one of the two easier to read regardless.
enum KeyboardAppearance: String, Codable, CaseIterable, Identifiable {
    /// Follow the host app — the stock keyboard's behaviour, and the default.
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "Match system"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var explanation: String {
        switch self {
        case .system: return "The keyboard follows the app you're typing in."
        case .light: return "Always the light keyboard, even in a dark app."
        case .dark: return "Always the dark keyboard, even in a light app."
        }
    }
}

/// Which colour vision the key tints are drawn for.
///
/// Steady puts information in colour: a key's tint says how likely its letter
/// is to come next. The shipped teal ramp is almost invisible to red-green
/// colour blindness — simulated, its adjacent tiers come out 1.7-2.2 ΔE00
/// apart, which is below the threshold for telling two large flat colours
/// apart at all. Each mode here re-tints the tiers in a hue that mode keeps,
/// and widens the ramp's lightness, which is the one channel every form of
/// colour blindness preserves.
enum ColorVisionMode: String, Codable, CaseIterable, Identifiable {
    /// The shipped teal ramp, unchanged.
    case standard
    /// Green-weak: the commonest form. Teal is the single worst hue for it.
    case deuteranopia
    /// Red-weak. Long wavelengths also look dimmer, so the ramp is spaced on
    /// lightness as well as hue.
    case protanopia
    /// Blue-yellow. Keeps blue-green, loses yellow — the opposite trade.
    case tritanopia
    /// No hue at all, for achromatopsia, low vision, and bright sunlight.
    case monochrome

    var id: String { rawValue }

    /// Short enough for five segments across a phone; `explanation` carries
    /// the full name, because these words are jargon to most people.
    var title: String {
        switch self {
        case .standard: return "Standard"
        case .deuteranopia: return "Deutan"
        case .protanopia: return "Protan"
        case .tritanopia: return "Tritan"
        case .monochrome: return "Mono"
        }
    }

    var explanation: String {
        switch self {
        case .standard:
            return "Normal colour vision. The likeliest letters are tinted teal."
        case .deuteranopia:
            return
                "Deuteranopia — green-weak, the commonest kind. An amber ramp, because teal is the one hue this vision can't see."
        case .protanopia:
            return "Protanopia — red-weak. A gold ramp, spaced on brightness as well as colour."
        case .tritanopia:
            return "Tritanopia — blue-yellow. An azure ramp, which this vision keeps."
        case .monochrome:
            return "No colour at all: the tints become a brightness ramp. Safe for any colour vision."
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
    /// Light, dark, or follow the app being typed into.
    var keyboardAppearance: KeyboardAppearance = .system
    /// Which colour vision the key tints are drawn for.
    var colorVision: ColorVisionMode = .standard

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
        resizeStrength =
            try container.decodeIfPresent(
                ResizeStrength.self, forKey: .resizeStrength) ?? fallback.resizeStrength
        hideImpossibleKeys =
            try container.decodeIfPresent(
                Bool.self, forKey: .hideImpossibleKeys) ?? fallback.hideImpossibleKeys
        enlargeLikelyKeys =
            try container.decodeIfPresent(
                Bool.self, forKey: .enlargeLikelyKeys) ?? fallback.enlargeLikelyKeys
        showSuggestionChips =
            try container.decodeIfPresent(
                Bool.self, forKey: .showSuggestionChips) ?? fallback.showSuggestionChips
        suggestionBrowsing =
            try container.decodeIfPresent(
                SuggestionBrowsing.self, forKey: .suggestionBrowsing) ?? fallback.suggestionBrowsing
        keyboardAppearance =
            try container.decodeIfPresent(
                KeyboardAppearance.self, forKey: .keyboardAppearance) ?? fallback.keyboardAppearance
        colorVision =
            try container.decodeIfPresent(
                ColorVisionMode.self, forKey: .colorVision) ?? fallback.colorVision
    }
}
