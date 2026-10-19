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
    /// Ring and bold the single most likely next letter.
    var highlightNextLetter = true
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
    /// A drag on the space bar, in characters — positive right, negative left.
    var onMoveCursor: (Int) -> Void = { _ in }
    /// Holding delete past the tap threshold, once per word crossed.
    var onDeleteWord: () -> Void = {}

    @State private var plane: KeyPlane
    /// When shift was last tapped, for the caps-lock double tap.
    @State private var lastShiftTap: Date?
    /// Set once a touch on the space bar has dragged far enough to mean
    /// "move the caret" rather than "type a space" — the stock keyboard's
    /// press-and-hold-to-drag trackpad.
    @State private var isSpaceTrackpadActive = false
    /// How much of the drag's (cumulative, from touch-down) translation has
    /// already been turned into caret steps, so the remainder — less than
    /// one character — carries over instead of being measured twice.
    @State private var spaceTrackpadConsumed: CGFloat = 0
    /// Ticks once the delete key has been held past the tap threshold,
    /// deleting one whole word per tick until the touch lifts.
    @State private var deleteHoldTimer: Timer?
    /// Set the first time that timer fires, so lifting the touch afterward
    /// doesn't also fire the single-character tap.
    @State private var didDeleteWordOnHold = false

    init(
        keyScales: [Character: KeyScale],
        topScale: Double,
        isStaticFallback: Bool,
        colorVision: ColorVisionMode = .standard,
        highlightNextLetter: Bool = true,
        traits: InputTraits = .standard,
        capsLockEnabled: Bool = true,
        returnEnabled: Bool = true,
        isShifted: Binding<Bool>,
        isCapsLocked: Binding<Bool>,
        onInsert: @escaping (String) -> Void,
        onDelete: @escaping () -> Void,
        onReturn: @escaping () -> Void,
        onMoveCursor: @escaping (Int) -> Void = { _ in },
        onDeleteWord: @escaping () -> Void = {}
    ) {
        self.keyScales = keyScales
        self.topScale = topScale
        self.isStaticFallback = isStaticFallback
        self.colorVision = colorVision
        self.highlightNextLetter = highlightNextLetter
        self.traits = traits
        self.capsLockEnabled = capsLockEnabled
        self.returnEnabled = returnEnabled
        _isShifted = isShifted
        _isCapsLocked = isCapsLocked
        self.onInsert = onInsert
        self.onDelete = onDelete
        self.onReturn = onReturn
        self.onMoveCursor = onMoveCursor
        self.onDeleteWord = onDeleteWord
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
        let isEmphasized = metrics.tier.isEmphasized && highlightNextLetter
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
                                lineWidth: isEmphasized ? 2 : 0)
                    )
                    .shadow(color: .black.opacity(palette.isDark ? 0.45 : 0.22), radius: 0, x: 0, y: 1)
                    .padding(.horizontal, keySpacing / 2)

                Text(label)
                    .font(
                        .system(
                            size: fontSize(for: metrics), weight: isEmphasized ? .bold : .medium)
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

            spaceKey

            deleteKey

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

    /// How far a drag has to travel, in points, before it counts as one
    /// caret step. Tuned against the stock keyboard's own trackpad feel —
    /// close enough to a key's width that it reads as deliberate.
    private let spaceTrackpadStep: CGFloat = 10
    /// How far a touch can wander before it stops being a tap. Below this,
    /// the lift still types a space.
    private let spaceTrackpadTapTolerance: CGFloat = 4

    /// Space bar. A tap types a space; press and drag turns it into a
    /// trackpad that moves the caret instead, the way holding the stock
    /// keyboard's space bar does — the label dims to say so.
    private var spaceKey: some View {
        Text(isSpaceTrackpadActive ? "" : "space")
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(palette.keyLabel)
            .frame(maxWidth: .infinity, minHeight: baseKeyHeight)
            .background(palette.keyFace.opacity(isSpaceTrackpadActive ? 0.6 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        let translation = value.translation.width
                        if !isSpaceTrackpadActive, abs(translation) > spaceTrackpadTapTolerance {
                            isSpaceTrackpadActive = true
                            spaceTrackpadConsumed = 0
                        }
                        guard isSpaceTrackpadActive else { return }
                        // `translation` is cumulative since touch-down, so
                        // steps are measured against what's already been
                        // spent rather than against the last callback.
                        let unconsumed = translation - spaceTrackpadConsumed
                        let steps = Int(unconsumed / spaceTrackpadStep)
                        guard steps != 0 else { return }
                        onMoveCursor(steps)
                        spaceTrackpadConsumed += CGFloat(steps) * spaceTrackpadStep
                    }
                    .onEnded { _ in
                        if !isSpaceTrackpadActive {
                            onInsert(" ")
                        }
                        isSpaceTrackpadActive = false
                        spaceTrackpadConsumed = 0
                    }
            )
            // Not a `Button` — a plain gesture recognizer is what lets a
            // drag keep tracking past the point a `Button` would cancel its
            // press — so the button trait is added by hand to keep
            // `app.buttons["Space"]` finding it in UI tests.
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Space")
            .accessibilityHint("Press and drag to move the cursor")
    }

    /// How long delete has to stay down before it starts clearing whole
    /// words, and the interval between words after that.
    private let deleteWordHoldInterval: TimeInterval = 0.45

    /// Delete key. A tap removes one character; holding past
    /// `deleteWordHoldInterval` starts clearing a whole word at a time,
    /// until the touch lifts.
    private var deleteKey: some View {
        Text("⌫")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(palette.keyLabel)
            .frame(width: 50, height: baseKeyHeight)
            .background(palette.keyUtility)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { _ in
                        guard deleteHoldTimer == nil else { return }
                        didDeleteWordOnHold = false
                        let timer = Timer(timeInterval: deleteWordHoldInterval, repeats: true) { _ in
                            didDeleteWordOnHold = true
                            onDeleteWord()
                        }
                        // `.common`, not the default mode, so the repeat
                        // keeps firing while the gesture is actively
                        // tracking this touch.
                        RunLoop.main.add(timer, forMode: .common)
                        deleteHoldTimer = timer
                    }
                    .onEnded { _ in
                        deleteHoldTimer?.invalidate()
                        deleteHoldTimer = nil
                        if !didDeleteWordOnHold {
                            onDelete()
                        }
                    }
            )
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Delete")
            .accessibilityHint("Hold to delete a word at a time")
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
