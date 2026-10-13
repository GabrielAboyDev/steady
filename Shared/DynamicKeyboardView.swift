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
    /// Whether the host needs a keyboard-switch (globe) key.
    let showsNextKeyboardKey: Bool
    /// Which colour vision to tint the tiers for. Defaulted, so a caller that
    /// doesn't care keeps the shipped teal.
    var colorVision: ColorVisionMode = .standard

    let onInsert: (String) -> Void
    let onDelete: () -> Void
    let onReturn: () -> Void
    var onNextKeyboard: () -> Void = {}

    @State private var plane: KeyPlane = .letters
    @State private var isShifted = false

    private let baseKeyHeight: CGFloat = 44
    private let maxHeightFactor: CGFloat = 1.5
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
        VStack(spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, rowKeys in
                keyRow(rowKeys, isIndented: plane == .letters && index == 1)
            }
            bottomRow
        }
        .padding(.horizontal, 5)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .background(Theme.keyTray)
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
        let palette = colorVision.keyPalette
        return Button {
            onInsert(label)
            if isShifted { isShifted = false }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(palette.face(metrics.tier))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(palette.ring, lineWidth: metrics.tier.isEmphasized ? 2 : 0)
                    )
                    .shadow(color: .black.opacity(0.22), radius: 0, x: 0, y: 1)
                    .padding(.horizontal, keySpacing / 2)

                Text(label)
                    .font(
                        .system(
                            size: fontSize(for: metrics), weight: metrics.tier.isEmphasized ? .bold : .medium)
                    )
                    .foregroundStyle(palette.label(metrics.tier))
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
                utilityKey(isShifted ? "⇧" : "⇧", width: 42, isActive: isShifted) {
                    isShifted.toggle()
                }
            } else {
                utilityKey(plane == .numbers ? "#+=" : "123", width: 46) {
                    plane = plane == .numbers ? .symbols : .numbers
                }
            }

            if showsNextKeyboardKey {
                utilityKey("🌐", width: 42) { onNextKeyboard() }
            }

            Button {
                onInsert(" ")
            } label: {
                Text("space")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: baseKeyHeight)
                    .background(Theme.keyFace)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Space")

            utilityKey("⌫", width: 50, action: onDelete)
                .accessibilityLabel("Delete")

            utilityKey("return", width: 66, action: onReturn)
        }
        .frame(height: baseKeyHeight)
    }

    private var planeToggleLabel: String {
        plane == .letters ? "123" : "ABC"
    }

    private func utilityKey(
        _ label: String,
        width: CGFloat,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isActive ? .white : Theme.textPrimary)
                .frame(width: width, height: baseKeyHeight)
                .background(isActive ? Theme.brand : Theme.keyUtility)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }
}
