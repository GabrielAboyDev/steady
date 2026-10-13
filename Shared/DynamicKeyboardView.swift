import PredictiveEngine
import SwiftUI

/// Which set of keys is showing.
enum KeyPlane {
    case letters
    case numbers
    case symbols
}

/// The QWERTY keyboard that reshapes itself.
///
/// Keys keep their position and order at all times — they only grow, shrink,
/// or collapse to nothing in place. The row's footprint is fixed to the tallest
/// possible key and keys sit on the row's baseline, so a key the user is
/// reaching for never slides somewhere else (US-003).
struct DynamicKeyboardView: View {

    let keyScales: [Character: KeyScale]
    let topScale: Double
    /// True in secure fields: render a plain, uniform layout.
    let isStaticFallback: Bool
    /// Which colour vision to tint the tiers for. Defaulted, so a caller that
    /// doesn't care keeps the shipped teal.
    var colorVision: ColorVisionMode = .standard
    /// What the field asks of the layout: which plane to open on, extra keys
    /// by the space bar, and what the return key says.
    var traits: InputTraits = .standard
    /// Double-tapping shift locks it. Off, a double tap is two toggles.
    var capsLockEnabled = true
    /// Whether the return key can be tapped (a field can ask for it to stay
    /// dead while it is empty).
    var returnEnabled = true

    /// Owned by the surface: autocapitalization sets it after every key, and
    /// the shift key overrides it until the next letter.
    @Binding var isShifted: Bool
    @Binding var isCapsLocked: Bool

    let onInsert: (String) -> Void
    let onDelete: () -> Void
    let onReturn: () -> Void

    @State private var plane: KeyPlane
    /// When shift was last tapped, for the caps-lock double tap.
    @State private var lastShiftTap: Date?

    init(
        keyScales: [Character: KeyScale],
        topScale: Double,
        isStaticFallback: Bool,
        colorVision: ColorVisionMode = .standard,
        traits: InputTraits = .standard,
        capsLockEnabled: Bool = true,
        returnEnabled: Bool = true,
        isShifted: Binding<Bool>,
        isCapsLocked: Binding<Bool>,
        onInsert: @escaping (String) -> Void,
        onDelete: @escaping () -> Void,
        onReturn: @escaping () -> Void
    ) {
        self.keyScales = keyScales
        self.topScale = topScale
        self.isStaticFallback = isStaticFallback
        self.colorVision = colorVision
        self.traits = traits
        self.capsLockEnabled = capsLockEnabled
        self.returnEnabled = returnEnabled
        _isShifted = isShifted
        _isCapsLocked = isCapsLocked
        self.onInsert = onInsert
        self.onDelete = onDelete
        self.onReturn = onReturn
        // A number field opens on the digits, as the stock keyboard does.
        _plane = State(initialValue: traits.opensOnNumbers ? .numbers : .letters)
    }

    /// Set by `KeyboardSurface` from the appearance setting; light by default.
    @Environment(\.keyboardPalette) private var palette

    private let baseKeyHeight: CGFloat = 44
    /// How tall a likely key may grow. Each row reserves this much room above
    /// its baseline so growth never moves anything, and at rest that room is
    /// empty — it is the gap under the toolbar and between the rows. 1.5 left
    /// 22pt of it per row; 1.25 leaves 11.
    private let maxHeightFactor: CGFloat = 1.25
    private let keySpacing: CGFloat = 6

    private var rowHeight: CGFloat { baseKeyHeight * maxHeightFactor }

    private var rows: [[Character]] {
        switch plane {
        case .letters: return KeyLayout.qwertyRows
        case .numbers: return [Array("1234567890"), Array("-/:;()$&@\""), Array(".,?!'")]
        case .symbols: return [Array("[]{}#%^*+="), Array("_\\|~<>€£¥•"), Array(".,?!'")]
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, rowKeys in
                keyRow(rowKeys, isIndented: plane == .letters && index == 1)
            }
            bottomRow
        }
        .padding(.horizontal, 5)
        // No top padding: the top row's growth headroom already keeps the
        // keys off the toolbar.
        .padding(.bottom, 6)
        .background(palette.tray)
        // The field changed under us (the host moved focus): open on the
        // plane the new one asks for.
        .onChange(of: traits.opensOnNumbers) { opensOnNumbers in
            plane = opensOnNumbers ? .numbers : .letters
        }
    }

    // MARK: Letter rows

    private func keyRow(_ rowKeys: [Character], isIndented: Bool) -> some View {
        GeometryReader { geometry in
            let widths = layoutWidths(for: rowKeys, available: geometry.size.width)
            // No HStack spacing: each key owns its full slice of the row and
            // insets its own cap, so a collapsed key leaves no gap behind.
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(Array(rowKeys.enumerated()), id: \.offset) { index, key in
                    let metrics = self.metrics(for: key)
                    if metrics.isHidden {
                        // Removed from the row entirely: no width, and nothing
                        // left for a stray tap or VoiceOver to land on.
                        Color.clear.frame(width: 0, height: baseKeyHeight)
                    } else {
                        keyCap(for: key, metrics: metrics)
                            .frame(width: widths[index], height: baseKeyHeight * metrics.heightFactor)
                            .opacity(metrics.opacity)
                    }
                }
            }
            .frame(width: geometry.size.width, height: rowHeight, alignment: .bottom)
        }
        .frame(height: rowHeight)
        .padding(.horizontal, isIndented ? 16 : 0)
        .animation(.easeOut(duration: 0.18), value: animationToken)
    }

    /// Widths proportional to each key's scale, so likelier letters are wider.
    private func layoutWidths(for rowKeys: [Character], available: CGFloat) -> [CGFloat] {
        let scales = rowKeys.map { key -> CGFloat in
            CGFloat(max(0, metrics(for: key).widthWeight))
        }
        let total = scales.reduce(0, +)
        guard total > 0, available > 0 else {
            let equal = available / CGFloat(max(rowKeys.count, 1))
            return Array(repeating: equal, count: rowKeys.count)
        }
        return scales.map { available * ($0 / total) }
    }

    private struct KeyMetrics {
        let widthWeight: Double
        let heightFactor: CGFloat
        let tier: KeyTier
        let opacity: Double
        let isHidden: Bool
    }

    private func metrics(for key: Character) -> KeyMetrics {
        // Non-letter planes and secure fields don't reshape.
        guard plane == .letters, !isStaticFallback else {
            return KeyMetrics(widthWeight: 1, heightFactor: 1, tier: .unlikely, opacity: 1, isHidden: false)
        }

        let scale = keyScales[key]?.scale ?? 1.0
        let isPossible = keyScales[key]?.isPossible ?? true

        if scale <= 0 {
            return KeyMetrics(widthWeight: 0, heightFactor: 1, tier: .impossible, opacity: 0, isHidden: true)
        }

        let tier = KeyTier.forScale(scale, isPossible: isPossible, topScale: topScale)
        // Height grows more gently than width so rows stay calm.
        let heightFactor = min(max(1 + (CGFloat(scale) - 1) * 0.5, 0.7), maxHeightFactor)
        return KeyMetrics(
            widthWeight: scale,
            heightFactor: heightFactor,
            tier: tier,
            opacity: isPossible ? 1 : 0.34,
            isHidden: false
        )
    }

    /// Changes to this value drive the resize animation.
    private var animationToken: Double {
        keyScales.keys.sorted().reduce(0) { partial, key in
            partial + (keyScales[key]?.scale ?? 0)
        }
    }

    private func keyCap(for key: Character, metrics: KeyMetrics) -> some View {
        let label = isShifted && plane == .letters ? String(key).uppercased() : String(key)
        // The colour-vision palette picks the light tints; the appearance
        // palette (from the environment) decides whether they apply or the
        // dark ramp does. See `KeyboardPalette.face(for:vision:)`.
        let vision = colorVision.keyPalette
        return Button {
            onInsert(label)
            // One capital, then back down — unless locked. The surface then
            // re-reads autocapitalization for the next letter.
            if isShifted, !isCapsLocked { isShifted = false }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(palette.face(for: metrics.tier, vision: vision))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(
                                palette.ring(vision: vision),
                                lineWidth: metrics.tier.isEmphasized ? 2 : 0)
                    )
                    .shadow(color: .black.opacity(palette.isDark ? 0.45 : 0.22), radius: 0, x: 0, y: 1)
                    .padding(.horizontal, keySpacing / 2)

                Text(label)
                    .font(
                        .system(
                            size: fontSize(for: metrics), weight: metrics.tier.isEmphasized ? .bold : .medium)
                    )
                    .foregroundStyle(palette.label(for: metrics.tier, vision: vision))
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // The label follows shift; the identifier is the letter itself, so a
        // test (or anything else) can find "t" whether it reads "t" or "T".
        .accessibilityIdentifier(String(key))
        .accessibilityLabel(Text(label))
    }

    private func fontSize(for metrics: KeyMetrics) -> CGFloat {
        let base: CGFloat = 19
        return min(max(base * metrics.heightFactor, 11), 31)
    }

    // MARK: Bottom row

    private var bottomRow: some View {
        HStack(spacing: keySpacing) {
            utilityKey(planeToggleLabel, width: 46) {
                plane = plane == .letters ? .numbers : .letters
            }

            if plane == .letters {
                utilityKey(
                    shiftSymbol, width: 42, isActive: isShifted || isCapsLocked, isSymbol: true,
                    action: tapShift
                )
                .accessibilityLabel(isCapsLocked ? "Caps lock on" : isShifted ? "Shift on" : "Shift")
            } else {
                utilityKey(plane == .numbers ? "#+=" : "123", width: 46) {
                    plane = plane == .numbers ? .symbols : .numbers
                }
            }

            // An address field gets its certain characters as keys of their
            // own, the way the stock keyboard does, and the space bar gives
            // up the room.
            ForEach(traits.extraBottomKeys, id: \.self) { key in
                utilityKey(key, width: 36) { onInsert(key) }
            }

            Button {
                onInsert(" ")
            } label: {
                Text("space")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(palette.keyLabel)
                    .frame(maxWidth: .infinity, minHeight: baseKeyHeight)
                    .background(palette.keyFace)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Space")

            utilityKey("⌫", width: 50, action: onDelete)
                .accessibilityLabel("Delete")

            // The field's own return key: "search", "send", "go"… An action
            // key takes the accent, as the stock keyboard's does.
            utilityKey(
                traits.returnKeyLabel, width: 66, isActive: traits.returnKeyIsAction && returnEnabled,
                action: onReturn
            )
            .disabled(!returnEnabled)
            .opacity(returnEnabled ? 1 : 0.4)
            .accessibilityLabel(traits.returnKeyLabel.capitalized)
        }
        .frame(height: baseKeyHeight)
    }

    private var shiftSymbol: String {
        if isCapsLocked { return "capslock.fill" }
        return isShifted ? "shift.fill" : "shift"
    }

    /// One tap toggles; two quick taps lock, when the setting allows it; a
    /// tap while locked unlocks.
    private func tapShift() {
        let now = Date()
        defer { lastShiftTap = now }
        if isCapsLocked {
            isCapsLocked = false
            isShifted = false
            return
        }
        if capsLockEnabled, let last = lastShiftTap, now.timeIntervalSince(last) < 0.35 {
            isCapsLocked = true
            isShifted = true
            return
        }
        isShifted.toggle()
    }

    private var planeToggleLabel: String {
        plane == .letters ? "123" : "ABC"
    }

    /// `isSymbol` draws `label` as an SF Symbol instead of text.
    private func utilityKey(
        _ label: String,
        width: CGFloat,
        isActive: Bool = false,
        isSymbol: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Group {
                if isSymbol {
                    Image(systemName: label).font(.system(size: 17, weight: .medium))
                } else {
                    Text(label).font(.system(size: 14, weight: .semibold))
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(isActive ? .white : palette.keyLabel)
            .frame(width: width, height: baseKeyHeight)
            .background(isActive ? palette.accent : palette.keyUtility)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }
}
