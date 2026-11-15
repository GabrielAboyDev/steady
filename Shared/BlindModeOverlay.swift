import SwiftUI
import UIKit

/// Identity of everything the exploring finger can land on in blind mode:
/// every key on the keyboard, and the items around it.
enum KeyID: Hashable {
    case character(Character)
    case space
    case delete
    case returnKey
    case shift
    /// "123" / "ABC".
    case planeToggle
    /// "#+=" / "123" on the non-letter planes.
    case secondaryPlaneToggle
    case extra(String)
    case submit
    /// Anything that is not a key — a suggestion, a saved phrase, a name
    /// tile, a toolbar segment. Named and acted on by the view that reports
    /// it, so the string only has to be unique on the surface.
    case item(String)
}

/// What a key's spoken name depends on.
struct SpokenNameContext {
    var plane: KeyPlane
    var isShifted: Bool
    var isCapsLocked: Bool
    var returnLabel: String
}

extension KeyID {

    func spokenName(in context: SpokenNameContext) -> String {
        switch self {
        case .character(let character):
            if let name = Self.punctuationNames[character] { return name }
            guard character.isLetter else { return String(character) }
            // Spoken lowercase: the system voices read a lone uppercase
            // letter as "capital A" of their own accord, so an uppercase
            // key name would hear "capital" whether or not shift was down.
            // `KeySpeaker` pins the one ambiguous letter, "a", to its name
            // so it is not read as the article.
            let letter = String(character).lowercased()
            let isCapital = context.plane == .letters && (context.isShifted || context.isCapsLocked)
            return isCapital ? "capital \(letter)" : letter
        case .space: return "space"
        case .delete: return "delete"
        case .returnKey: return context.returnLabel
        case .shift:
            if context.isCapsLocked { return "caps lock on" }
            return context.isShifted ? "shift on" : "shift"
        case .planeToggle: return context.plane == .letters ? "numbers" : "letters"
        case .secondaryPlaneToggle: return context.plane == .numbers ? "symbols" : "numbers"
        case .extra(let text):
            if text.count == 1, let first = text.first, let name = Self.punctuationNames[first] {
                return name
            }
            return text
        case .submit: return "submit"
        // Items name themselves when they report their frame; see `BlindTarget`.
        case .item: return ""
        }
    }

    static let punctuationNames: [Character: String] = [
        ".": "period", ",": "comma", "?": "question mark", "!": "exclamation mark",
        "'": "apostrophe", "\"": "quote", "-": "dash", "/": "slash", ":": "colon",
        ";": "semicolon", "(": "left parenthesis", ")": "right parenthesis", "$": "dollar",
        "&": "ampersand", "@": "at", "#": "hash", "%": "percent", "^": "caret",
        "*": "asterisk", "+": "plus", "=": "equals", "[": "left bracket", "]": "right bracket",
        "{": "left brace", "}": "right brace", "_": "underscore", "\\": "backslash", "|": "bar",
        "~": "tilde", "<": "less than", ">": "greater than", "€": "euro", "£": "pound",
        "¥": "yen", "•": "bullet",
    ]
}

/// One thing the exploring finger can select: where it is, what it is
/// called, and what submitting it does.
struct BlindTarget {
    let anchor: Anchor<CGRect>
    /// Read aloud when the finger arrives on it.
    let spokenName: String
    /// Does what a tap would, and returns what to say about it — the letter
    /// typed, the word inserted, the blank now being asked — or `nil` for
    /// nothing.
    let action: () -> String?
}

/// Every target on the surface, collected up the tree as anchors so the
/// overlay can resolve them in its own coordinate space.
struct BlindTargetsPreferenceKey: PreferenceKey {
    static var defaultValue: [KeyID: BlindTarget] { [:] }

    static func reduce(value: inout [KeyID: BlindTarget], nextValue: () -> [KeyID: BlindTarget]) {
        value.merge(nextValue()) { $1 }
    }
}

private struct BlindHoveredTargetKey: EnvironmentKey {
    static let defaultValue: KeyID? = nil
}

extension EnvironmentValues {
    /// The target under the exploring finger, set by `KeyboardSurface` so
    /// each target can ring itself for a sighted helper to follow along.
    var blindHoveredTarget: KeyID? {
        get { self[BlindHoveredTargetKey.self] }
        set { self[BlindHoveredTargetKey.self] = newValue }
    }
}

extension View {
    /// Makes this view a blind-mode target: hovering it speaks `spokenName`,
    /// submitting it runs `action`, and while hovered it wears a ring shaped
    /// like its own corners. A `nil` id reports nothing.
    func blindTarget(
        _ id: KeyID?,
        spokenName: String,
        cornerRadius: CGFloat = 6,
        ringInset: CGFloat = 0,
        action: @escaping () -> String?
    ) -> some View {
        modifier(
            BlindTargetModifier(
                id: id, spokenName: spokenName, cornerRadius: cornerRadius, ringInset: ringInset,
                action: action))
    }
}

private struct BlindTargetModifier: ViewModifier {
    let id: KeyID?
    let spokenName: String
    let cornerRadius: CGFloat
    let ringInset: CGFloat
    let action: () -> String?

    @Environment(\.blindHoveredTarget) private var hovered
    @Environment(\.keyboardPalette) private var palette

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(palette.accent, lineWidth: 3)
                    .padding(.horizontal, ringInset)
                    .opacity(id != nil && hovered == id ? 1 : 0)
                    .allowsHitTesting(false)
            )
            .anchorPreference(key: BlindTargetsPreferenceKey.self, value: .bounds) { anchor in
                guard let id else { return [:] }
                return [id: BlindTarget(anchor: anchor, spokenName: spokenName, action: action)]
            }
    }
}

/// The one key tapped directly in blind mode. The keyboard puts it at the
/// right end of its bottom row; the Names and Phrases panels put it in the
/// same place under themselves, so a finger finds it by feel wherever it is.
struct BlindSubmitKey: View {

    static let width: CGFloat = 76
    static let height: CGFloat = 44

    @Environment(\.keyboardPalette) private var palette

    var body: some View {
        Text("Submit")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: Self.width, height: Self.height)
            .background(palette.accent)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Submit")
            // A real `Button` gets this identifier for free, defaulted from
            // its title; a plain `Text` wearing the button trait by hand
            // does not, so `app.buttons["Submit"]` needs it spelled out.
            .accessibilityIdentifier("Submit")
            .blindTarget(.submit, spokenName: "submit") { nil }
    }
}

/// The multitouch layer that sits over the surface in blind mode. One finger
/// explores — the target under it is the selection — and a touch that lands
/// on Submit commits that selection.
struct BlindModeTouchOverlay: UIViewRepresentable {
    let frames: [KeyID: CGRect]
    /// The hovered target changed; `nil` when the exploring finger lifts.
    let onHover: (KeyID?) -> Void
    /// The exploring finger slid onto Submit.
    let onSubmitHovered: () -> Void
    /// A touch began on Submit.
    let onSubmit: () -> Void

    func makeUIView(context: Context) -> BlindModeTouchView {
        BlindModeTouchView()
    }

    func updateUIView(_ view: BlindModeTouchView, context: Context) {
        view.onHover = onHover
        view.onSubmitHovered = onSubmitHovered
        view.onSubmit = onSubmit
        view.frames = frames
    }
}

final class BlindModeTouchView: UIView {

    var frames: [KeyID: CGRect] = [:] {
        didSet {
            guard frames != oldValue, explorerPoint != nil else { return }
            // Keys reshape after a commit: re-read what is now under the
            // resting finger. Deferred, since the frames arrive mid-render.
            DispatchQueue.main.async { [weak self] in
                guard let self, let point = self.explorerPoint else { return }
                self.updateHover(at: point)
            }
        }
    }
    var onHover: (KeyID?) -> Void = { _ in }
    var onSubmitHovered: () -> Void = {}
    var onSubmit: () -> Void = {}
    /// How far outside every key a point may fall and still pick the nearest
    /// one — wide enough to bridge the gaps between keys and rows.
    var hoverTolerance: CGFloat = 14

    private var explorer: UITouch?
    private var explorerPoint: CGPoint?
    private var hovered: KeyID?
    private var isOverSubmit = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
        isAccessibilityElement = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        var submitTaps = 0
        for touch in touches {
            let point = touch.location(in: self)
            if let submitFrame = frames[.submit], submitFrame.contains(point) {
                submitTaps += 1
            } else if explorer == nil {
                explorer = touch
                explorerPoint = point
                updateHover(at: point)
            }
        }
        // After the loop, so two fingers landing in one event still commit
        // the key under the exploring one.
        for _ in 0..<submitTaps { onSubmit() }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let explorer, touches.contains(explorer) else { return }
        let point = explorer.location(in: self)
        explorerPoint = point
        updateHover(at: point)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        liftExplorer(if: touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        liftExplorer(if: touches)
    }

    private func liftExplorer(if touches: Set<UITouch>) {
        guard let explorer, touches.contains(explorer) else { return }
        self.explorer = nil
        explorerPoint = nil
        isOverSubmit = false
        setHovered(nil)
    }

    private func updateHover(at point: CGPoint) {
        if let submitFrame = frames[.submit], submitFrame.contains(point) {
            if !isOverSubmit {
                isOverSubmit = true
                onSubmitHovered()
            }
            return
        }
        isOverSubmit = false
        // No key within reach keeps the previous selection; only lifting clears it.
        if let hit = key(at: point) { setHovered(hit) }
    }

    private func key(at point: CGPoint) -> KeyID? {
        var nearest: (id: KeyID, distance: CGFloat)?
        for (id, rect) in frames where id != .submit {
            if rect.contains(point) { return id }
            let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
            let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
            let distance = hypot(dx, dy)
            if distance <= hoverTolerance, distance < (nearest?.distance ?? .infinity) {
                nearest = (id, distance)
            }
        }
        return nearest?.id
    }

    private func setHovered(_ id: KeyID?) {
        guard id != hovered else { return }
        hovered = id
        onHover(id)
    }
}
