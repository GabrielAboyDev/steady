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

// MARK: - Appearance

/// The keyboard surface's colours for one appearance.
///
/// Additive on purpose: the `Theme` tokens above are the light values and stay
/// exactly as they were, so everything that doesn't go through a palette — the
/// container app, the Names and Phrases panels — is unaffected. Only the keys,
/// the suggestion row and the panel toolbar read these.
struct KeyboardPalette {

    /// The slab behind the keys.
    let tray: Color
    /// A letter key at neutral likelihood.
    let keyFace: Color
    /// Shift / numbers / delete / return.
    let keyUtility: Color
    /// A key or chip label.
    let keyLabel: Color
    /// A label that should recede (impossible keys, "no suggestions").
    let keyLabelMuted: Color
    /// The bar the panel toolbar sits on, and the well inside it.
    let toolbarBar: Color
    let segmentTrack: Color
    /// An unselected toolbar segment's label.
    let segmentLabel: Color
    /// Fill for the selected segment and the top suggestion chip.
    let accent: Color
    /// The 2pt ring around the single most likely key.
    let accentStroke: Color
    /// The free-text draft bar above the keys.
    let draftBar: Color
    let isDark: Bool

    /// Unchanged from what shipped: the existing `Theme` tokens.
    static let light = KeyboardPalette(
        tray: Theme.keyTray,
        keyFace: Theme.keyFace,
        keyUtility: Theme.keyUtility,
        keyLabel: Theme.textPrimary,
        keyLabelMuted: Theme.textMuted,
        toolbarBar: Theme.surfaceBase,
        segmentTrack: Theme.segmentTrack,
        segmentLabel: Theme.textSecondary,
        accent: Theme.brand,
        accentStroke: Theme.brand,
        draftBar: Theme.surfaceRaised,
        isDark: false
    )

    /// Measured off a stock iOS dark keyboard at 3x, so the keyboard sits in a
    /// dark host app the way the system one does rather than as a bright slab.
    static let dark = KeyboardPalette(
        tray: Color(hex: 0x19191B),
        keyFace: Color(hex: 0x3E3E3E),
        keyUtility: Color(hex: 0x2A2A2C),
        keyLabel: .white,
        keyLabelMuted: Color(hex: 0x8A8A8E),
        toolbarBar: Color(hex: 0x1F1F22),
        segmentTrack: Color(hex: 0x2E2E31),
        segmentLabel: Color(hex: 0xB4B9BD),
        accent: Theme.brand,
        // The brand is too close to the most-likely key's own teal to read as a
        // ring on it, so dark gets a lighter one.
        accentStroke: Color(hex: 0x6FBFB6),
        draftBar: Color(hex: 0x2A2A2C),
        isDark: true
    )
}

extension KeyboardPalette {

    /// Light keeps the established tints on `KeyTier`; dark needs its own ramp
    /// because those run from #C9E7E3 down to white, which all read as "bright"
    /// on a near-black tray and so lose the ordering entirely.
    ///
    /// The dark ramp carries the same two signals as the light one — more teal,
    /// and further from the neutral key face — but upwards in luminance rather
    /// than downwards. Relative luminance runs 0.21 / 0.12 / 0.08 / 0.05 / 0.03
    /// from most likely to impossible, so the order survives even for someone
    /// who can't separate the teal from the grey.
    func face(for tier: KeyTier) -> Color {
        guard isDark else { return tier.face }
        switch tier {
        case .mostLikely: return Color(hex: 0x3C8C84)
        case .likely: return Color(hex: 0x2F6B66)
        case .possible: return Color(hex: 0x41514F)
        case .unlikely: return keyFace
        case .impossible: return Color(hex: 0x2F2F31)
        }
    }

    func label(for tier: KeyTier) -> Color {
        guard isDark else { return tier.label }
        switch tier {
        case .impossible: return keyLabelMuted
        default: return keyLabel
        }
    }
}

extension KeyboardAppearance {
    /// `colorScheme` is the environment's — in the extension, that is the host
    /// app's appearance, which is what `system` is meant to follow.
    func palette(for colorScheme: ColorScheme) -> KeyboardPalette {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return colorScheme == .dark ? .dark : .light
        }
    }
}

private struct KeyboardPaletteKey: EnvironmentKey {
    /// Light, so anything outside the keyboard surface — the settings preview
    /// row, SwiftUI previews — keeps the colours it already had.
    static let defaultValue = KeyboardPalette.light
}

extension EnvironmentValues {
    var keyboardPalette: KeyboardPalette {
        get { self[KeyboardPaletteKey.self] }
        set { self[KeyboardPaletteKey.self] = newValue }
    }
}
