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

    var isEmphasized: Bool { self == .mostLikely }
}

/// One colour-vision mode's key tints: a face and a label per tier, plus the
/// ring drawn round the emphasised key.
///
/// Passed to the views as a value rather than read from a global, so SwiftUI
/// still sees a change of mode as a change of input and redraws the keys.
///
/// Every palette was checked by simulating it through the Machado (2009)
/// colour-blindness matrices — cross-checked against Viénot (1999) — and
/// measuring CIEDE2000 between tiers that sit next to each other. The shared
/// shape of all five: the three tinted tiers climb a ~6-7 L* lightness ramp
/// (lightness is the one channel every form of colour blindness keeps),
/// `unlikely` stays plain white, and `impossible` is a neutral grey that the
/// 0.34 opacity the view already applies composites down into the key tray —
/// so "letters that can't follow get out of the way" survives every mode as a
/// lightness difference, never a hue one. Hue is the second, reinforcing cue,
/// and is chosen per mode as the hue that mode retains.
struct KeyPalette {

    let mostLikelyFace: Color
    let likelyFace: Color
    let possibleFace: Color
    let unlikelyFace: Color
    let impossibleFace: Color

    let mostLikelyLabel: Color
    let plainLabel: Color
    let impossibleLabel: Color

    /// The ring round the emphasised key. It reads as a ring in every mode
    /// because it contrasts with the face in lightness, not in hue.
    let ring: Color

    func face(_ tier: KeyTier) -> Color {
        switch tier {
        case .mostLikely: return mostLikelyFace
        case .likely: return likelyFace
        case .possible: return possibleFace
        case .unlikely: return unlikelyFace
        case .impossible: return impossibleFace
        }
    }

    func label(_ tier: KeyTier) -> Color {
        switch tier {
        case .mostLikely: return mostLikelyLabel
        case .impossible: return impossibleLabel
        default: return plainLabel
        }
    }
}

extension KeyPalette {

    /// Teal, as shipped — the brand tokens themselves, not copies of them, so
    /// a change to the palette file still reaches the default mode. Adjacent
    /// tiers are 4.2 ΔE00 apart in normal vision.
    static let standard = KeyPalette(
        mostLikelyFace: Color(hex: 0xC9E7E3),
        likelyFace: Color(hex: 0xDCEDEB),
        possibleFace: Color(hex: 0xEDF5F4),
        unlikelyFace: Theme.keyFace,
        impossibleFace: Color(hex: 0xECEEF1),
        mostLikelyLabel: Theme.brandDark,
        plainLabel: Theme.textPrimary,
        impossibleLabel: Theme.textMuted,
        ring: Theme.brand)

    /// Amber (LCh hue 85). Deuteranopia's best-surviving hue; the shipped
    /// teal is its worst. Adjacent tiers 7.7 ΔE00 apart, simulated, up from
    /// 2.2 — and it holds up under protanopia too (7.6).
    static let deuteranopia = KeyPalette(
        mostLikelyFace: Color(hex: 0xE8C57E),
        likelyFace: Color(hex: 0xF0DAB5),
        possibleFace: Color(hex: 0xF6EDDF),
        unlikelyFace: Theme.keyFace,
        impossibleFace: Color(hex: 0xD9DDE2),
        mostLikelyLabel: Color(hex: 0x514019),
        plainLabel: Theme.textPrimary,
        impossibleLabel: Theme.textSecondary,
        ring: Theme.brand)

    /// Gold (LCh hue 95), pushed away from red because protanopia sees long
    /// wavelengths dimmer. Adjacent tiers 8.0 ΔE00 apart, up from 1.7.
    static let protanopia = KeyPalette(
        mostLikelyFace: Color(hex: 0xDCC982),
        likelyFace: Color(hex: 0xE9DCB7),
        possibleFace: Color(hex: 0xF3EEDE),
        unlikelyFace: Theme.keyFace,
        impossibleFace: Color(hex: 0xD9DDE2),
        mostLikelyLabel: Color(hex: 0x4B4219),
        plainLabel: Theme.textPrimary,
        impossibleLabel: Theme.textSecondary,
        ring: Theme.brand)

    /// Azure (LCh hue 210). Tritanopia keeps blue-green, so this stays in the
    /// brand's family — only stronger and spread wider. 9.1 ΔE00, up from 4.9.
    static let tritanopia = KeyPalette(
        mostLikelyFace: Color(hex: 0x62DAE8),
        likelyFace: Color(hex: 0xB0E6ED),
        possibleFace: Color(hex: 0xDEF2F4),
        unlikelyFace: Theme.keyFace,
        impossibleFace: Color(hex: 0xD9DDE2),
        mostLikelyLabel: Color(hex: 0x004C55),
        plainLabel: Theme.textPrimary,
        impossibleLabel: Theme.textSecondary,
        ring: Theme.brand)

    /// Lightness only, so it reads identically to every colour vision: 11.7
    /// ΔE00 between adjacent tiers under all four simulations. The emphasised
    /// key inverts to a white label on dark grey, which no hue loss can take
    /// away; its ring turns white for the same reason.
    static let monochrome = KeyPalette(
        mostLikelyFace: Color(hex: 0x636363),
        likelyFace: Color(hex: 0x989898),
        possibleFace: Color(hex: 0xC1C1C1),
        unlikelyFace: Theme.keyFace,
        impossibleFace: Color(hex: 0xF7F7F7),
        mostLikelyLabel: .white,
        plainLabel: Theme.textPrimary,
        impossibleLabel: Theme.textSecondary,
        ring: .white)
}

extension ColorVisionMode {
    var keyPalette: KeyPalette {
        switch self {
        case .standard: return .standard
        case .deuteranopia: return .deuteranopia
        case .protanopia: return .protanopia
        case .tritanopia: return .tritanopia
        case .monochrome: return .monochrome
        }
    }
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
