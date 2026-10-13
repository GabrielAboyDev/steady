import SwiftUI

/// Brand tokens, mirroring `branding/palette.css` in the BuildBoard workspace.
/// Chrome carries the brand; the key tray keeps iOS's familiar shape and
/// greys, with brand-tinted emphasis for the likelihood tiers.
enum Theme {

    // Brand
    static let brand = Color(hex: 0x1C6E68)
    static let brandDark = Color(hex: 0x124A46)
    static let brandSoft = Color(hex: 0xD9EEEB)

    // Semantic
    static let positive = Color(hex: 0x3F7D4A)
    static let info = Color(hex: 0x2F6FA3)
    static let caution = Color(hex: 0xB2791F)
    static let negative = Color(hex: 0xA83F3F)

    // Surface
    static let surfaceBase = Color(hex: 0xF6F8F7)
    static let surfaceRaised = Color.white
    static let surfaceDraft = Color(hex: 0xEEF4F2)
    /// The well a segmented control sits in — a step darker than the bar
    /// behind it, so the unselected segments read as recessed.
    static let segmentTrack = Color(hex: 0xE7ECEA)

    // Text
    static let textPrimary = Color(hex: 0x15201D)
    static let textSecondary = Color(hex: 0x4B5B57)
    static let textMuted = Color(hex: 0x7C8C87)

    // Rules
    static let ruleStrong = Color(hex: 0xC7D5D1)
    static let ruleHairline = Color(hex: 0xE2EAE7)

    // Keyboard tray — iOS-native form per the PRD's design considerations.
    static let keyTray = Color(hex: 0xD1D4DB)
    static let keyFace = Color.white
    static let keyUtility = Color(hex: 0xADB3BD)

    static let cardRadius: CGFloat = 14
}

/// Tint and emphasis for a key, by how likely its letter is to come next.
enum KeyTier {
    case mostLikely
    case likely
    case possible
    case unlikely
    case impossible

    /// Classify from the engine's computed scale relative to the neutral 1.0.
    static func forScale(_ scale: Double, isPossible: Bool, topScale: Double) -> KeyTier {
        guard isPossible else { return .impossible }
        if scale >= topScale - 0.001, scale > 1.05 { return .mostLikely }
        if scale > 1.2 { return .likely }
        if scale >= 0.95 { return .possible }
        return .unlikely
    }

    var face: Color {
        switch self {
        case .mostLikely: return Color(hex: 0xC9E7E3)
        case .likely: return Color(hex: 0xDCEDEB)
        case .possible: return Color(hex: 0xEDF5F4)
        case .unlikely: return Theme.keyFace
        case .impossible: return Color(hex: 0xECEEF1)
        }
    }

    var label: Color {
        switch self {
        case .mostLikely: return Theme.brandDark
        case .impossible: return Theme.textMuted
        default: return Theme.textPrimary
        }
    }

    var isEmphasized: Bool { self == .mostLikely }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
