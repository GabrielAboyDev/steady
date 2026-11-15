import SwiftUI
import UIKit

/// Identity of every key on the surface, for frame reporting and dispatch.
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

/// Bounds of every visible key, collected up the tree as anchors so the
/// overlay can resolve them in its own coordinate space.
struct KeyFramesPreferenceKey: PreferenceKey {
    static var defaultValue: [KeyID: Anchor<CGRect>] { [:] }

    static func reduce(value: inout [KeyID: Anchor<CGRect>], nextValue: () -> [KeyID: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    /// Reports this view's bounds as `id`'s hit frame; `nil` reports nothing.
    func reportsKeyFrame(_ id: KeyID?) -> some View {
        anchorPreference(key: KeyFramesPreferenceKey.self, value: .bounds) { anchor in
            id.map { [$0: anchor] } ?? [:]
        }
    }
}

/// The multitouch layer that sits over the keys in blind mode. One finger
/// explores — the key under it is the selection — and a touch that lands on
/// Submit commits that selection.
struct BlindModeTouchOverlay: UIViewRepresentable {
    let frames: [KeyID: CGRect]
    /// The hovered key changed; `nil` when the exploring finger lifts.
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
