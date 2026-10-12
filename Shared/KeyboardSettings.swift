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

/// User-tunable keyboard behaviour, persisted to the app group.
struct KeyboardSettings: Codable, Equatable {

    var resizeStrength: ResizeStrength = .aggressive
    /// Remove impossible letters outright instead of shrinking them.
    var hideImpossibleKeys: Bool = true
    /// Grow the most probable next letters above neutral size.
    var enlargeLikelyKeys: Bool = true
    /// Show the three large word-completion chips above the keys.
    var showSuggestionChips: Bool = true

    static let `default` = KeyboardSettings()
}
